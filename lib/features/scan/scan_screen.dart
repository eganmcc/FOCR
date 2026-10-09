import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ocr/scan_pipeline.dart';
import '../../providers.dart';
import '../review/review_screen.dart';

/// Live scan (US4): grabs a still about every [_interval] while the previous OCR is idle, and
/// auto-locks on the first valid number (research R4: stills work the same on Android, iOS, web).
/// The shutter button captures immediately and always opens the review screen.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> with WidgetsBindingObserver {
  static const _interval = Duration(milliseconds: 800);

  CameraController? _controller;
  String? _fatalError;
  String _status = 'Point at the confirmation screen';
  bool _done = false;
  bool _busy = false;
  bool _manual = false;
  int _attempts = 0;
  Timer? _timer;

  /// The still capture in flight, if any. The camera must not be closed under it: the Android
  /// plugin's capture callbacks then hit a closed device (third_party/camera_android/FOCR_PATCH.md).
  Future<XFile>? _pictureInFlight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stop();
    } else if (state == AppLifecycleState.resumed && _controller == null && !_done) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _fatalError = 'No camera found on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      try {
        await controller.setFlashMode(FlashMode.off);
        await controller.setFocusMode(FocusMode.auto);
      } on CameraException {
        // Not supported on every device; harmless.
      }
      setState(() {
        _controller = controller;
        _fatalError = null;
      });
      _scheduleNext(const Duration(milliseconds: 500)); // let exposure/focus settle
    } on CameraException catch (e) {
      debugPrint('FOCR scan: camera init failed: ${e.code} ${e.description}');
      if (!mounted) return;
      setState(() => _fatalError = switch (e.code) {
            'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
              'Camera permission was denied. Allow it in Settings, or upload a screenshot instead.',
            _ => 'Camera unavailable: ${e.description ?? e.code}',
          });
    }
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    final inFlight = _pictureInFlight;
    if (inFlight == null) {
      controller.dispose();
    } else {
      // Close only once the capture has finished, successfully or not.
      inFlight.then((_) {}, onError: (Object _) {}).whenComplete(controller.dispose);
    }
  }

  void _scheduleNext([Duration delay = Duration.zero]) {
    _timer?.cancel();
    if (_done || _manual) return;
    _timer = Timer(delay, _tick);
  }

  /// Captures one still and runs OCR. Returns null on failure (and shows why).
  Future<ScanResult?> _captureAndScan({required bool tryRotations}) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) {
      return null;
    }
    _busy = true;
    try {
      final picture = _pictureInFlight = controller.takePicture();
      final XFile shot;
      try {
        shot = await picture;
      } finally {
        _pictureInFlight = null;
      }
      if (!mounted || _controller != controller) return null;
      final bytes = await shot.readAsBytes();
      return await ref.read(scanPipelineProvider).scan(bytes, tryRotations: tryRotations);
    } on Object catch (e) {
      debugPrint('FOCR scan: capture/OCR failed: $e');
      if (mounted) setState(() => _status = 'Capture failed: $e');
      return null;
    } finally {
      _busy = false;
    }
  }

  Future<void> _tick() async {
    if (!mounted || _done || _manual) return;
    final started = DateTime.now();
    setState(() {
      _attempts++;
      _status = 'Reading… (frame $_attempts)';
    });
    final result = await _captureAndScan(tryRotations: false);
    if (!mounted || _done) return;
    if (result != null) {
      if (result.found) {
        await _openReview(result);
        return;
      }
      if (!_manual) {
        setState(() => _status = result.rawText.trim().isEmpty
            ? 'No text seen yet (frame $_attempts): move closer, avoid glare'
            : 'Text seen but no valid number yet (frame $_attempts): hold steady');
      }
    }
    final spent = DateTime.now().difference(started);
    _scheduleNext(spent >= _interval ? Duration.zero : _interval - spent);
  }

  /// Shutter: pause auto-scan, wait for an in-flight frame, capture with the full rotation
  /// search, and open the review screen whatever the outcome (manual entry if not found).
  Future<void> _captureNow() async {
    if (_manual || _done) return;
    setState(() {
      _manual = true;
      _status = 'Capturing…';
    });
    _timer?.cancel();
    while (_busy) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    final result = await _captureAndScan(tryRotations: true);
    if (!mounted) return;
    if (result != null) {
      await _openReview(result);
    } else {
      setState(() => _manual = false);
      _scheduleNext(_interval);
    }
  }

  Future<void> _openReview(ScanResult result) async {
    _done = true;
    _stop();
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => ReviewScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan')),
      body: SafeArea(
        child: _fatalError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 16),
                      Text(_fatalError!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Back to upload'),
                      ),
                    ],
                  ),
                ),
              )
            : controller == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(child: Center(child: CameraPreview(controller))),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(_status, key: const Key('scanStatus'), textAlign: TextAlign.center),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        child: Column(
                          children: [
                            const Text(
                              'Detects automatically, or tap the shutter to read this frame now.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            FloatingActionButton.large(
                              key: const Key('shutter'),
                              onPressed: _manual ? null : _captureNow,
                              tooltip: 'Read now',
                              child: _manual
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.camera_alt_outlined),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

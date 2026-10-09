import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/extraction/registration_extractor.dart';
import '../../core/ocr/scan_pipeline.dart';
import '../../data/models.dart';
import '../../providers.dart';
import 'registration_field.dart';
import 'zoomable_image.dart';

/// Shows the image next to an editable, pre-filled number and saves it on confirmation
/// (US1, US3). Either [sourceImage] (runs the scan here), [result] (from live scan), or
/// neither (manual entry).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, this.sourceImage, this.result});

  final Uint8List? sourceImage;
  final ScanResult? result;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _controller = TextEditingController();
  ScanResult? _result;
  bool _scanning = false;
  bool _saving = false;
  String? _error;

  String? get _extracted => switch (_result?.extraction) {
        Found(:final number) => number.value,
        _ => null,
      };

  Uint8List? get _image => _result?.image ?? widget.sourceImage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    if (widget.result != null) {
      _apply(widget.result!);
    } else if (widget.sourceImage != null) {
      _scan(widget.sourceImage!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scan(Uint8List bytes) async {
    setState(() => _scanning = true);
    try {
      final result = await ref.read(scanPipelineProvider).scan(bytes);
      if (mounted) _apply(result);
    } on FormatException {
      if (mounted) setState(() => _error = 'This file is not a readable image.');
    } on Object catch (e) {
      if (mounted) setState(() => _error = 'Text recognition failed: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  void _apply(ScanResult result) {
    setState(() {
      _result = result;
      _controller.text = _extracted ?? '';
    });
  }

  Future<void> _confirm() async {
    final today = ref.read(clockProvider).now();
    final validation = validateTyped(_controller.text, today);
    if (!validation.isValid || _saving) return;
    final number = validation.number!;
    final repo = ref.read(repositoryProvider);

    setState(() => _saving = true);
    try {
      final existing = await repo.findByNumber(number.value);
      var override = false;
      if (existing != null) {
        if (!mounted) return;
        setState(() => _saving = false); // no spinner behind the dialog
        override = await _confirmDuplicate(existing) ?? false;
        if (!override || !mounted) return;
        setState(() => _saving = true);
      }

      String? captureId;
      final image = _result?.image;
      if (image != null) {
        final thumb = await ref.read(imageOpsProvider).normalize(image, maxSide: 1280);
        captureId = await repo.saveCapture(
          CaptureDraft(imageJpeg: thumb, rotationDegrees: _result!.rotationDegrees, rawText: _result!.rawText),
        );
      }

      final extracted = _extracted;
      final method = extracted == null
          ? EntryMethod.manual
          : (extracted == number.value ? EntryMethod.auto : EntryMethod.edited);
      await repo.saveRecord(
        RecordDraft(number: number, captureId: captureId, entryMethod: method, duplicateOverride: override),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${number.value} — waiting to sync')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool?> _confirmDuplicate(RegistrationRecord existing) => showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: const Key('duplicateDialog'),
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Already saved'),
          content: Text(
            '${existing.number} was already saved on '
            '${MaterialLocalizations.of(context).formatMediumDate(existing.confirmedAt.toLocal())} '
            '${TimeOfDay.fromDateTime(existing.confirmedAt.toLocal()).format(context)}.\n\n'
            'Save it again anyway?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(
              key: const Key('saveAnyway'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final validation = validateTyped(_controller.text, ref.watch(clockProvider).now());
    final manualOnly = widget.sourceImage == null && widget.result == null;
    final notFound = _result != null && _extracted == null;

    final form = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_scanning)
          const _Status(icon: null, text: 'Reading the registration number…')
        else if (_error != null)
          _Status(icon: Icons.error_outline, text: _error!)
        else if (notFound)
          const _Status(
            icon: Icons.help_outline,
            text: 'No valid registration number found. Retake the photo, or type it below.',
          )
        else if (_result != null)
          _Status(
            icon: Icons.check_circle_outline,
            text: 'Found in ${(_result!.elapsed.inMilliseconds / 1000).toStringAsFixed(1)} s'
                '${_result!.rotationDegrees == 0 ? '' : ' (image rotated ${_result!.rotationDegrees}°)'}. '
                'Check it against the image.',
          ),
        const SizedBox(height: 16),
        RegistrationField(
          controller: _controller,
          validation: validation,
          autofocus: manualOnly,
          onSubmitted: _confirm,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const Key('confirm'),
          onPressed: validation.isValid && !_scanning && !_saving ? _confirm : null,
          icon: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.done),
          label: const Text('Confirm & save'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ],
    );

    final image = _image;
    return Scaffold(
      appBar: AppBar(title: Text(manualOnly ? 'Enter number' : 'Check number')),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final preview = image == null ? null : ZoomableImage(bytes: image);
            if (preview == null) {
              return ListView(padding: const EdgeInsets.all(16), children: [form]);
            }
            if (constraints.maxWidth >= 720) {
              return Row(
                children: [
                  Expanded(child: preview),
                  SizedBox(
                    width: 380,
                    child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: form),
                  ),
                ],
              );
            }
            // Phone: the zoomable image is NOT inside a scrollable, so pinch gestures aren't
            // stolen by list scrolling. It shrinks when the keyboard opens.
            return Column(
              children: [
                Expanded(child: preview),
                Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 16), child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.text});

  final IconData? icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon == null)
          const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
        else
          Icon(icon),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}

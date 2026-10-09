import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Pinch / pan / double-tap zoomable image with reset and full-screen controls.
///
/// Must not be placed inside a scrollable: the scrollable's drag recognizer competes with the
/// pinch gesture and wins on vertical finger movement (zoom-out stops working).
class ZoomableImage extends StatefulWidget {
  const ZoomableImage({super.key, required this.bytes, this.showFullScreenButton = true});

  final Uint8List bytes;
  final bool showFullScreenButton;

  @override
  State<ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<ZoomableImage> with SingleTickerProviderStateMixin {
  static const double _doubleTapScale = 3;

  final _transform = TransformationController();
  late final AnimationController _anim =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
        ..addListener(() => _transform.value = _tween!.evaluate(_anim));
  Matrix4Tween? _tween;
  Offset? _doubleTapAt;
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _transform.addListener(() {
      final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _tween = Matrix4Tween(begin: _transform.value, end: target);
    _anim.forward(from: 0);
  }

  void _reset() => _animateTo(Matrix4.identity());

  void _onDoubleTap() {
    if (_zoomed) {
      _reset();
      return;
    }
    final p = _doubleTapAt ?? Offset.zero;
    // Zoom so the tapped point stays under the finger.
    _animateTo(Matrix4.identity()
      ..translateByDouble(-p.dx * (_doubleTapScale - 1), -p.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1));
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Image'),
          ),
          body: SafeArea(child: ZoomableImage(bytes: widget.bytes, showFullScreenButton: false)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onDoubleTapDown: (d) => _doubleTapAt = d.localPosition,
          onDoubleTap: _onDoubleTap,
          child: InteractiveViewer(
            transformationController: _transform,
            minScale: 1,
            maxScale: 8,
            clipBehavior: Clip.hardEdge,
            child: Image.memory(widget.bytes, fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Row(
            children: [
              if (_zoomed)
                _OverlayButton(icon: Icons.zoom_out_map, tooltip: 'Reset zoom', onPressed: _reset),
              if (widget.showFullScreenButton) ...[
                const SizedBox(width: 8),
                _OverlayButton(icon: Icons.fullscreen, tooltip: 'Full screen', onPressed: _openFullScreen),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      shape: const CircleBorder(),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}

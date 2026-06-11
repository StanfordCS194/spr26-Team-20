import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;

import '../../app/theme.dart';

class Stroke {
  Stroke(this.points);
  final List<Offset> points;
}

class DrawingController extends ChangeNotifier {
  final List<Stroke> _strokes = [];
  Stroke? _current;

  List<Stroke> get strokes => List.unmodifiable(_strokes);
  bool get isEmpty => _strokes.isEmpty;

  void beginStroke(Offset p) {
    _current = Stroke([p]);
    _strokes.add(_current!);
    notifyListeners();
  }

  void extendStroke(Offset p) {
    _current?.points.add(p);
    notifyListeners();
  }

  void endStroke() {
    _current = null;
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      _strokes.removeLast();
      notifyListeners();
    }
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }
}

class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.controller,
    this.aspectRatio = 1.0,
  });
  final DrawingController controller;
  final double aspectRatio;

  @override
  State<DrawingCanvas> createState() => DrawingCanvasState();
}

class DrawingCanvasState extends State<DrawingCanvas> {
  final GlobalKey _boundaryKey = GlobalKey();

  /// Rasterizes the strokes to a black-on-white PNG.
  ///
  /// Done on the CPU with the `image` package rather than a GPU
  /// `RenderRepaintBoundary.toImage()` readback, because on real iOS devices
  /// (Impeller) that readback comes back blank — it only worked on the
  /// simulator/Android/web (Skia). This path is renderer-independent.
  Uint8List? exportPng({int targetWidth = 384}) {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final size = boundary.size;
    if (size.width == 0) return null;

    final scale = targetWidth / size.width;
    final w = targetWidth;
    final h = (size.height * scale).round().clamp(1, 4000);

    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final black = img.ColorRgb8(0, 0, 0);
    final thickness = (3.0 * scale).round().clamp(1, 24);

    for (final stroke in widget.controller.strokes) {
      final pts = stroke.points;
      if (pts.isEmpty) continue;
      if (pts.length == 1) {
        img.fillCircle(
          image,
          x: (pts.first.dx * scale).round(),
          y: (pts.first.dy * scale).round(),
          radius: (thickness / 2).ceil(),
          color: black,
        );
        continue;
      }
      for (var i = 1; i < pts.length; i++) {
        img.drawLine(
          image,
          x1: (pts[i - 1].dx * scale).round(),
          y1: (pts[i - 1].dy * scale).round(),
          x2: (pts[i].dx * scale).round(),
          y2: (pts[i].dy * scale).round(),
          color: black,
          thickness: thickness,
          antialias: true,
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: RepaintBoundary(
        key: _boundaryKey,
        child: ClipRect(
          child: Container(
            color: Colors.black,
            child: GestureDetector(
              onPanStart: (d) => widget.controller.beginStroke(d.localPosition),
              onPanUpdate: (d) => widget.controller.extendStroke(d.localPosition),
              onPanEnd: (_) => widget.controller.endStroke(),
              child: CustomPaint(
                painter: _StrokesPainter(widget.controller),
                size: Size.infinite,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.controller) : super(repaint: controller);
  final DrawingController controller;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in controller.strokes) {
      if (stroke.points.length < 2) {
        if (stroke.points.length == 1) {
          canvas.drawCircle(stroke.points.first, 1.5, Paint()..color = Colors.white);
        }
        continue;
      }
      final path = Path()..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) => false;
}

class DrawingToolbar extends StatelessWidget {
  const DrawingToolbar({
    super.key,
    required this.controller,
  });
  final DrawingController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final empty = controller.isEmpty;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: empty ? null : controller.undo,
                child: const Text('UNDO'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton(
                onPressed: empty ? null : controller.clear,
                style: OutlinedButton.styleFrom(
                  foregroundColor: PrintimateColors.text,
                ),
                child: const Text('CLEAR'),
              ),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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

  Future<Uint8List?> exportPng({int targetWidth = 384}) async {
    final boundary = _boundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final logicalWidth = boundary.size.width;
    if (logicalWidth == 0) return null;
    final pixelRatio = targetWidth / logicalWidth;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
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

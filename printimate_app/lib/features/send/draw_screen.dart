import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'drawing_canvas.dart';
import 'receipt_pipeline.dart';

/// Full-screen drawing page that handles the whole flow itself: draw, then
/// send straight to [destinationPid].
///
/// It's pushed as its own route (above HomeShell's horizontal PageView and the
/// send page's vertical scroll view), so the canvas pan gesture has no
/// scrollable competitors — drawing works in every direction.
class DrawScreen extends StatefulWidget {
  const DrawScreen({
    super.key,
    required this.controller,
    required this.destinationPid,
  });

  final DrawingController controller;
  final String destinationPid;

  @override
  State<DrawScreen> createState() => _DrawScreenState();
}

class _DrawScreenState extends State<DrawScreen> {
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();
  bool _sending = false;

  Future<void> _send() async {
    if (widget.controller.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw something first.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      // CPU-rasterized black-on-white PNG (renderer-independent — works on
      // real iOS devices where GPU toImage came back blank).
      final png = _canvasKey.currentState?.exportPng(targetWidth: 384);
      if (png == null) throw Exception('Could not capture the drawing.');

      final processed = await processForReceiptPrinter(png);
      final user = FirebaseAuth.instance.currentUser;
      await sendImageToPrinter(
        pid: widget.destinationPid,
        image: processed,
        authorUid: user?.uid ?? '',
        authorName: user?.displayName ?? 'Unknown',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent → ${widget.destinationPid}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PrintimateColors.background,
      appBar: AppBar(
        backgroundColor: PrintimateColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: PrintimateColors.text),
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'DRAW',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(letterSpacing: 2),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.print_outlined,
                      size: 16, color: PrintimateColors.textDim),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sending to ${widget.destinationPid}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: PrintimateColors.textDim,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: PrintimateColors.border),
                    ),
                    child: DrawingCanvas(
                      key: _canvasKey,
                      controller: widget.controller,
                      aspectRatio: 1.0,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DrawingToolbar(controller: widget.controller),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('SEND  →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

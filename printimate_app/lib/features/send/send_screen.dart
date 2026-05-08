import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;


import '../../app/theme.dart';
import '../profile/profile_repository.dart';
import 'drawing_canvas.dart';

const int _printerWidthPx = 384;
const String _defaultServerUrl = 'http://localhost:3000';

enum _Source { text, photo, draw }

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _messageCtl = TextEditingController();
  final _printerIdCtl = TextEditingController();
  final _picker = ImagePicker();
  final _drawingController = DrawingController();
  final GlobalKey<DrawingCanvasState> _canvasKey = GlobalKey();

  _Source _source = _Source.text;
  Uint8List? _previewBytes;
  Uint8List? _selectedRawBytes;
  bool _processing = false;
  bool _sending = false;
  String _sendStatus = '';
  String? _error;
  String? _info;
  String _serverUrl = _defaultServerUrl;

  @override
  void initState() {
    super.initState();
    _fetchServerUrl();
  }

  Future<void> _fetchServerUrl() async {
    try {
      final response = await http.get(
        Uri.parse('$_defaultServerUrl/server-info'),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _serverUrl = data['primaryUrl'] ?? _defaultServerUrl;
        });
      }
    } catch (e) {
      // Fall back to default if fetch fails
      debugPrint('Failed to fetch server URL: $e');
    }
  }

  @override
  void dispose() {
    _messageCtl.dispose();
    _printerIdCtl.dispose();
    _drawingController.dispose();
    super.dispose();
  }

  void _setSource(_Source s) {
    if (s == _source) return;
    setState(() {
      _source = s;
      _previewBytes = null;
      _selectedRawBytes = null;
      _info = null;
      _error = null;
    });
  }

  Future<void> _pickImage() async {
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
      );
      if (picked == null) return;
      final mime = picked.mimeType ?? '';
      final name = picked.name.toLowerCase();
      if (name.endsWith('.gif') || mime == 'image/gif') {
        setState(() => _error = 'Animated images aren\'t supported.');
        return;
      }
      setState(() => _processing = true);
      final raw = await picked.readAsBytes();
      final decoder = img.findDecoderForData(raw);
      if (decoder == null) {
        setState(() => _error = 'Unsupported image format.');
        return;
      }
      final probed = decoder.decode(raw);
      if (probed == null) {
        setState(() => _error = 'Could not read image.');
        return;
      }
      if (probed.numFrames > 1) {
        setState(() => _error = 'Animated images aren\'t supported.');
        return;
      }
      final preview = await compute(_grayscaleOnly, raw);
      if (!mounted) return;
      setState(() {
        _previewBytes = preview;
        _selectedRawBytes = raw;
        _info = '${probed.width}×${probed.height}px';
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load image: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _clearImage() {
    setState(() {
      _previewBytes = null;
      _selectedRawBytes = null;
      _info = null;
    });
  }

  Future<Uint8List?> _captureDrawingRaw() async {
    final state = _canvasKey.currentState;
    if (state == null) return null;
    final png = await state.exportPng(targetWidth: _printerWidthPx);
    if (png == null) return null;
    final decoded = img.decodeImage(png);
    if (decoded == null) return null;
    // Canvas is white-on-black for visual contrast; printer needs black-on-white.
    final inverted = img.invert(decoded);
    return Uint8List.fromList(img.encodePng(inverted));
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _sendStatus = 'PREPARING...';
      _error = null;
    });
    try {
      Uint8List rawForPipeline;
      String sourceLabel;

      switch (_source) {
        case _Source.text:
          final text = _messageCtl.text.trim();
          if (text.isEmpty) {
            setState(() => _error = 'Type a message first.');
            return;
          }
          setState(() => _sendStatus = 'RENDERING TEXT...');
          rawForPipeline = await _renderTextToPng(text);
          sourceLabel = 'text';
          break;
        case _Source.photo:
          if (_selectedRawBytes == null) {
            setState(() => _error = 'Attach an image first.');
            return;
          }
          rawForPipeline = _selectedRawBytes!;
          sourceLabel = 'photo';
          break;
        case _Source.draw:
          if (_drawingController.isEmpty) {
            setState(() => _error = 'Draw something first.');
            return;
          }
          final drawing = await _captureDrawingRaw();
          if (drawing == null) {
            setState(() => _error = 'Could not capture drawing.');
            return;
          }
          rawForPipeline = drawing;
          sourceLabel = 'drawing';
          break;
      }

      setState(() => _sendStatus = 'PROCESSING IMAGE...');
      final processed = await _processForReceiptPrinter(rawForPipeline);

      setState(() => _sendStatus = 'UPLOADING...');
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = ref
          .read(firebaseStorageProvider)
          .ref('messages/$uid/$timestamp.png');
      await storageRef.putData(
        processed.pngBytes,
        SettableMetadata(
          contentType: 'image/png',
          customMetadata: {
            'senderUid': uid,
            'createdAtMs': '$timestamp',
            'source': sourceLabel,
            'widthPx': '${processed.width}',
            'heightPx': '${processed.height}',
          },
        ),
      );

      setState(() => _sendStatus = 'SENDING TO SERVER...');
      final printerId = _printerIdCtl.text.trim();
      if (printerId.isEmpty) {
        setState(() => _error = 'Enter a printer ID first.');
        return;
      }

      final messageText = sourceLabel == 'text' ? _messageCtl.text : '[${sourceLabel.toUpperCase()}]';
      final currentUser = FirebaseAuth.instance.currentUser!;

      try {
        final response = await http.post(
          Uri.parse('$_serverUrl/send?pid=$printerId'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'authorUid': currentUser.uid,
            'authorName': currentUser.displayName ?? 'Unknown',
            'messageText': messageText,
            'images': [],
          }),
        );

        if (response.statusCode != 201) {
          throw Exception('Server returned ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        if (mounted) setState(() => _error = 'Server send failed: $e');
        return;
      }

      if (!mounted) return;
      _messageCtl.clear();
      _clearImage();
      _drawingController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sent → messages/$uid/$timestamp.png')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Send failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
          _sendStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.print_outlined,
                        color: PrintimateColors.text),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('SEND',
                          style: Theme.of(context).textTheme.headlineMedium),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(color: PrintimateColors.border, height: 1),
                const SizedBox(height: 24),
                _SourceToggle(value: _source, onChanged: _setSource),
                const SizedBox(height: 24),
                _buildPrinterSelector(context),
                const SizedBox(height: 24),
                if (_source == _Source.text) _buildText(context),
                if (_source == _Source.photo) _buildPhoto(context),
                if (_source == _Source.draw) _buildDraw(context),
                const SizedBox(height: 24),
                if (_error != null) ...[
                  Text(_error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent)),
                  const SizedBox(height: 12),
                ],
                OutlinedButton(
                  onPressed: _sending ? null : _send,
                  child: const Text('SEND  →'),
                ),
              ],
            ),
          ),
        ),
        if (_sending) _SendingOverlay(status: _sendStatus),
      ],
    );
  }

  Widget _buildPrinterSelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('PRINTER ID', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _printerIdCtl,
          decoration: const InputDecoration(
            hintText: 'Enter printer ID...',
          ),
        ),
      ],
    );
  }

  Widget _buildText(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('MESSAGE', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _messageCtl,
          maxLines: 6,
          minLines: 4,
          decoration: const InputDecoration(
            hintText: 'Type something to print...',
          ),
        ),
      ],
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final hasImage = _previewBytes != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('IMAGE', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (hasImage)
          _ImagePreview(bytes: _previewBytes!, onClear: _clearImage)
        else
          OutlinedButton(
            onPressed: _processing ? null : _pickImage,
            child: _processing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PrintimateColors.text,
                    ),
                  )
                : const Text('+  ATTACH IMAGE'),
          ),
        if (_info != null) ...[
          const SizedBox(height: 8),
          Text(_info!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildDraw(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('DRAW', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: PrintimateColors.border),
          ),
          child: DrawingCanvas(
            key: _canvasKey,
            controller: _drawingController,
            aspectRatio: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        DrawingToolbar(controller: _drawingController),
      ],
    );
  }
}

class _SendingOverlay extends StatelessWidget {
  const _SendingOverlay({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: PrintimateColors.text,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontFamilyFallback: ['Menlo', 'monospace'],
                  color: PrintimateColors.text,
                  fontSize: 13,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceToggle extends StatelessWidget {
  const _SourceToggle({required this.value, required this.onChanged});
  final _Source value;
  final ValueChanged<_Source> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = [
      (_Source.text, 'TEXT'),
      (_Source.photo, 'PHOTO'),
      (_Source.draw, 'DRAW'),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: PrintimateColors.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(items[i].$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: value == items[i].$1
                        ? PrintimateColors.text
                        : Colors.transparent,
                    border: i == 0
                        ? null
                        : const Border(
                            left: BorderSide(color: PrintimateColors.border),
                          ),
                  ),
                  child: Text(
                    items[i].$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Courier',
                      fontFamilyFallback: const ['Menlo', 'monospace'],
                      color: value == items[i].$1
                          ? PrintimateColors.background
                          : PrintimateColors.textDim,
                      fontSize: 13,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({required this.bytes, required this.onClear});
  final Uint8List bytes;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: PrintimateColors.surface,
        border: Border.all(color: PrintimateColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Image.memory(bytes, fit: BoxFit.contain),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onClear,
                child: const Text('REMOVE',
                    style: TextStyle(color: PrintimateColors.textDim)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcessedImage {
  const _ProcessedImage({
    required this.pngBytes,
    required this.base64,
    required this.width,
    required this.height,
  });
  final Uint8List pngBytes;
  final String base64;
  final int width;
  final int height;
}

Future<_ProcessedImage> _processForReceiptPrinter(Uint8List raw) {
  return compute(_resizeGrayscaleDither, raw);
}

_ProcessedImage _resizeGrayscaleDither(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Unsupported image format.');
  }
  final resized = decoded.width == _printerWidthPx
      ? decoded
      : img.copyResize(decoded, width: _printerWidthPx);
  final gray = img.grayscale(resized);
  final dithered = img.ditherImage(
    gray,
    kernel: img.DitherKernel.floydSteinberg,
    serpentine: true,
  );
  final pngBytes = Uint8List.fromList(img.encodePng(dithered));
  return _ProcessedImage(
    pngBytes: pngBytes,
    base64: base64Encode(pngBytes),
    width: dithered.width,
    height: dithered.height,
  );
}

Uint8List _grayscaleOnly(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Unsupported image format.');
  }
  final gray = img.grayscale(decoded);
  return Uint8List.fromList(img.encodePng(gray));
}

Future<Uint8List> _renderTextToPng(String text) async {
  const padding = 16.0;
  const fontSize = 22.0;
  const lineHeight = 1.3;
  final maxWidth = _printerWidthPx - padding * 2;

  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        fontFamily: 'Courier',
        fontFamilyFallback: ['Menlo', 'monospace'],
        color: Color(0xFF000000),
        fontSize: fontSize,
        height: lineHeight,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  painter.layout(maxWidth: maxWidth);

  final width = _printerWidthPx;
  final height = (painter.height + padding * 2).ceil();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFFFFFFFF),
  );
  painter.paint(canvas, const Offset(padding, padding));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

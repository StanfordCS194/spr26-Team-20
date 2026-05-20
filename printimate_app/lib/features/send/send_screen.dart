import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';

const int _printerWidthPx = 384;

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  final _messageCtl = TextEditingController();
  final _picker = ImagePicker();

  Uint8List? _previewBytes;
  String? _base64Image;
  bool _processing = false;
  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _messageCtl.dispose();
    super.dispose();
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
      setState(() => _processing = true);
      final raw = await picked.readAsBytes();
      final result = await _processForReceiptPrinter(raw);
      if (!mounted) return;
      setState(() {
        _previewBytes = result.pngBytes;
        _base64Image = result.base64;
        _info = '${result.width}×${result.height}px • '
            '${(result.pngBytes.lengthInBytes / 1024).toStringAsFixed(1)} KB '
            '• base64 ${(result.base64.length / 1024).toStringAsFixed(1)} KB';
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
      _base64Image = null;
      _info = null;
    });
  }

  Future<void> _send() async {
    final text = _messageCtl.text.trim();
    if (text.isEmpty && _base64Image == null) {
      setState(() => _error = 'Add a message or an image first.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      // TODO: write to Firestore once the endpoint is provided.
      // Example shape (subject to change):
      // await FirebaseFirestore.instance.collection('messages').add({
      //   'senderUid': FirebaseAuth.instance.currentUser!.uid,
      //   'body': text,
      //   'imageBase64': _base64Image,         // 1-bit PNG, FS-dithered
      //   'imageWidth': _printerWidthPx,
      //   'createdAt': FieldValue.serverTimestamp(),
      //   'status': 'queued',
      // });
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      _messageCtl.clear();
      _clearImage();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queued (stub — Firestore endpoint TBD).')),
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'Send failed: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider).signOut();
    if (mounted) context.go('/intro');
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _previewBytes != null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.print_outlined, color: PrintimateColors.text),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('COMPOSE',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  IconButton(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout, color: PrintimateColors.textDim),
                    tooltip: 'Sign out',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: PrintimateColors.border, height: 1),
              const SizedBox(height: 32),
              Text('MESSAGE:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _messageCtl,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Type something to print...',
                ),
              ),
              const SizedBox(height: 24),
              Text('IMAGE (OPTIONAL):',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              if (hasImage) _ImagePreview(
                bytes: _previewBytes!,
                onClear: _clearImage,
              ) else OutlinedButton(
                onPressed: _processing ? null : _pickImage,
                child: _processing
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PrintimateColors.text),
                      )
                    : const Text('+  ATTACH IMAGE'),
              ),
              if (_info != null) ...[
                const SizedBox(height: 8),
                Text(_info!, style: Theme.of(context).textTheme.bodyMedium),
              ],
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PrintimateColors.text),
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

Future<_ProcessedImage> _processForReceiptPrinter(Uint8List raw) async {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Unsupported image format.');
  }
  // 1. Resize so width matches the receipt printer head.
  final resized = decoded.width == _printerWidthPx
      ? decoded
      : img.copyResize(decoded, width: _printerWidthPx);
  // 2. Grayscale.
  final gray = img.grayscale(resized);
  // 3. Floyd–Steinberg dither down to 2 colors (pure black / pure white).
  final dithered = img.ditherImage(
    gray,
    kernel: img.DitherKernel.floydSteinberg,
    serpentine: true,
  );
  // 4. Encode PNG and base64.
  final pngBytes = Uint8List.fromList(img.encodePng(dithered));
  final b64 = base64Encode(pngBytes);
  return _ProcessedImage(
    pngBytes: pngBytes,
    base64: b64,
    width: dithered.width,
    height: dithered.height,
  );
}

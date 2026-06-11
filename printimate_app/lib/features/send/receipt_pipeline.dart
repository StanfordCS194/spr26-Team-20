import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../app/config.dart';

const int kPrinterWidthPx = 384;
const int kMaxPrintHeightPx = 800;

/// A 1-bit-per-pixel image ready to send to the thermal printer.
class ProcessedImage {
  const ProcessedImage({
    required this.width,
    required this.height,
    required this.bitmapBase64,
  });
  final int width;
  final int height;
  final String bitmapBase64;
}

/// Resize to printer width, grayscale, then Floyd–Steinberg dither to 1bpp.
/// Runs off the UI isolate.
Future<ProcessedImage> processForReceiptPrinter(Uint8List raw) {
  return compute(_resizeGrayscaleDither, raw);
}

ProcessedImage _resizeGrayscaleDither(Uint8List raw) {
  final decoded = img.decodeImage(raw);
  if (decoded == null) {
    throw Exception('Unsupported image format.');
  }
  var resized = decoded.width == kPrinterWidthPx
      ? decoded
      : img.copyResize(decoded, width: kPrinterWidthPx);
  if (resized.height > kMaxPrintHeightPx) {
    final cropY = (resized.height - kMaxPrintHeightPx) ~/ 2;
    resized = img.copyCrop(
      resized,
      x: 0,
      y: cropY,
      width: resized.width,
      height: kMaxPrintHeightPx,
    );
  }
  final gray = img.grayscale(resized);

  final w = gray.width;
  final h = gray.height;
  final bytesPerRow = (w + 7) ~/ 8;
  final out = Uint8List(bytesPerRow * h);

  var errCurr = List<double>.filled(w, 0.0);
  var errNext = List<double>.filled(w, 0.0);

  for (var y = 0; y < h; y++) {
    final rowOffset = y * bytesPerRow;
    final ltr = y.isEven;

    for (var i = 0; i < w; i++) {
      final x = ltr ? i : w - 1 - i;
      final oldVal = (gray.getPixel(x, y).r as num).toDouble() + errCurr[x];
      final newVal = oldVal < 128.0 ? 0.0 : 255.0;
      final error = oldVal - newVal;

      if (newVal == 0.0) {
        out[rowOffset + (x >> 3)] |= 0x80 >> (x & 7);
      }

      final xFwd = ltr ? x + 1 : x - 1;
      final xBwd = ltr ? x - 1 : x + 1;
      if (xFwd >= 0 && xFwd < w) errCurr[xFwd] += error * (7.0 / 16.0);
      if (y + 1 < h) {
        if (xBwd >= 0 && xBwd < w) errNext[xBwd] += error * (3.0 / 16.0);
        errNext[x] += error * (5.0 / 16.0);
        if (xFwd >= 0 && xFwd < w) errNext[xFwd] += error * (1.0 / 16.0);
      }
    }

    final tmp = errCurr;
    errCurr = errNext;
    errNext = tmp;
    errNext.fillRange(0, w, 0.0);
  }

  return ProcessedImage(
    width: w,
    height: h,
    bitmapBase64: base64Encode(out),
  );
}

/// POSTs a processed image to the printer's `/send` endpoint. Throws on failure.
Future<void> sendImageToPrinter({
  required String pid,
  required ProcessedImage image,
  required String authorUid,
  required String authorName,
  String messageText = '',
}) async {
  final response = await http.post(
    Uri.parse('${Config.serverBaseUrl}/send?pid=$pid'),
    headers: const {'Content-Type': 'application/json'},
    body: jsonEncode({
      'authorUid': authorUid,
      'authorName': authorName,
      'messageText': messageText,
      'images': [
        {
          'width': image.width,
          'height': image.height,
          'bitmap': image.bitmapBase64,
        },
      ],
    }),
  );
  if (response.statusCode != 201) {
    throw Exception('Server returned ${response.statusCode}: ${response.body}');
  }
}

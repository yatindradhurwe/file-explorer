import 'dart:typed_data';
import 'package:file_explorer/services/media_tools_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Noisy photo-like image so JPEG quality has a visible effect on size.
Uint8List _photo(int w, int h) {
  final image = img.Image(width: w, height: h);
  for (final px in image) {
    px
      ..r = (px.x * 7 + px.y * 3) % 256
      ..g = (px.x * px.y) % 256
      ..b = (px.y * 11) % 256;
  }
  return img.encodeJpg(image, quality: 100);
}

void main() {
  group('resizeWorker', () {
    test('keeps aspect ratio when fitting into a box', () {
      final out = resizeWorker({
        'bytes': _photo(400, 200),
        'width': 100,
        'height': 100,
        'keepAspect': true,
        'png': false,
        'quality': 90,
      });
      expect(out['width'], 100);
      expect(out['height'], 50);
      final decoded = img.decodeJpg(out['bytes'] as Uint8List)!;
      expect(decoded.width, 100);
    });

    test('stretches to exact size without aspect lock', () {
      final out = resizeWorker({
        'bytes': _photo(400, 200),
        'width': 120,
        'height': 300,
        'keepAspect': false,
        'png': true,
        'quality': 90,
      });
      final decoded = img.decodePng(out['bytes'] as Uint8List)!;
      expect(decoded.width, 120);
      expect(decoded.height, 300);
    });
  });

  group('compressWorker', () {
    test('lower quality yields a smaller file', () {
      final src = _photo(300, 300);
      final hi = compressWorker({'bytes': src, 'quality': 90, 'maxSide': null, 'targetKb': null});
      final lo = compressWorker({'bytes': src, 'quality': 20, 'maxSide': null, 'targetKb': null});
      expect((lo['bytes'] as Uint8List).length, lessThan((hi['bytes'] as Uint8List).length));
    });

    test('respects max side', () {
      final out = compressWorker({'bytes': _photo(800, 400), 'quality': 70, 'maxSide': 200, 'targetKb': null});
      expect(out['width'], 200);
      expect(out['height'], 100);
    });

    test('lands under the target size', () {
      final out = compressWorker({'bytes': _photo(600, 600), 'quality': 70, 'maxSide': null, 'targetKb': 15});
      expect((out['bytes'] as Uint8List).length, lessThanOrEqualTo(15 * 1024));
    });
  });

  group('plainBackgroundWorker', () {
    test('makes a solid backdrop transparent and keeps the subject', () {
      final image = img.Image(width: 100, height: 100, numChannels: 4);
      img.fill(image, color: img.ColorRgba8(255, 255, 255, 255));
      img.fillRect(image, x1: 30, y1: 30, x2: 70, y2: 70, color: img.ColorRgba8(200, 20, 20, 255));

      final png = plainBackgroundWorker({'png': img.encodePng(image), 'tolerance': 40});
      final out = img.decodePng(png)!;

      // Trimmed to the red square.
      expect(out.width, inInclusiveRange(40, 42));
      expect(out.height, inInclusiveRange(40, 42));
      final centre = out.getPixel(out.width ~/ 2, out.height ~/ 2);
      expect(centre.a, 255);
      expect(centre.r, 200);
    });
  });
}

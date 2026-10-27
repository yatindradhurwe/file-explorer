import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'storage_service.dart';

enum ImageOutputFormat { jpg, png }

enum BackgroundRemovalMode { ai, plainColor }

class ImageToolResult {
  final File file;
  final int originalBytes;
  final int outputBytes;
  final int width;
  final int height;

  ImageToolResult({
    required this.file,
    required this.originalBytes,
    required this.outputBytes,
    required this.width,
    required this.height,
  });
}

class PdfToolResult {
  final File file;
  final int originalBytes;
  final int outputBytes;
  final int pageCount;

  PdfToolResult({
    required this.file,
    required this.originalBytes,
    required this.outputBytes,
    required this.pageCount,
  });
}

/// Offline image & PDF utilities: background removal, resize, compress.
class MediaToolsService {
  static const int _maxSegmentationSide = 2048;

  /// Output folder for image tools: `<root>/Pictures/File Explore`
  static Future<Directory> imageOutputDir() async {
    return _outputDir(['Pictures', 'File Explore']);
  }

  /// Output folder for PDF tools: `<root>/Documents/File Explore`
  static Future<Directory> pdfOutputDir() async {
    return _outputDir(['Documents', 'File Explore']);
  }

  static Future<Directory> _outputDir(List<String> parts) async {
    Directory dir;
    try {
      final root = await StorageService.getRootPath();
      dir = Directory(p.joinAll([root, ...parts]));
      if (!await dir.exists()) await dir.create(recursive: true);
    } catch (_) {
      final fallback = await getApplicationDocumentsDirectory();
      dir = Directory(p.joinAll([fallback.path, ...parts]));
      if (!await dir.exists()) await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<File> _uniqueFile(Directory dir, String baseName, String ext) async {
    var candidate = File(p.join(dir.path, '$baseName.$ext'));
    var i = 1;
    while (await candidate.exists()) {
      candidate = File(p.join(dir.path, '${baseName}_$i.$ext'));
      i++;
    }
    return candidate;
  }

  // ---------------------------------------------------------------------------
  // Image resize / compress
  // ---------------------------------------------------------------------------

  /// Resizes [source] to fit [width] x [height]. When [keepAspect] is true the
  /// image is scaled to fit inside the box; null dimensions are computed from
  /// the aspect ratio.
  static Future<ImageToolResult> resizeImage({
    required File source,
    int? width,
    int? height,
    bool keepAspect = true,
    ImageOutputFormat format = ImageOutputFormat.jpg,
    int quality = 92,
  }) async {
    final bytes = await source.readAsBytes();
    final encoded = await compute(resizeWorker, {
      'bytes': bytes,
      'width': width,
      'height': height,
      'keepAspect': keepAspect,
      'png': format == ImageOutputFormat.png,
      'quality': quality,
    });
    final dir = await imageOutputDir();
    final base = '${p.basenameWithoutExtension(source.path)}_resized';
    final out = await _uniqueFile(dir, base, format == ImageOutputFormat.png ? 'png' : 'jpg');
    await out.writeAsBytes(encoded['bytes'] as Uint8List);
    return ImageToolResult(
      file: out,
      originalBytes: bytes.length,
      outputBytes: (encoded['bytes'] as Uint8List).length,
      width: encoded['width'] as int,
      height: encoded['height'] as int,
    );
  }

  /// Compresses [source] to JPEG at [quality], optionally downscaling so the
  /// longest side is at most [maxSide]. When [targetKb] is set, quality is
  /// searched (binary search) to land at or under that size.
  static Future<ImageToolResult> compressImage({
    required File source,
    int quality = 70,
    int? maxSide,
    int? targetKb,
  }) async {
    final bytes = await source.readAsBytes();
    final encoded = await compute(compressWorker, {
      'bytes': bytes,
      'quality': quality,
      'maxSide': maxSide,
      'targetKb': targetKb,
    });
    final dir = await imageOutputDir();
    final base = '${p.basenameWithoutExtension(source.path)}_compressed';
    final out = await _uniqueFile(dir, base, 'jpg');
    final outBytes = encoded['bytes'] as Uint8List;
    await out.writeAsBytes(outBytes);
    return ImageToolResult(
      file: out,
      originalBytes: bytes.length,
      outputBytes: outBytes.length,
      width: encoded['width'] as int,
      height: encoded['height'] as int,
    );
  }

  // ---------------------------------------------------------------------------
  // Background removal
  // ---------------------------------------------------------------------------

  /// Removes the background of [source] and saves a transparent PNG.
  ///
  /// [BackgroundRemovalMode.ai] uses ML Kit subject segmentation, which runs
  /// on-device (the model is fetched once by Google Play services). If it is
  /// unavailable, the plain-colour algorithm is used instead, which works fully
  /// offline and suits product shots / documents on a uniform backdrop.
  static Future<({ImageToolResult result, bool usedAi})> removeBackground({
    required File source,
    BackgroundRemovalMode mode = BackgroundRemovalMode.ai,
    int tolerance = 40,
  }) async {
    final originalBytes = await source.length();
    // Normalise orientation and size first so the mask lines up exactly with
    // the pixels we composite.
    final prepared = await compute(_prepareWorker, {
      'bytes': await source.readAsBytes(),
      'maxSide': _maxSegmentationSide,
    });

    Uint8List? png;
    var usedAi = false;
    if (mode == BackgroundRemovalMode.ai && Platform.isAndroid) {
      try {
        final mask = await _segmentationMask(prepared);
        if (mask != null) {
          png = await compute(_applyMaskWorker, {
            'png': prepared,
            'mask': mask,
          });
          usedAi = true;
        }
      } catch (e) {
        debugPrint('AI background removal unavailable, falling back: $e');
      }
    }
    final Uint8List output = png ?? await compute(plainBackgroundWorker, {
      'png': prepared,
      'tolerance': tolerance,
    });

    final decoded = img.decodePng(output)!;
    final dir = await imageOutputDir();
    final base = '${p.basenameWithoutExtension(source.path)}_nobg';
    final out = await _uniqueFile(dir, base, 'png');
    await out.writeAsBytes(output);
    return (
      result: ImageToolResult(
        file: out,
        originalBytes: originalBytes,
        outputBytes: output.length,
        width: decoded.width,
        height: decoded.height,
      ),
      usedAi: usedAi,
    );
  }

  static Future<Float32List?> _segmentationMask(Uint8List preparedPng) async {
    final tmpDir = await getTemporaryDirectory();
    final tmp = File(p.join(tmpDir.path, 'seg_${DateTime.now().microsecondsSinceEpoch}.png'));
    await tmp.writeAsBytes(preparedPng);
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );
    try {
      final result = await segmenter.processImage(InputImage.fromFilePath(tmp.path));
      final mask = result.foregroundConfidenceMask;
      if (mask == null || mask.isEmpty) return null;
      return Float32List.fromList(mask);
    } finally {
      await segmenter.close();
      if (await tmp.exists()) await tmp.delete();
    }
  }

  // ---------------------------------------------------------------------------
  // PDF compress / resize
  // ---------------------------------------------------------------------------

  /// Re-renders each page of [source] at [dpi] and re-encodes it as JPEG at
  /// [quality]. When [pageFormat] is set, each page is fitted onto that paper
  /// size (PDF resize); otherwise the original page size is kept.
  ///
  /// Pages become images, so text is no longer selectable in the output.
  static Future<PdfToolResult> rebuildPdf({
    required File source,
    required double dpi,
    required int quality,
    PdfPageFormat? pageFormat,
    bool grayscale = false,
    String suffix = 'compressed',
    void Function(int pagesDone)? onProgress,
  }) async {
    final bytes = await source.readAsBytes();
    final info = await Printing.info();
    if (!info.canRaster) {
      throw UnsupportedError('PDF rendering is not supported on this device');
    }

    final doc = pw.Document(compress: true);
    var pageCount = 0;
    await for (final page in Printing.raster(bytes, dpi: dpi)) {
      pageCount++;
      final jpg = await compute(_rasterToJpegWorker, {
        'pixels': page.pixels,
        'width': page.width,
        'height': page.height,
        'quality': quality,
        'grayscale': grayscale,
      });
      // Original page size in points = pixels / dpi * 72.
      final originalFormat = PdfPageFormat(
        page.width / dpi * PdfPageFormat.inch,
        page.height / dpi * PdfPageFormat.inch,
      );
      var format = pageFormat ?? originalFormat;
      if (pageFormat != null) {
        // Match the target paper's orientation to the source page.
        final landscape = originalFormat.width > originalFormat.height;
        format = landscape ? pageFormat.landscape : pageFormat.portrait;
      }
      final image = pw.MemoryImage(jpg);
      doc.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain)),
        ),
      );
      onProgress?.call(pageCount);
    }
    if (pageCount == 0) {
      throw StateError('No pages could be read from this PDF');
    }

    final outBytes = await doc.save();
    final dir = await pdfOutputDir();
    final base = '${p.basenameWithoutExtension(source.path)}_$suffix';
    final out = await _uniqueFile(dir, base, 'pdf');
    await out.writeAsBytes(outBytes);
    return PdfToolResult(
      file: out,
      originalBytes: bytes.length,
      outputBytes: outBytes.length,
      pageCount: pageCount,
    );
  }
}

// -----------------------------------------------------------------------------
// Isolate workers (top-level so they can run in compute()).
// -----------------------------------------------------------------------------

img.Image _decodeOriented(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw const FormatException('Unsupported or corrupted image');
  }
  return img.bakeOrientation(decoded);
}

img.Image _flattenOnWhite(img.Image src) {
  if (!src.hasAlpha) return src;
  final canvas = img.Image(width: src.width, height: src.height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, src);
  return canvas;
}

img.Image _fitMaxSide(img.Image src, int? maxSide) {
  if (maxSide == null) return src;
  final longest = src.width > src.height ? src.width : src.height;
  if (longest <= maxSide) return src;
  return src.width >= src.height
      ? img.copyResize(src, width: maxSide, interpolation: img.Interpolation.average)
      : img.copyResize(src, height: maxSide, interpolation: img.Interpolation.average);
}

@visibleForTesting
Map<String, Object> resizeWorker(Map<String, Object?> args) {
  final src = _decodeOriented(args['bytes'] as Uint8List);
  final reqW = args['width'] as int?;
  final reqH = args['height'] as int?;
  final keepAspect = args['keepAspect'] as bool;
  final png = args['png'] as bool;

  img.Image out;
  if (reqW == null && reqH == null) {
    out = src;
  } else if (keepAspect) {
    final scaleW = reqW != null ? reqW / src.width : double.infinity;
    final scaleH = reqH != null ? reqH / src.height : double.infinity;
    final scale = scaleW < scaleH ? scaleW : scaleH;
    out = img.copyResize(
      src,
      width: (src.width * scale).round().clamp(1, 20000),
      height: (src.height * scale).round().clamp(1, 20000),
      interpolation: scale < 1 ? img.Interpolation.average : img.Interpolation.cubic,
    );
  } else {
    out = img.copyResize(
      src,
      width: reqW ?? src.width,
      height: reqH ?? src.height,
      interpolation: img.Interpolation.cubic,
    );
  }

  final bytes = png
      ? img.encodePng(out)
      : img.encodeJpg(_flattenOnWhite(out), quality: args['quality'] as int);
  return {'bytes': bytes, 'width': out.width, 'height': out.height};
}

@visibleForTesting
Map<String, Object> compressWorker(Map<String, Object?> args) {
  final src = _flattenOnWhite(
    _fitMaxSide(_decodeOriented(args['bytes'] as Uint8List), args['maxSide'] as int?),
  );
  final targetKb = args['targetKb'] as int?;
  Uint8List bytes;
  if (targetKb == null) {
    bytes = img.encodeJpg(src, quality: args['quality'] as int);
  } else {
    final limit = targetKb * 1024;
    var lo = 5, hi = 95;
    Uint8List? best;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      final attempt = img.encodeJpg(src, quality: mid);
      if (attempt.length <= limit) {
        best = attempt;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    // Even the lowest quality may be too big; shrink dimensions until it fits.
    var working = src;
    while (best == null) {
      working = img.copyResize(
        working,
        width: (working.width * 0.8).round().clamp(1, 20000),
        interpolation: img.Interpolation.average,
      );
      final attempt = img.encodeJpg(working, quality: 30);
      if (attempt.length <= limit || working.width <= 64) best = attempt;
    }
    bytes = best;
  }
  final decoded = img.decodeJpg(bytes)!;
  return {'bytes': bytes, 'width': decoded.width, 'height': decoded.height};
}

Uint8List _prepareWorker(Map<String, Object?> args) {
  final src = _fitMaxSide(_decodeOriented(args['bytes'] as Uint8List), args['maxSide'] as int);
  return img.encodePng(src.convert(numChannels: 4));
}

Uint8List _applyMaskWorker(Map<String, Object?> args) {
  final src = img.decodePng(args['png'] as Uint8List)!.convert(numChannels: 4);
  final mask = args['mask'] as Float32List;
  final w = src.width, h = src.height;
  if (mask.length != w * h) {
    throw StateError('Mask size ${mask.length} does not match image ${w}x$h');
  }
  for (final px in src) {
    final c = mask[px.y * w + px.x];
    // Soften the edge: hard cut below 0.15, full above 0.85.
    final a = ((c - 0.15) / 0.7).clamp(0.0, 1.0);
    px.a = (px.a * a).round();
  }
  return img.encodePng(_trimTransparent(src));
}

/// Flood-fills from every border pixel through pixels whose colour is close to
/// the dominant border colour, making them transparent.
@visibleForTesting
Uint8List plainBackgroundWorker(Map<String, Object?> args) {
  final src = img.decodePng(args['png'] as Uint8List)!.convert(numChannels: 4);
  final tolerance = (args['tolerance'] as int).toDouble();
  final w = src.width, h = src.height;

  // Dominant border colour via coarse histogram.
  final counts = <int, int>{};
  final sums = <int, List<int>>{};
  void sample(int x, int y) {
    final px = src.getPixel(x, y);
    final r = px.r.toInt(), g = px.g.toInt(), b = px.b.toInt();
    final key = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
    counts[key] = (counts[key] ?? 0) + 1;
    final s = sums.putIfAbsent(key, () => [0, 0, 0]);
    s[0] += r;
    s[1] += g;
    s[2] += b;
  }

  for (var x = 0; x < w; x++) {
    sample(x, 0);
    sample(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    sample(0, y);
    sample(w - 1, y);
  }
  final topKey = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  final n = counts[topKey]!;
  final bgR = sums[topKey]![0] / n, bgG = sums[topKey]![1] / n, bgB = sums[topKey]![2] / n;

  final tolSq = tolerance * tolerance;
  double distSq(int x, int y) {
    final px = src.getPixel(x, y);
    final dr = px.r - bgR, dg = px.g - bgG, db = px.b - bgB;
    return dr * dr + dg * dg + db * db;
  }

  // 0 = unvisited, 1 = background
  final visited = Uint8List(w * h);
  final stack = <int>[];
  void push(int x, int y) {
    final i = y * w + x;
    if (visited[i] != 0) return;
    if (distSq(x, y) > tolSq) return;
    visited[i] = 1;
    stack.add(i);
  }

  for (var x = 0; x < w; x++) {
    push(x, 0);
    push(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    push(0, y);
    push(w - 1, y);
  }
  while (stack.isNotEmpty) {
    final i = stack.removeLast();
    final x = i % w, y = i ~/ w;
    if (x > 0) push(x - 1, y);
    if (x < w - 1) push(x + 1, y);
    if (y > 0) push(x, y - 1);
    if (y < h - 1) push(x, y + 1);
  }

  // Background -> transparent; foreground pixels touching background get a
  // partial alpha based on colour distance for a softer edge.
  final edgeSq = tolSq * 2.25;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = y * w + x;
      final px = src.getPixel(x, y);
      if (visited[i] == 1) {
        px.a = 0;
        continue;
      }
      final touchesBg = (x > 0 && visited[i - 1] == 1) ||
          (x < w - 1 && visited[i + 1] == 1) ||
          (y > 0 && visited[i - w] == 1) ||
          (y < h - 1 && visited[i + w] == 1);
      if (touchesBg) {
        final d = distSq(x, y);
        if (d < edgeSq) {
          px.a = (255 * ((d - tolSq) / (edgeSq - tolSq)).clamp(0.3, 1.0)).round();
        }
      }
    }
  }
  return img.encodePng(_trimTransparent(src));
}

/// Crops away fully transparent borders (keeps at least 1px).
img.Image _trimTransparent(img.Image src) {
  var minX = src.width, minY = src.height, maxX = -1, maxY = -1;
  for (final px in src) {
    if (px.a > 8) {
      if (px.x < minX) minX = px.x;
      if (px.x > maxX) maxX = px.x;
      if (px.y < minY) minY = px.y;
      if (px.y > maxY) maxY = px.y;
    }
  }
  if (maxX < 0) return src;
  return img.copyCrop(src, x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1);
}

Uint8List _rasterToJpegWorker(Map<String, Object?> args) {
  final w = args['width'] as int, h = args['height'] as int;
  var page = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: (args['pixels'] as Uint8List).buffer,
    numChannels: 4,
  );
  page = _flattenOnWhite(page);
  if (args['grayscale'] as bool) page = img.grayscale(page);
  return img.encodeJpg(page, quality: args['quality'] as int);
}

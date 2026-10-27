import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ignore: avoid_classes_with_only_static_members

enum ScanDocFilter {
  magicColor,
  blackAndWhite,
  grayscale,
  lighten,
  original,
}

class DocumentCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  const DocumentCorners({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
  });

  static const defaultFull = DocumentCorners(
    topLeft: Offset(0.04, 0.04),
    topRight: Offset(0.96, 0.04),
    bottomRight: Offset(0.96, 0.96),
    bottomLeft: Offset(0.04, 0.96),
  );
}

class ProcessedScanResult {
  final File file;
  final DocumentCorners corners;
  final int width;
  final int height;

  ProcessedScanResult({
    required this.file,
    required this.corners,
    required this.width,
    required this.height,
  });
}

class ScannerImageProcessor {
  /// Detects document corners and auto-crops & enhances the document like Adobe Scan
  static Future<ProcessedScanResult> autoDetectCropAndEnhance({
    required File rawImageFile,
    ScanDocFilter filter = ScanDocFilter.magicColor,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final bytes = await rawImageFile.readAsBytes();

    final result = await compute(
      _autoDetectCropIsolate,
      _IsolateParams(
        bytes: bytes,
        tempDirPath: tempDir.path,
        filter: filter,
      ),
    );

    return ProcessedScanResult(
      file: File(result.filePath),
      corners: result.corners,
      width: result.width,
      height: result.height,
    );
  }

  /// Processes manual crop, rotation, flip, and filter
  static Future<File> processManualCrop({
    required Uint8List rawBytes,
    required DocumentCorners corners,
    required int rotation,
    required bool flipH,
    required bool flipV,
    required ScanDocFilter filter,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final outPath = await compute(
      _manualCropIsolate,
      _ManualCropParams(
        bytes: rawBytes,
        corners: corners,
        rotation: rotation,
        flipH: flipH,
        flipV: flipV,
        filter: filter,
        tempDirPath: tempDir.path,
      ),
    );
    return File(outPath);
  }

  /// Resolves a writable output directory, preferring external storage.
  static Future<Directory> _resolveOutputDir(String subPath) async {
    // Try external storage first (real device SD / internal public storage)
    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory(p.join(ext.parent.parent.parent.parent.path, subPath));
        await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    // Fall back to app's external files directory
    try {
      final dirs = await getExternalStorageDirectories();
      if (dirs != null && dirs.isNotEmpty) {
        final dir = Directory(p.join(dirs.first.path, subPath));
        await dir.create(recursive: true);
        return dir;
      }
    } catch (_) {}
    // Absolute fallback: app documents dir
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, subPath));
    await dir.create(recursive: true);
    return dir;
  }

  /// Generates a multi-page PDF from a list of scanned image files
  static Future<File> generatePdf({
    required List<File> imageFiles,
    required String title,
    String pageSize = 'A4', // 'A4' or 'Fit'
  }) async {
    final pdf = pw.Document(
      title: title,
      author: 'File Explore by yjtechnosoft',
      creator: 'Adobe Scan Engine',
    );

    for (int i = 0; i < imageFiles.length; i++) {
      final imgFile = imageFiles[i];
      if (!await imgFile.exists()) continue;

      final bytes = await imgFile.readAsBytes();
      final image = pw.MemoryImage(bytes);

      pdf.addPage(
        pw.Page(
          pageFormat: pageSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.undefined,
          margin: const pw.EdgeInsets.all(12),
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(
                image,
                fit: pw.BoxFit.contain,
              ),
            );
          },
        ),
      );
    }

    final targetDir = await _resolveOutputDir('Documents/Scanned');
    final cleanTitle = title.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    final outPath = p.join(targetDir.path, '$cleanTitle.pdf');
    final pdfFile = File(outPath);
    await pdfFile.writeAsBytes(await pdf.save());

    return pdfFile;
  }

  /// Saves scanned pages as individual high-resolution JPG images
  static Future<List<File>> saveAsImages({
    required List<File> imageFiles,
    required String title,
  }) async {
    final targetDir = await _resolveOutputDir('Pictures/Scanned');

    final cleanTitle = title.replaceAll(RegExp(r'[^\w\-_.]'), '_');
    final savedFiles = <File>[];

    for (int i = 0; i < imageFiles.length; i++) {
      final srcFile = imageFiles[i];
      if (!await srcFile.exists()) continue;

      final ext = p.extension(srcFile.path).isNotEmpty ? p.extension(srcFile.path) : '.jpg';
      final fileName = imageFiles.length == 1
          ? '$cleanTitle$ext'
          : '${cleanTitle}_page_${i + 1}$ext';
      final destPath = p.join(targetDir.path, fileName);
      final destFile = await srcFile.copy(destPath);
      savedFiles.add(destFile);
    }

    return savedFiles;
  }
}

class _IsolateParams {
  final Uint8List bytes;
  final String tempDirPath;
  final ScanDocFilter filter;

  _IsolateParams({
    required this.bytes,
    required this.tempDirPath,
    required this.filter,
  });
}

class _IsolateResult {
  final String filePath;
  final DocumentCorners corners;
  final int width;
  final int height;

  _IsolateResult({
    required this.filePath,
    required this.corners,
    required this.width,
    required this.height,
  });
}

_IsolateResult _autoDetectCropIsolate(_IsolateParams params) {
  var image = img.decodeImage(params.bytes);
  if (image == null) throw Exception('Failed to decode image');

  final origW = image.width;
  final origH = image.height;

  // 1. Auto detect corners based on contrast and edge luminance
  const marginInset = 0.05;
  double top = marginInset;
  double bottom = 1.0 - marginInset;
  double left = marginInset;
  double right = 1.0 - marginInset;

  // Horizontal scan (top edge)
  for (int y = 0; y < (origH * 0.30).toInt(); y += 4) {
    int bright = 0;
    final total = (origW * 0.5).toInt();
    for (int x = (origW * 0.25).toInt(); x < (origW * 0.75).toInt(); x += 6) {
      final p = image.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      if (lum > 130) bright++;
    }
    if (bright > total * 0.35) {
      top = math.max(0.03, y / origH);
      break;
    }
  }

  // Horizontal scan (bottom edge)
  for (int y = origH - 1; y > (origH * 0.70).toInt(); y -= 4) {
    int bright = 0;
    final total = (origW * 0.5).toInt();
    for (int x = (origW * 0.25).toInt(); x < (origW * 0.75).toInt(); x += 6) {
      final p = image.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      if (lum > 130) bright++;
    }
    if (bright > total * 0.35) {
      bottom = math.min(0.97, y / origH);
      break;
    }
  }

  // Vertical scan (left edge)
  for (int x = 0; x < (origW * 0.25).toInt(); x += 4) {
    int bright = 0;
    final total = (origH * 0.5).toInt();
    for (int y = (origH * 0.25).toInt(); y < (origH * 0.75).toInt(); y += 6) {
      final p = image.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      if (lum > 130) bright++;
    }
    if (bright > total * 0.35) {
      left = math.max(0.03, x / origW);
      break;
    }
  }

  // Vertical scan (right edge)
  for (int x = origW - 1; x > (origW * 0.75).toInt(); x -= 4) {
    int bright = 0;
    final total = (origH * 0.5).toInt();
    for (int y = (origH * 0.25).toInt(); y < (origH * 0.75).toInt(); y += 6) {
      final p = image.getPixel(x, y);
      final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
      if (lum > 130) bright++;
    }
    if (bright > total * 0.35) {
      right = math.min(0.97, x / origW);
      break;
    }
  }

  final corners = DocumentCorners(
    topLeft: Offset(left, top),
    topRight: Offset(right, top),
    bottomRight: Offset(right, bottom),
    bottomLeft: Offset(left, bottom),
  );

  // 2. Crop & Zoom in to the document
  final minPixelX = (left * origW).clamp(0, origW - 1).toInt();
  final maxPixelX = (right * origW).clamp(minPixelX + 20, origW).toInt();
  final minPixelY = (top * origH).clamp(0, origH - 1).toInt();
  final maxPixelY = (bottom * origH).clamp(minPixelY + 20, origH).toInt();

  final cropW = maxPixelX - minPixelX;
  final cropH = maxPixelY - minPixelY;

  var cropped = img.copyCrop(
    image,
    x: minPixelX,
    y: minPixelY,
    width: cropW,
    height: cropH,
  );

  // 3. Apply Document Filter
  cropped = _applyFilter(cropped, params.filter);

  // 4. Save to temporary file
  final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final outPath = p.join(params.tempDirPath, fileName);
  final encoded = img.encodeJpg(cropped, quality: 92);
  File(outPath).writeAsBytesSync(encoded);

  return _IsolateResult(
    filePath: outPath,
    corners: corners,
    width: cropped.width,
    height: cropped.height,
  );
}

class _ManualCropParams {
  final Uint8List bytes;
  final DocumentCorners corners;
  final int rotation;
  final bool flipH;
  final bool flipV;
  final ScanDocFilter filter;
  final String tempDirPath;

  _ManualCropParams({
    required this.bytes,
    required this.corners,
    required this.rotation,
    required this.flipH,
    required this.flipV,
    required this.filter,
    required this.tempDirPath,
  });
}

String _manualCropIsolate(_ManualCropParams params) {
  var image = img.decodeImage(params.bytes);
  if (image == null) throw Exception('Cannot decode image');

  final origW = image.width;
  final origH = image.height;

  final minX = (math.min(params.corners.topLeft.dx, params.corners.bottomLeft.dx) * origW).clamp(0, origW - 1).toInt();
  final maxX = (math.max(params.corners.topRight.dx, params.corners.bottomRight.dx) * origW).clamp(minX + 10, origW).toInt();
  final minY = (math.min(params.corners.topLeft.dy, params.corners.topRight.dy) * origH).clamp(0, origH - 1).toInt();
  final maxY = (math.max(params.corners.bottomLeft.dy, params.corners.bottomRight.dy) * origH).clamp(minY + 10, origH).toInt();

  final cropW = (maxX - minX).clamp(10, origW);
  final cropH = (maxY - minY).clamp(10, origH);

  image = img.copyCrop(image, x: minX, y: minY, width: cropW, height: cropH);

  if (params.rotation != 0) {
    image = img.copyRotate(image, angle: params.rotation);
  }
  if (params.flipH) {
    image = img.flip(image, direction: img.FlipDirection.horizontal);
  }
  if (params.flipV) {
    image = img.flip(image, direction: img.FlipDirection.vertical);
  }

  image = _applyFilter(image, params.filter);

  final outPath = p.join(params.tempDirPath, 'manual_scan_${DateTime.now().millisecondsSinceEpoch}.jpg');
  final encoded = img.encodeJpg(image, quality: 92);
  File(outPath).writeAsBytesSync(encoded);

  return outPath;
}

img.Image _applyFilter(img.Image image, ScanDocFilter filter) {
  switch (filter) {
    case ScanDocFilter.magicColor:
      image = img.contrast(image, contrast: 125);
      image = img.adjustColor(image, saturation: 1.15, brightness: 1.05);
      break;
    case ScanDocFilter.blackAndWhite:
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 160);
      break;
    case ScanDocFilter.grayscale:
      image = img.grayscale(image);
      break;
    case ScanDocFilter.lighten:
      image = img.adjustColor(image, brightness: 1.20, contrast: 110);
      break;
    case ScanDocFilter.original:
      break;
  }
  return image;
}

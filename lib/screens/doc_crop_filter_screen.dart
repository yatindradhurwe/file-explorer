import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum ScanFilter {
  original,
  magicColor,
  blackAndWhite,
  grayscale,
  lighten,
}

class DocCropFilterScreen extends StatefulWidget {
  final File imageFile;

  const DocCropFilterScreen({
    super.key,
    required this.imageFile,
  });

  @override
  State<DocCropFilterScreen> createState() => _DocCropFilterScreenState();
}

class _DocCropFilterScreenState extends State<DocCropFilterScreen> {
  Uint8List? _imageBytes;
  int _imageWidth = 1;
  int _imageHeight = 1;

  // Normalized corner coordinates (0.0 to 1.0)
  Offset _topLeft = const Offset(0.08, 0.08);
  Offset _topRight = const Offset(0.92, 0.08);
  Offset _bottomRight = const Offset(0.92, 0.92);
  Offset _bottomLeft = const Offset(0.08, 0.92);

  int _rotation = 0; // 0, 90, 180, 270
  bool _flipHorizontal = false;
  bool _flipVertical = false;
  ScanFilter _currentFilter = ScanFilter.magicColor;

  bool _isProcessing = false;
  int _selectedTab = 0; // 0: Crop, 1: Filter, 2: Transform
  int? _activeHandleIndex; // 0: TL, 1: TR, 2: BR, 3: BL

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final decoded = await compute(img.decodeImage, bytes);
    if (decoded != null && mounted) {
      setState(() {
        _imageBytes = bytes;
        _imageWidth = decoded.width;
        _imageHeight = decoded.height;
        _autoDetectCorners(decoded);
      });
    }
  }

  /// Auto Detect Object / Document corners based on edge contrast
  void _autoDetectCorners(img.Image decoded) {
    // Analyze luminosity across sample lines to detect page margins
    const sampleInset = 0.06;
    double top = sampleInset;
    double bottom = 1.0 - sampleInset;
    double left = sampleInset;
    double right = 1.0 - sampleInset;

    final w = decoded.width;
    final h = decoded.height;

    // Scan inward from top (10% to 30%)
    for (int y = 0; y < (h * 0.25).toInt(); y += 4) {
      int brightPixels = 0;
      final total = (w * 0.5).toInt();
      for (int x = (w * 0.25).toInt(); x < (w * 0.75).toInt(); x += 8) {
        final pixel = decoded.getPixel(x, y);
        final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        if (lum > 140) brightPixels++;
      }
      if (brightPixels > total * 0.4) {
        top = math.max(0.04, y / h);
        break;
      }
    }

    // Scan inward from bottom
    for (int y = h - 1; y > (h * 0.75).toInt(); y -= 4) {
      int brightPixels = 0;
      final total = (w * 0.5).toInt();
      for (int x = (w * 0.25).toInt(); x < (w * 0.75).toInt(); x += 8) {
        final pixel = decoded.getPixel(x, y);
        final lum = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        if (lum > 140) brightPixels++;
      }
      if (brightPixels > total * 0.4) {
        bottom = math.min(0.96, y / h);
        break;
      }
    }

    setState(() {
      _topLeft = Offset(left, top);
      _topRight = Offset(right, top);
      _bottomRight = Offset(right, bottom);
      _bottomLeft = Offset(left, bottom);
    });
  }

  void _resetCropToFull() {
    setState(() {
      _topLeft = const Offset(0.02, 0.02);
      _topRight = const Offset(0.98, 0.02);
      _bottomRight = const Offset(0.98, 0.98);
      _bottomLeft = const Offset(0.02, 0.98);
    });
  }

  void _rotateClockwise() {
    setState(() {
      _rotation = (_rotation + 90) % 360;
    });
  }

  void _rotateCounterClockwise() {
    setState(() {
      _rotation = (_rotation - 90 + 360) % 360;
    });
  }

  void _toggleFlipH() {
    setState(() {
      _flipHorizontal = !_flipHorizontal;
    });
  }

  void _toggleFlipV() {
    setState(() {
      _flipVertical = !_flipVertical;
    });
  }

  /// Process and export the enhanced image
  Future<void> _applyAndSave() async {
    if (_imageBytes == null) return;

    setState(() => _isProcessing = true);

    try {
      final processedPath = await compute(_processImageWorker, _WorkerParams(
        imageBytes: _imageBytes!,
        topLeft: _topLeft,
        topRight: _topRight,
        bottomRight: _bottomRight,
        bottomLeft: _bottomLeft,
        rotation: _rotation,
        flipH: _flipHorizontal,
        flipV: _flipVertical,
        filter: _currentFilter,
        tempDir: (await getTemporaryDirectory()).path,
        origName: p.basenameWithoutExtension(widget.imageFile.path),
      ));

      if (mounted) {
        Navigator.pop(context, File(processedPath));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Edit Document Scan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: _isProcessing ? null : _applyAndSave,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _imageBytes == null || _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text('Enhancing document...', style: TextStyle(color: Colors.white70)),
                ],
              ),
            )
          : Column(
              children: [
                // Main Interactive Preview Canvas
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Compute displayed image rect maintaining aspect ratio
                          final double rawAspect = _imageWidth / _imageHeight;
                          final bool isRotated = _rotation == 90 || _rotation == 270;
                          final double aspect = isRotated ? (1.0 / rawAspect) : rawAspect;

                          double dispWidth = constraints.maxWidth;
                          double dispHeight = dispWidth / aspect;

                          if (dispHeight > constraints.maxHeight) {
                            dispHeight = constraints.maxHeight;
                            dispWidth = dispHeight * aspect;
                          }

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Transformed and filtered preview image
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()
                                  ..rotateZ(_rotation * math.pi / 180)
                                  // ignore: deprecated_member_use
                                  ..scale(_flipHorizontal ? -1.0 : 1.0, _flipVertical ? -1.0 : 1.0),
                                child: ColorFiltered(
                                  colorFilter: _getColorFilter(),
                                  child: Image.memory(
                                    _imageBytes!,
                                    width: isRotated ? dispHeight : dispWidth,
                                    height: isRotated ? dispWidth : dispHeight,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),

                              // Interactive 4-Corner Cropping Overlay (visible in Crop tab)
                              if (_selectedTab == 0)
                                SizedBox(
                                  width: dispWidth,
                                  height: dispHeight,
                                  child: GestureDetector(
                                    onPanDown: (details) {
                                      _onPanDown(details.localPosition, dispWidth, dispHeight);
                                    },
                                    onPanUpdate: (details) {
                                      _onPanUpdate(details.localPosition, dispWidth, dispHeight);
                                    },
                                    onPanEnd: (_) {
                                      setState(() => _activeHandleIndex = null);
                                    },
                                    child: CustomPaint(
                                      painter: _CornerCropPainter(
                                        topLeft: _topLeft,
                                        topRight: _topRight,
                                        bottomRight: _bottomRight,
                                        bottomLeft: _bottomLeft,
                                        activeHandle: _activeHandleIndex,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // Tool Options Tray
                _buildToolTray(isDark),

                // Bottom Tab Navigation Bar
                Container(
                  color: const Color(0xFF111827),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _navTab(0, Icons.crop_rounded, 'Crop & Corners'),
                      _navTab(1, Icons.auto_awesome_rounded, 'Filters'),
                      _navTab(2, Icons.rotate_right_rounded, 'Rotate & Flip'),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _onPanDown(Offset pos, double w, double h) {
    const touchRadius = 36.0;
    final tl = Offset(_topLeft.dx * w, _topLeft.dy * h);
    final tr = Offset(_topRight.dx * w, _topRight.dy * h);
    final br = Offset(_bottomRight.dx * w, _bottomRight.dy * h);
    final bl = Offset(_bottomLeft.dx * w, _bottomLeft.dy * h);

    if ((pos - tl).distance <= touchRadius) {
      _activeHandleIndex = 0;
    } else if ((pos - tr).distance <= touchRadius) {
      _activeHandleIndex = 1;
    } else if ((pos - br).distance <= touchRadius) {
      _activeHandleIndex = 2;
    } else if ((pos - bl).distance <= touchRadius) {
      _activeHandleIndex = 3;
    } else {
      _activeHandleIndex = null;
    }
    setState(() {});
  }

  void _onPanUpdate(Offset pos, double w, double h) {
    if (_activeHandleIndex == null) return;

    final norm = Offset(
      (pos.dx / w).clamp(0.0, 1.0),
      (pos.dy / h).clamp(0.0, 1.0),
    );

    setState(() {
      switch (_activeHandleIndex) {
        case 0:
          _topLeft = norm;
          break;
        case 1:
          _topRight = norm;
          break;
        case 2:
          _bottomRight = norm;
          break;
        case 3:
          _bottomLeft = norm;
          break;
      }
    });
  }

  ColorFilter _getColorFilter() {
    switch (_currentFilter) {
      case ScanFilter.magicColor:
        // Enhance contrast & saturation (Adobe Scan Magic Color)
        return const ColorFilter.matrix(<double>[
          1.2, 0.0, 0.0, 0.0, -10.0,
          0.0, 1.2, 0.0, 0.0, -10.0,
          0.0, 0.0, 1.2, 0.0, -10.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case ScanFilter.blackAndWhite:
        // High contrast clean document B&W
        return const ColorFilter.matrix(<double>[
          1.8, 1.8, 1.8, 0.0, -250.0,
          1.8, 1.8, 1.8, 0.0, -250.0,
          1.8, 1.8, 1.8, 0.0, -250.0,
          0.0, 0.0, 0.0, 1.0, 0.0,
        ]);
      case ScanFilter.grayscale:
        // Standard Grayscale
        return const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.2126, 0.7152, 0.0722, 0.0, 0.0,
          0.0,    0.0,    0.0,    1.0, 0.0,
        ]);
      case ScanFilter.lighten:
        // Whitens background paper shadows
        return const ColorFilter.matrix(<double>[
          1.15, 0.0,  0.0,  0.0, 35.0,
          0.0,  1.15, 0.0,  0.0, 35.0,
          0.0,  0.0,  1.15, 0.0, 35.0,
          0.0,  0.0,  0.0,  1.0, 0.0,
        ]);
      case ScanFilter.original:
        return const ColorFilter.mode(Colors.transparent, BlendMode.dst);
    }
  }

  Widget _buildToolTray(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_selectedTab == 0) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.document_scanner_rounded, size: 18, color: Colors.teal),
                  label: const Text('Auto Detect Corners', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.teal)),
                  onPressed: () {
                    // Re-run auto detect
                    if (_imageBytes != null) {
                      final decoded = img.decodeImage(_imageBytes!);
                      if (decoded != null) _autoDetectCorners(decoded);
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.fullscreen_rounded, size: 18, color: Colors.amber),
                  label: const Text('Expand Full', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.amber)),
                  onPressed: _resetCropToFull,
                ),
              ],
            ),
          ] else if (_selectedTab == 1) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterButton(ScanFilter.magicColor, 'Magic Color', Icons.auto_awesome_rounded, Colors.teal),
                  _filterButton(ScanFilter.blackAndWhite, 'B&W Doc', Icons.filter_b_and_w_rounded, Colors.white),
                  _filterButton(ScanFilter.grayscale, 'Grayscale', Icons.tonality_rounded, Colors.grey),
                  _filterButton(ScanFilter.lighten, 'Lighten', Icons.wb_sunny_rounded, Colors.amber),
                  _filterButton(ScanFilter.original, 'Original', Icons.image_rounded, Colors.blue),
                ],
              ),
            ),
          ] else if (_selectedTab == 2) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.rotate_left_rounded),
                  tooltip: 'Rotate 90° CCW',
                  onPressed: _rotateCounterClockwise,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.rotate_right_rounded),
                  tooltip: 'Rotate 90° CW',
                  onPressed: _rotateClockwise,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.flip_rounded),
                  tooltip: 'Flip Horizontal',
                  onPressed: _toggleFlipH,
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.swap_vertical_circle_rounded),
                  tooltip: 'Flip Vertical',
                  onPressed: _toggleFlipV,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterButton(ScanFilter filter, String label, IconData icon, Color color) {
    final isSelected = _currentFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ChoiceChip(
        avatar: Icon(icon, color: isSelected ? Colors.black : color, size: 16),
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.tealAccent,
        labelStyle: TextStyle(
          color: isSelected ? Colors.black : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        ),
        onSelected: (val) {
          if (val) setState(() => _currentFilter = filter);
        },
      ),
    );
  }

  Widget _navTab(int index, IconData icon, String label) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.teal : Colors.grey, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.teal : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for rendering Adobe Scan-style 4 corner cropping handles
class _CornerCropPainter extends CustomPainter {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final int? activeHandle;

  _CornerCropPainter({
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    this.activeHandle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pTL = Offset(topLeft.dx * size.width, topLeft.dy * size.height);
    final pTR = Offset(topRight.dx * size.width, topRight.dy * size.height);
    final pBR = Offset(bottomRight.dx * size.width, bottomRight.dy * size.height);
    final pBL = Offset(bottomLeft.dx * size.width, bottomLeft.dy * size.height);

    // 1. Dark mask outside crop polygon
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addPolygon([pTL, pTR, pBR, pBL], true)
      ..fillType = PathFillType.evenOdd;

    final maskPaint = Paint()..color = Colors.black.withAlpha(140);
    canvas.drawPath(path, maskPaint);

    // 2. Crop boundary lines
    final linePaint = Paint()
      ..color = Colors.tealAccent
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final borderPath = Path()..addPolygon([pTL, pTR, pBR, pBL], true);
    canvas.drawPath(borderPath, linePaint);

    // 3. Grid guidelines (3x3 grid)
    final gridPaint = Paint()
      ..color = Colors.tealAccent.withAlpha(80)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal thirds
    canvas.drawLine(
      Offset.lerp(pTL, pBL, 0.33)!,
      Offset.lerp(pTR, pBR, 0.33)!,
      gridPaint,
    );
    canvas.drawLine(
      Offset.lerp(pTL, pBL, 0.66)!,
      Offset.lerp(pTR, pBR, 0.66)!,
      gridPaint,
    );

    // Vertical thirds
    canvas.drawLine(
      Offset.lerp(pTL, pTR, 0.33)!,
      Offset.lerp(pBL, pBR, 0.33)!,
      gridPaint,
    );
    canvas.drawLine(
      Offset.lerp(pTL, pTR, 0.66)!,
      Offset.lerp(pBL, pBR, 0.66)!,
      gridPaint,
    );

    // 4. Circular Handles at 4 corners
    _drawHandle(canvas, pTL, activeHandle == 0);
    _drawHandle(canvas, pTR, activeHandle == 1);
    _drawHandle(canvas, pBR, activeHandle == 2);
    _drawHandle(canvas, pBL, activeHandle == 3);
  }

  void _drawHandle(Canvas canvas, Offset center, bool isActive) {
    // Outer glow
    final glowPaint = Paint()
      ..color = isActive ? Colors.tealAccent : Colors.teal.withAlpha(120)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isActive ? 16 : 13, glowPaint);

    // White core
    final corePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isActive ? 8 : 6, corePaint);
  }

  @override
  bool shouldRepaint(covariant _CornerCropPainter old) {
    return old.topLeft != topLeft ||
        old.topRight != topRight ||
        old.bottomRight != bottomRight ||
        old.bottomLeft != bottomLeft ||
        old.activeHandle != activeHandle;
  }
}

class _WorkerParams {
  final Uint8List imageBytes;
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final int rotation;
  final bool flipH;
  final bool flipV;
  final ScanFilter filter;
  final String tempDir;
  final String origName;

  _WorkerParams({
    required this.imageBytes,
    required this.topLeft,
    required this.topRight,
    required this.bottomRight,
    required this.bottomLeft,
    required this.rotation,
    required this.flipH,
    required this.flipV,
    required this.filter,
    required this.tempDir,
    required this.origName,
  });
}

/// Background isolate worker for fast image cropping and filtering
String _processImageWorker(_WorkerParams params) {
  var image = img.decodeImage(params.imageBytes);
  if (image == null) throw Exception('Cannot decode image');

  final origW = image.width;
  final origH = image.height;

  // 1. Calculate bounding box of 4 corners
  final minX = (math.min(params.topLeft.dx, params.bottomLeft.dx) * origW).clamp(0, origW - 1).toInt();
  final maxX = (math.max(params.topRight.dx, params.bottomRight.dx) * origW).clamp(minX + 10, origW).toInt();
  final minY = (math.min(params.topLeft.dy, params.topRight.dy) * origH).clamp(0, origH - 1).toInt();
  final maxY = (math.max(params.bottomLeft.dy, params.bottomRight.dy) * origH).clamp(minY + 10, origH).toInt();

  final cropW = (maxX - minX).clamp(10, origW);
  final cropH = (maxY - minY).clamp(10, origH);

  // 2. Crop
  image = img.copyCrop(image, x: minX, y: minY, width: cropW, height: cropH);

  // 3. Rotation
  if (params.rotation != 0) {
    image = img.copyRotate(image, angle: params.rotation);
  }

  // 4. Flip
  if (params.flipH) {
    image = img.flip(image, direction: img.FlipDirection.horizontal);
  }
  if (params.flipV) {
    image = img.flip(image, direction: img.FlipDirection.vertical);
  }

  // 5. Apply Filter
  switch (params.filter) {
    case ScanFilter.magicColor:
      // Boost contrast and text sharpness
      image = img.contrast(image, contrast: 125);
      image = img.adjustColor(image, saturation: 1.15, brightness: 1.05);
      break;
    case ScanFilter.blackAndWhite:
      image = img.grayscale(image);
      image = img.contrast(image, contrast: 160);
      break;
    case ScanFilter.grayscale:
      image = img.grayscale(image);
      break;
    case ScanFilter.lighten:
      image = img.adjustColor(image, brightness: 1.2, contrast: 110);
      break;
    case ScanFilter.original:
      break;
  }

  // 6. Save processed image to disk
  final outName = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final outPath = p.join(params.tempDir, outName);
  final encoded = img.encodeJpg(image, quality: 90);
  File(outPath).writeAsBytesSync(encoded);

  return outPath;
}

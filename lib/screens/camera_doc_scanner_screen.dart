import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/scanner_image_processor.dart';
import 'doc_crop_filter_screen.dart';
import 'doc_export_share_screen.dart';

class ScannedDocPage {
  File rawFile;
  File processedFile;
  DocumentCorners corners;
  ScanDocFilter filter;
  int rotation;

  ScannedDocPage({
    required this.rawFile,
    required this.processedFile,
    required this.corners,
    this.filter = ScanDocFilter.magicColor,
    this.rotation = 0,
  });
}

class CameraDocScannerScreen extends StatefulWidget {
  const CameraDocScannerScreen({super.key});

  @override
  State<CameraDocScannerScreen> createState() => _CameraDocScannerScreenState();
}

class _CameraDocScannerScreenState extends State<CameraDocScannerScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _hasCameraPermission = false;
  bool _isAutoScan = true;
  bool _isTorchOn = false;
  bool _isProcessing = false;

  final List<ScannedDocPage> _scannedPages = [];
  final ImagePicker _picker = ImagePicker();

  late AnimationController _animController;
  late Animation<double> _scanLineAnim;

  Timer? _autoCaptureTimer;
  double _autoCaptureProgress = 0.0;
  bool _isDocumentDetected = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scanLineAnim = Tween<double>(begin: 0.15, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  @override
  void dispose() {
    _autoCaptureTimer?.cancel();
    _animController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted) {
        setState(() {
          _hasCameraPermission = false;
        });
      }
      return;
    }

    _hasCameraPermission = true;

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() {});
        return;
      }

      final backCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        _startAutoDetectSimulation();
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  void _startAutoDetectSimulation() {
    if (!mounted) return;
    if (!_isAutoScan || _isProcessing) return;
    if (!_isCameraInitialized || _cameraController == null) return;

    // Small grace delay so the user can react before auto-capture
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted || !_isAutoScan || _isProcessing) return;

      // Simulate Adobe Scan document detection stabilization
      setState(() {
        _isDocumentDetected = true;
        _autoCaptureProgress = 0.0;
      });

      _autoCaptureTimer?.cancel();
      const tickMs = 60;
      const totalMs = 1800; // slightly longer so the user has time to frame
      int elapsed = 0;

      _autoCaptureTimer = Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
        if (!mounted || !_isAutoScan || _isProcessing) {
          timer.cancel();
          return;
        }

        elapsed += tickMs;
        setState(() {
          _autoCaptureProgress = (elapsed / totalMs).clamp(0.0, 1.0);
        });

        if (elapsed >= totalMs) {
          timer.cancel();
          _captureDocument(isAuto: true);
        }
      });
    });
  }

  Future<void> _captureDocument({bool isAuto = false}) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isProcessing) return;

    _autoCaptureTimer?.cancel();
    setState(() {
      _isProcessing = true;
    });

    HapticFeedback.mediumImpact();

    try {
      final xfile = await _cameraController!.takePicture();
      final rawFile = File(xfile.path);

      // Auto detect corners, auto-crop, and zoom into the document
      final processed = await ScannerImageProcessor.autoDetectCropAndEnhance(
        rawImageFile: rawFile,
        filter: ScanDocFilter.magicColor,
      );

      final newPage = ScannedDocPage(
        rawFile: rawFile,
        processedFile: processed.file,
        corners: processed.corners,
        filter: ScanDocFilter.magicColor,
      );

      if (mounted) {
        setState(() {
          _scannedPages.add(newPage);
          _isProcessing = false;
          _autoCaptureProgress = 0.0;
        });

        // Present Adobe Scan-style post-capture sheet
        _showPostCaptureReviewSheet(newPage);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    _autoCaptureTimer?.cancel();
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (picked == null || !mounted) {
      _startAutoDetectSimulation();
      return;
    }

    setState(() => _isProcessing = true);
    final rawFile = File(picked.path);

    final processed = await ScannerImageProcessor.autoDetectCropAndEnhance(
      rawImageFile: rawFile,
      filter: ScanDocFilter.magicColor,
    );

    final newPage = ScannedDocPage(
      rawFile: rawFile,
      processedFile: processed.file,
      corners: processed.corners,
      filter: ScanDocFilter.magicColor,
    );

    if (mounted) {
      setState(() {
        _scannedPages.add(newPage);
        _isProcessing = false;
      });
      _showPostCaptureReviewSheet(newPage);
    }
  }

  void _showPostCaptureReviewSheet(ScannedDocPage page) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(160),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle pill
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),

              // Title row with page count
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.teal.withAlpha(40),
                      border: Border.all(color: Colors.tealAccent.withAlpha(140)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Page ${_scannedPages.length}',
                      style: const TextStyle(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Auto-Cropped & Scanned',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _scannedPages.remove(page);
                      });
                      _startAutoDetectSimulation();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Zoomed Scanned Preview Box
              Container(
                height: 190,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  page.processedFile,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons Row: Adjust Corners, Add More Pages, Continue
              Row(
                children: [
                  // Adjust Corners & Filters
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.crop, size: 18, color: Colors.tealAccent),
                      label: const Text(
                        'Adjust Crop',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _openManualCropAdjuster(page);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Add More Pages (Adobe Scan continuous loop)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF334155),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_photo_alternate, size: 18),
                      label: const Text(
                        'Add Page',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _startAutoDetectSimulation();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Continue to Generate PDF / Images / Share
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 20),
                  label: Text(
                    'Continue (${_scannedPages.length} ${_scannedPages.length == 1 ? 'Page' : 'Pages'})',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _navigateToExport();
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openManualCropAdjuster(ScannedDocPage page) async {
    final editedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => DocCropFilterScreen(imageFile: page.rawFile),
      ),
    );

    if (editedFile != null && mounted) {
      setState(() {
        page.processedFile = editedFile;
      });
      _showPostCaptureReviewSheet(page);
    } else {
      _showPostCaptureReviewSheet(page);
    }
  }

  void _navigateToExport() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocExportShareScreen(
          pages: _scannedPages,
          onAddMorePages: () {
            Navigator.pop(context);
            _startAutoDetectSimulation();
          },
        ),
      ),
    );
  }

  void _toggleTorch() async {
    if (_cameraController == null) return;
    try {
      final newMode = _isTorchOn ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newMode);
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (e) {
      debugPrint('Error toggling torch: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasCameraPermission) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Document Scanner', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.camera_alt_outlined, size: 64, color: Colors.tealAccent),
                const SizedBox(height: 20),
                const Text(
                  'Camera Permission Required',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  'To auto-detect documents and scan pages like Adobe Scan, please grant camera access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _initCamera,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Grant Permission'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: _pickFromGallery,
                  icon: const Icon(Icons.photo_library, color: Colors.tealAccent),
                  label: const Text('Import from Gallery instead', style: TextStyle(color: Colors.tealAccent)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Live Camera Viewfinder
          if (_isCameraInitialized && _cameraController != null)
            Center(
              child: AspectRatio(
                aspectRatio: 1 / _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              ),
            )
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.tealAccent),
            ),

          // 2. Real-time Adobe Scan Overlay (Corners + Scanning Laser Beam)
          AnimatedBuilder(
            animation: _animController,
            builder: (context, _) {
              return CustomPaint(
                painter: _AdobeScanOverlayPainter(
                  scanLineRatio: _scanLineAnim.value,
                  isDetected: _isDocumentDetected,
                ),
              );
            },
          ),

          // 3. Top Navigation & Status Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 28),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),

                        // Auto / Manual Switcher
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() => _isAutoScan = true);
                                  _startAutoDetectSimulation();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _isAutoScan ? Colors.tealAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        size: 14,
                                        color: _isAutoScan ? Colors.black : Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Auto-Scan',
                                        style: TextStyle(
                                          color: _isAutoScan ? Colors.black : Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  _autoCaptureTimer?.cancel();
                                  setState(() {
                                    _isAutoScan = false;
                                    _autoCaptureProgress = 0.0;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: !_isAutoScan ? Colors.tealAccent : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    'Manual',
                                    style: TextStyle(
                                      color: !_isAutoScan ? Colors.black : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),

                        // Flashlight
                        IconButton(
                          icon: Icon(
                            _isTorchOn ? Icons.flash_on : Icons.flash_off,
                            color: _isTorchOn ? Colors.yellowAccent : Colors.white,
                          ),
                          onPressed: _toggleTorch,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Document Detection Banner
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isDocumentDetected
                            ? const Color(0xFF065F46).withAlpha(220)
                            : Colors.black54,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _isDocumentDetected
                              ? Colors.tealAccent
                              : Colors.white24,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDocumentDetected
                                ? Icons.document_scanner
                                : Icons.center_focus_strong,
                            color: _isDocumentDetected ? Colors.tealAccent : Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isDocumentDetected
                                ? (_isAutoScan
                                    ? 'Document Detected — Hold Steady'
                                    : 'Document Framed — Tap Shutter')
                                : 'Looking for document...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Processing Spinner Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.tealAccent),
                    SizedBox(height: 16),
                    Text(
                      'Auto-Cropping & Enhancing...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 5. Bottom Shutter Bar
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87, Colors.black],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Gallery Pick Button
                  IconButton(
                    icon: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 28),
                    tooltip: 'Import from Gallery',
                    onPressed: _pickFromGallery,
                  ),

                  // Shutter Button with Auto-Capture Progress Ring
                  GestureDetector(
                    onTap: () => _captureDocument(isAuto: false),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress ring for auto scan
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            value: _isAutoScan ? _autoCaptureProgress : 0.0,
                            strokeWidth: 4,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        // Outer white circle
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            color: Colors.white24,
                          ),
                          child: Center(
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Review / Finish Pill Button (shows page count if > 0)
                  if (_scannedPages.isNotEmpty)
                    GestureDetector(
                      onTap: _navigateToExport,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2563EB).withAlpha(120),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_scannedPages.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for Adobe Scan-style live corner brackets and scanning laser beam
class _AdobeScanOverlayPainter extends CustomPainter {
  final double scanLineRatio;
  final bool isDetected;

  _AdobeScanOverlayPainter({
    required this.scanLineRatio,
    required this.isDetected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double padX = size.width * 0.08;
    final double padTop = size.height * 0.16;
    final double padBottom = size.height * 0.22;

    final docRect = Rect.fromLTRB(
      padX,
      padTop,
      size.width - padX,
      size.height - padBottom,
    );

    // 1. Semi-dark background vignette outside document framing rect
    final maskPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(docRect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    final vignettePaint = Paint()..color = Colors.black.withAlpha(90);
    canvas.drawPath(maskPath, vignettePaint);

    // 2. Corner Bracket Highlights
    final bracketColor = isDetected ? const Color(0xFF10B981) : const Color(0xFF38BDF8);
    final bracketPaint = Paint()
      ..color = bracketColor
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLen = 32.0;

    // Top-Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(docRect.left, docRect.top + cornerLen)
        ..lineTo(docRect.left, docRect.top)
        ..lineTo(docRect.left + cornerLen, docRect.top),
      bracketPaint,
    );

    // Top-Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(docRect.right - cornerLen, docRect.top)
        ..lineTo(docRect.right, docRect.top)
        ..lineTo(docRect.right, docRect.top + cornerLen),
      bracketPaint,
    );

    // Bottom-Right Corner
    canvas.drawPath(
      Path()
        ..moveTo(docRect.right, docRect.bottom - cornerLen)
        ..lineTo(docRect.right, docRect.bottom)
        ..lineTo(docRect.right - cornerLen, docRect.bottom),
      bracketPaint,
    );

    // Bottom-Left Corner
    canvas.drawPath(
      Path()
        ..moveTo(docRect.left + cornerLen, docRect.bottom)
        ..lineTo(docRect.left, docRect.bottom)
        ..lineTo(docRect.left, docRect.bottom - cornerLen),
      bracketPaint,
    );

    // 3. Animated Scanning Laser Line
    final scanY = docRect.top + (docRect.height * scanLineRatio);
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          bracketColor.withAlpha(220),
          Colors.white,
          bracketColor.withAlpha(220),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(docRect.left, scanY - 2, docRect.width, 4))
      ..strokeWidth = 2.5;

    canvas.drawLine(
      Offset(docRect.left + 8, scanY),
      Offset(docRect.right - 8, scanY),
      laserPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AdobeScanOverlayPainter old) {
    return old.scanLineRatio != scanLineRatio || old.isDetected != isDetected;
  }
}

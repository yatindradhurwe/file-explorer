import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/file_item.dart';
import '../services/storage_service.dart';
import 'camera_doc_scanner_screen.dart';
import 'doc_crop_filter_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';

class ScannedPage {
  final File file;
  int rotation; // 0, 90, 180, 270 degrees

  ScannedPage({required this.file, this.rotation = 0});
}

class DocScannerScreen extends StatefulWidget {
  const DocScannerScreen({super.key});

  @override
  State<DocScannerScreen> createState() => _DocScannerScreenState();
}

class _DocScannerScreenState extends State<DocScannerScreen> {
  final List<ScannedPage> _pages = [];
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _titleController = TextEditingController();
  bool _isGeneratingPdf = false;
  String _pageSize = 'A4'; // 'A4', 'Fit'

  @override
  void initState() {
    super.initState();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _titleController.text = 'Scan_$timestamp';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _captureFromCamera() async {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CameraDocScannerScreen()),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final pickedList = await _picker.pickMultiImage(imageQuality: 95);
      if (pickedList.isNotEmpty && mounted) {
        for (var item in pickedList) {
          _pages.add(ScannedPage(file: File(item.path)));
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    }
  }

  Future<void> _editPage(int index) async {
    final page = _pages[index];
    final editedFile = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => DocCropFilterScreen(imageFile: page.file),
      ),
    );
    if (editedFile != null && mounted) {
      setState(() {
        _pages[index] = ScannedPage(file: editedFile);
      });
    }
  }

  void _removePage(int index) {
    setState(() {
      _pages.removeAt(index);
    });
  }

  void _movePage(int oldIndex, int newIndex) {
    if (newIndex < 0 || newIndex >= _pages.length) return;
    setState(() {
      final item = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, item);
    });
  }

  Future<void> _generatePdf() async {
    if (_pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one scanned page.')),
      );
      return;
    }

    setState(() => _isGeneratingPdf = true);

    try {
      final pdf = pw.Document(
        title: _titleController.text.trim(),
        author: 'File Explore by yjtechnosoft',
      );

      for (int i = 0; i < _pages.length; i++) {
        final pageItem = _pages[i];
        final imageBytes = await pageItem.file.readAsBytes();
        final image = pw.MemoryImage(imageBytes);

        final pageFormat = _pageSize == 'A4' ? PdfPageFormat.a4 : PdfPageFormat.undefined;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.all(16),
            build: (pw.Context ctx) {
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

      // Determine output directory
      final root = await StorageService.getRootPath();
      final documentsDir = Directory(p.join(root, 'Documents', 'Scanned'));
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }

      var sanitizedName = _titleController.text.trim();
      if (!sanitizedName.toLowerCase().endsWith('.pdf')) {
        sanitizedName += '.pdf';
      }

      final targetPath = p.join(documentsDir.path, sanitizedName);
      final pdfFile = File(targetPath);
      await pdfFile.writeAsBytes(await pdf.save());

      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        _showSuccessDialog(targetPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate PDF: $e')),
        );
      }
    }
  }

  void _showSuccessDialog(String savedPath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
            SizedBox(width: 10),
            Text('PDF Created!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Document successfully compiled with ${_pages.length} ${_pages.length == 1 ? 'page' : 'pages'}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.basename(savedPath),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Saved to: ${p.dirname(savedPath)}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return from scanner
            },
            child: const Text('Done'),
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
            label: const Text('QuickDrop'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuickDropScreen(
                    filesToSend: [FileItem.fromEntity(File(savedPath))],
                  ),
                ),
              );
            },
          ),
          FilledButton.icon(
            icon: const Icon(Icons.menu_book_rounded, size: 18),
            label: const Text('Read PDF'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(filePath: savedPath),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.document_scanner_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text('Doc Scanner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          if (_pages.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: 'Clear all pages',
              onPressed: () {
                setState(() => _pages.clear());
              },
            ),
        ],
      ),
      body: _isGeneratingPdf
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Building high-quality PDF...', style: TextStyle(fontWeight: FontWeight.w600)),
                  SizedBox(height: 4),
                  Text('Optimizing pages & layout', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            )
          : Column(
              children: [
                // Document Info Header Card
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withAlpha(30),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _titleController,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              decoration: const InputDecoration(
                                labelText: 'Document Name',
                                isDense: true,
                                border: InputBorder.none,
                                hintText: 'Enter PDF title',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Page Format:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(width: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'A4', label: Text('A4')),
                                  ButtonSegment(value: 'Fit', label: Text('Auto Fit')),
                                ],
                                selected: {_pageSize},
                                onSelectionChanged: (set) {
                                  setState(() => _pageSize = set.first);
                                },
                                style: const ButtonStyle(
                                  visualDensity: VisualDensity.compact,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withAlpha(25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_pages.length} ${_pages.length == 1 ? 'Page' : 'Pages'}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Scanned Pages Gallery Grid
                Expanded(
                  child: _pages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withAlpha(25),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.document_scanner_rounded,
                                    size: 56,
                                    color: Colors.teal,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Scan Documents to PDF',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Take photos of physical documents, receipts, or notes, or import images from your gallery to create a multi-page PDF.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    FilledButton.icon(
                                      icon: const Icon(Icons.camera_alt_rounded),
                                      label: const Text('Camera'),
                                      onPressed: _captureFromCamera,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.teal,
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      icon: const Icon(Icons.photo_library_rounded),
                                      label: const Text('Gallery'),
                                      onPressed: _pickFromGallery,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _pages.length,
                          itemBuilder: (context, index) {
                            final page = _pages[index];
                            return Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withAlpha(10),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () => _editPage(index),
                                          child: Image.file(
                                            page.file,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade100,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Page ${index + 1}',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (index > 0)
                                                  InkWell(
                                                    onTap: () => _movePage(index, index - 1),
                                                    child: const Icon(Icons.arrow_back_ios_rounded, size: 14),
                                                  ),
                                                const SizedBox(width: 6),
                                                if (index < _pages.length - 1)
                                                  InkWell(
                                                    onTap: () => _movePage(index, index + 1),
                                                    child: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  left: 6,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.crop_rotate_rounded, color: Colors.tealAccent, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      tooltip: 'Crop, Filter & Rotate',
                                      onPressed: () => _editPage(index),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                      onPressed: () => _removePage(index),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),

                // Bottom Action Bar
                if (_pages.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(
                        top: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      child: Row(
                        children: [
                          IconButton.filledTonal(
                            icon: const Icon(Icons.camera_alt_rounded),
                            tooltip: 'Add Page with Camera',
                            onPressed: _captureFromCamera,
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            icon: const Icon(Icons.photo_library_rounded),
                            tooltip: 'Add Page from Gallery',
                            onPressed: _pickFromGallery,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              icon: const Icon(Icons.picture_as_pdf_rounded),
                              label: Text('Save PDF (${_pages.length})'),
                              onPressed: _generatePdf,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.teal,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

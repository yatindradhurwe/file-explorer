import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/file_item.dart';
import '../services/scanner_image_processor.dart';
import 'camera_doc_scanner_screen.dart';
import 'doc_crop_filter_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';

enum ExportFormat { pdf, images }

class DocExportShareScreen extends StatefulWidget {
  final List<ScannedDocPage> pages;
  final VoidCallback onAddMorePages;

  const DocExportShareScreen({
    super.key,
    required this.pages,
    required this.onAddMorePages,
  });

  @override
  State<DocExportShareScreen> createState() => _DocExportShareScreenState();
}

class _DocExportShareScreenState extends State<DocExportShareScreen> {
  late final TextEditingController _titleController;
  int _currentPageIndex = 0;
  ExportFormat _selectedFormat = ExportFormat.pdf;
  String _pdfPageSize = 'A4'; // 'A4' or 'Fit'
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    _titleController = TextEditingController(text: 'Scan_$timestamp');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _adjustCrop(int index) async {
    final page = widget.pages[index];
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
    }
  }

  void _deletePage(int index) {
    if (widget.pages.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the only page')),
      );
      return;
    }

    setState(() {
      widget.pages.removeAt(index);
      if (_currentPageIndex >= widget.pages.length) {
        _currentPageIndex = widget.pages.length - 1;
      }
    });
  }

  Future<File?> _generatePdfIfNeeded() async {
    final images = widget.pages.map((p) => p.processedFile).toList();
    final file = await ScannerImageProcessor.generatePdf(
      imageFiles: images,
      title: _titleController.text.trim(),
      pageSize: _pdfPageSize,
    );
    return file;
  }

  Future<List<File>?> _generateImagesIfNeeded() async {
    final images = widget.pages.map((p) => p.processedFile).toList();
    final saved = await ScannerImageProcessor.saveAsImages(
      imageFiles: images,
      title: _titleController.text.trim(),
    );
    return saved;
  }

  Future<void> _saveToDevice() async {
    setState(() => _isExporting = true);
    try {
      if (_selectedFormat == ExportFormat.pdf) {
        final pdf = await _generatePdfIfNeeded();
        if (pdf != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF saved: ${pdf.path}'),
              backgroundColor: const Color(0xFF10B981),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => _openExportedFile(pdf),
              ),
            ),
          );
        }
      } else {
        final imgs = await _generateImagesIfNeeded();
        if (imgs != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${imgs.length} images saved to Pictures/Scanned'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _shareFile() async {
    setState(() => _isExporting = true);
    try {
      if (_selectedFormat == ExportFormat.pdf) {
        final pdf = await _generatePdfIfNeeded();
        if (pdf != null) {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(pdf.path)],
              text: 'Scanned document: ${_titleController.text.trim()}',
            ),
          );
        }
      } else {
        final imgs = await _generateImagesIfNeeded();
        if (imgs != null && imgs.isNotEmpty) {
          await SharePlus.instance.share(
            ShareParams(
              files: imgs.map((f) => XFile(f.path)).toList(),
              text: 'Scanned images: ${_titleController.text.trim()}',
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _sendViaQuickDrop() async {
    setState(() => _isExporting = true);
    try {
      File fileToSend;
      if (_selectedFormat == ExportFormat.pdf) {
        fileToSend = (await _generatePdfIfNeeded())!;
      } else {
        final imgs = await _generateImagesIfNeeded();
        fileToSend = imgs!.first;
      }

      if (mounted) {
        final fileItem = FileItem.fromEntity(fileToSend);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QuickDropScreen(filesToSend: [fileItem]),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('QuickDrop prepare failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _openExportedFile(File file) {
    if (file.path.toLowerCase().endsWith('.pdf')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: file.path,
            title: _titleController.text.trim(),
          ),
        ),
      );
    } else {
      OpenFilex.open(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    if (widget.pages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Export Scans')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No pages scanned yet.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Open Camera Scanner'),
              ),
            ],
          ),
        ),
      );
    }

    final currentPage = widget.pages[_currentPageIndex];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Save Scan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share',
            onPressed: _isExporting ? null : _shareFile,
          ),
        ],
      ),
      body: _isExporting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating file and preparing...', style: TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title edit field
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        icon: Icon(Icons.edit_document, color: Colors.teal),
                        border: InputBorder.none,
                        labelText: 'Document Name',
                        isDense: true,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Scanned Page Card with Preview & Controls
                  Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          // Header: Page X of Y & Quick Actions
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withAlpha(30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Page ${_currentPageIndex + 1} of ${widget.pages.length}',
                                  style: const TextStyle(
                                    color: Colors.teal,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                icon: const Icon(Icons.crop, size: 16, color: Colors.teal),
                                label: const Text('Adjust Crop', style: TextStyle(color: Colors.teal, fontSize: 12)),
                                onPressed: () => _adjustCrop(_currentPageIndex),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                tooltip: 'Delete page',
                                onPressed: () => _deletePage(_currentPageIndex),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Large Scanned Page Preview
                          Container(
                            height: 280,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black38 : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              currentPage.processedFile,
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Thumbnails Carousel
                          if (widget.pages.length > 1)
                            SizedBox(
                              height: 64,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemCount: widget.pages.length,
                                separatorBuilder: (context, index) => const SizedBox(width: 8),
                                itemBuilder: (context, idx) {
                                  final isSelected = idx == _currentPageIndex;
                                  return GestureDetector(
                                    onTap: () => setState(() => _currentPageIndex = idx),
                                    child: Container(
                                      width: 48,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected ? Colors.tealAccent : Colors.transparent,
                                          width: 2.5,
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: Image.file(
                                        widget.pages[idx].processedFile,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Add More Scan Images Button (Continuous workflow)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: primaryColor, width: 1.5),
                      ),
                      icon: Icon(Icons.add_a_photo, color: primaryColor),
                      label: Text(
                        '➕ Add More Pages (${widget.pages.length} Scanned)',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        widget.onAddMorePages();
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Output Format Selector: PDF vs Images
                  const Text('EXPORT FORMAT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFormat = ExportFormat.pdf),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedFormat == ExportFormat.pdf
                                  ? Colors.teal.withAlpha(30)
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedFormat == ExportFormat.pdf ? Colors.teal : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.picture_as_pdf, color: _selectedFormat == ExportFormat.pdf ? Colors.teal : Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'PDF Document',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedFormat == ExportFormat.pdf ? Colors.teal : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFormat = ExportFormat.images),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _selectedFormat == ExportFormat.images
                                  ? Colors.teal.withAlpha(30)
                                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedFormat == ExportFormat.images ? Colors.teal : Colors.grey.shade400,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, color: _selectedFormat == ExportFormat.images ? Colors.teal : Colors.grey),
                                const SizedBox(width: 8),
                                Text(
                                  'Images (JPG)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _selectedFormat == ExportFormat.images ? Colors.teal : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (_selectedFormat == ExportFormat.pdf) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('PDF Page Size: ', style: TextStyle(fontWeight: FontWeight.w600)),
                        const Spacer(),
                        ChoiceChip(
                          label: const Text('A4 Standard'),
                          selected: _pdfPageSize == 'A4',
                          onSelected: (val) => setState(() => _pdfPageSize = 'A4'),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Fit to Image'),
                          selected: _pdfPageSize == 'Fit',
                          onSelected: (val) => setState(() => _pdfPageSize = 'Fit'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons: Send via QuickDrop, Share, Save
                  const Text('SAVE & SHARE OPTIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                  const SizedBox(height: 12),

                  // 1. Send via QuickDrop Button (Apple AirDrop style in milliseconds)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 3,
                      ),
                      icon: const Icon(Icons.radar, color: Colors.cyanAccent),
                      label: const Text(
                        '⚡ Send File via QuickDrop (Millisecond Beam)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: _sendViaQuickDrop,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 2. Row: Share & Save to Device
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.share),
                          label: const Text('Share File', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _shareFile,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.save_alt),
                          label: const Text('Save to Device', style: TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _saveToDevice,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 3. Open Directly
                  if (_selectedFormat == ExportFormat.pdf)
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        icon: const Icon(Icons.visibility),
                        label: const Text('Generate & Open in PDF Viewer'),
                        onPressed: () async {
                          final pdf = await _generatePdfIfNeeded();
                          if (pdf != null) _openExportedFile(pdf);
                        },
                      ),
                    ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}

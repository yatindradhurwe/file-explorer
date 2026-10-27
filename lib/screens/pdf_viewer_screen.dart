import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import 'quick_drop_screen.dart';

class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String? title;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.title,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  PDFViewController? _pdfViewController;
  bool _isNightMode = false;
  bool _swipeHorizontal = false;

  String get _fileName => widget.title ?? p.basename(widget.filePath);

  Future<void> _jumpToPageDialog() async {
    if (_totalPages <= 1 || _pdfViewController == null) return;

    final controller = TextEditingController(text: '${_currentPage + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Page Number (1 - $_totalPages)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final page = int.tryParse(controller.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                Navigator.pop(context, page - 1);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (target != null && mounted) {
      await _pdfViewController?.setPage(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _isNightMode ? Colors.black : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fileName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (_isReady && _totalPages > 0)
              Text(
                'Page ${_currentPage + 1} of $_totalPages',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: [
          // Jump to page button
          if (_isReady && _totalPages > 1)
            IconButton(
              icon: const Icon(Icons.bookmark_outline_rounded),
              tooltip: 'Jump to Page',
              onPressed: _jumpToPageDialog,
            ),

          // Invert/Night Mode Toggle
          IconButton(
            icon: Icon(_isNightMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: _isNightMode ? 'Light Mode' : 'Night Mode',
            onPressed: () {
              setState(() => _isNightMode = !_isNightMode);
            },
          ),

          // More options menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              switch (val) {
                case 'orientation':
                  setState(() => _swipeHorizontal = !_swipeHorizontal);
                  break;
                case 'quickdrop':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickDropScreen(
                        filesToSend: [FileItem.fromEntity(File(widget.filePath))],
                      ),
                    ),
                  );
                  break;
                case 'share':
                  await FileOperationsService.shareFiles([widget.filePath]);
                  break;
                case 'open_external':
                  await FileOperationsService.openFile(widget.filePath, type: 'application/pdf');
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'orientation',
                child: Row(
                  children: [
                    Icon(_swipeHorizontal ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded, size: 20),
                    const SizedBox(width: 12),
                    Text(_swipeHorizontal ? 'Vertical Scroll' : 'Horizontal Swipe'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'quickdrop',
                child: Row(
                  children: [
                    Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                    SizedBox(width: 12),
                    Text('⚡ QuickDrop (AirDrop)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.share_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Share PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'open_external',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Open in External App'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorMessage.isEmpty)
            PDFView(
              filePath: widget.filePath,
              enableSwipe: true,
              swipeHorizontal: _swipeHorizontal,
              autoSpacing: true,
              pageFling: true,
              pageSnap: true,
              nightMode: _isNightMode,
              defaultPage: _currentPage,
              fitPolicy: FitPolicy.BOTH,
              preventLinkNavigation: false,
              onRender: (pages) {
                setState(() {
                  _totalPages = pages ?? 0;
                  _isReady = true;
                });
              },
              onError: (error) {
                setState(() {
                  _errorMessage = error.toString();
                  _isReady = true; // stop spinner when error occurs
                });
              },
              onPageError: (page, error) {
                setState(() {
                  _errorMessage = '$page: ${error.toString()}';
                  _isReady = true;
                });
              },
              onViewCreated: (PDFViewController controller) {
                _pdfViewController = controller;
              },
              onPageChanged: (int? page, int? total) {
                setState(() {
                  _currentPage = page ?? 0;
                  _totalPages = total ?? 0;
                });
              },
            ),

          if (!_isReady && _errorMessage.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading PDF document...'),
                ],
              ),
            ),

          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load PDF directly',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open with External PDF Viewer'),
                      onPressed: () {
                        FileOperationsService.openFile(widget.filePath, type: 'application/pdf');
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isReady && _totalPages > 1
          ? Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    tooltip: 'Previous Page',
                    onPressed: _currentPage > 0
                        ? () => _pdfViewController?.setPage(_currentPage - 1)
                        : null,
                  ),
                  Text(
                    'Page ${_currentPage + 1} of $_totalPages',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    tooltip: 'Next Page',
                    onPressed: _currentPage < _totalPages - 1
                        ? () => _pdfViewController?.setPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

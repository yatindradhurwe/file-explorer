import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import '../services/office_document_parser.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';

class OfficeViewerScreen extends StatefulWidget {
  final FileItem item;

  const OfficeViewerScreen({
    super.key,
    required this.item,
  });

  @override
  State<OfficeViewerScreen> createState() => _OfficeViewerScreenState();
}

class _OfficeViewerScreenState extends State<OfficeViewerScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  OfficeFileType _fileType = OfficeFileType.unknown;
  ParsedWordDoc? _wordDoc;
  ParsedPptDoc? _pptDoc;
  ParsedExcelDoc? _excelDoc;

  // View state
  int _currentPage = 0;
  int _selectedSheetIndex = 0;
  bool _isNightMode = false;
  bool _swipeHorizontal = true;
  String _searchQuery = '';
  double _fontSize = 15.0;

  final PageController _pageController = PageController();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fileType = OfficeDocumentParser.detectFileType(widget.item.path);
    _loadDocument();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_fileType == OfficeFileType.word) {
        final parsed = await OfficeDocumentParser.parseWord(widget.item.path);
        if (mounted) {
          setState(() {
            _wordDoc = parsed;
            _isLoading = false;
          });
        }
      } else if (_fileType == OfficeFileType.powerpoint) {
        final parsed = await OfficeDocumentParser.parsePowerPoint(widget.item.path);
        if (mounted) {
          setState(() {
            _pptDoc = parsed;
            _isLoading = false;
          });
        }
      } else if (_fileType == OfficeFileType.excel || _fileType == OfficeFileType.csv) {
        final parsed = await OfficeDocumentParser.parseExcel(widget.item.path);
        if (mounted) {
          setState(() {
            _excelDoc = parsed;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unsupported document format.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // -------------------------------------------------------------
  // OPEN AS PDF LIKE PDF VIEWER
  // -------------------------------------------------------------
  Future<void> _openAsPdf() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Rendering as PDF...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      File? pdfFile;
      if (_fileType == OfficeFileType.word && _wordDoc != null) {
        pdfFile = await OfficeDocumentParser.convertWordDocToPdf(_wordDoc!);
      } else if (_fileType == OfficeFileType.powerpoint && _pptDoc != null) {
        pdfFile = await OfficeDocumentParser.convertPptToPdf(_pptDoc!);
      } else if (_excelDoc != null && _excelDoc!.sheets.isNotEmpty) {
        final sheet = _excelDoc!.sheets[_selectedSheetIndex];
        pdfFile = await OfficeDocumentParser.convertSpreadsheetToPdf(sheet, widget.item.name);
      }

      if (mounted) {
        Navigator.pop(context); // close loader
        if (pdfFile != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: pdfFile!.path,
                title: '${widget.item.name} (PDF Mode)',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to convert to PDF: $e')),
        );
      }
    }
  }

  // -------------------------------------------------------------
  // JUMP TO PAGE / SLIDE DIALOG
  // -------------------------------------------------------------
  Future<void> _jumpToPageDialog(int maxPages) async {
    if (maxPages <= 1) return;
    final controller = TextEditingController(text: '${_currentPage + 1}');
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_fileType == OfficeFileType.powerpoint ? 'Go to Slide' : 'Go to Page'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Number (1 - $maxPages)',
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
              if (page != null && page >= 1 && page <= maxPages) {
                Navigator.pop(context, page - 1);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );

    if (target != null && mounted) {
      _pageController.jumpToPage(target);
      setState(() => _currentPage = target);
    }
  }

  // -------------------------------------------------------------
  // EXTERNAL APP REDIRECT
  // -------------------------------------------------------------
  Future<void> _openInExternalApp() async {
    try {
      final res = await FileOperationsService.openFile(widget.item.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              res.message.isNotEmpty
                  ? res.message
                  : 'No external application found for this file type.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch external viewer: $e')),
        );
      }
    }
  }

  Color get _themeColor {
    switch (_fileType) {
      case OfficeFileType.excel:
      case OfficeFileType.csv:
        return const Color(0xFF107C41); // Excel Green
      case OfficeFileType.powerpoint:
        return const Color(0xFFD24726); // PowerPoint Orange
      case OfficeFileType.word:
        return const Color(0xFF185ABD); // Word Blue
      default:
        return Colors.indigo;
    }
  }

  IconData get _docIcon {
    switch (_fileType) {
      case OfficeFileType.excel:
      case OfficeFileType.csv:
        return Icons.table_chart_rounded;
      case OfficeFileType.powerpoint:
        return Icons.slideshow_rounded;
      case OfficeFileType.word:
        return Icons.article_rounded;
      default:
        return Icons.description_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark || _isNightMode;
    final bgColor = _isNightMode
        ? const Color(0xFF0F172A)
        : (isDark ? const Color(0xFF131D33) : const Color(0xFFF8FAFC));

    final totalPages = _fileType == OfficeFileType.word
        ? (_wordDoc?.pages.length ?? 0)
        : (_fileType == OfficeFileType.powerpoint ? (_pptDoc?.slides.length ?? 0) : 0);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF10192D) : Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_docIcon, color: _themeColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (totalPages > 0)
              Text(
                _fileType == OfficeFileType.powerpoint
                    ? 'Slide ${_currentPage + 1} of $totalPages'
                    : 'Page ${_currentPage + 1} of $totalPages',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _themeColor,
                ),
              ),
          ],
        ),
        actions: [
          // Jump to Page / Slide
          if (totalPages > 1)
            IconButton(
              icon: const Icon(Icons.bookmark_outline_rounded),
              tooltip: _fileType == OfficeFileType.powerpoint ? 'Jump to Slide' : 'Jump to Page',
              onPressed: () => _jumpToPageDialog(totalPages),
            ),

          // 1-Tap Convert & View in PDF Viewer
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
            tooltip: 'Open in PDF Viewer Engine',
            onPressed: _openAsPdf,
          ),

          // Night / Light Mode Toggle
          IconButton(
            icon: Icon(_isNightMode ? Icons.wb_sunny_rounded : Icons.nightlight_round),
            tooltip: _isNightMode ? 'Light Mode' : 'Night Mode',
            onPressed: () => setState(() => _isNightMode = !_isNightMode),
          ),

          // Popup Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) {
              switch (val) {
                case 'pdf':
                  _openAsPdf();
                  break;
                case 'orientation':
                  setState(() => _swipeHorizontal = !_swipeHorizontal);
                  break;
                case 'font_inc':
                  setState(() => _fontSize = (_fontSize + 2).clamp(12.0, 26.0));
                  break;
                case 'font_dec':
                  setState(() => _fontSize = (_fontSize - 2).clamp(12.0, 26.0));
                  break;
                case 'quickdrop':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuickDropScreen(filesToSend: [widget.item]),
                    ),
                  );
                  break;
                case 'share':
                  FileOperationsService.shareFiles([widget.item.path]);
                  break;
                case 'external':
                  _openInExternalApp();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
                    SizedBox(width: 12),
                    Text('Open in PDF Viewer'),
                  ],
                ),
              ),
              if (_fileType != OfficeFileType.excel)
                PopupMenuItem(
                  value: 'orientation',
                  child: Row(
                    children: [
                      Icon(
                        _swipeHorizontal ? Icons.swap_vert_rounded : Icons.swap_horiz_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(_swipeHorizontal ? 'Vertical Scroll' : 'Horizontal Swipe'),
                    ],
                  ),
                ),
              if (_fileType == OfficeFileType.word) ...[
                const PopupMenuItem(
                  value: 'font_inc',
                  child: Row(
                    children: [
                      Icon(Icons.text_increase_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Increase Font Size'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'font_dec',
                  child: Row(
                    children: [
                      Icon(Icons.text_decrease_rounded, size: 20),
                      SizedBox(width: 12),
                      Text('Decrease Font Size'),
                    ],
                  ),
                ),
              ],
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
                    Text('Share Document'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'external',
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
      body: _buildBody(isDark),
      bottomNavigationBar: _buildBottomBar(totalPages, isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: _themeColor),
            const SizedBox(height: 16),
            Text(
              'Opening ${widget.item.name} in-app...',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_docIcon, size: 64, color: _themeColor),
              const SizedBox(height: 16),
              const Text(
                'Could not read document directly',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open in External App'),
                style: FilledButton.styleFrom(backgroundColor: _themeColor),
                onPressed: _openInExternalApp,
              ),
            ],
          ),
        ),
      );
    }

    switch (_fileType) {
      case OfficeFileType.word:
        return _buildWordReader(isDark);
      case OfficeFileType.powerpoint:
        return _buildPptReader(isDark);
      case OfficeFileType.excel:
      case OfficeFileType.csv:
        return _buildExcelReader(isDark);
      default:
        return const Center(child: Text('Unsupported document format'));
    }
  }

  // =============================================================
  // 1. IN-APP WORD DOCUMENT READER (.docx, .doc)
  // =============================================================
  Widget _buildWordReader(bool isDark) {
    if (_wordDoc == null || _wordDoc!.pages.isEmpty) {
      return const Center(child: Text('No content in document'));
    }

    final pages = _wordDoc!.pages;

    return PageView.builder(
      controller: _pageController,
      scrollDirection: _swipeHorizontal ? Axis.horizontal : Axis.vertical,
      itemCount: pages.length,
      onPageChanged: (idx) => setState(() => _currentPage = idx),
      itemBuilder: (context, pageIdx) {
        final page = pages[pageIdx];

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 50 : 15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
              ),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _wordDoc!.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _themeColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _themeColor.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Page ${page.pageNumber} / ${pages.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _themeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Paragraphs
                ...page.paragraphs.map((p) {
                  if (p.isTable && p.tableData != null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Table(
                          border: TableBorder.all(
                            color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          children: p.tableData!.map((row) {
                            return TableRow(
                              children: row.map((cell) {
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    cell,
                                    style: TextStyle(
                                      fontSize: _fontSize * 0.85,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                );
                              }).toList(),
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  }

                  if (p.isHeading) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Text(
                        p.text,
                        style: TextStyle(
                          fontSize: p.headingLevel == 1 ? (_fontSize + 6) : (_fontSize + 3),
                          fontWeight: FontWeight.bold,
                          color: _themeColor,
                        ),
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (p.isBullet) ...[
                          Container(
                            margin: const EdgeInsets.only(top: 7, right: 8),
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _themeColor,
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            p.text,
                            style: TextStyle(
                              fontSize: _fontSize,
                              height: 1.5,
                              fontWeight: p.isBold ? FontWeight.bold : FontWeight.normal,
                              fontStyle: p.isItalic ? FontStyle.italic : FontStyle.normal,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================================================
  // 2. IN-APP POWERPOINT SLIDE VIEWER (.pptx, .ppt)
  // =============================================================
  Widget _buildPptReader(bool isDark) {
    if (_pptDoc == null || _pptDoc!.slides.isEmpty) {
      return const Center(child: Text('No slides found in presentation'));
    }

    final slides = _pptDoc!.slides;

    return Column(
      children: [
        // Slide Canvas Area
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: _swipeHorizontal ? Axis.horizontal : Axis.vertical,
            itemCount: slides.length,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemBuilder: (context, slideIdx) {
              final slide = slides[slideIdx];

              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _themeColor.withAlpha(isDark ? 100 : 70),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _themeColor.withAlpha(isDark ? 60 : 30),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Slide Header & Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  slide.title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: _themeColor,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _themeColor.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${slide.slideNumber} / ${slides.length}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: _themeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 18),

                          // Slide Content Bullets
                          Expanded(
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...slide.bullets.map((b) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '• ',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: _themeColor,
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                b,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  height: 1.4,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )),
                                  ...slide.textBlocks.map((t) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Text(
                                          t,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.4,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      )),
                                  if (slide.table != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Table(
                                        border: TableBorder.all(
                                          color: Colors.grey.shade400,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        children: slide.table!.map((r) {
                                          return TableRow(
                                            children: r.map((c) {
                                              return Padding(
                                                padding: const EdgeInsets.all(6),
                                                child: Text(c, style: const TextStyle(fontSize: 11)),
                                              );
                                            }).toList(),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Thumbnail Drawer Strip
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF10192D) : Colors.white,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: slides.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, idx) {
              final isSelected = idx == _currentPage;

              return InkWell(
                onTap: () {
                  _pageController.jumpToPage(idx);
                  setState(() => _currentPage = idx);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 72,
                  decoration: BoxDecoration(
                    color: isSelected ? _themeColor : (isDark ? const Color(0xFF1E293B) : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.white : Colors.grey.shade400,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Slide ${idx + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // =============================================================
  // 3. IN-APP EXCEL & SPREADSHEET VIEWER (.xlsx, .xls, .csv)
  // =============================================================
  Widget _buildExcelReader(bool isDark) {
    if (_excelDoc == null || _excelDoc!.sheets.isEmpty) {
      return const Center(child: Text('No sheets in spreadsheet'));
    }

    final sheets = _excelDoc!.sheets;
    final currentSheet = sheets[_selectedSheetIndex.clamp(0, sheets.length - 1)];

    // Filter rows
    final filteredRows = _searchQuery.isEmpty
        ? currentSheet.rows
        : currentSheet.rows.where((row) {
            return row.any((cell) => cell.toLowerCase().contains(_searchQuery.toLowerCase()));
          }).toList();

    return Column(
      children: [
        // Sheet Tabs & Search Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? const Color(0xFF10192D) : Colors.white,
          child: Column(
            children: [
              // Search input
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search within sheet...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                ),
              ),

              if (sheets.length > 1) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(sheets.length, (idx) {
                      final isSelected = idx == _selectedSheetIndex;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(Icons.table_chart_rounded, size: 16, color: isSelected ? Colors.white : _themeColor),
                          label: Text(sheets[idx].name),
                          selected: isSelected,
                          selectedColor: _themeColor,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _selectedSheetIndex = idx);
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Row count header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${filteredRows.length} rows • ${currentSheet.totalColumns} columns',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 16, color: Colors.red),
                label: const Text('View as PDF Table', style: TextStyle(fontSize: 11)),
                onPressed: _openAsPdf,
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Interactive Data Grid
        Expanded(
          child: filteredRows.isEmpty
              ? const Center(child: Text('No matching rows found'))
              : SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        _themeColor.withAlpha(isDark ? 60 : 30),
                      ),
                      columns: List.generate(currentSheet.totalColumns, (colIdx) {
                        final colLetter = String.fromCharCode(65 + (colIdx % 26));
                        final headerLabel = (filteredRows.isNotEmpty && colIdx < filteredRows.first.length)
                            ? filteredRows.first[colIdx]
                            : colLetter;

                        return DataColumn(
                          label: Text(
                            headerLabel.isNotEmpty ? headerLabel : colLetter,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _themeColor,
                              fontSize: 13,
                            ),
                          ),
                        );
                      }),
                      rows: filteredRows.skip(1).map((row) {
                        return DataRow(
                          cells: List.generate(currentSheet.totalColumns, (colIdx) {
                            final cellValue = colIdx < row.length ? row[colIdx] : '';
                            return DataCell(
                              Text(cellValue, style: const TextStyle(fontSize: 12.5)),
                            );
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // =============================================================
  // BOTTOM BAR
  // =============================================================
  Widget? _buildBottomBar(int totalPages, bool isDark) {
    if (totalPages <= 1) return null;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isDark ? const Color(0xFF10192D) : Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous',
            onPressed: _currentPage > 0
                ? () {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
          Text(
            _fileType == OfficeFileType.powerpoint
                ? 'Slide ${_currentPage + 1} of $totalPages'
                : 'Page ${_currentPage + 1} of $totalPages',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next',
            onPressed: _currentPage < totalPages - 1
                ? () {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}

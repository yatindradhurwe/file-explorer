import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_item.dart';
import '../services/document_creator_service.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../utils/app_state.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_details_sheet.dart';
import '../widgets/file_tile.dart';
import 'camera_doc_scanner_screen.dart';
import 'office_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';
import 'text_editor_screen.dart';

class DocumentSuiteScreen extends StatefulWidget {
  final int initialTabIndex;

  const DocumentSuiteScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  State<DocumentSuiteScreen> createState() => _DocumentSuiteScreenState();
}

class _DocumentSuiteScreenState extends State<DocumentSuiteScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FileItem> _allDocs = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadDocuments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    try {
      final items = await StorageService.getCategoryFiles(category: FileCategory.document);
      if (mounted) {
        setState(() {
          _allDocs = items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<FileItem> _filterByExtensions(Set<String> exts) {
    var filtered = _allDocs.where((i) => exts.contains(i.extension.toLowerCase())).toList();
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  void _openItem(FileItem item) {
    final ext = item.extension.toLowerCase();
    if (ext == '.pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(filePath: item.path, title: item.name),
        ),
      );
    } else if (ext == '.txt') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextEditorScreen(filePath: item.path, fileName: item.name),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfficeViewerScreen(item: item),
        ),
      );
    }
  }

  // =============================================================
  // CREATE FILE DIALOGS & HANDLERS
  // =============================================================

  // 1. Create New PDF Dialog
  Future<void> _createPdfDialog() async {
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final titleController = TextEditingController(text: 'Document_$timestamp');
    final contentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
            SizedBox(width: 10),
            Text('Create New PDF'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                suffixText: '.pdf',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Initial Notes / Content (Optional)',
                hintText: 'Enter text for your PDF...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Create & Open'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final pdfFile = await DocumentCreatorService.createNewPdf(
          title: titleController.text.trim(),
          initialContent: contentController.text.trim(),
        );
        _loadDocuments();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfViewerScreen(
                filePath: pdfFile.path,
                title: '${titleController.text.trim()}.pdf',
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create PDF: $e')),
          );
        }
      }
    }
  }

  // 2. Create New Excel Dialog
  Future<void> _createExcelDialog() async {
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final titleController = TextEditingController(text: 'Spreadsheet_$timestamp');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.table_chart_rounded, color: Color(0xFF107C41)),
            SizedBox(width: 10),
            Text('Create New Excel'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet Name',
                suffixText: '.xlsx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Creates a formatted Microsoft Excel spreadsheet with starter headers and columns.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF107C41)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Create & Open'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = await DocumentCreatorService.createNewExcel(
          title: titleController.text.trim(),
        );
        _loadDocuments();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfficeViewerScreen(
                item: FileItem.fromEntity(file),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create Excel file: $e')),
          );
        }
      }
    }
  }

  // 3. Create New PPT Dialog
  Future<void> _createPptDialog() async {
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final titleController = TextEditingController(text: 'Presentation_$timestamp');
    final subtitleController = TextEditingController(text: 'Project Overview');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.slideshow_rounded, color: Color(0xFFD24726)),
            SizedBox(width: 10),
            Text('Create New PPT'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Presentation Title',
                suffixText: '.pptx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subtitleController,
              decoration: const InputDecoration(
                labelText: 'Subtitle / Theme',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD24726)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Create & Open'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = await DocumentCreatorService.createNewPowerPoint(
          title: titleController.text.trim(),
          subtitle: subtitleController.text.trim(),
        );
        _loadDocuments();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfficeViewerScreen(
                item: FileItem.fromEntity(file),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create PPT: $e')),
          );
        }
      }
    }
  }

  // 4. Create New Word Doc Dialog
  Future<void> _createDocDialog() async {
    final timestamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final titleController = TextEditingController(text: 'Document_$timestamp');
    final contentController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.article_rounded, color: Color(0xFF185ABD)),
            SizedBox(width: 10),
            Text('Create New Document'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Document Name',
                suffixText: '.docx',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Initial Paragraph / Content (Optional)',
                hintText: 'Start writing notes...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF185ABD)),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Create & Open'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final file = await DocumentCreatorService.createNewWordDoc(
          title: titleController.text.trim(),
          initialContent: contentController.text.trim(),
        );
        _loadDocuments();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OfficeViewerScreen(
                item: FileItem.fromEntity(file),
              ),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create Word document: $e')),
          );
        }
      }
    }
  }

  // Bottom Sheet to Pick Any Document Creation Type
  void _showAllCreateOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create New Document',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.teal.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.document_scanner_rounded, color: Colors.teal),
              ),
              title: const Text('Scan to PDF (Camera)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Adobe Scan-style auto edge detection & crop'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraDocScannerScreen()),
                ).then((_) => _loadDocuments());
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
              ),
              title: const Text('New PDF Document', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Create a blank or formatted .pdf file'),
              onTap: () {
                Navigator.pop(ctx);
                _createPdfDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF107C41).withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41)),
              ),
              title: const Text('New Excel Spreadsheet (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Create a new workbook with table grid'),
              onTap: () {
                Navigator.pop(ctx);
                _createExcelDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFFD24726).withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.slideshow_rounded, color: Color(0xFFD24726)),
              ),
              title: const Text('New PowerPoint Presentation (.pptx)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Create slides with title and content layout'),
              onTap: () {
                Navigator.pop(ctx);
                _createPptDialog();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF185ABD).withAlpha(30), shape: BoxShape.circle),
                child: const Icon(Icons.article_rounded, color: Color(0xFF185ABD)),
              ),
              title: const Text('New Word Document (.docx)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Create formatted document with headings & text'),
              onTap: () {
                Navigator.pop(ctx);
                _createDocDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final pdfs = _filterByExtensions({'.pdf'});
    final excels = _filterByExtensions({'.xlsx', '.xls', '.csv', '.tsv'});
    final ppts = _filterByExtensions({'.pptx', '.ppt'});
    final words = _filterByExtensions({'.docx', '.doc', '.rtf', '.odt', '.txt'});

    return Scaffold(
      appBar: AppBar(
        title: const Text('Docs & Office Suite', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Create New Document...',
            onPressed: _showAllCreateOptions,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: theme.colorScheme.primary,
            labelColor: theme.colorScheme.primary,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 18),
                    const SizedBox(width: 6),
                    Text('PDFs (${pdfs.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.table_chart_rounded, color: Color(0xFF107C41), size: 18),
                    const SizedBox(width: 6),
                    Text('Excel (${excels.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.slideshow_rounded, color: Color(0xFFD24726), size: 18),
                    const SizedBox(width: 6),
                    Text('PPT (${ppts.length})'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  children: [
                    const Icon(Icons.article_rounded, color: Color(0xFF185ABD), size: 18),
                    const SizedBox(width: 6),
                    Text('Word (${words.length})'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search Input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search documents...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade100,
                    ),
                  ),
                ),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildFileList(pdfs, 'No PDF documents found', Icons.picture_as_pdf_rounded, Colors.red),
                      _buildFileList(excels, 'No Excel spreadsheets found', Icons.table_chart_rounded, const Color(0xFF107C41)),
                      _buildFileList(ppts, 'No PowerPoint slides found', Icons.slideshow_rounded, const Color(0xFFD24726)),
                      _buildFileList(words, 'No Word documents found', Icons.article_rounded, const Color(0xFF185ABD)),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  // =============================================================
  // CONTEXTUAL FLOATING ACTION BUTTONS
  // =============================================================
  Widget _buildFloatingActionButtons() {
    final currentTab = _tabController.index;

    switch (currentTab) {
      case 0: // PDF Tab
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Create New PDF Button
            FloatingActionButton.extended(
              heroTag: 'fab_create_pdf',
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create New PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _createPdfDialog,
            ),
            const SizedBox(height: 10),
            // Scan to PDF Button
            FloatingActionButton.extended(
              heroTag: 'fab_scan_pdf',
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.document_scanner_rounded),
              label: const Text('Scan to PDF', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraDocScannerScreen()),
                ).then((_) => _loadDocuments());
              },
            ),
          ],
        );

      case 1: // Excel Tab
        return FloatingActionButton.extended(
          heroTag: 'fab_create_excel',
          backgroundColor: const Color(0xFF107C41),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Excel (.xlsx)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _createExcelDialog,
        );

      case 2: // PPT Tab
        return FloatingActionButton.extended(
          heroTag: 'fab_create_ppt',
          backgroundColor: const Color(0xFFD24726),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create PPT (.pptx)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _createPptDialog,
        );

      case 3: // Word / Docs Tab
        return FloatingActionButton.extended(
          heroTag: 'fab_create_doc',
          backgroundColor: const Color(0xFF185ABD),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create Doc (.docx)', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _createDocDialog,
        );

      default:
        return FloatingActionButton.extended(
          heroTag: 'fab_default',
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New Document', style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: _showAllCreateOptions,
        );
    }
  }

  Widget _buildFileList(
    List<FileItem> items,
    String emptyMessage,
    IconData emptyIcon,
    Color accentColor,
  ) {
    if (items.isEmpty) {
      return Center(
        child: EmptyState(
          icon: emptyIcon,
          title: emptyMessage,
          subtitle: 'Tap the button below to create or scan documents.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDocuments,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return FileTile(
            item: item,
            isSelected: false,
            isSelectionMode: false,
            onTap: () => _openItem(item),
            onLongPress: () => _openItem(item),
            onOpen: () => _openItem(item),
            onShare: () => FileOperationsService.shareFiles([item.path]),
            onCopy: () {
              AppState.instance.copyToClipboard([item], '');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            onCut: () {
              AppState.instance.cutToClipboard([item], '');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ready to move')),
              );
            },
            onRename: () => _renameItem(item),
            onDelete: () async {
              await FileOperationsService.deleteItems([item.path]);
              _loadDocuments();
            },
            onDetails: () => FileDetailsSheet.show(context, item),
            onQuickDrop: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QuickDropScreen(filesToSend: [item]),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _renameItem(FileItem item) async {
    final controller = TextEditingController(text: item.name);
    final formKey = GlobalKey<FormState>();

    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'New name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(context, controller.text.trim());
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (newName != null && newName != item.name) {
      try {
        await FileOperationsService.rename(item.path, newName);
        _loadDocuments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rename failed: $e')),
          );
        }
      }
    }
  }
}

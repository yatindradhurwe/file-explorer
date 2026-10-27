import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_tile.dart';
import '../widgets/file_details_sheet.dart';
import 'image_viewer_screen.dart';
import 'office_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';
import 'text_editor_screen.dart';

class SearchScreen extends StatefulWidget {
  final String rootPath;

  const SearchScreen({
    super.key,
    required this.rootPath,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<FileItem> _results = [];
  bool _isSearching = false;
  String _lastQuery = '';

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _lastQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _lastQuery = clean;
    });

    try {
      final matches = await StorageService.searchFiles(
        rootPath: widget.rootPath,
        query: clean,
      );
      if (mounted && _lastQuery == clean) {
        setState(() {
          _results = matches;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _handleOpen(FileItem item) {
    if (item.isDirectory) {
      Navigator.pop(context, item.path);
    } else if (item.extension.toLowerCase() == '.pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(
            filePath: item.path,
            title: item.name,
          ),
        ),
      );
    } else if ({'.xlsx', '.xls', '.csv', '.tsv', '.pptx', '.ppt', '.docx', '.doc', '.rtf'}.contains(item.extension.toLowerCase())) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OfficeViewerScreen(item: item),
        ),
      );
    } else if (item.isImage) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewerScreen(
            item: item,
            onDelete: () => _performSearch(_lastQuery),
          ),
        ),
      );
    } else if (item.isTextEditable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TextEditorScreen(
            filePath: item.path,
            fileName: item.name,
          ),
        ),
      );
    } else {
      FileOperationsService.openFile(item.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _performSearch,
          decoration: InputDecoration(
            hintText: 'Search files and folders...',
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      _performSearch('');
                    },
                  )
                : null,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
            onPressed: () => _performSearch(_searchController.text),
          ),
        ],
      ),
      body: _isSearching
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Searching files...'),
                ],
              ),
            )
          : _lastQuery.isEmpty
              ? const EmptyState(
                  icon: Icons.search_rounded,
                  title: 'Search files & folders',
                  subtitle: 'Enter a file name or extension to search throughout your storage.',
                )
              : _results.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results found',
                      subtitle: 'No files or folders matching "$_lastQuery" were found.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Found ${_results.length} items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return FileTile(
                                item: item,
                                isSelected: false,
                                isSelectionMode: false,
                                onTap: () => _handleOpen(item),
                                onLongPress: () => _handleOpen(item),
                                onOpen: () => _handleOpen(item),
                                onQuickDrop: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QuickDropScreen(filesToSend: [item]),
                                    ),
                                  );
                                },
                                onShare: () => FileOperationsService.shareFiles([item.path]),
                                onCopy: () {},
                                onCut: () {},
                                onRename: () {},
                                onDelete: () async {
                                  await FileOperationsService.deleteItems([item.path]);
                                  _performSearch(_lastQuery);
                                },
                                onDetails: () => FileDetailsSheet.show(context, item),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../utils/app_state.dart';
import '../utils/file_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_grid_tile.dart';
import '../widgets/file_tile.dart';
import '../widgets/file_details_sheet.dart';
import 'image_viewer_screen.dart';
import 'office_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';
import 'text_editor_screen.dart';

class CategoryScreen extends StatefulWidget {
  final FileCategory category;

  const CategoryScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  final appState = AppState.instance;
  List<FileItem> _items = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearching = false;
  final Set<String> _selectedPaths = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final results = await StorageService.getCategoryFiles(category: widget.category);
      if (mounted) {
        setState(() {
          _items = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<FileItem> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    return _items
        .where((i) => i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _toggleSelection(FileItem item) {
    setState(() {
      if (_selectedPaths.contains(item.path)) {
        _selectedPaths.remove(item.path);
        if (_selectedPaths.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedPaths.add(item.path);
        _isSelectionMode = true;
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedPaths.length == _filteredItems.length) {
        _selectedPaths.clear();
        _isSelectionMode = false;
      } else {
        _selectedPaths.addAll(_filteredItems.map((e) => e.path));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleOpen(FileItem item) async {
    if (_isSelectionMode) {
      _toggleSelection(item);
      return;
    }

    if (item.extension.toLowerCase() == '.pdf') {
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
            onDelete: _loadItems,
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
      final res = await FileOperationsService.openFile(item.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'No application found to play or open this file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _deleteSelected() async {
    final count = _selectedPaths.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Items?'),
        content: Text('Permanently delete $count selected ${count == 1 ? 'item' : 'items'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FileOperationsService.deleteItems(_selectedPaths.toList());
      setState(() {
        _selectedPaths.clear();
        _isSelectionMode = false;
      });
      _loadItems();
    }
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
            decoration: const InputDecoration(labelText: 'New Name'),
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
              if (formKey.currentState!.validate()) {
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
        _loadItems();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rename failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryTitle = FileUtils.getCategoryLabel(widget.category);
    final displayedItems = _filteredItems;

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(categoryTitle),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayedItems.isEmpty
                  ? EmptyState(
                      icon: FileUtils.getCategoryIcon(widget.category),
                      title: 'No ${categoryTitle.toLowerCase()} found',
                      subtitle: 'Files of this type in standard storage folders will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: appState.isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 0.82,
                              ),
                              itemCount: displayedItems.length,
                              itemBuilder: (context, index) {
                                final item = displayedItems[index];
                                final isSelected = _selectedPaths.contains(item.path);

                                return FileGridTile(
                                  item: item,
                                  isSelected: isSelected,
                                  isSelectionMode: _isSelectionMode,
                                  onTap: () => _handleOpen(item),
                                  onLongPress: () => _toggleSelection(item),
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
                                  onCopy: () {
                                    appState.copyToClipboard([item], '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item copied to clipboard')),
                                    );
                                  },
                                  onCut: () {
                                    appState.cutToClipboard([item], '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item ready to move')),
                                    );
                                  },
                                  onRename: () => _renameItem(item),
                                  onDelete: () async {
                                    await FileOperationsService.deleteItems([item.path]);
                                    _loadItems();
                                  },
                                  onDetails: () => FileDetailsSheet.show(context, item),
                                );
                              },
                            )
                          : ListView.separated(
                              itemCount: displayedItems.length,
                              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                              itemBuilder: (context, index) {
                                final item = displayedItems[index];
                                final isSelected = _selectedPaths.contains(item.path);

                                return FileTile(
                                  item: item,
                                  isSelected: isSelected,
                                  isSelectionMode: _isSelectionMode,
                                  onTap: () => _handleOpen(item),
                                  onLongPress: () => _toggleSelection(item),
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
                                  onCopy: () {
                                    appState.copyToClipboard([item], '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item copied to clipboard')),
                                    );
                                  },
                                  onCut: () {
                                    appState.cutToClipboard([item], '');
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item ready to move')),
                                    );
                                  },
                                  onRename: () => _renameItem(item),
                                  onDelete: () async {
                                    await FileOperationsService.deleteItems([item.path]);
                                    _loadItems();
                                  },
                                  onDetails: () => FileDetailsSheet.show(context, item),
                                );
                              },
                            ),
                    ),
        );
      },
    );
  }

  AppBar _buildNormalAppBar(String title) {
    return AppBar(
      title: _isSearching
          ? TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Filter files...',
                border: InputBorder.none,
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            )
          : Text(title),
      actions: [
        IconButton(
          icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
          tooltip: _isSearching ? 'Close Search' : 'Search',
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) _searchQuery = '';
            });
          },
        ),
        IconButton(
          icon: Icon(appState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          tooltip: appState.isGridView ? 'List View' : 'Grid View',
          onPressed: () => appState.toggleViewMode(),
        ),
      ],
    );
  }

  AppBar _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          setState(() {
            _selectedPaths.clear();
            _isSelectionMode = false;
          });
        },
      ),
      title: Text('${_selectedPaths.length} selected'),
      actions: [
        IconButton(
          icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
          tooltip: 'QuickDrop',
          onPressed: () {
            final selectedItems = _items.where((i) => _selectedPaths.contains(i.path)).toList();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QuickDropScreen(filesToSend: selectedItems),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.select_all_rounded),
          tooltip: 'Select All',
          onPressed: _selectAll,
        ),
        IconButton(
          icon: const Icon(Icons.share_rounded),
          tooltip: 'Share',
          onPressed: () {
            FileOperationsService.shareFiles(_selectedPaths.toList());
          },
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
          tooltip: 'Delete',
          onPressed: _deleteSelected,
        ),
      ],
    );
  }
}

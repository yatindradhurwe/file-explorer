import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../services/file_operations_service.dart';
import '../services/storage_service.dart';
import '../utils/app_state.dart';
import '../widgets/breadcrumb_bar.dart';
import '../widgets/clipboard_banner.dart';
import '../widgets/empty_state.dart';
import '../widgets/file_details_sheet.dart';
import '../widgets/file_grid_tile.dart';
import '../widgets/file_tile.dart';
import 'image_viewer_screen.dart';
import 'office_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'quick_drop_screen.dart';
import 'search_screen.dart';
import 'text_editor_screen.dart';

class ExplorerScreen extends StatefulWidget {
  final String initialPath;
  final String rootPath;
  final String title;

  const ExplorerScreen({
    super.key,
    required this.initialPath,
    required this.rootPath,
    this.title = 'Files',
  });

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  final appState = AppState.instance;
  late String _currentPath;
  List<FileItem> _items = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Multi-selection state
  bool _isSelectionMode = false;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectory();
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await StorageService.listDirectory(
        path: _currentPath,
        showHidden: appState.showHiddenFiles,
        sortBy: appState.sortBy,
        ascending: appState.sortAscending,
      );

      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _navigateTo(String newPath) {
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedPaths.clear();
      });
    }
    setState(() {
      _currentPath = newPath;
    });
    _loadDirectory();
  }

  bool _navigateUp() {
    if (_isSelectionMode) {
      setState(() {
        _isSelectionMode = false;
        _selectedPaths.clear();
      });
      return false;
    }

    if (_currentPath != widget.rootPath) {
      final parent = p.dirname(_currentPath);
      if (parent.isNotEmpty && parent != _currentPath) {
        _navigateTo(parent);
        return false;
      }
    }
    return true; // Pop screen
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
      if (_selectedPaths.length == _items.length) {
        _selectedPaths.clear();
        _isSelectionMode = false;
      } else {
        _selectedPaths.addAll(_items.map((e) => e.path));
        _isSelectionMode = true;
      }
    });
  }

  Future<void> _handleItemTap(FileItem item) async {
    if (_isSelectionMode) {
      _toggleSelection(item);
      return;
    }

    if (item.isDirectory) {
      _navigateTo(item.path);
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
            onDelete: _loadDirectory,
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
      ).then((_) => _loadDirectory());
    } else {
      final res = await FileOperationsService.openFile(item.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res.message.isNotEmpty ? res.message : 'No application found to open or play this file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- File Actions ---

  Future<void> _createFolderDialog() async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Folder'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Folder Name',
              hintText: 'e.g. My Documents',
            ),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      try {
        await FileOperationsService.createFolder(_currentPath, folderName);
        _loadDirectory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create folder: $e')),
          );
        }
      }
    }
  }

  Future<void> _createFileDialog() async {
    final controller = TextEditingController(text: 'notes.txt');
    final formKey = GlobalKey<FormState>();

    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Text File'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'File Name',
              hintText: 'e.g. notes.txt',
            ),
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
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (fileName != null && fileName.isNotEmpty) {
      try {
        final created = await FileOperationsService.createFile(_currentPath, fileName);
        await _loadDirectory();
        if (mounted) {
          // Open newly created file in text editor
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TextEditorScreen(
                filePath: created.path,
                fileName: fileName,
              ),
            ),
          ).then((_) => _loadDirectory());
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create file: $e')),
          );
        }
      }
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
        _loadDirectory();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rename failed: $e')),
          );
        }
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
      _loadDirectory();
    }
  }

  void _copySelected() {
    final selectedItems = _items.where((i) => _selectedPaths.contains(i.path)).toList();
    appState.copyToClipboard(selectedItems, _currentPath);
    setState(() {
      _selectedPaths.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedItems.length} items copied. Go to destination and tap Paste.')),
    );
  }

  void _cutSelected() {
    final selectedItems = _items.where((i) => _selectedPaths.contains(i.path)).toList();
    appState.cutToClipboard(selectedItems, _currentPath);
    setState(() {
      _selectedPaths.clear();
      _isSelectionMode = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${selectedItems.length} items ready to move. Go to destination and tap Paste.')),
    );
  }

  Future<void> _pasteClipboard() async {
    final clip = appState.clipboardData;
    if (clip == null) return;

    final paths = clip.items.map((i) => i.path).toList();
    if (clip.isCut) {
      await FileOperationsService.moveItems(paths, _currentPath);
      appState.clearClipboard();
    } else {
      await FileOperationsService.copyItems(paths, _currentPath);
    }

    _loadDirectory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pasted ${paths.length} items successfully')),
      );
    }
  }

  void _showSortDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sort Files By',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    title: const Text('Name'),
                    leading: const Icon(Icons.sort_by_alpha_rounded),
                    trailing: appState.sortBy == SortBy.name ? const Icon(Icons.check_rounded, color: Colors.blue) : null,
                    onTap: () {
                      appState.setSortOption(SortBy.name, appState.sortAscending);
                      Navigator.pop(context);
                      _loadDirectory();
                    },
                  ),
                  ListTile(
                    title: const Text('Date Modified'),
                    leading: const Icon(Icons.calendar_today_rounded),
                    trailing: appState.sortBy == SortBy.date ? const Icon(Icons.check_rounded, color: Colors.blue) : null,
                    onTap: () {
                      appState.setSortOption(SortBy.date, appState.sortAscending);
                      Navigator.pop(context);
                      _loadDirectory();
                    },
                  ),
                  ListTile(
                    title: const Text('Size'),
                    leading: const Icon(Icons.data_usage_rounded),
                    trailing: appState.sortBy == SortBy.size ? const Icon(Icons.check_rounded, color: Colors.blue) : null,
                    onTap: () {
                      appState.setSortOption(SortBy.size, appState.sortAscending);
                      Navigator.pop(context);
                      _loadDirectory();
                    },
                  ),
                  ListTile(
                    title: const Text('File Type'),
                    leading: const Icon(Icons.category_rounded),
                    trailing: appState.sortBy == SortBy.type ? const Icon(Icons.check_rounded, color: Colors.blue) : null,
                    onTap: () {
                      appState.setSortOption(SortBy.type, appState.sortAscending);
                      Navigator.pop(context);
                      _loadDirectory();
                    },
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Ascending Order'),
                    value: appState.sortAscending,
                    onChanged: (val) {
                      appState.setSortOption(appState.sortBy, val);
                      setModalState(() {});
                      _loadDirectory();
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRoot = _currentPath == widget.rootPath;

    return PopScope(
      canPop: isRoot && !_isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _navigateUp();
      },
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return Scaffold(
            appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
            body: Column(
              children: [
                // Interactive Breadcrumb Navigation
                BreadcrumbBar(
                  currentPath: _currentPath,
                  rootPath: widget.rootPath,
                  onPathSelected: _navigateTo,
                ),

                // Content Area
                Expanded(
                  child: Stack(
                    children: [
                      _buildBody(),

                      // Clipboard Banner for Paste
                      if (appState.hasClipboard)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: ClipboardBanner(
                            data: appState.clipboardData!,
                            onPaste: _pasteClipboard,
                            onCancel: () => appState.clearClipboard(),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: _isSelectionMode
                ? null
                : FloatingActionButton.extended(
                    onPressed: () => _showAddOptions(context),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return EmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Access Restricted',
        subtitle: 'Could not access this directory. Check system permissions.',
        actionLabel: 'Retry',
        onAction: _loadDirectory,
      );
    }

    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.folder_open_rounded,
        title: 'Folder is empty',
        subtitle: 'Tap the + button below to create a new folder or file.',
        actionLabel: 'Create Folder',
        onAction: _createFolderDialog,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDirectory,
      child: appState.isGridView
          ? GridView.builder(
              padding: EdgeInsets.fromLTRB(12, 12, 12, appState.hasClipboard ? 90 : 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.82,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = _selectedPaths.contains(item.path);

                return FileGridTile(
                  item: item,
                  isSelected: isSelected,
                  isSelectionMode: _isSelectionMode,
                  onTap: () => _handleItemTap(item),
                  onLongPress: () => _toggleSelection(item),
                  onOpen: () => _handleItemTap(item),
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
                    appState.copyToClipboard([item], _currentPath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item copied. Navigate and tap Paste.')),
                    );
                  },
                  onCut: () {
                    appState.cutToClipboard([item], _currentPath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item ready to move. Navigate and tap Paste.')),
                    );
                  },
                  onRename: () => _renameItem(item),
                  onDelete: () async {
                    await FileOperationsService.deleteItems([item.path]);
                    _loadDirectory();
                  },
                  onDetails: () => FileDetailsSheet.show(context, item),
                );
              },
            )
          : ListView.separated(
              padding: EdgeInsets.fromLTRB(0, 0, 0, appState.hasClipboard ? 90 : 80),
              itemCount: _items.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isSelected = _selectedPaths.contains(item.path);

                return FileTile(
                  item: item,
                  isSelected: isSelected,
                  isSelectionMode: _isSelectionMode,
                  onTap: () => _handleItemTap(item),
                  onLongPress: () => _toggleSelection(item),
                  onOpen: () => _handleItemTap(item),
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
                    appState.copyToClipboard([item], _currentPath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item copied. Navigate and tap Paste.')),
                    );
                  },
                  onCut: () {
                    appState.cutToClipboard([item], _currentPath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Item ready to move. Navigate and tap Paste.')),
                    );
                  },
                  onRename: () => _renameItem(item),
                  onDelete: () async {
                    await FileOperationsService.deleteItems([item.path]);
                    _loadDirectory();
                  },
                  onDetails: () => FileDetailsSheet.show(context, item),
                );
              },
            ),
    );
  }

  AppBar _buildNormalAppBar() {
    final folderName = p.basename(_currentPath);

    return AppBar(
      leading: _currentPath != widget.rootPath
          ? IconButton(
              icon: const Icon(Icons.arrow_upward_rounded),
              tooltip: 'Up one level',
              onPressed: _navigateUp,
            )
          : null,
      title: Text(
        folderName.isEmpty ? widget.title : folderName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          tooltip: 'Search in folder',
          onPressed: () async {
            final selectedPath = await Navigator.push<String>(
              context,
              MaterialPageRoute(
                builder: (_) => SearchScreen(rootPath: _currentPath),
              ),
            );
            if (selectedPath != null && mounted) {
              _navigateTo(selectedPath);
            }
          },
        ),
        IconButton(
          icon: Icon(appState.isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
          tooltip: appState.isGridView ? 'List View' : 'Grid View',
          onPressed: () => appState.toggleViewMode(),
        ),
        IconButton(
          icon: const Icon(Icons.sort_rounded),
          tooltip: 'Sort',
          onPressed: _showSortDialog,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (val) {
            if (val == 'hidden') {
              appState.toggleShowHiddenFiles();
              _loadDirectory();
            } else if (val == 'refresh') {
              _loadDirectory();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'hidden',
              child: Row(
                children: [
                  Icon(
                    appState.showHiddenFiles
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(appState.showHiddenFiles ? 'Hide hidden files' : 'Show hidden files'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 20),
                  SizedBox(width: 12),
                  Text('Refresh'),
                ],
              ),
            ),
          ],
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
          icon: const Icon(Icons.content_copy_rounded),
          tooltip: 'Copy',
          onPressed: _copySelected,
        ),
        IconButton(
          icon: const Icon(Icons.content_cut_rounded),
          tooltip: 'Cut / Move',
          onPressed: _cutSelected,
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

  void _showAddOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.create_new_folder_rounded, color: Colors.amber),
                ),
                title: const Text('New Folder'),
                subtitle: const Text('Create a new directory in current folder'),
                onTap: () {
                  Navigator.pop(context);
                  _createFolderDialog();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.note_add_rounded, color: Colors.blue),
                ),
                title: const Text('New Text File'),
                subtitle: const Text('Create and edit a new text file'),
                onTap: () {
                  Navigator.pop(context);
                  _createFileDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../models/storage_info.dart';
import '../services/permission_service.dart';
import '../services/storage_service.dart';
import '../utils/app_state.dart';
import '../widgets/app_drawer.dart';
import '../widgets/category_grid.dart';
import '../widgets/storage_card.dart';
import 'camera_doc_scanner_screen.dart';
import 'category_screen.dart';
import 'document_suite_screen.dart';
import 'explorer_screen.dart';
import 'permission_screen.dart';
import 'quick_drop_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final appState = AppState.instance;
  bool _hasPermission = false;
  bool _isLoading = true;
  String _rootPath = '';
  List<StorageInfo> _storages = [];
  Map<String, String> _quickFolders = {};

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    setState(() => _isLoading = true);
    // First check if already granted
    bool granted = await PermissionService.hasStoragePermission();
    if (!granted) {
      // Request at launch (only the first time or after being denied)
      granted = await PermissionService.requestStoragePermission();
    }
    if (granted) {
      _hasPermission = true;
      await _loadStorageData();
    } else {
      _hasPermission = false;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStorageData() async {
    setState(() => _isLoading = true);
    final root = await StorageService.getRootPath();
    final storages = await StorageService.getStorageLocations();
    final quickFolders = await StorageService.getQuickAccessFolders();

    if (mounted) {
      setState(() {
        _rootPath = root;
        _storages = storages;
        _quickFolders = quickFolders;
        _isLoading = false;
      });
    }
  }

  void _onCategoryTapped(FileCategory category) {
    if (category == FileCategory.document) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DocumentSuiteScreen(),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryScreen(category: category),
      ),
    );
  }

  void _openFolder(String path, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExplorerScreen(
          initialPath: path,
          rootPath: _rootPath,
          title: title,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return PermissionScreen(
        onPermissionGranted: () {
          setState(() => _hasPermission = true);
          _loadStorageData();
        },
      );
    }

    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        return Scaffold(
          drawer: const AppDrawer(),
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withAlpha(80),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'File Explore',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3),
                    ),
                    Text(
                      'design by yjtechnosoft',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.bolt_rounded, color: Colors.amber),
                tooltip: 'QuickDrop (AirDrop)',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QuickDropScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.search_rounded),
                tooltip: 'Search files',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SearchScreen(rootPath: _rootPath),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(appState.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
                tooltip: appState.isDarkMode ? 'Light Mode' : 'Dark Mode',
                onPressed: () => appState.toggleTheme(),
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: _loadStorageData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Storage Cards
                  const Text(
                    'Storage',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._storages.map(
                    (storage) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: StorageCard(
                        storage: storage,
                        onTap: () => _openFolder(storage.path, storage.name),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  // QuickDrop Instant Transfer Card
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuickDropScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF38BDF8).withAlpha(80),
                          width: 1.4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withAlpha(40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.amber.withAlpha(100),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 28),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'QuickDrop',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'AirDrop',
                                      style: TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Transfer in milliseconds • 0% mobile data',
                                  style: TextStyle(
                                    color: Color(0xFF94A3B8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withAlpha(30),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Adobe Scan & PDF Suite Quick Bar
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CameraDocScannerScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.teal.withAlpha(70),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.document_scanner_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Doc Scanner',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'Scan to PDF',
                                        style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 10, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DocumentSuiteScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.indigo.withAlpha(70),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.menu_book_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Office & PDFs',
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                      Text(
                                        'PDF • Excel • PPT',
                                        style: TextStyle(color: Color(0xFFE0E7FF), fontSize: 10, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Categories Section
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  CategoryGrid(onCategoryTap: _onCategoryTapped),

                  const SizedBox(height: 24),

                  // Quick Access Folders
                  if (_quickFolders.isNotEmpty) ...[
                    const Text(
                      'Quick Access',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: _quickFolders.entries.map((entry) {
                          IconData folderIcon = Icons.folder_rounded;
                          Color folderColor = Colors.amber;

                          if (entry.key.contains('Download')) {
                            folderIcon = Icons.download_rounded;
                            folderColor = Colors.blue;
                          } else if (entry.key.contains('Photos') || entry.key.contains('Camera')) {
                            folderIcon = Icons.photo_camera_rounded;
                            folderColor = Colors.purple;
                          } else if (entry.key.contains('Music')) {
                            folderIcon = Icons.headphones_rounded;
                            folderColor = Colors.orange;
                          } else if (entry.key.contains('Movies') || entry.key.contains('Videos')) {
                            folderIcon = Icons.movie_rounded;
                            folderColor = Colors.red;
                          } else if (entry.key.contains('WhatsApp')) {
                            folderIcon = Icons.chat_rounded;
                            folderColor = Colors.green;
                          }

                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: folderColor.withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(folderIcon, color: folderColor, size: 22),
                            ),
                            title: Text(
                              entry.key,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              entry.value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                            onTap: () => _openFolder(entry.value, entry.key),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Browse Entire Storage Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _openFolder(_rootPath, 'Internal Storage'),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('Browse All Files'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import '../screens/camera_doc_scanner_screen.dart';
import '../screens/document_suite_screen.dart';
import '../screens/explorer_screen.dart';
import '../screens/quick_drop_screen.dart';
import '../screens/search_screen.dart';
import '../services/storage_service.dart';
import '../utils/app_state.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppState.instance;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 50, bottom: 20, left: 20, right: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.folder_copy_rounded,
                        color: Color(0xFF2563EB),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'File Explore',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'design by yjtechnosoft',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(35),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'v1.0.0 • Google Play Edition',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Menu List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _sectionHeader('DOCUMENT TOOLS & SCANNER'),
                _drawerTile(
                  context,
                  icon: Icons.document_scanner_rounded,
                  iconColor: Colors.teal,
                  title: 'Doc Scanner (Adobe Scan)',
                  badge: 'NEW',
                  badgeColor: Colors.teal,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CameraDocScannerScreen()),
                    );
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: Colors.red,
                  title: 'PDF Reader & Viewer',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DocumentSuiteScreen(initialTabIndex: 0)),
                    );
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.table_chart_rounded,
                  iconColor: const Color(0xFF107C41),
                  title: 'Excel & Spreadsheets',
                  subtitle: '.xlsx, .xls, .csv',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DocumentSuiteScreen(initialTabIndex: 1)),
                    );
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.slideshow_rounded,
                  iconColor: const Color(0xFFD24726),
                  title: 'PowerPoint & Slides',
                  subtitle: '.pptx, .ppt',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DocumentSuiteScreen(initialTabIndex: 2)),
                    );
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.article_rounded,
                  iconColor: const Color(0xFF185ABD),
                  title: 'Word Documents',
                  subtitle: '.docx, .doc, .rtf',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DocumentSuiteScreen(initialTabIndex: 3)),
                    );
                  },
                ),

                const Divider(height: 24),
                _sectionHeader('TRANSFER & STORAGE'),
                _drawerTile(
                  context,
                  icon: Icons.bolt_rounded,
                  iconColor: Colors.amber,
                  title: 'QuickDrop (AirDrop)',
                  subtitle: 'Instant peer-to-peer file transfer',
                  badge: 'FAST',
                  badgeColor: Colors.amber,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const QuickDropScreen()),
                    );
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: 'Internal Storage',
                  subtitle: 'Browse all files & directories',
                  onTap: () async {
                    Navigator.pop(context);
                    final root = await StorageService.getRootPath();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExplorerScreen(initialPath: root, rootPath: root),
                        ),
                      );
                    }
                  },
                ),
                _drawerTile(
                  context,
                  icon: Icons.search_rounded,
                  iconColor: Colors.purple,
                  title: 'Search Storage',
                  onTap: () async {
                    Navigator.pop(context);
                    final root = await StorageService.getRootPath();
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SearchScreen(rootPath: root),
                        ),
                      );
                    }
                  },
                ),

                const Divider(height: 24),
                _sectionHeader('SETTINGS & PREFERENCES'),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.indigo : Colors.amber).withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: isDark ? Colors.indigo.shade200 : Colors.amber.shade700,
                      size: 20,
                    ),
                  ),
                  title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  trailing: Switch(
                    value: appState.isDarkMode,
                    onChanged: (val) {
                      appState.toggleTheme();
                    },
                  ),
                ),
                _drawerTile(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: Colors.grey,
                  title: 'About File Explore',
                  onTap: () {
                    Navigator.pop(context);
                    _showAboutDialog(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _drawerTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withAlpha(25),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
          if (badge != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (badgeColor ?? Colors.blue).withAlpha(35),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: badgeColor ?? Colors.blue,
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))
          : null,
      onTap: onTap,
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'File Explore',
      applicationVersion: '1.0.0 (Build 1)',
      applicationLegalese: '© 2026 yjtechnosoft. All rights reserved.\nDesign by yjtechnosoft.',
      applicationIcon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.folder_copy_rounded, color: Colors.white, size: 32),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'File Explore is a complete mobile file manager and offline peer-to-peer sharing solution with built-in PDF Reader, Adobe Scan-like document scanner, and Office document viewer.',
        ),
      ],
    );
  }
}

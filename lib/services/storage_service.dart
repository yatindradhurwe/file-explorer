import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../models/storage_info.dart';

class StorageService {
  static const String androidInternalStorage = '/storage/emulated/0';

  /// Returns the main root directory to explore
  static Future<String> getRootPath() async {
    if (kIsWeb) return '/';

    if (Platform.isAndroid) {
      final dir = Directory(androidInternalStorage);
      if (await dir.exists()) {
        return androidInternalStorage;
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        return ext.path;
      }
    }

    if (Platform.isIOS) {
      final appDocDir = await getApplicationDocumentsDirectory();
      return appDocDir.path;
    }

    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && await Directory(userProfile).exists()) {
        return userProfile;
      }
      return 'C:\\';
    }

    if (Platform.isMacOS || Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && await Directory(home).exists()) {
        return home;
      }
      return '/';
    }

    final docDir = await getApplicationDocumentsDirectory();
    return docDir.path;
  }

  /// Returns list of detected storages (e.g., Internal Storage, SD Card, etc.)
  static Future<List<StorageInfo>> getStorageLocations() async {
    final List<StorageInfo> storages = [];

    if (Platform.isAndroid) {
      final internalDir = Directory(androidInternalStorage);
      if (await internalDir.exists()) {
        storages.add(
          const StorageInfo(
            name: 'Internal Storage',
            path: androidInternalStorage,
            totalBytes: 128 * 1024 * 1024 * 1024, // 128 GB estimate placeholder or calculated
            usedBytes: 64 * 1024 * 1024 * 1024,
            freeBytes: 64 * 1024 * 1024 * 1024,
            icon: Icons.phone_android_rounded,
          ),
        );
      }

      // Check for SD Cards in /storage
      try {
        final storageRoot = Directory('/storage');
        if (await storageRoot.exists()) {
          final entities = storageRoot.listSync();
          for (var entity in entities) {
            final name = p.basename(entity.path);
            if (entity is Directory &&
                name != 'emulated' &&
                name != 'self' &&
                !name.startsWith('.')) {
              storages.add(
                StorageInfo(
                  name: 'SD Card ($name)',
                  path: entity.path,
                  totalBytes: 64 * 1024 * 1024 * 1024,
                  usedBytes: 20 * 1024 * 1024 * 1024,
                  freeBytes: 44 * 1024 * 1024 * 1024,
                  icon: Icons.sd_card_rounded,
                ),
              );
            }
          }
        }
      } catch (_) {}
    } else {
      // Fallback for Desktop/iOS
      final root = await getRootPath();
      storages.add(
        StorageInfo(
          name: Platform.isWindows ? 'Local Disk' : 'Primary Storage',
          path: root,
          totalBytes: 256 * 1024 * 1024 * 1024,
          usedBytes: 100 * 1024 * 1024 * 1024,
          freeBytes: 156 * 1024 * 1024 * 1024,
          icon: Icons.storage_rounded,
        ),
      );
    }

    return storages;
  }

  /// Common shortcut directories (Downloads, Documents, Photos/DCIM, Music, Movies)
  static Future<Map<String, String>> getQuickAccessFolders() async {
    final Map<String, String> folders = {};
    final root = await getRootPath();

    final candidates = {
      'Downloads': ['Download', 'Downloads'],
      'Documents': ['Documents', 'Docs'],
      'Camera / Photos': ['DCIM', 'Pictures', 'Photos'],
      'Music': ['Music', 'Audio'],
      'Movies / Videos': ['Movies', 'Videos'],
      'WhatsApp': ['Android/media/com.whatsapp/WhatsApp/Media', 'WhatsApp'],
    };

    for (var entry in candidates.entries) {
      for (var sub in entry.value) {
        final candidatePath = p.join(root, sub);
        if (await Directory(candidatePath).exists()) {
          folders[entry.key] = candidatePath;
          break;
        }
      }
    }

    return folders;
  }

  /// Lists entities in a directory with sorting and hidden files filtering
  static Future<List<FileItem>> listDirectory({
    required String path,
    bool showHidden = false,
    SortBy sortBy = SortBy.name,
    bool ascending = true,
  }) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      return [];
    }

    final List<FileItem> items = [];
    try {
      await for (final entity in dir.list(followLinks: false)) {
        final name = p.basename(entity.path);
        if (!showHidden && name.startsWith('.')) {
          continue;
        }

        try {
          final stat = await entity.stat();
          items.add(FileItem.fromEntity(entity, stat: stat));
        } catch (_) {
          // If stat fails (e.g. permission or special file), create basic item
          items.add(FileItem.fromEntity(entity));
        }
      }
    } catch (e) {
      // Permission denied or IO error
      debugPrint('Error listing directory $path: $e');
      rethrow;
    }

    // Sort items (folders first, then files)
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int comparison = 0;
      switch (sortBy) {
        case SortBy.name:
          comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortBy.date:
          comparison = a.modified.compareTo(b.modified);
          break;
        case SortBy.size:
          comparison = a.size.compareTo(b.size);
          break;
        case SortBy.type:
          comparison = a.extension.compareTo(b.extension);
          break;
      }
      return ascending ? comparison : -comparison;
    });

    return items;
  }

  /// Scans files of a specific category across primary directories
  static Future<List<FileItem>> getCategoryFiles({
    required FileCategory category,
    int maxResults = 1000,
  }) async {
    final root = await getRootPath();
    final List<FileItem> results = [];
    final visited = <String>{};

    // Determine target directories based on category for fast search
    List<String> targetDirs = [];
    switch (category) {
      case FileCategory.image:
        targetDirs = [
          'DCIM',
          'Pictures',
          'Download',
          'WhatsApp',
          'Telegram',
          'Bluetooth',
          'Android/media',
          'Movies',
        ];
        break;
      case FileCategory.video:
        targetDirs = [
          'DCIM',
          'Movies',
          'Pictures',
          'Download',
          'Videos',
          'Video',
          'WhatsApp',
          'Telegram',
          'Bluetooth',
          'Recordings',
          'Android/media',
          'Screen records',
          'Snaptube',
          'Vidmate',
          'ShareMe',
          'Xender',
        ];
        break;
      case FileCategory.audio:
        targetDirs = [
          'Music',
          'Download',
          'Podcasts',
          'Audiobooks',
          'Recordings',
          'Ringtones',
          'Notifications',
          'Alarms',
          'WhatsApp',
          'Telegram',
          'Bluetooth',
          'Android/media',
        ];
        break;
      case FileCategory.document:
        targetDirs = [
          'Documents',
          'Download',
          'WhatsApp',
          'Telegram',
          'Bluetooth',
          'Android/media',
        ];
        break;
      case FileCategory.apk:
        targetDirs = [
          'Download',
          'Telegram',
          'Bluetooth',
          'ShareMe',
          'Documents',
        ];
        break;
      case FileCategory.archive:
        targetDirs = [
          'Download',
          'Documents',
          'Telegram',
          'Bluetooth',
        ];
        break;
      case FileCategory.code:
        targetDirs = [
          'Download',
          'Documents',
          'Projects',
          'GitHub',
        ];
        break;
      default:
        targetDirs = ['Download'];
    }

    // 1. Scan prioritized directories first
    for (var rel in targetDirs) {
      final dirPath = p.join(root, rel);
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (results.length >= maxResults) break;
            if (entity is File) {
              final name = p.basename(entity.path);
              if (name.startsWith('.')) continue;

              final item = FileItem.fromEntity(entity);
              if (item.category == category && !visited.contains(item.path)) {
                visited.add(item.path);
                results.add(item);
              }
            }
          }
        } catch (_) {}
      }
      if (results.length >= maxResults) break;
    }

    // 2. Also scan any other user-created top-level directories in storage that were not in targetDirs
    if (results.length < maxResults) {
      try {
        final rootDir = Directory(root);
        final topLevelEntities = await rootDir.list(followLinks: false).toList();
        for (final entity in topLevelEntities) {
          if (results.length >= maxResults) break;
          if (entity is Directory) {
            final dirName = p.basename(entity.path);
            if (dirName.startsWith('.')) continue;
            if (dirName == 'Android') continue; // App sandboxes / Android/media already handled
            if (targetDirs.contains(dirName)) continue; // Already scanned

            try {
              await for (final subEntity in entity.list(recursive: true, followLinks: false)) {
                if (results.length >= maxResults) break;
                if (subEntity is File) {
                  final name = p.basename(subEntity.path);
                  if (name.startsWith('.')) continue;

                  final item = FileItem.fromEntity(subEntity);
                  if (item.category == category && !visited.contains(item.path)) {
                    visited.add(item.path);
                    results.add(item);
                  }
                }
              }
            } catch (_) {}
          } else if (entity is File) {
            final item = FileItem.fromEntity(entity);
            if (item.category == category && !visited.contains(item.path)) {
              visited.add(item.path);
              results.add(item);
            }
          }
        }
      } catch (_) {}
    }

    // Sort by modified date descending (newest first)
    results.sort((a, b) => b.modified.compareTo(a.modified));
    return results;
  }

  /// Search files recursively in a directory or root
  static Future<List<FileItem>> searchFiles({
    required String rootPath,
    required String query,
    int maxResults = 100,
  }) async {
    final List<FileItem> results = [];
    final dir = Directory(rootPath);
    if (!await dir.exists()) return [];

    final cleanQuery = query.toLowerCase().trim();

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (results.length >= maxResults) break;
        final name = p.basename(entity.path);
        if (name.startsWith('.')) continue;

        if (name.toLowerCase().contains(cleanQuery)) {
          try {
            results.add(FileItem.fromEntity(entity));
          } catch (_) {}
        }
      }
    } catch (_) {}

    return results;
  }
}

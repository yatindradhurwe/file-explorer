import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import '../models/file_item.dart';
import '../utils/file_utils.dart';

class FileOperationsService {
  /// Create a new folder
  static Future<Directory> createFolder(String parentPath, String folderName) async {
    final sanitized = folderName.trim();
    if (sanitized.isEmpty) {
      throw Exception('Folder name cannot be empty');
    }
    final targetPath = p.join(parentPath, sanitized);
    final dir = Directory(targetPath);
    if (await dir.exists()) {
      throw Exception('A folder with this name already exists');
    }
    return await dir.create(recursive: true);
  }

  /// Create a new text file
  static Future<File> createFile(String parentPath, String fileName, [String content = '']) async {
    final sanitized = fileName.trim();
    if (sanitized.isEmpty) {
      throw Exception('File name cannot be empty');
    }
    final targetPath = p.join(parentPath, sanitized);
    final file = File(targetPath);
    if (await file.exists()) {
      throw Exception('A file with this name already exists');
    }
    return await file.writeAsString(content);
  }

  /// Rename file or folder
  static Future<FileSystemEntity> rename(String currentPath, String newName) async {
    final sanitized = newName.trim();
    if (sanitized.isEmpty) {
      throw Exception('Name cannot be empty');
    }
    final parent = p.dirname(currentPath);
    final targetPath = p.join(parent, sanitized);

    if (await File(targetPath).exists() || await Directory(targetPath).exists()) {
      throw Exception('An item with name "$sanitized" already exists');
    }

    final isDir = await FileSystemEntity.isDirectory(currentPath);
    if (isDir) {
      final dir = Directory(currentPath);
      return await dir.rename(targetPath);
    } else {
      final file = File(currentPath);
      return await file.rename(targetPath);
    }
  }

  /// Delete multiple files or folders
  static Future<int> deleteItems(List<String> paths) async {
    int deletedCount = 0;
    for (final path in paths) {
      try {
        final isDir = await FileSystemEntity.isDirectory(path);
        if (isDir) {
          final dir = Directory(path);
          if (await dir.exists()) {
            await dir.delete(recursive: true);
            deletedCount++;
          }
        } else {
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
            deletedCount++;
          }
        }
      } catch (e) {
        debugPrint('Error deleting $path: $e');
      }
    }
    return deletedCount;
  }

  /// Copy files or folders to target directory
  static Future<int> copyItems(List<String> sourcePaths, String destinationDir) async {
    int count = 0;
    for (final src in sourcePaths) {
      try {
        final baseName = p.basename(src);
        String destPath = p.join(destinationDir, baseName);

        // Avoid copying into itself
        if (p.isWithin(src, destinationDir)) {
          continue;
        }

        // Handle name collision
        destPath = _getUniquePath(destPath);

        final isDir = await FileSystemEntity.isDirectory(src);
        if (isDir) {
          await _copyDirectory(Directory(src), Directory(destPath));
          count++;
        } else {
          final file = File(src);
          await file.copy(destPath);
          count++;
        }
      } catch (e) {
        debugPrint('Error copying $src: $e');
      }
    }
    return count;
  }

  /// Move files or folders to target directory
  static Future<int> moveItems(List<String> sourcePaths, String destinationDir) async {
    int count = 0;
    for (final src in sourcePaths) {
      try {
        final baseName = p.basename(src);
        String destPath = p.join(destinationDir, baseName);

        // Avoid moving into itself
        if (p.isWithin(src, destinationDir)) {
          continue;
        }

        destPath = _getUniquePath(destPath);

        final isDir = await FileSystemEntity.isDirectory(src);
        if (isDir) {
          final dir = Directory(src);
          try {
            await dir.rename(destPath);
          } catch (_) {
            // Across different mount points, rename fails; do copy + delete
            await _copyDirectory(dir, Directory(destPath));
            await dir.delete(recursive: true);
          }
          count++;
        } else {
          final file = File(src);
          try {
            await file.rename(destPath);
          } catch (_) {
            await file.copy(destPath);
            await file.delete();
          }
          count++;
        }
      } catch (e) {
        debugPrint('Error moving $src: $e');
      }
    }
    return count;
  }

  static String _getUniquePath(String targetPath) {
    String current = targetPath;
    final parent = p.dirname(targetPath);
    final ext = p.extension(targetPath);
    final nameWithoutExt = p.basenameWithoutExtension(targetPath);
    int counter = 1;

    while (File(current).existsSync() || Directory(current).existsSync()) {
      current = p.join(parent, '$nameWithoutExt ($counter)$ext');
      counter++;
    }
    return current;
  }

  static Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(followLinks: false)) {
      final newPath = p.join(destination.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  /// Open file with external application with automatic MIME type matching
  static Future<OpenResult> openFile(String path, {String? type}) async {
    try {
      final ext = p.extension(path).toLowerCase();
      String? mimeType = type;
      if (mimeType == null) {
        final detected = FileUtils.getMimeType(ext);
        if (detected != 'application/octet-stream') {
          mimeType = detected;
        } else {
          // Try to infer a broad MIME by category for unknown extensions
          final f = File(path);
          if (f.existsSync()) {
            final category = FileItem.fromEntity(f).category;
            if (category == FileCategory.video) {
              mimeType = 'video/*';
            } else if (category == FileCategory.audio) {
              mimeType = 'audio/*';
            } else if (category == FileCategory.image) {
              mimeType = 'image/*';
            }
          }
        }
      }
      return await OpenFilex.open(path, type: mimeType);
    } catch (e) {
      debugPrint('openFile error for $path: $e');
      return OpenResult(
        type: ResultType.error,
        message: 'Could not open file: $e',
      );
    }
  }

  /// Share file(s) via platform share sheet
  static Future<void> shareFiles(List<String> paths) async {
    final xFiles = paths.map((p) => XFile(p)).toList();
    // ignore: deprecated_member_use
    await Share.shareXFiles(xFiles);
  }

  /// Read text from file
  static Future<String> readTextFile(String path) async {
    final file = File(path);
    return await file.readAsString();
  }

  /// Write text to file
  static Future<void> writeTextFile(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);
  }
}

import 'package:flutter/material.dart';
import '../models/clipboard_item.dart';
import '../models/file_item.dart';

class AppState extends ChangeNotifier {
  static final AppState instance = AppState._internal();
  factory AppState() => instance;
  AppState._internal();

  bool _isDarkMode = false;
  bool _isGridView = false;
  bool _showHiddenFiles = false;
  SortBy _sortBy = SortBy.name;
  bool _sortAscending = true;
  FileClipboardData? _clipboardData;

  bool get isDarkMode => _isDarkMode;
  bool get isGridView => _isGridView;
  bool get showHiddenFiles => _showHiddenFiles;
  SortBy get sortBy => _sortBy;
  bool get sortAscending => _sortAscending;
  FileClipboardData? get clipboardData => _clipboardData;
  bool get hasClipboard => _clipboardData != null && _clipboardData!.items.isNotEmpty;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleViewMode() {
    _isGridView = !_isGridView;
    notifyListeners();
  }

  void toggleShowHiddenFiles() {
    _showHiddenFiles = !_showHiddenFiles;
    notifyListeners();
  }

  void setSortOption(SortBy by, bool ascending) {
    _sortBy = by;
    _sortAscending = ascending;
    notifyListeners();
  }

  void copyToClipboard(List<FileItem> items, String sourceDir) {
    _clipboardData = FileClipboardData(
      items: items,
      operation: ClipboardOperation.copy,
      sourceDirectory: sourceDir,
    );
    notifyListeners();
  }

  void cutToClipboard(List<FileItem> items, String sourceDir) {
    _clipboardData = FileClipboardData(
      items: items,
      operation: ClipboardOperation.cut,
      sourceDirectory: sourceDir,
    );
    notifyListeners();
  }

  void clearClipboard() {
    _clipboardData = null;
    notifyListeners();
  }
}

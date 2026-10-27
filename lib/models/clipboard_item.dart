import 'file_item.dart';

enum ClipboardOperation {
  copy,
  cut,
}

class FileClipboardData {
  final List<FileItem> items;
  final ClipboardOperation operation;
  final String sourceDirectory;

  const FileClipboardData({
    required this.items,
    required this.operation,
    required this.sourceDirectory,
  });

  bool get isCut => operation == ClipboardOperation.cut;
  bool get isCopy => operation == ClipboardOperation.copy;
  int get count => items.length;
}

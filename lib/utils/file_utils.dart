import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/file_item.dart';

class FileUtils {
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  static String formatDate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0 && dateTime.day == now.day) {
      return 'Today, ${DateFormat.jm().format(dateTime)}';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && dateTime.day == now.day - 1)) {
      return 'Yesterday, ${DateFormat.jm().format(dateTime)}';
    } else if (dateTime.year == now.year) {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }

  static IconData getCategoryIcon(FileCategory category) {
    switch (category) {
      case FileCategory.folder:
        return Icons.folder_rounded;
      case FileCategory.image:
        return Icons.image_rounded;
      case FileCategory.video:
        return Icons.videocam_rounded;
      case FileCategory.audio:
        return Icons.music_note_rounded;
      case FileCategory.document:
        return Icons.description_rounded;
      case FileCategory.archive:
        return Icons.archive_rounded;
      case FileCategory.apk:
        return Icons.android_rounded;
      case FileCategory.code:
        return Icons.code_rounded;
      case FileCategory.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  static IconData getItemIcon(FileItem item) {
    if (item.isDirectory) return Icons.folder_rounded;
    final ext = item.extension.toLowerCase();
    switch (ext) {
      case '.pdf':
        return Icons.picture_as_pdf_rounded;
      case '.xlsx':
      case '.xls':
      case '.csv':
      case '.tsv':
        return Icons.table_chart_rounded;
      case '.pptx':
      case '.ppt':
        return Icons.slideshow_rounded;
      case '.docx':
      case '.doc':
      case '.rtf':
        return Icons.article_rounded;
      default:
        return getCategoryIcon(item.category);
    }
  }

  static Color getItemColor(FileItem item) {
    if (item.isDirectory) return const Color(0xFFFFA000);
    final ext = item.extension.toLowerCase();
    switch (ext) {
      case '.pdf':
        return const Color(0xFFDC2626); // PDF Red
      case '.xlsx':
      case '.xls':
      case '.csv':
      case '.tsv':
        return const Color(0xFF107C41); // Excel Green
      case '.pptx':
      case '.ppt':
        return const Color(0xFFD24726); // PPT Orange
      case '.docx':
      case '.doc':
        return const Color(0xFF185ABD); // Word Blue
      default:
        return getCategoryColor(item.category);
    }
  }

  static Color getCategoryColor(FileCategory category) {
    switch (category) {
      case FileCategory.folder:
        return const Color(0xFFFFA000); // Amber
      case FileCategory.image:
        return const Color(0xFF9C27B0); // Purple
      case FileCategory.video:
        return const Color(0xFFE91E63); // Pink / Red
      case FileCategory.audio:
        return const Color(0xFFFF5722); // Deep Orange
      case FileCategory.document:
        return const Color(0xFF2196F3); // Blue
      case FileCategory.archive:
        return const Color(0xFF795548); // Brown
      case FileCategory.apk:
        return const Color(0xFF4CAF50); // Green
      case FileCategory.code:
        return const Color(0xFF009688); // Teal
      case FileCategory.other:
        return const Color(0xFF78909C); // Blue Grey
    }
  }

  static String getCategoryLabel(FileCategory category) {
    switch (category) {
      case FileCategory.folder:
        return 'Folders';
      case FileCategory.image:
        return 'Images';
      case FileCategory.video:
        return 'Videos';
      case FileCategory.audio:
        return 'Audio';
      case FileCategory.document:
        return 'Documents';
      case FileCategory.archive:
        return 'Archives';
      case FileCategory.apk:
        return 'APKs';
      case FileCategory.code:
        return 'Code & Text';
      case FileCategory.other:
        return 'Other Files';
    }
  }

  static String getMimeType(String ext) {
    switch (ext.toLowerCase()) {
      // Images
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.svg':
        return 'image/svg+xml';
      case '.bmp':
        return 'image/bmp';
      case '.heic':
        return 'image/heic';

      // Video Formats
      case '.mp4':
      case '.m4v':
      case '.m4p':
        return 'video/mp4';
      case '.mkv':
        return 'video/x-matroska';
      case '.webm':
        return 'video/webm';
      case '.mov':
      case '.qt':
        return 'video/quicktime';
      case '.avi':
        return 'video/x-msvideo';
      case '.wmv':
        return 'video/x-ms-wmv';
      case '.asf':
        return 'video/x-ms-asf';
      case '.flv':
      case '.f4v':
      case '.f4p':
        return 'video/x-flv';
      case '.3gp':
      case '.3gpp':
        return 'video/3gpp';
      case '.3g2':
      case '.3gpp2':
        return 'video/3gpp2';
      case '.ts':
      case '.mts':
      case '.m2ts':
        return 'video/mp2t';
      case '.mpg':
      case '.mpeg':
      case '.m1v':
      case '.m2v':
      case '.mpv':
      case '.mpe':
        return 'video/mpeg';
      case '.ogv':
        return 'video/ogg';
      case '.vob':
        return 'video/x-ms-vob';
      case '.divx':
      case '.xvid':
        return 'video/divx';
      case '.rm':
      case '.rmvb':
        return 'video/vnd.rn-realvideo';

      // Audio Formats
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      case '.m4a':
        return 'audio/mp4';
      case '.wma':
        return 'audio/x-ms-wma';

      // Documents & Archives
      case '.pdf':
        return 'application/pdf';
      case '.doc':
        return 'application/msword';
      case '.docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case '.xls':
        return 'application/vnd.ms-excel';
      case '.xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case '.ppt':
        return 'application/vnd.ms-powerpoint';
      case '.pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case '.zip':
        return 'application/zip';
      case '.rar':
        return 'application/x-rar-compressed';
      case '.7z':
        return 'application/x-7z-compressed';
      case '.tar':
      case '.gz':
        return 'application/x-tar';
      case '.apk':
        return 'application/vnd.android.package-archive';
      case '.txt':
        return 'text/plain';
      case '.html':
        return 'text/html';
      case '.json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }
}

import 'dart:io';
import 'package:path/path.dart' as p;

enum FileCategory {
  folder,
  image,
  video,
  audio,
  document,
  archive,
  apk,
  code,
  other,
}

enum SortBy {
  name,
  date,
  size,
  type,
}

class FileItem {
  final FileSystemEntity entity;
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final String extension;
  final FileCategory category;
  final bool isHidden;
  final int? itemCount; // For folders: count of items inside (if computed)

  FileItem({
    required this.entity,
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
    required this.extension,
    required this.category,
    required this.isHidden,
    this.itemCount,
  });

  factory FileItem.fromEntity(FileSystemEntity entity, {FileStat? stat}) {
    final path = entity.path;
    final name = p.basename(path);
    final isDir = entity is Directory;
    final isHidden = name.startsWith('.');

    FileStat fileStat = stat ?? entity.statSync();
    final ext = isDir ? '' : p.extension(path).toLowerCase();
    final category = isDir ? FileCategory.folder : _categorize(ext);

    return FileItem(
      entity: entity,
      path: path,
      name: name,
      isDirectory: isDir,
      size: isDir ? 0 : fileStat.size,
      modified: fileStat.modified,
      extension: ext,
      category: category,
      isHidden: isHidden,
    );
  }

  static FileCategory _categorize(String ext) {
    switch (ext) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
      case '.bmp':
      case '.webp':
      case '.svg':
      case '.heic':
        return FileCategory.image;
      // Video formats (all universal video containers & codecs)
      case '.mp4':
      case '.m4v':
      case '.m4p':
      case '.mkv':
      case '.mov':
      case '.qt':
      case '.avi':
      case '.wmv':
      case '.asf':
      case '.webm':
      case '.flv':
      case '.f4v':
      case '.f4p':
      case '.f4a':
      case '.f4b':
      case '.3gp':
      case '.3g2':
      case '.3gpp':
      case '.3gpp2':
      case '.ts':
      case '.mts':
      case '.m2ts':
      case '.vob':
      case '.ogv':
      case '.mpg':
      case '.mpeg':
      case '.m1v':
      case '.m2v':
      case '.mpv':
      case '.mpe':
      case '.divx':
      case '.xvid':
      case '.rm':
      case '.rmvb':
      case '.h264':
      case '.h265':
      case '.264':
      case '.265':
      case '.hevc':
      case '.av1':
      case '.wtv':
      case '.drc':
      case '.yuv':
      case '.amv':
      case '.viv':
      case '.bik':
      case '.svi':
      case '.mod':
      case '.tod':
      case '.roq':
      case '.nsv':
        return FileCategory.video;
      case '.mp3':
      case '.wav':
      case '.aac':
      case '.ogg':
      case '.flac':
      case '.m4a':
      case '.wma':
        return FileCategory.audio;
      case '.pdf':
      case '.doc':
      case '.docx':
      case '.xls':
      case '.xlsx':
      case '.ppt':
      case '.pptx':
      case '.csv':
      case '.tsv':
      case '.txt':
      case '.rtf':
      case '.odt':
        return FileCategory.document;
      case '.zip':
      case '.rar':
      case '.7z':
      case '.tar':
      case '.gz':
      case '.bz2':
      case '.xz':
        return FileCategory.archive;
      case '.apk':
      case '.xapk':
      case '.apks':
        return FileCategory.apk;
      case '.dart':
      case '.java':
      case '.kt':
      case '.swift':
      case '.c':
      case '.cpp':
      case '.h':
      case '.cs':
      case '.py':
      case '.js':
      case '.html':
      case '.css':
      case '.json':
      case '.xml':
      case '.yaml':
      case '.yml':
      case '.sh':
      case '.bat':
      case '.md':
      case '.sql':
        return FileCategory.code;
      default:
        return FileCategory.other;
    }
  }

  bool get isTextEditable {
    if (isDirectory) return false;
    final textExtensions = {
      '.txt', '.md', '.json', '.xml', '.yaml', '.yml', '.csv', '.log',
      '.dart', '.js', '.ts', '.html', '.css', '.py', '.java', '.kt',
      '.c', '.cpp', '.h', '.cs', '.sh', '.bat', '.sql', '.properties',
      '.ini', '.conf', '.env', '.gradle',
    };
    return textExtensions.contains(extension) || category == FileCategory.code;
  }

  bool get isImage {
    return category == FileCategory.image;
  }

  bool get isVideo {
    return category == FileCategory.video;
  }
}

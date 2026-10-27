import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../utils/file_utils.dart';

class FileGridTile extends StatelessWidget {
  final FileItem item;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onCopy;
  final VoidCallback onCut;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback onDetails;
  final VoidCallback? onQuickDrop;

  const FileGridTile({
    super.key,
    required this.item,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onTap,
    required this.onLongPress,
    required this.onOpen,
    required this.onShare,
    required this.onCopy,
    required this.onCut,
    required this.onRename,
    required this.onDelete,
    required this.onDetails,
    this.onQuickDrop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconColor = FileUtils.getItemColor(item);
    final iconData = FileUtils.getItemIcon(item);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withAlpha(35)
              : (isDark ? const Color(0xFF252525) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon or Image thumbnail
                  Expanded(
                    child: Center(
                      child: item.isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.file(
                                File(item.path),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildIcon(iconData, iconColor),
                              ),
                            )
                          : _buildIcon(iconData, iconColor),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Name
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: item.isHidden ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 2),

                  // Size or date
                  Text(
                    item.isDirectory
                        ? 'Folder'
                        : FileUtils.formatBytes(item.size),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),

            // Selection checkbox (top left)
            if (isSelectionMode)
              Positioned(
                top: 4,
                left: 4,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

            // More options popup (top right)
            if (!isSelectionMode)
              Positioned(
                top: 2,
                right: 2,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'open':
                        onOpen();
                        break;
                      case 'quickdrop':
                        onQuickDrop?.call();
                        break;
                      case 'share':
                        onShare();
                        break;
                      case 'copy':
                        onCopy();
                        break;
                      case 'cut':
                        onCut();
                        break;
                      case 'rename':
                        onRename();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                      case 'details':
                        onDetails();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    if (!item.isDirectory)
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Open with...'),
                          ],
                        ),
                      ),
                    if (!item.isDirectory)
                      const PopupMenuItem(
                        value: 'quickdrop',
                        child: Row(
                          children: [
                            Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
                            SizedBox(width: 8),
                            Text('QuickDrop (AirDrop)'),
                          ],
                        ),
                      ),
                    if (!item.isDirectory)
                      const PopupMenuItem(
                        value: 'share',
                        child: Row(
                          children: [
                            Icon(Icons.share_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Share...'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: Row(
                        children: [
                          Icon(Icons.content_copy_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Copy'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'cut',
                      child: Row(
                        children: [
                          Icon(Icons.content_cut_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Cut / Move'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.drive_file_rename_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Details'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(IconData iconData, Color color) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 30,
      ),
    );
  }
}

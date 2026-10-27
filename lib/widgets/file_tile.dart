import 'dart:io';
import 'package:flutter/material.dart';
import '../models/file_item.dart';
import '../utils/file_utils.dart';

class FileTile extends StatelessWidget {
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

  const FileTile({
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
    final iconColor = FileUtils.getItemColor(item);
    final iconData = FileUtils.getItemIcon(item);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isSelected
            ? theme.colorScheme.primary.withAlpha(35)
            : Colors.transparent,
        child: Row(
          children: [
            // Selection checkbox or leading icon
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Checkbox(
                  value: isSelected,
                  onChanged: (_) => onTap(),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              )
            else
              _buildLeadingIcon(iconData, iconColor),

            const SizedBox(width: 14),

            // File Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: item.isHidden ? Colors.grey : null,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (!item.isDirectory) ...[
                        Text(
                          FileUtils.formatBytes(item.size),
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        FileUtils.formatDate(item.modified),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trailing actions
            if (!isSelectionMode)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20),
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
                          Icon(Icons.open_in_new_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Open with...'),
                        ],
                      ),
                    ),
                  if (!item.isDirectory)
                    const PopupMenuItem(
                      value: 'quickdrop',
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 20, color: Colors.amber),
                          SizedBox(width: 12),
                          Text('QuickDrop (AirDrop)'),
                        ],
                      ),
                    ),
                  if (!item.isDirectory)
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share_rounded, size: 20),
                          SizedBox(width: 12),
                          Text('Share...'),
                        ],
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'copy',
                    child: Row(
                      children: [
                        Icon(Icons.content_copy_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Copy'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'cut',
                    child: Row(
                      children: [
                        Icon(Icons.content_cut_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Cut / Move'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'rename',
                    child: Row(
                      children: [
                        Icon(Icons.drive_file_rename_outline_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Rename'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'details',
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 20),
                        SizedBox(width: 12),
                        Text('Details'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadingIcon(IconData iconData, Color color) {
    if (item.isImage) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(item.path),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallbackContainer(iconData, color),
        ),
      );
    }

    return _fallbackContainer(iconData, color);
  }

  Widget _fallbackContainer(IconData iconData, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withAlpha(35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        iconData,
        color: color,
        size: 24,
      ),
    );
  }
}

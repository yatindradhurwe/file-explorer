import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class BreadcrumbBar extends StatelessWidget {
  final String currentPath;
  final String rootPath;
  final ValueChanged<String> onPathSelected;

  const BreadcrumbBar({
    super.key,
    required this.currentPath,
    required this.rootPath,
    required this.onPathSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final segments = _buildSegments();

    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF10192D) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: segments.length,
        separatorBuilder: (_, _) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
          ),
        ),
        itemBuilder: (context, index) {
          final seg = segments[index];
          final isLast = index == segments.length - 1;

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isLast ? null : () => onPathSelected(seg.path),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              alignment: Alignment.center,
              decoration: isLast
                  ? BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E293B), const Color(0xFF334155)]
                            : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withAlpha(60),
                        width: 1.2,
                      ),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index == 0) ...[
                    Icon(
                      Icons.home_rounded,
                      size: 16,
                      color: isLast
                          ? theme.colorScheme.primary
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    seg.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isLast ? FontWeight.w700 : FontWeight.w600,
                      color: isLast
                          ? theme.colorScheme.primary
                          : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<_PathSegment> _buildSegments() {
    final List<_PathSegment> segments = [];

    // Root segment
    segments.add(_PathSegment(name: 'Storage', path: rootPath));

    if (currentPath == rootPath) {
      return segments;
    }

    if (p.isWithin(rootPath, currentPath)) {
      final relative = p.relative(currentPath, from: rootPath);
      final parts = p.split(relative);
      String accumulated = rootPath;

      for (var part in parts) {
        accumulated = p.join(accumulated, part);
        segments.add(_PathSegment(name: part, path: accumulated));
      }
    } else {
      final parts = p.split(currentPath);
      String accumulated = '';
      for (int i = 0; i < parts.length; i++) {
        if (parts[i].isEmpty) continue;
        accumulated = accumulated.isEmpty ? parts[i] : p.join(accumulated, parts[i]);
        segments.add(_PathSegment(name: parts[i], path: accumulated));
      }
    }

    return segments;
  }
}

class _PathSegment {
  final String name;
  final String path;
  _PathSegment({required this.name, required this.path});
}

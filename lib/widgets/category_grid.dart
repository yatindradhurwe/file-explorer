import 'package:flutter/material.dart';
import '../models/file_item.dart';

class CategoryItem {
  final FileCategory category;
  final String label;
  final IconData icon;
  final List<Color> gradient;

  const CategoryItem({
    required this.category,
    required this.label,
    required this.icon,
    required this.gradient,
  });
}

class CategoryGrid extends StatelessWidget {
  final Function(FileCategory category) onCategoryTap;

  const CategoryGrid({
    super.key,
    required this.onCategoryTap,
  });

  static const List<CategoryItem> categories = [
    CategoryItem(
      category: FileCategory.image,
      label: 'Images',
      icon: Icons.image_rounded,
      gradient: [Color(0xFFA855F7), Color(0xFF7E22CE)], // Violet
    ),
    CategoryItem(
      category: FileCategory.video,
      label: 'Videos',
      icon: Icons.videocam_rounded,
      gradient: [Color(0xFFF43F5E), Color(0xFFBE123C)], // Rose
    ),
    CategoryItem(
      category: FileCategory.audio,
      label: 'Audio',
      icon: Icons.music_note_rounded,
      gradient: [Color(0xFFFB923C), Color(0xFFEA580C)], // Orange
    ),
    CategoryItem(
      category: FileCategory.document,
      label: 'Documents',
      icon: Icons.description_rounded,
      gradient: [Color(0xFF38BDF8), Color(0xFF0284C7)], // Sky
    ),
    CategoryItem(
      category: FileCategory.apk,
      label: 'APKs & Apps',
      icon: Icons.android_rounded,
      gradient: [Color(0xFF34D399), Color(0xFF059669)], // Emerald
    ),
    CategoryItem(
      category: FileCategory.archive,
      label: 'Archives',
      icon: Icons.archive_rounded,
      gradient: [Color(0xFFA8A29E), Color(0xFF57534E)], // Stone
    ),
    CategoryItem(
      category: FileCategory.code,
      label: 'Code & Text',
      icon: Icons.terminal_rounded,
      gradient: [Color(0xFF2DD4BF), Color(0xFF0F766E)], // Teal
    ),
    CategoryItem(
      category: FileCategory.other,
      label: 'Others',
      icon: Icons.folder_special_rounded,
      gradient: [Color(0xFF818CF8), Color(0xFF4338CA)], // Indigo
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.88,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];

        return InkWell(
          onTap: () => onCategoryTap(cat.category),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF131D33) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withAlpha(40)
                      : const Color(0xFF0F172A).withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: cat.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: cat.gradient.first.withAlpha(90),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    cat.icon,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  cat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

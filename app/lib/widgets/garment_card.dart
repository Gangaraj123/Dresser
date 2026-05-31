import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/garment.dart';
import '../theme/app_theme.dart';

class GarmentCard extends StatelessWidget {
  final Garment garment;
  final VoidCallback? onTap;

  const GarmentCard({super.key, required this.garment, this.onTap});

  static const _categoryIcons = {
    'topwear': Icons.checkroom_outlined,
    'bottomwear': Icons.airline_seat_legroom_normal_outlined,
    'outerwear': Icons.dry_cleaning_outlined,
    'footwear': Icons.snowshoeing_outlined,
    'accessory': Icons.watch_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final imageUrl = garment.thumbnailUrl ?? garment.displayImageUrl;
    final colorHex = garment.dominantColorHex;
    Color? dotColor;
    if (colorHex != null && colorHex.length == 7) {
      dotColor = Color(int.parse('FF${colorHex.substring(1)}', radix: 16));
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border, width: 1),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Garment image or placeholder
            Positioned.fill(
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, url) => _Placeholder(
                        category: garment.category,
                        icons: _categoryIcons,
                        bg: c.bg2,
                        color: c.textTertiary,
                      ),
                      errorWidget: (_, url, err) => _Placeholder(
                        category: garment.category,
                        icons: _categoryIcons,
                        bg: c.bg2,
                        color: c.textTertiary,
                      ),
                    )
                  : _Placeholder(
                      category: garment.category,
                      icons: _categoryIcons,
                      bg: c.bg2,
                      color: c.textTertiary,
                    ),
            ),
            // Category badge — frosted pill, bottom left
            Positioned(
              bottom: 8,
              left: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  color: Colors.white.withValues(alpha: 0.85),
                  child: Text(
                    garment.displayName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ),
            ),
            // Processing badge — top right when photo is still being enhanced
            if (garment.isProcessing)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 8,
                        height: 8,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Enhancing',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            // Color dot — top right (only when not processing)
            else if (dotColor != null)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String category;
  final Map<String, IconData> icons;
  final Color bg;
  final Color color;

  const _Placeholder({
    required this.category,
    required this.icons,
    required this.bg,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bg,
      child: Center(
        child: Icon(
          icons[category] ?? Icons.checkroom_outlined,
          size: 32,
          color: color,
        ),
      ),
    );
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/outfit.dart';
import '../theme/app_theme.dart';

class OutfitCard extends StatelessWidget {
  final Outfit outfit;
  /// Resolved thumbnail URLs for each garment in garmentIds (same order, may contain nulls).
  final List<String?> thumbnails;
  final VoidCallback? onTap;

  const OutfitCard({
    super.key,
    required this.outfit,
    this.thumbnails = const [],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final score = outfit.matchScore ?? 0;
    final scoreColor = score >= 85 ? c.sage : score >= 65 ? c.gold : c.blush;
    final scoreBg = score >= 85 ? c.sageLight : score >= 65 ? c.goldLight : c.blushLight;
    final label = outfit.occasion ?? (outfit.aiGenerated ? 'AI suggestion' : 'Saved look');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Garment thumbnails row
            LayoutBuilder(
              builder: (context, constraints) {
                final count = thumbnails.isEmpty ? outfit.garmentIds.length : thumbnails.length;
                final displayCount = count.clamp(1, 5);
                final totalSpacing = 8.0 * (displayCount - 1);
                final w = ((constraints.maxWidth - totalSpacing) / displayCount).clamp(40.0, 80.0);
                final h = w * 1.25;

                return Row(
                  children: List.generate(displayCount, (i) {
                    final url = i < thumbnails.length ? thumbnails[i] : null;
                    return Padding(
                      padding: EdgeInsets.only(right: i < displayCount - 1 ? 8 : 0),
                      child: _GarmentTile(url: url, width: w, height: h, c: c),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outfit.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (score > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: scoreBg,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      '$score%',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: scoreColor,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GarmentTile extends StatelessWidget {
  final String? url;
  final double width;
  final double height;
  final DresserColors c;

  const _GarmentTile({required this.url, required this.width, required this.height, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.hardEdge,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.cover,
              placeholder: (ctx, u) => const SizedBox(),
              errorWidget: (ctx, u, e) => Center(
                child: Icon(Icons.checkroom_outlined, color: c.textTertiary, size: 22),
              ),
            )
          : Center(
              child: Icon(Icons.checkroom_outlined, color: c.textTertiary, size: 22),
            ),
    );
  }
}

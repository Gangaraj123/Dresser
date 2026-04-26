import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum TagType { category, color, season, formality, fabric, pattern }

class TagChip extends StatelessWidget {
  final String label;
  final TagType type;
  final Color? dotColor;

  const TagChip({
    super.key,
    required this.label,
    required this.type,
    this.dotColor,
  });

  _TagStyle _getStyle(BuildContext context) {
    final c = context.dc;
    switch (type) {
      case TagType.category:
        return _TagStyle(bg: c.bg2, text: c.textPrimary);
      case TagType.color:
        return _TagStyle(bg: c.bg, text: c.textSecondary, border: c.border);
      case TagType.season:
        return _TagStyle(bg: c.sageLight, text: c.sage);
      case TagType.formality:
        return _TagStyle(bg: c.steelLight, text: c.steel);
      case TagType.fabric:
        return _TagStyle(bg: c.lavenderLight, text: c.lavender);
      case TagType.pattern:
        return _TagStyle(bg: c.goldLight, text: c.gold);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _getStyle(context);
    return Container(
      margin: const EdgeInsets.only(right: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(50),
        border: style.border != null
            ? Border.all(color: style.border!, width: 1)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (type == TagType.color && dotColor != null) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: style.text,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagStyle {
  final Color bg;
  final Color text;
  final Color? border;

  _TagStyle({required this.bg, required this.text, this.border});
}

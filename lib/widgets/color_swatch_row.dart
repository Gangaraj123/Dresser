import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ColorSwatchItem {
  final Color color;
  final String label;
  final bool avoid;

  const ColorSwatchItem({
    required this.color,
    required this.label,
    this.avoid = false,
  });
}

class ColorSwatchRow extends StatelessWidget {
  final List<ColorSwatchItem> items;

  const ColorSwatchRow({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: items.map((item) {
        return Expanded(
          child: Container(
            height: 44,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              color: item.avoid ? item.color.withValues(alpha: 0.6) : item.color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  item.label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

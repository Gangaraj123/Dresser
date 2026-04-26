import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class DresserBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const DresserBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = [
      _NavItem(icon: Icons.grid_view_rounded, label: 'Closet'),
      _NavItem(icon: Icons.layers_outlined, label: 'Outfits'),
      _NavItem(icon: Icons.auto_awesome_outlined, label: 'Stylist'),
      _NavItem(icon: Icons.manage_search, label: 'Discover'),
      _NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    final bgColor = dark
        ? const Color(0xFF1E1E1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.88);

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border(
              top: BorderSide(color: c.border.withValues(alpha: 0.6), width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: List.generate(items.length, (index) {
                  final isActive = index == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(index),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive ? c.bg2 : Colors.transparent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              items[index].icon,
                              size: 22,
                              color: isActive ? c.textPrimary : c.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            items[index].label,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                              color: isActive ? c.textPrimary : c.textTertiary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  _NavItem({required this.icon, required this.label});
}

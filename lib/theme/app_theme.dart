import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Light Theme — pure B&W luxury base
  static const Color bg = Color(0xFFFFFFFF);
  static const Color bg2 = Color(0xFFF5F5F5);
  static const Color bg3 = Color(0xFFEBEBEB);
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color borderColor = Color(0xFFE8E8E8);

  // Semantic accent colors (light)
  static const Color sage = Color(0xFF5C8A6E);
  static const Color sageLight = Color(0xFFE7F4ED);
  static const Color blush = Color(0xFFD4726A);
  static const Color blushLight = Color(0xFFFAECEB);
  static const Color steel = Color(0xFF6B89A8);
  static const Color steelLight = Color(0xFFE5EFF8);
  static const Color gold = Color(0xFFC4985A);
  static const Color goldLight = Color(0xFFFAF0E0);
  static const Color lavender = Color(0xFF9B8BB4);
  static const Color lavenderLight = Color(0xFFF0E5F5);

  // Dark Theme
  static const Color bgDark = Color(0xFF121212);
  static const Color bg2Dark = Color(0xFF1E1E1E);
  static const Color bg3Dark = Color(0xFF252525);
  static const Color textPrimaryDark = Color(0xFFF0F0F0);
  static const Color textSecondaryDark = Color(0xFFA0A0A0);
  static const Color textTertiaryDark = Color(0xFF666666);
  static const Color cardBgDark = Color(0xFF1E1E1E);
  static const Color borderColorDark = Color(0xFF333333);

  // Semantic accent colors (dark — brightened)
  static const Color sageDark = Color(0xFF6DAF8A);
  static const Color sageLightDark = Color(0xFF1A2E22);
  static const Color blushDark = Color(0xFFE0877F);
  static const Color blushLightDark = Color(0xFF2E1A1A);
  static const Color steelDark = Color(0xFF85A3C0);
  static const Color steelLightDark = Color(0xFF1A2433);
  static const Color goldDark = Color(0xFFD4AD6A);
  static const Color goldLightDark = Color(0xFF2E2210);
  static const Color lavenderDark = Color(0xFFB4A3CC);
  static const Color lavenderLightDark = Color(0xFF2A1A30);
}

class AppTheme {
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
        fontSize: 48,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      displayMedium: GoogleFonts.cormorantGaramond(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      displaySmall: GoogleFonts.cormorantGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.cormorantGaramond(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.cormorantGaramond(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textTertiary,
      ),
    );
  }

  static TextTheme _buildDarkTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.cormorantGaramond(
          fontSize: 48, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
      displayMedium: GoogleFonts.cormorantGaramond(
          fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
      displaySmall: GoogleFonts.cormorantGaramond(
          fontSize: 24, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
      headlineMedium: GoogleFonts.cormorantGaramond(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
      headlineSmall: GoogleFonts.cormorantGaramond(
          fontSize: 18, fontWeight: FontWeight.w500, color: AppColors.textPrimaryDark),
      bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textPrimaryDark),
      bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimaryDark),
      bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondaryDark),
      labelLarge: GoogleFonts.plusJakartaSans(
          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimaryDark),
      labelMedium: GoogleFonts.plusJakartaSans(
          fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondaryDark),
      labelSmall: GoogleFonts.plusJakartaSans(
          fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textTertiaryDark),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: AppColors.textPrimary,
        secondary: AppColors.sage,
        surface: AppColors.bg,
        error: AppColors.blush,
      ),
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: _buildTextTheme(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: AppColors.textTertiary,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.textPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderColor, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.textPrimaryDark,
        secondary: AppColors.sageDark,
        surface: AppColors.bgDark,
        error: AppColors.blushDark,
      ),
      scaffoldBackgroundColor: AppColors.bgDark,
      textTheme: _buildDarkTextTheme(),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bg2Dark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.borderColorDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(50),
          borderSide: const BorderSide(color: AppColors.textPrimaryDark, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: AppColors.textTertiaryDark),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          // Keep dark bg + white text in dark mode too — spinners stay white
          // A white border provides contrast against the dark screen bg
          backgroundColor: const Color(0xFF2A2A2A),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
            side: const BorderSide(color: Color(0xFF444444), width: 1),
          ),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          side: const BorderSide(color: AppColors.borderColorDark, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

/// Theme-aware color set. Use via BuildContext extension: `context.dc`
class DresserColors {
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  // Semantic accent colors
  final Color sage;
  final Color sageLight;
  final Color blush;
  final Color blushLight;
  final Color steel;
  final Color steelLight;
  final Color gold;
  final Color goldLight;
  final Color lavender;
  final Color lavenderLight;

  const DresserColors._({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.sage,
    required this.sageLight,
    required this.blush,
    required this.blushLight,
    required this.steel,
    required this.steelLight,
    required this.gold,
    required this.goldLight,
    required this.lavender,
    required this.lavenderLight,
  });

  factory DresserColors.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (dark) {
      return const DresserColors._(
        bg: AppColors.bgDark,
        bg2: AppColors.bg2Dark,
        bg3: AppColors.bg3Dark,
        card: AppColors.cardBgDark,
        border: AppColors.borderColorDark,
        textPrimary: AppColors.textPrimaryDark,
        textSecondary: AppColors.textSecondaryDark,
        textTertiary: AppColors.textTertiaryDark,
        sage: AppColors.sageDark,
        sageLight: AppColors.sageLightDark,
        blush: AppColors.blushDark,
        blushLight: AppColors.blushLightDark,
        steel: AppColors.steelDark,
        steelLight: AppColors.steelLightDark,
        gold: AppColors.goldDark,
        goldLight: AppColors.goldLightDark,
        lavender: AppColors.lavenderDark,
        lavenderLight: AppColors.lavenderLightDark,
      );
    }
    return const DresserColors._(
      bg: AppColors.bg,
      bg2: AppColors.bg2,
      bg3: AppColors.bg3,
      card: AppColors.cardBg,
      border: AppColors.borderColor,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textTertiary: AppColors.textTertiary,
      sage: AppColors.sage,
      sageLight: AppColors.sageLight,
      blush: AppColors.blush,
      blushLight: AppColors.blushLight,
      steel: AppColors.steel,
      steelLight: AppColors.steelLight,
      gold: AppColors.gold,
      goldLight: AppColors.goldLight,
      lavender: AppColors.lavender,
      lavenderLight: AppColors.lavenderLight,
    );
  }
}

extension DresserThemeExt on BuildContext {
  DresserColors get dc => DresserColors.of(this);
}

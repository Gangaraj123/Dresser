import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../providers/profile_provider.dart';
import '../../../services/auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_notifier.dart';
import '../../../widgets/color_swatch_row.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _analyzingColor = false;
  bool _savingSettings = false;

  Future<void> _updateSetting(String field, bool value) async {
    if (_savingSettings) return;
    setState(() => _savingSettings = true);
    try {
      await ref.read(profileProvider.notifier).updateSetting(field, value);
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a selfie'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndAnalyzePhoto() async {
    final source = await _chooseImageSource();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;

    setState(() => _analyzingColor = true);
    try {
      final token =
          Supabase.instance.client.auth.currentSession?.accessToken;
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/profile/analyze-color'),
      )
        ..headers['Authorization'] = 'Bearer $token'
        ..files.add(await http.MultipartFile.fromPath('file', picked.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        // Re-fetch the profile with updated color data
        ref.invalidate(profileProvider);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Color profile updated!')),
          );
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to analyze photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _analyzingColor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    if (profileAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final c = context.dc;
    final profile = profileAsync.valueOrNull;
    final user = Supabase.instance.client.auth.currentUser;
    final meta = user?.userMetadata ?? {};
    final displayName = (profile?['display_name'] as String?)?.isNotEmpty == true
        ? profile!['display_name'] as String
        : (meta['full_name'] as String?) ?? (meta['name'] as String?) ?? 'You';
    final avatarUrl =
        (meta['avatar_url'] as String?) ?? (meta['picture'] as String?);
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final seasonalType = profile?['seasonal_type'] as String?;

    final powerColors = _parseSwatches(profile?['power_colors']);
    final neutralColors = _parseSwatches(profile?['neutral_colors']);
    final avoidColors = _parseSwatches(profile?['avoid_colors']);

    final colorAware = (profile?['color_aware_recommendations'] as bool?) ?? true;
    final weatherAware = (profile?['weather_aware_styling'] as bool?) ?? true;
    final repeatDetect = (profile?['repeat_detection'] as bool?) ?? false;
    final savingSettings = _savingSettings;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ── Avatar + name + seasonal type ──
            Center(
              child: Column(
                children: [
                  _Avatar(avatarUrl: avatarUrl, initial: initial),
                  const SizedBox(height: 12),
                  Text(
                    displayName,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: c.textTertiary),
                  ),
                  if (seasonalType != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: c.bg2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _capitalise(seasonalType),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Color palettes ──
            if (powerColors.isEmpty && neutralColors.isEmpty)
              _NoColorProfile(onTap: _analyzingColor ? null : _pickAndAnalyzePhoto)
            else ...[
              if (powerColors.isNotEmpty) ...[
                _PaletteSection(
                  label: 'YOUR POWER COLORS',
                  child: ColorSwatchRow(items: powerColors),
                ),
                const SizedBox(height: 16),
              ],
              if (neutralColors.isNotEmpty) ...[
                _PaletteSection(
                  label: 'SAFE NEUTRALS',
                  child: ColorSwatchRow(items: neutralColors),
                ),
                const SizedBox(height: 16),
              ],
              if (avoidColors.isNotEmpty) ...[
                _PaletteSection(
                  label: 'COLORS TO AVOID',
                  child: ColorSwatchRow(
                    items: avoidColors.map((e) => ColorSwatchItem(
                      color: e.color,
                      label: e.label,
                      avoid: true,
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            const SizedBox(height: 12),

            // ── Settings toggles ──
            ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeNotifier.notifier,
              builder: (context2, themeMode, _) {
                return Opacity(
                  opacity: savingSettings ? 0.6 : 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: c.border,
                          width: 0.5),
                    ),
                    child: Column(
                      children: [
                        _SettingItem(
                          title: 'Dark mode',
                          description: 'Switch between light and dark theme',
                          value: themeMode == ThemeMode.dark,
                          onChanged: (_) => ThemeNotifier.toggle(),
                          showBorder: true,
                          accentColor: c.textPrimary,
                          bg3Color: c.bg3,
                          borderColor: c.border,
                          textPrimaryColor: c.textPrimary,
                          textTertiaryColor: c.textTertiary,
                        ),
                        _SettingItem(
                          title: 'Color-aware recommendations',
                          description: 'Prioritise items that match your palette',
                          value: colorAware,
                          onChanged: savingSettings
                              ? null
                              : (v) => _updateSetting('color_aware_recommendations', v),
                          showBorder: true,
                          accentColor: c.textPrimary,
                          bg3Color: c.bg3,
                          borderColor: c.border,
                          textPrimaryColor: c.textPrimary,
                          textTertiaryColor: c.textTertiary,
                        ),
                        _SettingItem(
                          title: 'Weather-aware styling',
                          description: 'Factor in local weather conditions',
                          value: weatherAware,
                          onChanged: savingSettings
                              ? null
                              : (v) => _updateSetting('weather_aware_styling', v),
                          showBorder: true,
                          accentColor: c.textPrimary,
                          bg3Color: c.bg3,
                          borderColor: c.border,
                          textPrimaryColor: c.textPrimary,
                          textTertiaryColor: c.textTertiary,
                        ),
                        _SettingItem(
                          title: 'Repeat detection',
                          description: 'Avoid recent outfit repeats',
                          value: repeatDetect,
                          onChanged: savingSettings
                              ? null
                              : (v) => _updateSetting('repeat_detection', v),
                          showBorder: false,
                          accentColor: c.textPrimary,
                          bg3Color: c.bg3,
                          borderColor: c.border,
                          textPrimaryColor: c.textPrimary,
                          textTertiaryColor: c.textTertiary,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Update photos ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _analyzingColor ? null : _pickAndAnalyzePhoto,
                child: _analyzingColor
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Update my colour profile'),
              ),
            ),
            const SizedBox(height: 12),

            // ── Sign out ──
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async => await AuthService.signOut(),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.blush),
                child: Text(
                  'Sign out',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blush,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  List<ColorSwatchItem> _parseSwatches(dynamic raw) {
    if (raw == null) return [];
    try {
      final list = raw as List<dynamic>;
      return list.map((e) {
        final hex = (e['hex'] as String).replaceFirst('#', '');
        final color = Color(int.parse('FF$hex', radix: 16));
        return ColorSwatchItem(color: color, label: e['name'] as String);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  String _capitalise(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final String? avatarUrl;
  final String initial;

  const _Avatar({this.avatarUrl, required this.initial});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: c.bg2,
        backgroundImage: CachedNetworkImageProvider(avatarUrl!),
      );
    }
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.textPrimary, AppColors.textSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
      ),
    );
  }
}

class _NoColorProfile extends StatelessWidget {
  final VoidCallback? onTap;

  const _NoColorProfile({this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: c.textPrimary.withValues(alpha: 0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(Icons.palette_outlined,
                size: 36, color: c.textPrimary),
            const SizedBox(height: 10),
            Text(
              'Discover your colour profile',
              style: GoogleFonts.cormorantGaramond(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'Upload a selfie and we\'ll analyse your seasonal palette',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                // Always use static dark bg so white text is always readable
                color: AppColors.textPrimary,
                borderRadius: BorderRadius.circular(50),
              ),
              child: Text('Upload selfie',
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaletteSection extends StatelessWidget {
  final String label;
  final Widget child;

  const _PaletteSection({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showBorder;
  final Color accentColor;
  final Color bg3Color;
  final Color borderColor;
  final Color textPrimaryColor;
  final Color textTertiaryColor;

  const _SettingItem({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    required this.showBorder,
    required this.accentColor,
    required this.bg3Color,
    required this.borderColor,
    required this.textPrimaryColor,
    required this.textTertiaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: showBorder
            ? Border(
                bottom: BorderSide(
                    color: borderColor, width: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textPrimaryColor)),
                const SizedBox(height: 2),
                Text(description,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 11, color: textTertiaryColor)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _CustomToggle(
              value: value,
              onChanged: onChanged ?? (_) {},
              accentColor: accentColor,
              bg3Color: bg3Color),
        ],
      ),
    );
  }
}

class _CustomToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accentColor;
  final Color bg3Color;

  const _CustomToggle({
    required this.value,
    required this.onChanged,
    required this.accentColor,
    required this.bg3Color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        decoration: BoxDecoration(
          color: value ? accentColor : bg3Color,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../models/chat_message.dart';
import '../../../models/garment.dart';
import '../../../providers/garment_provider.dart';
import '../../../providers/outfit_provider.dart';
import '../../../theme/app_theme.dart';
import '../closet/garment_detail_screen.dart';

class OutfitPreviewScreen extends ConsumerStatefulWidget {
  final ChatOutfitSuggestion suggestion;

  const OutfitPreviewScreen({
    super.key,
    required this.suggestion,
  });

  @override
  ConsumerState<OutfitPreviewScreen> createState() =>
      _OutfitPreviewScreenState();
}

class _OutfitPreviewScreenState extends ConsumerState<OutfitPreviewScreen> {
  bool _saving = false;
  bool _saved = false;

  Color _scoreColor(int score) {
    if (score >= 85) return AppColors.sage;
    if (score >= 65) return AppColors.gold;
    return AppColors.blush;
  }

  Color _scoreBg(int score) {
    if (score >= 85) return AppColors.sageLight;
    if (score >= 65) return AppColors.goldLight;
    return AppColors.blushLight;
  }

  Future<void> _saveOutfit() async {
    if (_saving || _saved) return;
    setState(() => _saving = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/outfits'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': widget.suggestion.name,
          'garment_ids': widget.suggestion.garmentIds,
        }),
      );

      if (res.statusCode == 200) {
        // Invalidate the outfit list so OutfitsScreen reflects the new outfit
        ref.invalidate(outfitListProvider);
        setState(() {
          _saving = false;
          _saved = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Outfit saved to your Outfits tab',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13)),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.sage,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Save failed (HTTP ${res.statusCode})');
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', ''),
                style: GoogleFonts.plusJakartaSans(fontSize: 13)),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.blush,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final s = widget.suggestion;
    final score = s.matchScore;
    final garmentMap = ref.watch(garmentMapProvider);
    final garments = s.garmentIds
        .map((id) => garmentMap[id])
        .where((g) => g != null)
        .cast<Garment>()
        .toList();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.arrow_back, color: c.textTertiary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s.name,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (score > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _scoreBg(score),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '$score%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor(score),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // ── Scrollable content ────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.reasoning.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_awesome, size: 15, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.reasoning,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                  color: c.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      '${garments.length} piece${garments.length == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ...garments.map((g) => GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => GarmentDetailScreen(garment: g),
                            ),
                          ),
                          child: _GarmentItem(garment: g, c: c),
                        )),
                    Builder(builder: (context) {
                      final missing = s.garmentIds
                          .where((id) => !garmentMap.containsKey(id))
                          .length;
                      if (missing == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$missing item${missing == 1 ? '' : 's'} not found in your wardrobe',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 12, color: c.textTertiary),
                        ),
                      );
                    }),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Save button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_saving || _saved) ? null : _saveOutfit,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(_saved ? Icons.check : Icons.bookmark_outline, size: 18),
                  label: Text(_saved
                      ? 'Saved to Outfits'
                      : _saving
                          ? 'Saving…'
                          : 'Save to Outfits'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single garment item ───────────────────────────────────────────────────────

class _GarmentItem extends StatelessWidget {
  final Garment garment;
  final DresserColors c;

  const _GarmentItem({required this.garment, required this.c});

  String _cap(String? s) {
    if (s == null || s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final displayUrl = garment.displayImageUrl ?? garment.thumbnailUrl;
    final name = garment.subCategory?.isNotEmpty == true
        ? _cap(garment.subCategory)
        : _cap(garment.category);
    final colorName = garment.dominantColorName;
    final colorHex = garment.dominantColorHex;

    Color? dotColor;
    if (colorHex != null && colorHex.length == 7) {
      dotColor = Color(int.parse('FF${colorHex.substring(1)}', radix: 16));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        children: [
          SizedBox(
            width: 90,
            height: 110,
            child: displayUrl != null
                ? CachedNetworkImage(
                    imageUrl: displayUrl,
                    fit: BoxFit.cover,
                    placeholder: (ctx, url) => Container(color: c.bg2),
                    errorWidget: (ctx, url, err) => Container(
                      color: c.bg2,
                      child: Center(
                        child: Icon(Icons.checkroom_outlined,
                            color: c.textTertiary, size: 28),
                      ),
                    ),
                  )
                : Container(
                    color: c.bg2,
                    child: Center(
                      child: Icon(Icons.checkroom_outlined,
                          color: c.textTertiary, size: 28),
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cap(garment.category),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: c.textTertiary,
                    ),
                  ),
                  if (colorName != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (dotColor != null)
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border, width: 1),
                            ),
                          ),
                        Text(
                          _cap(colorName),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.chevron_right_rounded, size: 16, color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

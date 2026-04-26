import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../config/supabase_config.dart';
import '../../../models/garment.dart';
import '../../../models/outfit.dart';
import '../../../providers/garment_provider.dart';
import '../../../providers/outfit_provider.dart';
import '../../../theme/app_theme.dart';
import '../closet/garment_detail_screen.dart';

class OutfitDetailScreen extends ConsumerStatefulWidget {
  final Outfit outfit;

  const OutfitDetailScreen({super.key, required this.outfit});

  @override
  ConsumerState<OutfitDetailScreen> createState() => _OutfitDetailScreenState();
}

class _OutfitDetailScreenState extends ConsumerState<OutfitDetailScreen> {
  bool _loggingWorn = false;
  bool _deleting = false;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.outfit.isFavorite;
  }

  Color _scoreColor(DresserColors c, int score) {
    if (score >= 85) return c.sage;
    if (score >= 65) return c.gold;
    return c.blush;
  }

  Color _scoreBg(DresserColors c, int score) {
    if (score >= 85) return c.sageLight;
    if (score >= 65) return c.goldLight;
    return c.blushLight;
  }

  Future<void> _logWorn() async {
    if (_loggingWorn) return;
    setState(() => _loggingWorn = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      await http.post(
        Uri.parse(
            '${SupabaseConfig.apiBaseUrl}/api/v1/outfits/${widget.outfit.id}/worn'),
        headers: {'Authorization': 'Bearer $token'},
      );
      ref.invalidate(outfitListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Marked as worn today',
              style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          backgroundColor: AppColors.sage,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loggingWorn = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final newVal = !_isFavorite;
    setState(() => _isFavorite = newVal);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      await http.put(
        Uri.parse(
            '${SupabaseConfig.apiBaseUrl}/api/v1/outfits/${widget.outfit.id}'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'is_favorite': newVal}),
      );
      ref.invalidate(outfitListProvider);
    } catch (_) {
      if (mounted) setState(() => _isFavorite = !newVal);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete outfit?',
            style: GoogleFonts.cormorantGaramond(
                fontSize: 20, fontWeight: FontWeight.w600)),
        content: Text('This cannot be undone.',
            style: GoogleFonts.plusJakartaSans(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Delete',
                  style: TextStyle(color: AppColors.blush))),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      await http.delete(
        Uri.parse(
            '${SupabaseConfig.apiBaseUrl}/api/v1/outfits/${widget.outfit.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      ref.invalidate(outfitListProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final o = widget.outfit;
    final garmentMap = ref.watch(garmentMapProvider);
    final garments = o.garmentIds
        .map((id) => garmentMap[id])
        .where((g) => g != null)
        .cast<Garment>()
        .toList();
    final score = o.matchScore ?? 0;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.arrow_back,
                        color: c.textTertiary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      o.name,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: _scoreBg(c, score),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: Text(
                        '$score%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _scoreColor(c, score),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _toggleFavorite,
                    child: Icon(
                      _isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_outline_rounded,
                      color: _isFavorite ? AppColors.blush : c.textTertiary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable body ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta row
                    Row(
                      children: [
                        if (o.occasion != null)
                          _Chip(label: o.occasion!, c: c),
                        if (o.aiGenerated) ...[
                          const SizedBox(width: 8),
                          _Chip(label: 'AI styled', c: c, highlight: true),
                        ],
                        const Spacer(),
                        if (o.timesWorn > 0)
                          Text(
                            'Worn ${o.timesWorn}×',
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: c.textTertiary),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // AI reasoning
                    if (o.aiReasoning != null &&
                        o.aiReasoning!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.auto_awesome,
                                size: 15, color: AppColors.gold),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                o.aiReasoning!,
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

                    // Garments
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
                          child: _GarmentRow(garment: g, c: c),
                        )),

                    // Missing garments notice
                    Builder(builder: (context) {
                      final missing = o.garmentIds
                          .where((id) => !garmentMap.containsKey(id))
                          .length;
                      if (missing == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '$missing item${missing == 1 ? '' : 's'} no longer in wardrobe',
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

            // ── Actions ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _deleting ? null : _delete,
                      icon: _deleting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.blush,
                        side: BorderSide(
                            color: AppColors.blush.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _loggingWorn ? null : _logWorn,
                      icon: _loggingWorn
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_circle_outline, size: 16),
                      label: const Text('Wore this today'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final DresserColors c;
  final bool highlight;

  const _Chip({required this.label, required this.c, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: highlight ? AppColors.goldLight : c.bg2,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: highlight ? AppColors.gold : c.textSecondary,
        ),
      ),
    );
  }
}

class _GarmentRow extends StatelessWidget {
  final Garment garment;
  final DresserColors c;

  const _GarmentRow({required this.garment, required this.c});

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
    final colorHex = garment.dominantColorHex;
    Color? dotColor;
    if (colorHex != null && colorHex.length == 7) {
      dotColor =
          Color(int.parse('FF${colorHex.substring(1)}', radix: 16));
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
                              color: c.textTertiary, size: 28)),
                    ),
                  )
                : Container(
                    color: c.bg2,
                    child: Center(
                        child: Icon(Icons.checkroom_outlined,
                            color: c.textTertiary, size: 28)),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                  const SizedBox(height: 2),
                  Text(_cap(garment.category),
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 12, color: c.textTertiary)),
                  if (garment.dominantColorName != null) ...[
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
                              border:
                                  Border.all(color: c.border, width: 1),
                            ),
                          ),
                        Text(_cap(garment.dominantColorName),
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12, color: c.textSecondary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(Icons.chevron_right_rounded,
                size: 16, color: c.textTertiary),
          ),
        ],
      ),
    );
  }
}

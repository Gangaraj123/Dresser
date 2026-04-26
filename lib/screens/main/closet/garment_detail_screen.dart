import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../config/supabase_config.dart';
import '../../../theme/app_theme.dart';
import '../../../models/garment.dart';
import '../../../widgets/tag_chip.dart';

class GarmentDetailScreen extends StatefulWidget {
  final Garment garment;

  const GarmentDetailScreen({super.key, required this.garment});

  @override
  State<GarmentDetailScreen> createState() => _GarmentDetailScreenState();
}

class _GarmentDetailScreenState extends State<GarmentDetailScreen> {
  bool _deleting = false;

  List<_GarmentTag> _buildTags() {
    final g = widget.garment;
    final tags = <_GarmentTag>[];

    // Sub-category / category
    if (g.subCategory != null && g.subCategory!.isNotEmpty) {
      tags.add(_GarmentTag(g.subCategory!, TagType.category));
    } else {
      tags.add(_GarmentTag(_cap(g.category), TagType.category));
    }

    // Color
    if (g.dominantColorName != null) {
      tags.add(_GarmentTag(g.dominantColorName!, TagType.color));
    }

    // Fabric
    if (g.fabric != null) {
      tags.add(_GarmentTag(_cap(g.fabric!), TagType.fabric));
    }

    // Pattern
    if (g.pattern != null) {
      tags.add(_GarmentTag(_cap(g.pattern!), TagType.pattern));
    }

    // Seasons
    for (final s in g.seasonSuitability) {
      tags.add(_GarmentTag(_cap(s), TagType.season));
    }

    // Formality
    if (g.formalityScore != null) {
      tags.add(_GarmentTag('Formality ${g.formalityScore}/5', TagType.formality));
    }

    // Brand
    if (g.brand != null) {
      tags.add(_GarmentTag(g.brand!, TagType.category));
    }

    return tags;
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _formatDate(String? iso) {
    if (iso == null) return 'Never';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day}/${d.month}/${d.year}';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays >= 365) return '${(diff.inDays / 365).floor()}y ago';
    if (diff.inDays >= 30) return '${(diff.inDays / 30).floor()}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    return 'Today';
  }

  Future<void> _deleteGarment() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.dc.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove garment?',
          style: GoogleFonts.cormorantGaramond(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.dc.textPrimary,
          ),
        ),
        content: Text(
          'This will permanently delete the garment from your wardrobe.',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: context.dc.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(color: context.dc.textTertiary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(color: AppColors.blush),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) throw Exception('Not authenticated');

      final res = await http.delete(
        Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/garments/${widget.garment.id}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200 && res.statusCode != 204) {
        final body = jsonDecode(res.body);
        throw Exception(body['detail'] ?? 'Delete failed');
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final g = widget.garment;
    final tags = _buildTags();
    final imageUrl = g.displayImageUrl ?? g.thumbnailUrl;

    Color? dotColor;
    if (g.dominantColorHex != null && g.dominantColorHex!.length == 7) {
      dotColor = Color(int.parse('FF${g.dominantColorHex!.substring(1)}', radix: 16));
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(Icons.arrow_back, color: c.textTertiary, size: 22),
                  ),
                  const Spacer(),
                  if (_deleting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    GestureDetector(
                      onTap: _deleteGarment,
                      child: Icon(Icons.delete_outline, color: c.textTertiary, size: 22),
                    ),
                ],
              ),
            ),
            // ── Scrollable body ───────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: imageUrl != null
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, url) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (_, url, err) => Center(
                                  child: Icon(
                                    Icons.checkroom_outlined,
                                    size: 48,
                                    color: c.textTertiary,
                                  ),
                                ),
                              )
                            : Center(
                                child: Icon(
                                  Icons.checkroom_outlined,
                                  size: 48,
                                  color: c.textTertiary,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Name + color dot row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            g.displayName,
                            style: GoogleFonts.cormorantGaramond(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                        ),
                        if (dotColor != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: dotColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border, width: 1.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added ${_timeAgo(g.createdAt)} · Worn ${g.timesWorn} time${g.timesWorn == 1 ? '' : 's'}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: c.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Tags
                    if (tags.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: tags.map((t) {
                          return TagChip(label: t.label, type: t.type);
                        }).toList(),
                      ),
                    const SizedBox(height: 20),

                    // Stats row
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            value: '${g.timesWorn}',
                            label: 'Times worn',
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatBox(
                            value: _formatDate(g.lastWornDate),
                            label: 'Last worn',
                            color: c.textPrimary,
                          ),
                        ),
                        if (g.skinCompatibilityScore != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StatBox(
                              value: '${g.skinCompatibilityScore}/5',
                              label: 'Skin match',
                              color: AppColors.sage,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 24),
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

class _GarmentTag {
  final String label;
  final TagType type;
  const _GarmentTag(this.label, this.type);
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatBox({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.bg2,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              color: c.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

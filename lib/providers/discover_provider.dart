import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class WardrobeGap {
  final String category;
  final String description;
  final String action;
  final String priority; // high | medium | low
  final int outfitsUnlocked;

  const WardrobeGap({
    required this.category,
    required this.description,
    required this.action,
    required this.priority,
    required this.outfitsUnlocked,
  });

  factory WardrobeGap.fromJson(Map<String, dynamic> j) => WardrobeGap(
        category: j['category'] as String? ?? '',
        description: j['description'] as String? ?? '',
        action: j['action'] as String? ?? '',
        priority: j['priority'] as String? ?? 'medium',
        outfitsUnlocked: (j['outfits_unlocked'] as num?)?.toInt() ?? 0,
      );
}

class ForgottenItem {
  final String garmentId;
  final String suggestion;
  final int? daysSinceWorn;
  final int timesWorn;
  final String? category;
  final String? subCategory;

  const ForgottenItem({
    required this.garmentId,
    required this.suggestion,
    required this.daysSinceWorn,
    required this.timesWorn,
    required this.category,
    required this.subCategory,
  });

  factory ForgottenItem.fromJson(Map<String, dynamic> j) => ForgottenItem(
        garmentId: j['garment_id'] as String? ?? '',
        suggestion: j['suggestion'] as String? ?? '',
        daysSinceWorn: (j['days_since_worn'] as num?)?.toInt(),
        timesWorn: (j['times_worn'] as num?)?.toInt() ?? 0,
        category: j['category'] as String?,
        subCategory: j['sub_category'] as String?,
      );
}

class UntriedCombo {
  final List<String> garmentIds;
  final String reasoning;
  final String occasion;

  const UntriedCombo({
    required this.garmentIds,
    required this.reasoning,
    required this.occasion,
  });

  factory UntriedCombo.fromJson(Map<String, dynamic> j) => UntriedCombo(
        garmentIds: (j['garment_ids'] as List?)?.cast<String>() ?? [],
        reasoning: j['reasoning'] as String? ?? '',
        occasion: j['occasion'] as String? ?? '',
      );
}

class ColorEntry {
  final String colorFamily;
  final int count;
  final int percentage;

  const ColorEntry({
    required this.colorFamily,
    required this.count,
    required this.percentage,
  });

  factory ColorEntry.fromJson(Map<String, dynamic> j) => ColorEntry(
        colorFamily: j['color_family'] as String? ?? 'unknown',
        count: (j['count'] as num?)?.toInt() ?? 0,
        percentage: (j['percentage'] as num?)?.toInt() ?? 0,
      );
}

class ColorBalance {
  final List<ColorEntry> breakdown;
  final String? recommendation;

  const ColorBalance({required this.breakdown, required this.recommendation});

  factory ColorBalance.fromJson(Map<String, dynamic> j) => ColorBalance(
        breakdown: (j['breakdown'] as List?)
                ?.map((e) => ColorEntry.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        recommendation: j['recommendation'] as String?,
      );
}

class WeeklyTip {
  final String title;
  final String body;
  final String basedOn;

  const WeeklyTip({
    required this.title,
    required this.body,
    required this.basedOn,
  });

  factory WeeklyTip.fromJson(Map<String, dynamic> j) => WeeklyTip(
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        basedOn: j['based_on'] as String? ?? '',
      );
}

class DiscoverInsights {
  final List<WardrobeGap> gaps;
  final List<ForgottenItem> forgottenItems;
  final List<UntriedCombo> untriedCombinations;
  final ColorBalance colorBalance;
  final WeeklyTip? weeklyTip;
  final Map<String, String?> garmentThumbnails;

  const DiscoverInsights({
    required this.gaps,
    required this.forgottenItems,
    required this.untriedCombinations,
    required this.colorBalance,
    required this.weeklyTip,
    required this.garmentThumbnails,
  });

  factory DiscoverInsights.fromJson(Map<String, dynamic> j) => DiscoverInsights(
        gaps: (j['gaps'] as List?)
                ?.map((e) => WardrobeGap.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        forgottenItems: (j['forgotten_items'] as List?)
                ?.map((e) => ForgottenItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        untriedCombinations: (j['untried_combinations'] as List?)
                ?.map((e) => UntriedCombo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        colorBalance: ColorBalance.fromJson(
            (j['color_balance'] as Map<String, dynamic>?) ?? {}),
        weeklyTip: j['weekly_tip'] != null
            ? WeeklyTip.fromJson(j['weekly_tip'] as Map<String, dynamic>)
            : null,
        garmentThumbnails: (j['garment_thumbnails'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v as String?)) ??
            {},
      );
}

// ── Provider ──────────────────────────────────────────────────────────────────

class DiscoverNotifier extends AsyncNotifier<DiscoverInsights> {
  @override
  Future<DiscoverInsights> build() => _fetch();

  Future<DiscoverInsights> _fetch() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');

    final res = await http.get(
      Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/discover/insights'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>?;
      final msg = body?['error']?['message'] as String? ?? 'Could not load insights';
      throw Exception(msg);
    }

    final data = (jsonDecode(res.body) as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    return DiscoverInsights.fromJson(data);
  }
}

final discoverInsightsProvider =
    AsyncNotifierProvider<DiscoverNotifier, DiscoverInsights>(
        DiscoverNotifier.new);

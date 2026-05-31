import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/garment.dart';

const _kCacheKey = 'garment_list_cache';

// ---------------------------------------------------------------------------
// Garment list
// ---------------------------------------------------------------------------

class GarmentListNotifier extends AsyncNotifier<List<Garment>> {
  @override
  Future<List<Garment>> build() async {
    // 1. Return cached data immediately so the UI is never blank
    final cached = await _loadCache();
    if (cached.isNotEmpty) {
      state = AsyncData(cached);
      // 2. Refresh from network in the background; UI updates when done
      _fetchAndCache()
          .then<void>((fresh) => state = AsyncData(fresh))
          .catchError((Object _) {});
      return cached;
    }
    // No cache yet — block until first network load
    return _fetchAndCache();
  }

  Future<List<Garment>> _fetchAndCache() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');
    final res = await http.get(
      Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/garments'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      throw Exception(_parseError(res.body, res.statusCode, 'Could not load garments'));
    }
    final data = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
    final garments = data.map(Garment.fromJson).toList();
    await _saveCache(garments);
    return garments;
  }

  // Called after a garment is added or deleted — re-fetches and re-caches
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchAndCache);
  }

  static Future<List<Garment>> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(Garment.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveCache(List<Garment> garments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kCacheKey,
        jsonEncode(garments.map((g) => g.toJson()).toList()),
      );
    } catch (_) {}
  }

  static String _parseError(String body, int status, String fallback) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final msg = json['error']?['message'] as String? ??
          json['detail'] as String? ??
          json['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
    return '$fallback (HTTP $status)';
  }
}

Future<void> clearGarmentCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
  } catch (_) {}
}

final garmentListProvider =
    AsyncNotifierProvider<GarmentListNotifier, List<Garment>>(
  GarmentListNotifier.new,
);

// ---------------------------------------------------------------------------
// Wardrobe stats — re-fetches whenever garment list is invalidated
// ---------------------------------------------------------------------------

final wardrobeStatsProvider = FutureProvider<WardrobeStats>((ref) async {
  ref.watch(garmentListProvider);
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  if (token == null) return WardrobeStats.empty;
  final res = await http.get(
    Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/garments/stats'),
    headers: {'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return WardrobeStats.empty;
  final data = jsonDecode(res.body)['data'] as Map<String, dynamic>;
  return WardrobeStats.fromJson(data);
});

// ---------------------------------------------------------------------------
// Derived map: garmentId → Garment  (used by Stylist + OutfitPreview)
// ---------------------------------------------------------------------------

final garmentMapProvider = Provider<Map<String, Garment>>((ref) {
  final garments = ref.watch(garmentListProvider).valueOrNull ?? [];
  return {for (final g in garments) g.id: g};
});

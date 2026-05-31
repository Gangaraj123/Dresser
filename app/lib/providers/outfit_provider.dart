import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../models/outfit.dart';

class OutfitListNotifier extends AsyncNotifier<List<Outfit>> {
  @override
  Future<List<Outfit>> build() => _fetch();

  Future<List<Outfit>> _fetch() async {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    if (token == null) throw Exception('Not authenticated');
    final res = await http.get(
      Uri.parse('${SupabaseConfig.apiBaseUrl}/api/v1/outfits'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Failed to load outfits (HTTP ${res.statusCode})');
    final data = (jsonDecode(res.body)['data'] as List).cast<Map<String, dynamic>>();
    return data.map(Outfit.fromJson).toList();
  }
}

final outfitListProvider =
    AsyncNotifierProvider<OutfitListNotifier, List<Outfit>>(
  OutfitListNotifier.new,
);

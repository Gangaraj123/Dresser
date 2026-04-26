import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() => _fetch();

  Future<Map<String, dynamic>?> _fetch() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;
    return Supabase.instance.client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }

  Future<void> updateSetting(String field, dynamic value) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await Supabase.instance.client.from('profiles').upsert({
      'id': userId,
      field: value,
    });
    // Optimistic update — patch in place without a re-fetch
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData({...current, field: value});
    } else {
      ref.invalidateSelf();
    }
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, Map<String, dynamic>?>(
  ProfileNotifier.new,
);

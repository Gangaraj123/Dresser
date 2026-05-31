import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL']!;
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY']!;
  static String get apiBaseUrl => dotenv.env['API_BASE_URL']!;

  static String get redirectScheme =>
      dotenv.env['REDIRECT_SCHEME'] ?? 'io.supabase.dresser';
  static String get redirectUrl => '$redirectScheme://login-callback';
}

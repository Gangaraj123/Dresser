import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/garment_provider.dart';

class AuthService {
  static final _supabase = Supabase.instance.client;

  static final _googleSignIn = GoogleSignIn(
    serverClientId:
        '728878973015-cq3hhu731aluf98dra2909ektbqn8plb.apps.googleusercontent.com',
  );

  static User? get currentUser => _supabase.auth.currentUser;
  static Session? get currentSession => _supabase.auth.currentSession;
  static bool get isLoggedIn => currentUser != null;

  static Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  /// Native Google Sign-In popup — no browser redirect.
  static Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return; // user cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    if (idToken == null) {
      throw Exception('Google Sign-In failed: no ID token received.');
    }

    await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: googleAuth.accessToken,
    );
  }

  /// Sign in with email + password
  static Future<AuthResponse> signInWithEmail(
      String email, String password) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with email + password
  static Future<AuthResponse> signUpWithEmail(
      String email, String password) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Sign out (also clears Google session and local caches)
  static Future<void> signOut() async {
    await clearGarmentCache();
    await _googleSignIn.signOut();
    await _supabase.auth.signOut();
  }
}

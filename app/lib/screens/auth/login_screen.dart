import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../services/auth_service.dart';
import 'onboarding_step1_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _setLoading(bool value) => setState(() => _isLoading = value);
  void _setError(String? msg) => setState(() => _errorMessage = msg);

  Future<void> _handleGoogleSignIn() async {
    _setError(null);
    _setLoading(true);
    try {
      await AuthService.signInWithGoogle();
      // Auth gate in main.dart will handle navigation once session is set
    } catch (e) {
      _setError('Google sign-in failed. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _setError('Please enter your email and password.');
      return;
    }

    _setError(null);
    _setLoading(true);
    try {
      AuthResponse response;
      if (_isSignUp) {
        response = await AuthService.signUpWithEmail(email, password);
        if (response.user != null && response.session == null) {
          // Email confirmation required
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Check your email to confirm your account.'),
              ),
            );
          }
          return;
        }
      } else {
        response = await AuthService.signInWithEmail(email, password);
      }

      if (response.session != null && mounted) {
        // New user: go to onboarding; existing user: AuthGate handles MainShell
        final isNew = response.user?.createdAt == response.user?.lastSignInAt;
        if (isNew || _isSignUp) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const OnboardingStep1Screen()),
          );
        }
        // Existing sign-in: AuthGate's StreamBuilder will navigate to MainShell
      }
    } on AuthException catch (e) {
      _setError(e.message);
    } catch (e) {
      _setError('Something went wrong. Please try again.');
    } finally {
      if (mounted) _setLoading(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Text(
                'Dresser',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your AI-powered personal stylist',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 48),

              // Google sign-in button
              _GoogleButton(
                onTap: _isLoading ? null : _handleGoogleSignIn,
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                      child: Divider(
                          color: c.border, thickness: 0.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: GoogleFonts.plusJakartaSans(
                          fontSize: 13, color: c.textTertiary),
                    ),
                  ),
                  Expanded(
                      child: Divider(
                          color: c.border, thickness: 0.5)),
                ],
              ),
              const SizedBox(height: 24),

              // Email field
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textPrimary),
                decoration: const InputDecoration(hintText: 'Email address'),
              ),
              const SizedBox(height: 12),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 14, color: c.textPrimary),
                decoration: const InputDecoration(hintText: 'Password'),
                onSubmitted: (_) => _handleEmailAuth(),
              ),

              // Error message
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.blush.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 13, color: AppColors.blush),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Sign in / Sign up button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleEmailAuth,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(_isSignUp ? 'Sign up' : 'Sign in'),
                ),
              ),

              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() {
                  _isSignUp = !_isSignUp;
                  _errorMessage = null;
                }),
                child: RichText(
                  text: TextSpan(
                    text: _isSignUp
                        ? 'Already have an account? '
                        : "Don't have an account? ",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 14, color: c.textSecondary),
                    children: [
                      TextSpan(
                        text: _isSignUp ? 'Sign in' : 'Sign up',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          color: c.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoogleButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _GoogleButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: c.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.string(
              _googleLogoSvg,
              width: 20,
              height: 20,
            ),
            const SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Official Google "G" logo SVG
const _googleLogoSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
  <path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
  <path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
  <path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
  <path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
  <path fill="none" d="M0 0h48v48H0z"/>
</svg>
''';

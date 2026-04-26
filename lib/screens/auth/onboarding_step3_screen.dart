import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../main/main_shell.dart';

class OnboardingStep3Screen extends StatelessWidget {
  const OnboardingStep3Screen({super.key});

  void _goToMainApp(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    final options = [
      _ClosetOption(
        icon: Icons.camera_alt_outlined,
        title: 'Take a photo',
        subtitle: 'Lay flat or hang on a plain background',
      ),
      _ClosetOption(
        icon: Icons.image_outlined,
        title: 'Upload from gallery',
        subtitle: 'Select existing photos of your clothes',
      ),
      _ClosetOption(
        icon: Icons.upload_outlined,
        title: 'Bulk upload',
        subtitle: 'Select multiple items at once',
      ),
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _ProgressIndicator(current: 3, total: 3),
              const SizedBox(height: 32),
              Text(
                'Build your closet',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add your clothes to get personalized outfit suggestions',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              ...options.map((option) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () => _goToMainApp(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.border,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: c.bg2,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                option.icon,
                                color: c.textPrimary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.title,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    option.subtitle,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: c.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: c.textTertiary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToMainApp(context),
                  child: const Text("Let's get started"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _goToMainApp(context),
                  child: const Text("I'll do this later"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClosetOption {
  final IconData icon;
  final String title;
  final String subtitle;

  _ClosetOption({required this.icon, required this.title, required this.subtitle});
}

class _ProgressIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _ProgressIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Row(
      children: List.generate(total, (index) {
        final isActive = index < current;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: isActive ? c.textPrimary : c.bg3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}

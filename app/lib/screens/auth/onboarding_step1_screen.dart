import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'onboarding_step2_screen.dart';

class OnboardingStep1Screen extends StatefulWidget {
  const OnboardingStep1Screen({super.key});

  @override
  State<OnboardingStep1Screen> createState() => _OnboardingStep1ScreenState();
}

class _OnboardingStep1ScreenState extends State<OnboardingStep1Screen> {
  final Set<String> _selected = {'Minimalist', 'Bohemian'};

  final List<_StyleOption> _styles = [
    _StyleOption(symbol: '▢', name: 'Minimalist', subtitle: 'Clean, simple, modern'),
    _StyleOption(symbol: '★', name: 'Classic', subtitle: 'Timeless, elegant, refined'),
    _StyleOption(symbol: '◆', name: 'Streetwear', subtitle: 'Urban, bold, expressive'),
    _StyleOption(symbol: '✦', name: 'Bohemian', subtitle: 'Free-spirited, eclectic'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.dc;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _ProgressIndicator(current: 1, total: 3),
              const SizedBox(height: 32),
              Text(
                "What's your style?",
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that resonate with you',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 28),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  children: _styles.map((style) {
                    final isSelected = _selected.contains(style.name);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(style.name);
                          } else {
                            _selected.add(style.name);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: c.bg2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? c.textPrimary : c.border,
                            width: isSelected ? 2 : 0.5,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              style.symbol,
                              style: TextStyle(
                                fontSize: 36,
                                color: isSelected ? c.textPrimary : c.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              style.name,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              style.subtitle,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                color: c.textTertiary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const OnboardingStep2Screen()),
                    );
                  },
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StyleOption {
  final String symbol;
  final String name;
  final String subtitle;

  _StyleOption({required this.symbol, required this.name, required this.subtitle});
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

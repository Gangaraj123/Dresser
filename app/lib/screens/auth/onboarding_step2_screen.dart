import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import 'onboarding_step3_screen.dart';

class OnboardingStep2Screen extends StatelessWidget {
  const OnboardingStep2Screen({super.key});

  void _goToStep3(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const OnboardingStep3Screen()),
    );
  }

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
              _ProgressIndicator(current: 2, total: 3),
              const SizedBox(height: 32),
              Text(
                'Find your best colors',
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a photo so we can analyze your skin tone and suggest your perfect palette',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: c.textTertiary,
                ),
              ),
              const SizedBox(height: 32),
              // Upload area
              GestureDetector(
                onTap: () => _goToStep3(context),
                child: Container(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.25,
                  decoration: BoxDecoration(
                    color: c.bg2,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: c.textPrimary.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _DashedBorderPainter(accentColor: c.textPrimary),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: c.bg2,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: c.textPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Tap to upload your photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A well-lit selfie works best',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Privacy notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.bg2,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: c.textPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Your photo is processed locally and never stored on our servers. We only save your color analysis results.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _goToStep3(context),
                  child: const Text('Upload photo'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _goToStep3(context),
                  child: const Text('Skip for now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color accentColor;

  _DashedBorderPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    const borderRadius = 20.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);

    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final String title;
  final bool isDark;

  const BrandLogo({
    super.key,
    this.size = 72,
    this.showText = true,
    this.title = 'T69 ESPORTS',
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // High-Resolution Neon Speed Monogram App Icon
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D2FF).withValues(alpha: 0.35),
                blurRadius: size * 0.25,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFFF7A00).withValues(alpha: 0.25),
                blurRadius: size * 0.3,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.24),
            child: Image.asset(
              'assets/images/t69_logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: const Color(0xFF0F172A),
                child: Center(
                  child: Text(
                    'T69',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppColors.primary,
                      fontSize: size * 0.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

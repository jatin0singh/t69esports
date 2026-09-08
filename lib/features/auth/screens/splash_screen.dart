import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/brand_logo.dart';
import '../controllers/auth_controller.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';
import '../../home/screens/home_hub_screen.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
    );

    _animController.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTimerAndNavigate();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startTimerAndNavigate() async {
    // Small delay to let splash animation render gracefully
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    // Check user auth immediately without blocking delays
    Widget nextScreen = const LoginScreen();
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = repo.currentUser;

      if (user != null && repo.isEmailConfirmed) {
        // Fast profile check with a 400ms timeout fallback so network lag never stalls startup
        final profile = await repo.getCurrentProfile().timeout(
          const Duration(milliseconds: 400),
          onTimeout: () => null,
        );
        if (profile != null && !profile.isOnboarded) {
          nextScreen = const OnboardingScreen();
        } else {
          nextScreen = const HomeHubScreen();
        }
      } else if (user != null && !repo.isEmailConfirmed) {
        // Real Gmail not verified: force logout to LoginScreen
        await repo.signOut();
        nextScreen = const LoginScreen();
      }
    } catch (_) {
      nextScreen = const LoginScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, _, _) => nextScreen,
        transitionsBuilder: (_, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      body: Stack(
        children: [
          // Subtle Ambient Background Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00D2FF).withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF7A00).withValues(alpha: 0.10),
              ),
            ),
          ),

          // Central Logo and Branding
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const BrandLogo(size: 110, showText: false),
                    const SizedBox(height: 20),
                    Text(
                      'T69 ESPORTS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        'COMPETITIVE TOURNAMENT NETWORK',
                        style: AppTextStyles.badge.copyWith(
                          color: const Color(0xFF00D2FF),
                          letterSpacing: 1.2,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom Loading Indicator
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF00D2FF).withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

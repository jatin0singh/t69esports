import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/brand_logo.dart';
import '../controllers/auth_controller.dart';
import '../../../core/services/rate_limiter_service.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'onboarding_screen.dart';
import '../../home/screens/home_hub_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController.clear();
    _passwordController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      UiHelpers.vibrateError();
      return;
    }

    final email = _emailController.text.trim();

    // 1. Check Rate Limit (5 attempts / 15 mins -> 10m lockout)
    final rlCheck = await RateLimiterService.checkLogin(email);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      setState(() {
        _errorMessage = rlCheck.customMessage ?? 'Too many failed login attempts. Please wait ${rlCheck.formattedRetryAfter} before trying again.';
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.signIn(
      email: email,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      await RateLimiterService.resetLogin(email);
      if (!mounted) return;
      UiHelpers.showSuccessBanner(context, 'Authentication successful.');
      final profile = ref.read(authControllerProvider).value;
      if (profile == null || !profile.isOnboarded) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeHubScreen()),
        );
      }
    } else {
      await RateLimiterService.recordFailedLogin(email);
      final updatedCheck = await RateLimiterService.checkLogin(email);

      if (!mounted) return;
      final error = ref.read(authControllerProvider).error;
      String msg = error?.toString().replaceAll('Exception: ', '') ?? 'Invalid credentials or connection error.';
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network error')) {
        msg = 'No internet connection. Please check your network or Wi-Fi settings and try again.';
      } else if (!updatedCheck.isAllowed) {
        msg = updatedCheck.customMessage ?? 'Account locked due to too many failed attempts.';
      } else if (updatedCheck.remainingAttempts > 0 && updatedCheck.remainingAttempts <= 3) {
        msg = '$msg (${updatedCheck.remainingAttempts} attempts remaining before 10-min security lockout)';
      }
      setState(() {
        _errorMessage = msg;
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      body: Column(
        children: [
          // Top Sky Blue Header Area
          SizedBox(height: topPadding + 20),

          // Main White Sheet (Curved Top)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),

                        // Modern Colorful Brand Emblem & Title (Matching reference)
                        const BrandLogo(size: 80, title: 'T69 Esports'),

                        const SizedBox(height: 32),

                        // Error Banner if any
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4E6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Username / Email Input (Pill)
                        TacticalTextField(
                          hint: 'Username / Email',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [],
                          validator: Validators.validateEmail,
                        ),

                        const SizedBox(height: 16),

                        // Password Input (Pill)
                        TacticalTextField(
                          hint: 'Password',
                          controller: _passwordController,
                          isPassword: true,
                          autofillHints: const [],
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Password is required.';
                            return null;
                          },
                        ),

                        const SizedBox(height: 10),

                        // Forget your password?
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forget your password?',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Login Button (Vibrant Blue Pill)
                        TacticalButton(
                          label: 'Login',
                          isLoading: _isLoading,
                          onPressed: _handleLogin,
                        ),

                        const SizedBox(height: 14),

                        // Create Account Button (Secondary Pill)
                        TacticalButton(
                          label: 'Create Account',
                          variant: TacticalButtonVariant.secondary,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                        ),

                        const SizedBox(height: 36),

                        // Bottom 3 Quick Action Utilities (Matching reference icons)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBottomUtility(
                              icon: Icons.sync_alt_rounded,
                              label: 'Transfer Rates',
                              onTap: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'Prize pool payout rate: 100% instant UPI / Bank transfer.',
                                );
                              },
                            ),
                            _buildBottomUtility(
                              icon: Icons.location_on_rounded,
                              label: 'Branches',
                              onTap: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'T69 Esports official community & discord hubs active.',
                                );
                              },
                            ),
                            _buildBottomUtility(
                              icon: Icons.translate_rounded,
                              label: 'Language',
                              onTap: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'Supported languages: English & Hindi.',
                                );
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                      ],
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

  Widget _buildBottomUtility({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

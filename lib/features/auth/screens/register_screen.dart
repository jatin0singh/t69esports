import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../controllers/auth_controller.dart';
import 'onboarding_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _agreeTerms = true;
  bool _isLoading = false;
  String? _errorMessage;
  PasswordStrength _passwordStrength = const PasswordStrength(
    score: 0,
    label: 'EMPTY',
    color: AppColors.textDisabled,
  );

  @override
  void initState() {
    super.initState();
    _usernameController.clear();
    _fullNameController.clear();
    _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged(String value) {
    setState(() {
      _passwordStrength = Validators.calculatePasswordStrength(value);
    });
  }

  Future<void> _handleRegister() async {
    if (!_agreeTerms) {
      UiHelpers.showErrorBanner(context, 'Please accept the Terms of Service.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      UiHelpers.vibrateError();
      return;
    }

    final email = _emailController.text.trim();

    // 1. Check Rate Limit on Registration (max 3 in 10 mins)
    final rlCheck = await RateLimiterService.checkRegister(email);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      setState(() {
        _errorMessage = rlCheck.customMessage ?? 'Too many registration attempts. Please wait ${rlCheck.formattedRetryAfter}.';
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await RateLimiterService.recordRegisterAttempt(email);

    final authController = ref.read(authControllerProvider.notifier);
    final success = await authController.signUp(
      email: email,
      password: _passwordController.text,
      username: _usernameController.text.trim(),
      fullName: _fullNameController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      final repo = ref.read(authRepositoryProvider);
      if (!repo.isEmailConfirmed) {
        // Confirmation required! User MUST enter OTP sent to their real Gmail
        _showOtpVerificationDialog(
          context,
          email,
        );
      } else {
        UiHelpers.showSuccessBanner(context, 'Account registered successfully.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } else {
      final error = ref.read(authControllerProvider).error;
      String msg = error?.toString().replaceAll('Exception: ', '') ??
          'Registration failed. Please check your details.';
      if (msg.contains('SocketException') || msg.contains('Failed host lookup') || msg.contains('Network error')) {
        msg = 'No internet connection. Please check your network or Wi-Fi settings and try again.';
      } else if (msg.toLowerCase().contains('rate') || msg.toLowerCase().contains('security') || msg.toLowerCase().contains('once every')) {
        msg = 'Security rate limit reached. Please wait a moment before trying again.';
      }
      setState(() {
        _errorMessage = msg;
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
    }
  }

  void _showOtpVerificationDialog(BuildContext context, String email) {
    final otpController = TextEditingController();
    bool isVerifying = false;
    String? otpError;
    int resendCooldown = 60;
    Timer? cooldownTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          final bottomInset = MediaQuery.of(modalCtx).viewInsets.bottom;

          // Start cooldown timer on modal open if not started
          cooldownTimer ??= Timer.periodic(const Duration(seconds: 1), (t) {
            if (modalCtx.mounted && resendCooldown > 0) {
              setModalState(() => resendCooldown--);
            } else if (resendCooldown <= 0) {
              t.cancel();
            }
          });

          return Container(
            padding: EdgeInsets.fromLTRB(24, 20, 24, bottomInset + 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE0F2FE),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.mark_email_unread_rounded, color: Color(0xFF0288D1), size: 32),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Verify Your Real Gmail',
                  style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit verification code to\n'),
                      TextSpan(
                        text: email,
                        style: const TextStyle(color: Color(0xFF0288D1), fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: '.\nEnter it below to confirm this is your real Gmail.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (otpError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE4E6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            otpError!,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error, fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                TacticalTextField(
                  hint: 'Enter 6-Digit OTP Code',
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  isMonospace: true,
                  autofillHints: const [AutofillHints.oneTimeCode],
                ),
                const SizedBox(height: 20),

                TacticalButton(
                  label: 'Verify & Activate Account',
                  isLoading: isVerifying,
                  onPressed: () async {
                    final code = otpController.text.trim();
                    if (code.length < 6) {
                      setModalState(() => otpError = 'Enter the complete 6-digit OTP code.');
                      return;
                    }

                    setModalState(() {
                      isVerifying = true;
                      otpError = null;
                    });

                    final authController = ref.read(authControllerProvider.notifier);
                    final verified = await authController.verifyEmailOtp(
                      email: email,
                      token: code,
                    );

                    if (!mounted || !modalCtx.mounted) return;
                    setModalState(() => isVerifying = false);

                    if (verified) {
                      cooldownTimer?.cancel();
                      Navigator.of(modalCtx).pop();
                      if (!mounted) return;
                      UiHelpers.showSuccessBanner(context, 'Real Gmail verified! Welcome to T69 Esports.');
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                        (route) => false,
                      );
                    } else {
                      final error = ref.read(authControllerProvider).error;
                      setModalState(() {
                        otpError = error?.toString().replaceAll('Exception: ', '') ??
                            'Invalid or expired code. Please check your Gmail.';
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),

                TextButton.icon(
                  onPressed: resendCooldown > 0
                      ? null
                      : () async {
                          final ok = await ref.read(authControllerProvider.notifier).resendSignupOtp(email);
                          if (ok && mounted && modalCtx.mounted) {
                            setModalState(() => resendCooldown = 60);
                            UiHelpers.showSuccessBanner(context, 'New confirmation code sent to $email');
                          }
                        },
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: resendCooldown > 0 ? AppColors.textDisabled : AppColors.textSecondary,
                  ),
                  label: Text(
                    resendCooldown > 0 ? 'Resend Code in ${resendCooldown}s' : 'Resend Code to Gmail',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: resendCooldown > 0 ? AppColors.textDisabled : AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) => cooldownTimer?.cancel());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Account',
          style: AppTextStyles.h4.copyWith(color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const BrandLogo(size: 64, showText: false),
                        const SizedBox(height: 10),
                        Text('Join T69 Esports', style: AppTextStyles.h2),
                        const SizedBox(height: 4),
                        Text(
                          'Create your gamer profile to enter arenas',
                          style: AppTextStyles.bodyMedium,
                        ),

                        const SizedBox(height: 24),

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

                        // Gamer Tag
                        TacticalTextField(
                          hint: 'Gamer Tag / Username',
                          controller: _usernameController,
                          autofillHints: const [],
                          validator: Validators.validateUsername,
                        ),

                        const SizedBox(height: 14),

                        // Full Name
                        TacticalTextField(
                          hint: 'Full Name (Optional)',
                          controller: _fullNameController,
                          autofillHints: const [],
                        ),

                        const SizedBox(height: 14),

                        // Real Gmail Address
                        TacticalTextField(
                          hint: 'Real Gmail Address (e.g. name@gmail.com)',
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [],
                          validator: Validators.validateRealGmail,
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.verified_user_outlined, size: 13, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Enter your real Gmail to receive password reset OTPs.',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Password
                        TacticalTextField(
                          hint: 'Password (min. 8 characters)',
                          controller: _passwordController,
                          isPassword: true,
                          autofillHints: const [],
                          onChanged: _onPasswordChanged,
                          validator: Validators.validatePassword,
                        ),

                        // Password Strength Bar
                        if (_passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: _passwordStrength.score,
                                    backgroundColor: AppColors.surfaceSoft,
                                    valueColor: AlwaysStoppedAnimation<Color>(_passwordStrength.color),
                                    minHeight: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _passwordStrength.label,
                                style: AppTextStyles.badge.copyWith(
                                  color: _passwordStrength.color,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],

                        const SizedBox(height: 14),

                        // Confirm Password
                        TacticalTextField(
                          hint: 'Confirm Password',
                          controller: _confirmPasswordController,
                          isPassword: true,
                          autofillHints: const [],
                          validator: (val) => Validators.validateConfirmPassword(
                            val,
                            _passwordController.text,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Terms
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Checkbox(
                              value: _agreeTerms,
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              onChanged: (val) => setState(() => _agreeTerms = val ?? false),
                            ),
                            Expanded(
                              child: Text(
                                'I agree to the Fair Play Code & Terms of Service.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Register Button
                        TacticalButton(
                          label: 'Create Account',
                          isLoading: _isLoading,
                          onPressed: _handleRegister,
                        ),

                        const SizedBox(height: 16),

                        // Already have account
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Already have an account? Login',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
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
}

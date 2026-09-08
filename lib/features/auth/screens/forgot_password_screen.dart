import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/brand_logo.dart';
import '../controllers/auth_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int _currentStep = 0; // 0 = Send Email, 1 = Enter OTP & New Password, 2 = Success
  bool _isLoading = false;
  String? _errorMessage;

  // Rate Limiting Cooldown Timer State
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  @override
  void initState() {
    super.initState();
    _emailController.clear();
    _otpController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    _errorMessage = null;
    _currentStep = 0;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startCooldownTimer(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  Future<void> _handleSendResetEmail() async {
    if (_currentStep == 0 && !_emailFormKey.currentState!.validate()) {
      UiHelpers.vibrateError();
      return;
    }

    final email = _emailController.text.trim();

    // 1. Check Rate Limit (60s cooldown, max 3 in 15 mins)
    final rlCheck = await RateLimiterService.checkPasswordResetEmail(email);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      if (rlCheck.retryAfterSeconds > 0) {
        _startCooldownTimer(rlCheck.retryAfterSeconds);
      }
      setState(() {
        _errorMessage = rlCheck.customMessage ?? 'Please wait ${rlCheck.formattedRetryAfter} before requesting another recovery code.';
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendPasswordResetEmail(email);
      await RateLimiterService.recordPasswordResetEmail(email);
      if (!mounted) return;
      _startCooldownTimer(60);

      setState(() {
        _isLoading = false;
        _currentStep = 1;
      });
      UiHelpers.showSuccessBanner(context, 'Recovery code sent to your email.');
    } catch (e) {
      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('over_email_send_rate_limit') || msg.contains('429')) {
        msg = 'Please wait 60 seconds before requesting another recovery code.';
        _startCooldownTimer(60);
      } else if (msg.contains('unexpected_failure') || msg.contains('Error sending')) {
        msg = 'Unable to send recovery email. Please check the email and try again.';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
    }
  }

  Future<void> _handleVerifyAndReset() async {
    if (!_resetFormKey.currentState!.validate()) {
      UiHelpers.vibrateError();
      return;
    }

    final email = _emailController.text.trim();

    // 1. Check Rate Limit on OTP verification (max 5 attempts in 15 mins)
    final rlCheck = await RateLimiterService.checkPasswordResetVerify(email);
    if (!rlCheck.isAllowed) {
      UiHelpers.vibrateError();
      if (!mounted) return;
      setState(() {
        _errorMessage = rlCheck.customMessage ?? 'Too many failed verification attempts. Please wait ${rlCheck.formattedRetryAfter}.';
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
      return;
    }

    if (!mounted) return;
    if (_newPasswordController.text != _confirmPasswordController.text) {
      UiHelpers.showErrorBanner(context, 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.verifyPasswordResetOtpAndSetPassword(
        email: email,
        token: _otpController.text.trim(),
        newPassword: _newPasswordController.text,
      );

      await RateLimiterService.resetPasswordResetVerify(email);
      _cooldownTimer?.cancel();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _currentStep = 2;
      });
      UiHelpers.showSuccessBanner(context, 'Password updated successfully!');
    } catch (e) {
      await RateLimiterService.recordFailedPasswordResetVerify(email);
      final updatedCheck = await RateLimiterService.checkPasswordResetVerify(email);

      if (!mounted) return;
      String msg = e.toString().replaceAll('Exception: ', '');
      if (msg.toLowerCase().contains('expired') || msg.toLowerCase().contains('invalid') || msg.toLowerCase().contains('token')) {
        msg = 'Invalid or expired code. Please use the code from your most recent email.';
      }
      if (!updatedCheck.isAllowed) {
        msg = updatedCheck.customMessage ?? 'Verification locked due to too many incorrect attempts.';
      } else if (updatedCheck.remainingAttempts > 0 && updatedCheck.remainingAttempts <= 3) {
        msg = '$msg (${updatedCheck.remainingAttempts} attempts remaining)';
      }
      setState(() {
        _isLoading = false;
        _errorMessage = msg;
      });
      UiHelpers.showErrorBanner(context, _errorMessage!);
    }
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
        title: Text('Reset Password', style: AppTextStyles.h4.copyWith(color: Colors.white)),
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
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: _currentStep == 2
                      ? _buildSuccessView()
                      : _currentStep == 1
                          ? _buildOtpAndNewPasswordView()
                          : _buildSendEmailView(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSendEmailView() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const BrandLogo(size: 64, showText: false),
          const SizedBox(height: 12),
          Text('Forgot Password', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Enter your registered email to receive a 6-digit recovery code.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

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

          TacticalTextField(
            hint: 'Registered Gmail Address',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [],
            validator: Validators.validateRealGmail,
          ),

          const SizedBox(height: 24),

          TacticalButton(
            label: 'Send Recovery Code',
            isLoading: _isLoading,
            onPressed: _handleSendResetEmail,
          ),
        ],
      ),
    );
  }

  Widget _buildOtpAndNewPasswordView() {
    return Form(
      key: _resetFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFE0F2FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AppColors.primaryDark, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Enter Recovery Code', style: AppTextStyles.h2),
          const SizedBox(height: 6),
          Text(
            'Enter the 6-digit code sent to ${_emailController.text.trim()} and choose a new password.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
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

          // 6-Digit OTP Code
          TacticalTextField(
            hint: '6-Digit Code (e.g. 123456)',
            controller: _otpController,
            keyboardType: TextInputType.number,
            prefixIcon: Icons.pin_rounded,
            validator: (val) {
              if (val == null || val.trim().length < 6) {
                return 'Enter the complete 6-digit code';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),

          // New Password
          TacticalTextField(
            hint: 'New Password',
            controller: _newPasswordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline_rounded,
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: 14),

          // Confirm Password
          TacticalTextField(
            hint: 'Confirm New Password',
            controller: _confirmPasswordController,
            isPassword: true,
            prefixIcon: Icons.lock_outline_rounded,
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please confirm your password';
              if (val != _newPasswordController.text) return 'Passwords do not match';
              return null;
            },
          ),
          const SizedBox(height: 24),

          TacticalButton(
            label: 'Update Password & Sign In',
            isLoading: _isLoading,
            onPressed: _handleVerifyAndReset,
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: (_isLoading || _cooldownSeconds > 0) ? null : _handleSendResetEmail,
            child: Text(
              _cooldownSeconds > 0 ? 'Resend Code in ${_cooldownSeconds}s' : 'Resend 6-Digit Code',
              style: AppTextStyles.bodyMedium.copyWith(
                color: _cooldownSeconds > 0 ? AppColors.textDisabled : AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 20),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 40),
          ),
        ),
        const SizedBox(height: 24),
        Text('Password Reset!', style: AppTextStyles.h2),
        const SizedBox(height: 8),
        Text(
          'Your T69 Esports account password has been successfully updated. You can now log in.',
          style: AppTextStyles.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TacticalButton(
          label: 'Proceed to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

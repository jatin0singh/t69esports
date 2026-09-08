import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PasswordStrength {
  final double score; // 0.0 to 1.0
  final String label; // WEAK, FAIR, STRONG, ELITE
  final Color color;

  const PasswordStrength({
    required this.score,
    required this.label,
    required this.color,
  });
}

class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required.';
    }
    final email = value.trim();
    final regex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)+$",
    );
    if (!regex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Strict Real Gmail Validator for Account Creation & Password OTP Recovery
  static String? validateRealGmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Gmail address is required.';
    }
    final email = value.trim().toLowerCase();

    // Must have standard email format
    if (!email.contains('@')) {
      return 'Enter a valid Gmail address (e.g. name@gmail.com).';
    }

    final parts = email.split('@');
    if (parts.length != 2) {
      return 'Enter a valid Gmail address.';
    }

    final localPart = parts[0];
    final domain = parts[1];

    // Must be @gmail.com or @googlemail.com
    if (domain != 'gmail.com' && domain != 'googlemail.com') {
      return 'Only real @gmail.com addresses are supported for OTP verification.';
    }

    // Google username length: 6 to 30 characters
    if (localPart.length < 6) {
      return 'Gmail username must be at least 6 characters.';
    }
    if (localPart.length > 30) {
      return 'Gmail username cannot exceed 30 characters.';
    }

    // Allowed characters: letters, numbers, periods
    if (!RegExp(r'^[a-z0-9.]+$').hasMatch(localPart)) {
      return 'Gmail usernames can only contain letters, numbers, and periods.';
    }

    // Cannot start or end with a period
    if (localPart.startsWith('.') || localPart.endsWith('.')) {
      return 'Gmail address cannot start or end with a period.';
    }

    // Cannot have consecutive periods
    if (localPart.contains('..')) {
      return 'Gmail address cannot contain consecutive periods.';
    }

    // Block obvious placeholder/test dummy patterns
    final sanitized = localPart.replaceAll('.', '');
    const blockedDummies = [
      'test', 'testing', 'fake', 'dummy', 'sample', 'asdfgh', 'qwerty',
      '123456', '12345678', 'abcdef', 'admin', 'tempmail', 'nobody'
    ];
    for (final d in blockedDummies) {
      if (sanitized == d || sanitized.startsWith('${d}1') || sanitized == '${d}user') {
        return 'Please enter your genuine personal Gmail address.';
      }
    }

    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Must include at least 1 uppercase letter.';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Must include at least 1 number.';
    }
    return null;
  }

  static PasswordStrength calculatePasswordStrength(String password) {
    if (password.isEmpty) {
      return const PasswordStrength(
        score: 0.0,
        label: 'EMPTY',
        color: AppColors.textDisabled,
      );
    }

    int score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 2) {
      return const PasswordStrength(
        score: 0.25,
        label: 'WEAK',
        color: AppColors.error,
      );
    } else if (score <= 4) {
      return const PasswordStrength(
        score: 0.50,
        label: 'MODERATE',
        color: AppColors.warning,
      );
    } else if (score == 5) {
      return const PasswordStrength(
        score: 0.75,
        label: 'STRONG',
        color: AppColors.primary,
      );
    } else {
      return const PasswordStrength(
        score: 1.0,
        label: 'TACTICAL ELITE',
        color: AppColors.primary,
      );
    }
  }

  static String? validateConfirmPassword(String? value, String originalPassword) {
    if (value == null || value.isEmpty) {
      return 'Confirm password is required.';
    }
    if (value != originalPassword) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Gamer tag is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 3) {
      return 'Gamer tag must be at least 3 characters.';
    }
    if (trimmed.length > 20) {
      return 'Gamer tag cannot exceed 20 characters.';
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only alphanumeric letters and underscores allowed.';
    }
    if (RegExp(r'^[0-9_]').hasMatch(trimmed)) {
      return 'Gamer tag must start with a letter.';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required.';
    }
    return null;
  }

  static String? validateGameUid(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Game Character UID is required.';
    }
    final trimmed = value.trim();
    if (trimmed.length < 4) {
      return 'Enter a valid Game UID (min 4 characters).';
    }
    return null;
  }
}

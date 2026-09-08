import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../screens/admin_payments_screen.dart';
import '../../host/screens/host_lobbies_screen.dart';

class AdminAuthDialog {
  static void show(BuildContext context) {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'STAFF / ADMIN HUB',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter Security PIN to unlock Admin Operations or Host Partner Terminal.',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 16),
              TacticalTextField(
                controller: pinController,
                label: 'Security PIN',
                hint: '••••',
                isPassword: true,
                keyboardType: TextInputType.text,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            ),
            TacticalButton(
              label: 'Unlock Hub',
              isFullWidth: false,
              height: 40,
              onPressed: () {
                final pin = pinController.text.trim().toLowerCase();
                if (pin == '6969' || pin == '696969' || pin == 't69admin' || pin == 'admin') {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminPaymentsScreen()),
                  );
                } else if (pin == '7788' || pin == 'host' || pin == 'host69') {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HostLobbiesScreen()),
                  );
                } else {
                  setState(() => errorMessage = 'Invalid Security PIN');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

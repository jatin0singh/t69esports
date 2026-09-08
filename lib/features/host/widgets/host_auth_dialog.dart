import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../screens/host_lobbies_screen.dart';

class HostAuthDialog {
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
                child: const Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Text(
                'HOST TERMINAL',
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
                'Enter Match Host Security PIN to manage active lobbies, inspect player rosters, and broadcast custom room credentials.',
                style: AppTextStyles.bodySmall.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 16),
              TacticalTextField(
                controller: pinController,
                label: 'Host Security PIN',
                hint: '••••',
                isPassword: true,
                keyboardType: TextInputType.number,
                prefixIcon: Icons.vpn_key_rounded,
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
              label: 'Unlock Host Hub',
              isFullWidth: false,
              height: 40,
              onPressed: () {
                final pin = pinController.text.trim();
                if (pin == '7788' || pin == 'host69' || pin == '6969' || pin == '1234') {
                  Navigator.of(dialogCtx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HostLobbiesScreen()),
                  );
                } else {
                  setState(() => errorMessage = 'Incorrect Host PIN (Default: 7788)');
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

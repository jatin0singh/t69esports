import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum BadgeType {
  primary,
  success,
  danger,
  warning,
  info,
  neutral,
}

class StatusBadge extends StatelessWidget {
  final String label;
  final BadgeType type;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.type = BadgeType.primary,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (type) {
      case BadgeType.primary:
        bgColor = AppColors.primaryLight;
        textColor = AppColors.primaryDark;
        break;
      case BadgeType.success:
        bgColor = const Color(0xFFD1FAE5);
        textColor = const Color(0xFF047857);
        break;
      case BadgeType.danger:
        bgColor = const Color(0xFFFFE4E6);
        textColor = const Color(0xFFBE123C);
        break;
      case BadgeType.warning:
        bgColor = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0369A1);
        break;
      case BadgeType.info:
        bgColor = AppColors.primaryLight;
        textColor = AppColors.primaryDark;
        break;
      case BadgeType.neutral:
        bgColor = AppColors.surfaceSoft;
        textColor = AppColors.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: AppTextStyles.badge.copyWith(color: textColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

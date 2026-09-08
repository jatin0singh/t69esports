import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum TacticalButtonVariant {
  primary,
  secondary,
  danger,
  outline,
  ghost,
}

class TacticalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final TacticalButtonVariant variant;
  final IconData? icon;
  final double height;
  final double borderRadius;

  const TacticalButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.variant = TacticalButtonVariant.primary,
    this.icon,
    this.height = 52,
    this.borderRadius = 28,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    BorderSide borderSide = BorderSide.none;
    Gradient? gradient;

    switch (variant) {
      case TacticalButtonVariant.primary:
        bgColor = AppColors.primary;
        textColor = Colors.white;
        gradient = const LinearGradient(
          colors: [Color(0xFF00B4D8), Color(0xFF0096C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        break;
      case TacticalButtonVariant.secondary:
        bgColor = AppColors.primaryLight;
        textColor = AppColors.primaryDark;
        break;
      case TacticalButtonVariant.danger:
        bgColor = AppColors.secondary;
        textColor = Colors.white;
        break;
      case TacticalButtonVariant.outline:
        bgColor = Colors.transparent;
        textColor = AppColors.primary;
        borderSide = const BorderSide(color: AppColors.primary, width: 1.8);
        break;
      case TacticalButtonVariant.ghost:
        bgColor = Colors.transparent;
        textColor = AppColors.textSecondary;
        break;
    }

    final effectiveOnPressed = isLoading ? null : onPressed;

    Widget content = isLoading
        ? SizedBox(
            height: 22,
            width: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: textColor),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          );

    Widget button = Container(
      height: height,
      decoration: BoxDecoration(
        color: effectiveOnPressed != null ? bgColor : bgColor.withValues(alpha: 0.4),
        gradient: effectiveOnPressed != null && variant == TacticalButtonVariant.primary ? gradient : null,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderSide != BorderSide.none ? Border.fromBorderSide(borderSide) : null,
        boxShadow: effectiveOnPressed != null && variant == TacticalButtonVariant.primary
            ? [
                BoxShadow(
                  color: const Color(0xFF0096C7).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: effectiveOnPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          splashColor: Colors.white.withValues(alpha: 0.2),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: content),
          ),
        ),
      ),
    );

    if (isFullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

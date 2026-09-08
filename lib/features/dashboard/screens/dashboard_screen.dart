import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_card.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authControllerProvider.notifier).refreshProfile());
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('TERMINATE SESSION', style: AppTextStyles.h4),
        content: Text(
          'Are you sure you want to log out from the T69 network?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('CANCEL', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
          ),
          TacticalButton(
            label: 'DISCONNECT',
            variant: TacticalButtonVariant.danger,
            isFullWidth: false,
            height: 38,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      UiHelpers.showSuccessBanner(context, 'Session terminated securely.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryMuted,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Text(
                'T69',
                style: AppTextStyles.badge.copyWith(color: AppColors.primary, fontSize: 13),
              ),
            ),
            const SizedBox(width: 12),
            Text('COMMAND DECK', style: AppTextStyles.h4),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Sync Profile',
            onPressed: () => ref.read(authControllerProvider.notifier).refreshProfile(),
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, size: 20, color: AppColors.secondary),
            tooltip: 'Sign Out',
            onPressed: _handleSignOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: profileState.when(
        loading: () => const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 36),
              const SizedBox(height: 12),
              Text('SYNC ERROR', style: AppTextStyles.h4),
              const SizedBox(height: 6),
              Text(
                err.toString().replaceAll('Exception: ', ''),
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TacticalButton(
                label: 'RETRY CONNECTION',
                isFullWidth: false,
                onPressed: () => ref.read(authControllerProvider.notifier).refreshProfile(),
              ),
            ],
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return Center(
              child: TacticalButton(
                label: 'RETURN TO LOGIN',
                isFullWidth: false,
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
              ),
            );
          }

          final createdDate = profile.createdAt != null
              ? DateFormat('dd MMM yyyy').format(profile.createdAt!)
              : 'Active';

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surfaceElevated,
            onRefresh: () => ref.read(authControllerProvider.notifier).refreshProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Ticker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'SYSTEM ONLINE // AP-NORTHEAST-1',
                                style: AppTextStyles.monoCode.copyWith(
                                  color: AppColors.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          StatusBadge(
                            label: profile.role.toUpperCase(),
                            type: profile.role == 'admin' ? BadgeType.danger : BadgeType.primary,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Gamer ID Tactical Card
                      TacticalCard(
                        accentColor: AppColors.primary,
                        title: 'COMPETITOR CREDENTIALS',
                        trailing: StatusBadge(
                          label: profile.isVerified ? 'VERIFIED' : 'UNVERIFIED',
                          type: profile.isVerified ? BadgeType.success : BadgeType.warning,
                          icon: profile.isVerified ? Icons.verified_rounded : Icons.pending_outlined,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Avatar
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceHighlight,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
                                    ? Image.network(
                                        profile.avatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                          Icons.sports_esports_outlined,
                                          color: AppColors.primary,
                                          size: 32,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sports_esports_outlined,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Gamer Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        profile.username.toUpperCase(),
                                        style: AppTextStyles.h3,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  if (profile.gameIgn != null)
                                    Text(
                                      'IGN: ${profile.gameIgn}',
                                      style: AppTextStyles.monoCode.copyWith(
                                        color: AppColors.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (profile.gameUid != null)
                                    Text(
                                      'UID: ${profile.gameUid}',
                                      style: AppTextStyles.monoCode.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      StatusBadge(
                                        label: profile.primaryGame,
                                        type: BadgeType.info,
                                      ),
                                      StatusBadge(
                                        label: 'JOINED $createdDate',
                                        type: BadgeType.neutral,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Wallet & Vault Card
                      TacticalCard(
                        title: 'ARENA VAULT & WALLET',
                        accentColor: AppColors.accentAmber,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AVAILABLE BALANCE',
                                  style: AppTextStyles.inputLabel,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '₹${profile.walletBalance.toStringAsFixed(2)}',
                                  style: AppTextStyles.h2.copyWith(
                                    color: AppColors.accentAmber,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            TacticalButton(
                              label: 'ADD FUNDS',
                              variant: TacticalButtonVariant.outline,
                              isFullWidth: false,
                              height: 38,
                              icon: Icons.account_balance_wallet_outlined,
                              onPressed: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'Wallet deposit module will connect to Razorpay/Stripe.',
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Command Modules
                      Text('AVAILABLE ARENAS & OPERATIONS', style: AppTextStyles.tacticalHeader),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TacticalCard(
                              title: 'TOURNAMENTS',
                              onTap: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'Tournaments module loaded. Ready for bracket setup.',
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Battle Royale & 5v5 Brackets',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'REGISTRATION OPEN',
                                    style: AppTextStyles.badge.copyWith(color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TacticalCard(
                              title: 'DAILY SCRIMS',
                              onTap: () {
                                UiHelpers.showSuccessBanner(
                                  context,
                                  'Daily Scrims slot reservation system.',
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Slot Booking & Room Distribution',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'NEXT SLOT: 20:00 IST',
                                    style: AppTextStyles.badge.copyWith(color: AppColors.accentAmber),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

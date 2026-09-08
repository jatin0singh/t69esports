import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../freefire/screens/freefire_hub_screen.dart';
import '../../games/screens/game_hub_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../history/screens/match_history_screen.dart';
import '../../admin/widgets/admin_auth_dialog.dart';
import '../../wallet/widgets/wallet_modal.dart';
import '../widgets/sponsors_strip.dart';

class HomeHubScreen extends ConsumerStatefulWidget {
  const HomeHubScreen({super.key});

  @override
  ConsumerState<HomeHubScreen> createState() => _HomeHubScreenState();
}

class _HomeHubScreenState extends ConsumerState<HomeHubScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(authControllerProvider.notifier).refreshProfile();
      ref.invalidate(walletTransactionsProvider);
      ref.invalidate(userRegisteredTournamentIdsProvider);
      ref.invalidate(matchHistoryProvider);
    });
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign Out', style: AppTextStyles.h3),
        content: Text(
          'Are you sure you want to log out from T69 Esports?',
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
          ),
          TacticalButton(
            label: 'Logout',
            variant: TacticalButtonVariant.danger,
            isFullWidth: false,
            height: 40,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (shouldSignOut == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (!mounted) return;
      UiHelpers.showSuccessBanner(context, 'Signed out successfully.');
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(authControllerProvider);
    final sponsorsState = ref.watch(sponsorsProvider);
    final transactionsState = ref.watch(walletTransactionsProvider);

    final profile = profileState.value;
    final walletBalance = profile?.walletBalance ?? 0.0;
    final username = profile?.username ?? 'Competitor';
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      body: Column(
        children: [
          // 1. TOP SKY BLUE HEADER AREA (Matching Reference Mockup)
          Container(
            color: AppColors.headerBackground,
            padding: EdgeInsets.only(
              top: topPadding + 8,
              left: 20,
              right: 20,
              bottom: 24,
            ),
            child: Column(
              children: [
                // Header Bar (Menu, Notification Bell, User Avatar)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Menu Drawer Icon
                    InkWell(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (ctx) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(
                                      children: [
                                        Text('Signed in as ', style: AppTextStyles.bodyMedium),
                                        Text(username, style: AppTextStyles.h4.copyWith(color: AppColors.primaryDark)),
                                      ],
                                    ),
                                  ),
                                  const Divider(color: AppColors.border),
                                  ListTile(
                                    leading: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                                    title: Text('Player Profile', style: AppTextStyles.h4),
                                    subtitle: Text('Gamer tags, UID & statistics', style: AppTextStyles.bodySmall),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const ProfileScreen()),
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accentOrange),
                                    title: Text('Arena Vault', style: AppTextStyles.h4),
                                    subtitle: Text('Deposit & withdraw tournament funds', style: AppTextStyles.bodySmall),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      WalletModal.show(context);
                                    },
                                  ),
                                  const Divider(color: AppColors.border),
                                  ListTile(
                                    leading: const Icon(Icons.power_settings_new_rounded, color: AppColors.secondary),
                                    title: Text('Sign Out', style: AppTextStyles.h4.copyWith(color: AppColors.secondary)),
                                    subtitle: Text('Disconnect your current session', style: AppTextStyles.bodySmall),
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      _handleSignOut();
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  // Discreet Secret Admin Access (5 Taps)
                                  InkWell(
                                    onTap: () {
                                      Navigator.of(ctx).pop();
                                      AdminAuthDialog.show(context);
                                    },
                                    child: Center(
                                      child: Text(
                                        'T69 Competitive Network • Build v1.0.4',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textTertiary,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
                    ),

                    const SizedBox(width: 8),

                    // Secret Admin Trigger: Long-press T69 Esports Logo & Title
                    InkWell(
                      onLongPress: () => AdminAuthDialog.show(context),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/t69_logo.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'T69 ESPORTS',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Right Actions (Notifications & User Avatar)
                    Row(
                      children: [
                        // Notification Bell with Badge Dot
                        Stack(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 26),
                              onPressed: () {
                                UiHelpers.showSuccessBanner(context, 'All tournament systems operational.');
                              },
                            ),
                            Positioned(
                              top: 10,
                              right: 12,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentOrange,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(width: 4),

                        // Circular User Avatar with White Border & Profile Action
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ProfileScreen()),
                            );
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: profile?.avatarUrl != null && profile!.avatarUrl!.isNotEmpty
                                  ? Image.network(
                                      profile.avatarUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.person,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    )
                                  : const Icon(Icons.person, color: Colors.white, size: 24),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Top 4 Quick Action Rounded Square Buttons (Sent, Request, Bank, Add Money)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTopQuickAction(
                      icon: Icons.send_rounded,
                      label: 'Free Fire',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                        );
                      },
                    ),
                    _buildTopQuickAction(
                      icon: Icons.request_quote_outlined,
                      label: 'Scrims',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                        );
                      },
                    ),
                    _buildTopQuickAction(
                      icon: Icons.account_balance_outlined,
                      label: 'Standings',
                      onTap: () {
                        UiHelpers.showSuccessBanner(context, 'Leaderboards updated after match results.');
                      },
                    ),
                    _buildTopQuickAction(
                      icon: Icons.credit_card_rounded,
                      label: 'Add Money',
                      hasPlusBadge: true,
                      onTap: () => WalletModal.show(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. CURVED WHITE BODY CONTAINER (Matching Reference Mockup)
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await ref.read(authControllerProvider.notifier).refreshProfile();
                  ref.invalidate(bannersProvider);
                  ref.invalidate(sponsorsProvider);
                  ref.invalidate(walletTransactionsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  children: [
                    // Section Title: "Tournaments Registrations"
                    Text(
                      'Tournaments Registrations',
                      style: AppTextStyles.sectionTitle,
                    ),

                    const SizedBox(height: 16),

                    // Grid of 8 Soft Blue Rounded Square Tiles (Matching reference layout)
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.85,
                      children: [
                        _buildGridServiceTile(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Free Fire',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.shield_outlined,
                          label: 'BGMI',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => GameHubScreen.bgmi()),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.track_changes_rounded,
                          label: 'Valorant',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => GameHubScreen.valorant()),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.timer_outlined,
                          label: 'Daily Scrims',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.military_tech_outlined,
                          label: 'Clash Squad',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FreeFireHubScreen(initialMode: 'CLASH SQUAD')),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.emoji_events_outlined,
                          label: 'BR Matches',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                            );
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.confirmation_number_outlined,
                          label: 'Match Pass',
                          onTap: () {
                            UiHelpers.showSuccessBanner(context, 'Season 4 Competitor Pass active.');
                          },
                        ),
                        _buildGridServiceTile(
                          icon: Icons.help_outline_rounded,
                          label: 'Rules & Help',
                          onTap: () {
                            UiHelpers.showSuccessBanner(context, 'Anti-Cheat Fair Play guidelines.');
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Section Title: "Recent Transaction"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Transaction',
                          style: AppTextStyles.sectionTitle,
                        ),
                        InkWell(
                          onTap: () => WalletModal.show(context),
                          child: Text(
                            'Vault: ₹${walletBalance.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Recent Transaction Feed (Styled like reference mockup)
                    transactionsState.when(
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (txs) {
                        if (txs.isEmpty) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textTertiary),
                                const SizedBox(height: 8),
                                Text(
                                  'No transactions yet',
                                  style: AppTextStyles.h4.copyWith(color: AppColors.textSecondary, fontSize: 14),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your match entries and prize credits will appear here.',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary, fontSize: 11),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        }

                        return Column(
                          children: txs.take(4).map((tx) {
                            final isCredit = tx.type == 'deposit' || tx.type == 'prize_credit';
                            final dateStr = DateFormat('dd/MMMM/yyyy').format(tx.createdAt);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildTransactionRow(
                                icon: isCredit ? Icons.account_balance_wallet_outlined : Icons.sports_esports_outlined,
                                iconBgColor: isCredit ? const Color(0xFFFEF3C7) : const Color(0xFFE0F2FE),
                                iconColor: isCredit ? const Color(0xFFF59E0B) : const Color(0xFF0288D1),
                                title: tx.description,
                                refId: 'TX${tx.id.substring(0, 8).toUpperCase()}',
                                date: dateStr,
                                amount: 'Rs.${tx.amount.toStringAsFixed(0)}',
                                onViewDetails: () => WalletModal.show(context),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Official Sponsors Strip
                    sponsorsState.when(
                      loading: () => const SizedBox(height: 60),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (sponsors) => SponsorsStrip(sponsors: sponsors),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 3. BOTTOM NAVIGATION BAR (Matching Reference Mockup)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home', index: 0),
                _buildNavItem(
                  icon: Icons.history_rounded,
                  activeIcon: Icons.history_rounded,
                  label: 'History',
                  index: 1,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
                    );
                  },
                ),
                
                // Center Floating '+' Action Button (Sky Blue)
                InkWell(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                    );
                  },
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),

                _buildNavItem(icon: Icons.credit_card_outlined, activeIcon: Icons.credit_card_rounded, label: 'Cards', index: 2, onTap: () => WalletModal.show(context)),
                _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profile',
                  index: 3,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Quick Action Button on Top Blue Header
  Widget _buildTopQuickAction({
    required IconData icon,
    required String label,
    bool hasPlusBadge = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: AppColors.primaryDark, size: 26),
              ),
              if (hasPlusBadge)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // Soft Blue Rounded Square Grid Tile
  Widget _buildGridServiceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.surfaceBlueTile,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: AppTextStyles.gridLabel,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // Recent Transaction Row Item (Matching reference)
  Widget _buildTransactionRow({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String refId,
    required String date,
    required String amount,
    required VoidCallback onViewDetails,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Soft Colored Circular Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),

          const SizedBox(width: 14),

          // Title & Ref ID / Date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$refId • Date: $date',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          // Amount & View Details Link
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: onViewDetails,
                child: Text(
                  'View Details >',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Bottom Navigation Bar Item
  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    VoidCallback? onTap,
  }) {
    final isSelected = _currentNavIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _currentNavIndex = index);
        onTap?.call();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

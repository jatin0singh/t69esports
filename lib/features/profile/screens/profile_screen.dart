import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_card.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/screens/login_screen.dart';
import '../../admin/widgets/admin_auth_dialog.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../wallet/widgets/wallet_modal.dart';
import '../../../core/services/app_update_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _matchAlertsEnabled = true;
  bool _hapticsEnabled = true;
  String _appVersion = '1.0.0';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final pkg = await AppUpdateService.getPackageInfo();
    if (mounted) {
      setState(() {
        _appVersion = '${pkg.version}+${pkg.buildNumber}';
      });
    }
  }

  void _showEditProfileDialog() {
    final profile = ref.read(authControllerProvider).value;
    final ignController = TextEditingController(text: profile?.gameIgn ?? '');
    final uidController = TextEditingController(text: profile?.gameUid ?? '');
    final discordController = TextEditingController(text: profile?.discordTag ?? '');
    String selectedGame = profile?.primaryGame ?? 'FREE FIRE';

    final games = ['FREE FIRE', 'BGMI', 'VALORANT', 'CS2', 'CODM'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Text('Edit Gamer Identity', style: AppTextStyles.h3),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Primary Game: ', style: AppTextStyles.inputLabel),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedGame,
                      dropdownColor: Colors.white,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                      items: games.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedGame = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'In-Game Name (IGN)',
                  controller: ignController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Game Character UID',
                  controller: uidController,
                ),
                const SizedBox(height: 12),
                TacticalTextField(
                  label: 'Discord Tag',
                  hint: 'player#0000',
                  controller: discordController,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary)),
            ),
            TacticalButton(
              label: 'Save Changes',
              isFullWidth: false,
              height: 40,
              onPressed: () async {
                try {
                  final authCtrl = ref.read(authControllerProvider.notifier);
                  await authCtrl.completeOnboarding(
                    gameIgn: ignController.text.trim(),
                    gameUid: uidController.text.trim(),
                    primaryGame: selectedGame,
                    discordTag: discordController.text.trim().isNotEmpty
                        ? discordController.text.trim()
                        : null,
                    avatarUrl: profile?.avatarUrl ?? '',
                  );
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                    UiHelpers.showSuccessBanner(context, 'Gamer profile updated successfully.');
                  }
                } catch (e) {
                  if (context.mounted) {
                    UiHelpers.showErrorBanner(context, 'Error updating profile: ${e.toString()}');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSignOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
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
    final profile = profileState.value;

    final username = profile?.username.toUpperCase() ?? 'COMPETITOR';
    final userIgn = profile?.gameIgn ?? 'Unlinked';
    final userUid = profile?.gameUid ?? 'N/A';
    final userGame = profile?.primaryGame ?? 'FREE FIRE';
    final userDiscord = profile?.discordTag ?? 'Not linked';
    final walletBalance = profile?.walletBalance ?? 0.0;
    final depositBalance = profile?.depositBalance ?? 0.0;
    final winningBalance = profile?.winningBalance ?? 0.0;
    final userStatsState = ref.watch(userStatsProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.headerBackground,
      body: Column(
        children: [
          // 1. TOP SKY BLUE HEADER WITH GAMER PROFILE CARD
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
                // Top App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                          tooltip: 'Go Back',
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.of(context).pop();
                            }
                          },
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Player Profile',
                          style: AppTextStyles.h3.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                      tooltip: 'Edit Profile',
                      onPressed: _showEditProfileDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Avatar & Gamer Tag
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
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
                                  size: 48,
                                ),
                              )
                            : const Icon(Icons.person, color: Colors.white, size: 48),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.accentOrange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Text(
                  username,
                  style: AppTextStyles.h2.copyWith(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'IGN: $userIgn • UID: $userUid',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 10),

                // Tier Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.stars_rounded, color: AppColors.accentAmber, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'TIER-1 VERIFIED COMPETITOR',
                        style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 2. CURVED WHITE BODY CONTAINER
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
                  ref.invalidate(userStatsProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  children: [
                    // Quick Stats Bar (4 Rounded Soft-Blue Tiles with Real Database Counts)
                    userStatsState.when(
                      loading: () => Row(
                        children: [
                          _buildStatBox(label: 'MATCHES', value: '...', icon: Icons.sports_esports_outlined),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'WINS', value: '...', icon: Icons.emoji_events_outlined, accentColor: AppColors.accentOrange),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'WIN RATE', value: '...', icon: Icons.speed_rounded),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'EARNINGS', value: '...', icon: Icons.account_balance_wallet_outlined, accentColor: AppColors.success),
                        ],
                      ),
                      error: (_, _) => Row(
                        children: [
                          _buildStatBox(label: 'MATCHES', value: '0', icon: Icons.sports_esports_outlined),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'WINS', value: '0', icon: Icons.emoji_events_outlined, accentColor: AppColors.accentOrange),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'WIN RATE', value: '0%', icon: Icons.speed_rounded),
                          const SizedBox(width: 10),
                          _buildStatBox(label: 'EARNINGS', value: '₹0', icon: Icons.account_balance_wallet_outlined, accentColor: AppColors.success),
                        ],
                      ),
                      data: (stats) {
                        final matches = stats['matches']?.toString() ?? '0';
                        final wins = stats['wins']?.toString() ?? '0';
                        final winRate = '${stats['winRate'] ?? 0}%';
                        final earnings = '₹${(stats['earnings'] as num?)?.toStringAsFixed(0) ?? "0"}';

                        return Row(
                          children: [
                            _buildStatBox(label: 'MATCHES', value: matches, icon: Icons.sports_esports_outlined),
                            const SizedBox(width: 10),
                            _buildStatBox(label: 'WINS', value: wins, icon: Icons.emoji_events_outlined, accentColor: AppColors.accentOrange),
                            const SizedBox(width: 10),
                            _buildStatBox(label: 'WIN RATE', value: winRate, icon: Icons.speed_rounded),
                            const SizedBox(width: 10),
                            _buildStatBox(label: 'EARNINGS', value: earnings, icon: Icons.account_balance_wallet_outlined, accentColor: AppColors.success),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Gamer Credentials Card
                    TacticalCard(
                      title: 'GAMER CREDENTIALS',
                      trailing: InkWell(
                        onTap: _showEditProfileDialog,
                        child: Text(
                          'Edit',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildCredentialRow('Primary Title', userGame, Icons.gamepad_outlined),
                          const Divider(height: 16, color: AppColors.border),
                          _buildCredentialRow('In-Game Name', userIgn, Icons.badge_outlined),
                          const Divider(height: 16, color: AppColors.border),
                          _buildCredentialRow('Player UID', userUid, Icons.numbers_outlined),
                          const Divider(height: 16, color: AppColors.border),
                          _buildCredentialRow('Discord Tag', userDiscord, Icons.chat_outlined),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Arena Vault & Payouts Card
                    TacticalCard(
                      title: 'VAULT & WALLET OVERVIEW',
                      accentColor: AppColors.accentAmber,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Total Vault Balance', style: AppTextStyles.bodySmall),
                                  const SizedBox(height: 2),
                                  Text(
                                    '₹${walletBalance.toStringAsFixed(2)}',
                                    style: AppTextStyles.monoCode.copyWith(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  TacticalButton(
                                    label: '+ Deposit',
                                    isFullWidth: false,
                                    height: 36,
                                    onPressed: () => WalletModal.show(context),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBlueTile,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('DEPOSIT CASH', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.primaryDark)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${depositBalance.toStringAsFixed(0)}',
                                        style: AppTextStyles.monoCode.copyWith(fontWeight: FontWeight.w900, fontSize: 14),
                                      ),
                                      Text('For match entry', style: AppTextStyles.bodySmall.copyWith(fontSize: 9)),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF7ED),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.accentOrange.withValues(alpha: 0.4)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('WINNING CASH', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.accentOrange)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${winningBalance.toStringAsFixed(0)}',
                                        style: AppTextStyles.monoCode.copyWith(fontWeight: FontWeight.w900, fontSize: 14, color: AppColors.accentOrange),
                                      ),
                                      Text('✅ Withdrawable', style: AppTextStyles.bodySmall.copyWith(fontSize: 9, color: AppColors.accentOrange)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.verified_user_outlined, color: AppColors.primaryDark, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Fair Play Rule: Only winning balance is eligible for cash withdrawal.',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // App & Match Settings
                    TacticalCard(
                      title: 'PREFERENCES & ALERTS',
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Match Room Notifications', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            subtitle: Text('Receive Room ID & Password alerts 15m prior', style: AppTextStyles.bodySmall),
                            value: _matchAlertsEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _matchAlertsEnabled = val),
                          ),
                          const Divider(height: 8, color: AppColors.border),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('Tactile Haptic Feedback', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                            subtitle: Text('Vibrate on match actions and confirmations', style: AppTextStyles.bodySmall),
                            value: _hapticsEnabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: (val) => setState(() => _hapticsEnabled = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // App Updates & Version Card
                    TacticalCard(
                      title: 'APP & UPDATES',
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : null,
                      child: Column(
                        children: [
                          _buildCredentialRow('Installed Version', 'v$_appVersion', Icons.info_outline_rounded),
                          const Divider(height: 16, color: AppColors.border),
                          _buildSettingRow(
                            icon: Icons.system_update_rounded,
                            title: 'Check for Updates',
                            trailingText: 'Latest Build',
                            onTap: () async {
                              setState(() => _isCheckingUpdate = true);
                              try {
                                await AppUpdateService.checkAndPromptUpdate(context, isManual: true);
                              } finally {
                                if (mounted) setState(() => _isCheckingUpdate = false);
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Fair Play & Security Card
                    TacticalCard(
                      title: 'SECURITY & FAIR PLAY',
                      child: Column(
                        children: [
                          _buildSettingRow(
                            icon: Icons.shield_outlined,
                            title: 'Anti-Cheat & Fair Play Status',
                            trailingText: '100% Clean',
                            onTap: () {
                              UiHelpers.showSuccessBanner(context, 'Fair play record is clean. No infractions.');
                            },
                          ),
                          const Divider(height: 16, color: AppColors.border),
                          _buildSettingRow(
                            icon: Icons.description_outlined,
                            title: 'Terms of Service & Rules',
                            onTap: () {
                              UiHelpers.showSuccessBanner(context, 'T69 Tournament Rulebook v4.2 active.');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Logout Button
                    TacticalButton(
                      label: 'Sign Out of T69',
                      variant: TacticalButtonVariant.outline,
                      icon: Icons.power_settings_new_rounded,
                      onPressed: _handleSignOut,
                    ),

                    const SizedBox(height: 20),

                    // Discreet Staff Terminal Trigger (Bottom Footer)
                    InkWell(
                      onTap: () => AdminAuthDialog.show(context),
                      child: Center(
                        child: Text(
                          'T69 Esports League • Encrypted Terminal • v$_appVersion',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox({
    required String label,
    required String value,
    required IconData icon,
    Color? accentColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceBlueTile,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: accentColor ?? AppColors.primaryDark, size: 20),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.monoCode.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: accentColor ?? AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.badge.copyWith(
                fontSize: 8.5,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 10),
        Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
        const Spacer(),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (trailingText != null)
            Text(
              trailingText,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}

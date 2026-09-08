import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/tactical_card.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/utils/lobby_schedule_helper.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../wallet/widgets/wallet_modal.dart';
import '../../host/widgets/host_auth_dialog.dart';
import '../../history/screens/match_history_screen.dart';
import 'lobby_room_screen.dart';
import '../../../core/widgets/johnny_error_widget.dart';
import '../../../core/services/connectivity_service.dart';

class FreeFireHubScreen extends ConsumerStatefulWidget {
  final String? initialMode;
  const FreeFireHubScreen({super.key, this.initialMode});

  @override
  ConsumerState<FreeFireHubScreen> createState() => _FreeFireHubScreenState();
}

class _FreeFireHubScreenState extends ConsumerState<FreeFireHubScreen> {
  // Main Modes: 'SOLO', 'DUO', 'SQUAD', 'CLASH SQUAD'
  String _selectedMainMode = 'SOLO';

  // Solo Sub-Tier: 15 for ₹15 lobby, 20 for ₹20 lobby
  int _selectedSoloTier = 15;

  // Clash Squad Sub-Tier: '1v1', '2v2', '4v4'
  String _selectedCsTier = '1v1';

  @override
  void initState() {
    super.initState();
    if (widget.initialMode != null) {
      _selectedMainMode = widget.initialMode!;
    }
    Future.microtask(() {
      ref.read(connectivityStateProvider.notifier).checkNow();
    });
  }

  Future<void> _showLobbyRegistrationModal(BuildContext context, TournamentModel tournament) async {
    if (tournament.status == 'live' || tournament.isIdpLocked || (tournament.roomId != null && tournament.roomId!.isNotEmpty)) {
      UiHelpers.showErrorBanner(context, 'This lobby is already LIVE in Free Fire. Registrations are closed.');
      return;
    }
    if (tournament.status == 'completed') {
      UiHelpers.showErrorBanner(context, 'This tournament has already ended.');
      return;
    }

    final profile = ref.read(authControllerProvider).value;
    if (tournament.isUserKickedOrBanned(profile?.id, profile?.gameUid)) {
      final kickInfo = tournament.getKickDetailsForUser(profile?.id, profile?.gameUid);
      final reason = kickInfo?['reason'] ?? 'Violation of lobby rules';
      final role = kickInfo?['role'] ?? 'Admin';
      UiHelpers.showErrorBanner(context, 'Access Denied: You were removed from this lobby by $role ($reason). Re-joining is blocked.');
      return;
    }

    final walletBalance = profile?.walletBalance ?? 0.0;
    final canAfford = walletBalance >= tournament.entryFee;
    final ignController = TextEditingController(text: profile?.gameIgn ?? '');
    final uidController = TextEditingController(text: profile?.gameUid ?? '');
    final teamNameController = TextEditingController();
    final p2IgnController = TextEditingController();
    final p2UidController = TextEditingController();
    final p3IgnController = TextEditingController();
    final p4IgnController = TextEditingController();

    // Fetch real taken slots from Supabase database (Zero fake data)
    final repo = ref.read(tournamentRepoProvider);
    final registrations = await repo.fetchTournamentRegistrations(tournament.id);
    final takenSlots = registrations.map((r) => (r['slot_number'] as num?)?.toInt()).whereType<int>().toSet();

    final is1v1 = tournament.format.toLowerCase().contains('1v1');
    final is2v2 = tournament.format.toLowerCase().contains('2v2');
    final is4v4 = tournament.format.toLowerCase().contains('4v4');
    final isCs = is1v1 || is2v2 || is4v4 || tournament.format.toLowerCase().contains('cs') || tournament.format.toLowerCase().contains('clash');
    final isSolo = (tournament.format.toLowerCase().contains('solo') || is1v1) && !is2v2 && !is4v4;
    final isDuo = (tournament.format.toLowerCase().contains('duo') || is2v2) && !is4v4;
    final isSquad = (tournament.format.toLowerCase().contains('squad') || is4v4) && !is2v2;

    int selectedSlot = 1;
    if (isCs) {
      if (!takenSlots.contains(1)) {
        selectedSlot = 1;
      } else if (!takenSlots.contains(2)) {
        selectedSlot = 2;
      } else {
        selectedSlot = 1;
      }
    } else {
      for (int i = 1; i <= tournament.maxSlots; i++) {
        if (!takenSlots.contains(i)) {
          selectedSlot = i;
          break;
        }
      }
    }

    bool isSubmitting = false;

    final bookingTitle = is1v1
        ? '1v1 Duel Booking'
        : is2v2
            ? '2v2 Clash Booking'
            : is4v4
                ? '4v4 Clash Squad Booking'
                : isSolo
                    ? 'Solo Lobby Booking'
                    : isDuo
                        ? 'Duo Team Booking'
                        : 'Squad Lobby Booking';

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.borderInput, borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // Title Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.sports_esports_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          bookingTitle,
                          style: AppTextStyles.h3,
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 22, color: AppColors.textTertiary),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header Summary Gradient Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00A3E0), Color(0xFF0288D1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  tournament.format.toUpperCase(),
                                  style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10),
                                ),
                              ),
                              Text(
                                '${registrations.length}/${tournament.maxSlots} SLOTS BOOKED',
                                style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            tournament.title,
                            style: AppTextStyles.h3.copyWith(color: Colors.white, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '⏰ Slot: ${LobbyScheduleHelper.formatSlotWithDay(LobbyScheduleHelper.getEffectiveStartTime(tournament))} • Map: ${tournament.mapName}',
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          if (LobbyScheduleHelper.isLateEntryAllowed(tournament)) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '⚡ LATE ENTRY ALLOWED • Host is preparing Room IDP',
                                style: AppTextStyles.badge.copyWith(color: const Color(0xFFB45309), fontSize: 9.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Prize & Financial Breakdown
                    if (is1v1) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('1v1 DUEL PRIZE', style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark)),
                                Text('Entry: ₹50 / Player', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: _buildPrizePodium('👑 WINNER TAKES ALL', '₹85', AppColors.accentOrange),
                            ),
                          ],
                        ),
                      ),
                    ] else if (is2v2) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('2v2 CLASH PRIZE', style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark)),
                                Text('Entry: ₹50 / Player', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: _buildPrizePodium('🏆 WINNING DUO TEAM', '₹85', AppColors.accentOrange),
                            ),
                          ],
                        ),
                      ),
                    ] else if (is4v4) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('4v4 SQUAD CLASH PRIZE', style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark)),
                                Text('Entry: ₹50 / Player', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: _buildPrizePodium('🏆 WINNING SQUAD TEAM', '₹85', AppColors.accentOrange),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isSolo) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TacticalCard(
                              title: 'ENTRY FEE',
                              accentColor: AppColors.primary,
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '₹${tournament.entryFee.toStringAsFixed(0)}',
                                style: AppTextStyles.monoCode.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TacticalCard(
                              title: 'PER KILL',
                              accentColor: AppColors.accentOrange,
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '₹${tournament.perKill.toStringAsFixed(0)}',
                                style: AppTextStyles.monoCode.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.accentOrange,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TacticalCard(
                              title: 'PRIZE POOL',
                              accentColor: AppColors.success,
                              padding: const EdgeInsets.all(12),
                              child: Text(
                                '₹${tournament.prizePool.toStringAsFixed(0)}',
                                style: AppTextStyles.monoCode.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else if (isDuo) ...[
                      // Duo Position Rewards: Top 1: ₹170, Top 2: ₹130, Top 3: ₹100
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('DUO POSITION PRIZES', style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark)),
                                Text('Entry: ₹20 / Duo', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPrizePodium('🥇 1ST PLACE', '₹170', AppColors.accentOrange),
                                _buildPrizePodium('🥈 2ND PLACE', '₹130', AppColors.primaryDark),
                                _buildPrizePodium('🥉 3RD PLACE', '₹100', AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else if (isSquad) ...[
                      // Squad Position Rewards: Top 1: ₹110, Top 2: ₹90, Top 3: ₹60
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('SQUAD POSITION PRIZES', style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark)),
                                Text('Entry: ₹25 / Squad', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildPrizePodium('🥇 1ST PLACE', '₹110', AppColors.accentOrange),
                                _buildPrizePodium('🥈 2ND PLACE', '₹90', AppColors.primaryDark),
                                _buildPrizePodium('🥉 3RD PLACE', '₹60', AppColors.success),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Wallet Balance Status
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: canAfford ? AppColors.surfaceBlueTile : const Color(0xFFFFE4E6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                canAfford ? Icons.account_balance_wallet_outlined : Icons.warning_amber_rounded,
                                color: canAfford ? AppColors.primaryDark : AppColors.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Vault Balance: ₹${walletBalance.toStringAsFixed(0)}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: canAfford ? AppColors.primaryDark : AppColors.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (!canAfford)
                            InkWell(
                              onTap: () {
                                Navigator.of(ctx).pop();
                                WalletModal.show(context);
                              },
                              child: Text(
                                '+ Add Funds',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.primaryDark,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Gamer Credential & Team Lineup Form
                    Text(
                      isSolo
                          ? 'Solo Player Verification'
                          : isDuo
                              ? 'Duo Team & Lineup Verification'
                              : 'Squad Team & 4-Player Lineup Verification',
                      style: AppTextStyles.sectionTitle,
                    ),
                    const SizedBox(height: 10),

                    if (isDuo || isSquad) ...[
                      TacticalTextField(
                        label: isDuo ? 'Duo Team Name' : 'Squad Team / Clan Name',
                        controller: teamNameController,
                        hint: isDuo ? 'e.g. Inferno Duo' : 'e.g. GodLike Esports',
                        prefixIcon: Icons.shield_outlined,
                      ),
                      const SizedBox(height: 12),
                    ],

                    TacticalTextField(
                      label: isSolo ? 'Your Free Fire IGN' : 'Player 1 (Captain / Leader) IGN',
                      controller: ignController,
                      hint: 'e.g. kuchupuchu',
                      prefixIcon: Icons.person_outline_rounded,
                    ),

                    const SizedBox(height: 12),

                    TacticalTextField(
                      label: isSolo ? 'Your Character UID' : 'Player 1 (Captain) UID',
                      controller: uidController,
                      hint: 'e.g. 2164068362',
                      prefixIcon: Icons.tag_rounded,
                      keyboardType: TextInputType.number,
                    ),

                    if (isDuo) ...[
                      const SizedBox(height: 12),
                      TacticalTextField(
                        label: 'Player 2 (Partner) IGN',
                        controller: p2IgnController,
                        hint: 'e.g. teammate_pro',
                        prefixIcon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(height: 12),
                      TacticalTextField(
                        label: 'Player 2 (Partner) UID (Optional)',
                        controller: p2UidController,
                        hint: 'e.g. 9876543210',
                        prefixIcon: Icons.tag_rounded,
                        keyboardType: TextInputType.number,
                      ),
                    ],

                    if (isSquad) ...[
                      const SizedBox(height: 12),
                      TacticalTextField(
                        label: 'Player 2 IGN',
                        controller: p2IgnController,
                        hint: 'e.g. player_two',
                        prefixIcon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(height: 12),
                      TacticalTextField(
                        label: 'Player 3 IGN',
                        controller: p3IgnController,
                        hint: 'e.g. player_three',
                        prefixIcon: Icons.person_add_alt_1_rounded,
                      ),
                      const SizedBox(height: 12),
                      TacticalTextField(
                        label: 'Player 4 IGN',
                        controller: p4IgnController,
                        hint: 'e.g. player_four',
                        prefixIcon: Icons.person_add_alt_1_rounded,
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Select Starting Slot or Clash Squad Side Selection
                    if (isCs) ...[
                      Text('Choose Your Match Side', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 4),
                      Text(
                        'Clash Squad is a 1 vs 1 match. Pick your starting side:',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(height: 12),

                      Builder(
                        builder: (context) {
                          final isLeftTaken = takenSlots.contains(1);
                          final isRightTaken = takenSlots.contains(2);
                          final isLeftSelected = selectedSlot == 1;
                          final isRightSelected = selectedSlot == 2;

                          return Row(
                            children: [
                              // LEFT SIDE
                              Expanded(
                                child: InkWell(
                                  onTap: isLeftTaken ? null : () => setModalState(() => selectedSlot = 1),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isLeftTaken
                                          ? AppColors.surfaceSoft
                                          : isLeftSelected
                                              ? const Color(0xFFEFF6FF)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isLeftTaken
                                            ? AppColors.border
                                            : isLeftSelected
                                                ? AppColors.primary
                                                : AppColors.border,
                                        width: isLeftSelected ? 2.0 : 1.2,
                                      ),
                                      boxShadow: isLeftSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isLeftSelected
                                                ? AppColors.primary
                                                : isLeftTaken
                                                    ? AppColors.textDisabled.withValues(alpha: 0.1)
                                                    : AppColors.surfaceBlueTile,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.shield_outlined,
                                            color: isLeftSelected
                                                ? Colors.white
                                                : isLeftTaken
                                                    ? AppColors.textDisabled
                                                    : AppColors.primaryDark,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'LEFT SIDE',
                                          style: AppTextStyles.tacticalHeader.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: isLeftTaken
                                                ? AppColors.textDisabled
                                                : isLeftSelected
                                                    ? AppColors.primaryDark
                                                    : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          is1v1
                                              ? 'Player 1'
                                              : is2v2
                                                  ? 'Duo Team 1'
                                                  : 'Squad Team 1',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            fontSize: 10.5,
                                            color: isLeftTaken ? AppColors.textDisabled : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isLeftTaken
                                                ? const Color(0xFFFEE2E2)
                                                : isLeftSelected
                                                    ? AppColors.primary
                                                    : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isLeftTaken
                                                ? '🔴 TAKEN'
                                                : isLeftSelected
                                                    ? '✓ SELECTED'
                                                    : '🟢 AVAILABLE',
                                            style: AppTextStyles.badge.copyWith(
                                              color: isLeftTaken
                                                  ? const Color(0xFFDC2626)
                                                  : isLeftSelected
                                                      ? Colors.white
                                                      : const Color(0xFF16A34A),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // VS BADGE IN CENTER
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBlueTile,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'VS',
                                    style: AppTextStyles.monoCode.copyWith(
                                      color: AppColors.accentOrange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),

                              // RIGHT SIDE
                              Expanded(
                                child: InkWell(
                                  onTap: isRightTaken ? null : () => setModalState(() => selectedSlot = 2),
                                  borderRadius: BorderRadius.circular(16),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                    decoration: BoxDecoration(
                                      color: isRightTaken
                                          ? AppColors.surfaceSoft
                                          : isRightSelected
                                              ? const Color(0xFFEFF6FF)
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isRightTaken
                                            ? AppColors.border
                                            : isRightSelected
                                                ? AppColors.primary
                                                : AppColors.border,
                                        width: isRightSelected ? 2.0 : 1.2,
                                      ),
                                      boxShadow: isRightSelected
                                          ? [
                                              BoxShadow(
                                                color: AppColors.primary.withValues(alpha: 0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: isRightSelected
                                                ? AppColors.primary
                                                : isRightTaken
                                                    ? AppColors.textDisabled.withValues(alpha: 0.1)
                                                    : AppColors.surfaceBlueTile,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.shield_outlined,
                                            color: isRightSelected
                                                ? Colors.white
                                                : isRightTaken
                                                    ? AppColors.textDisabled
                                                    : AppColors.primaryDark,
                                            size: 24,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'RIGHT SIDE',
                                          style: AppTextStyles.tacticalHeader.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: isRightTaken
                                                ? AppColors.textDisabled
                                                : isRightSelected
                                                    ? AppColors.primaryDark
                                                    : AppColors.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          is1v1
                                              ? 'Player 2'
                                              : is2v2
                                                  ? 'Duo Team 2'
                                                  : 'Squad Team 2',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            fontSize: 10.5,
                                            color: isRightTaken ? AppColors.textDisabled : AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isRightTaken
                                                ? const Color(0xFFFEE2E2)
                                                : isRightSelected
                                                    ? AppColors.primary
                                                    : const Color(0xFFDCFCE7),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            isRightTaken
                                                ? '🔴 TAKEN'
                                                : isRightSelected
                                                    ? '✓ SELECTED'
                                                    : '🟢 AVAILABLE',
                                            style: AppTextStyles.badge.copyWith(
                                              color: isRightTaken
                                                  ? const Color(0xFFDC2626)
                                                  : isRightSelected
                                                      ? Colors.white
                                                      : const Color(0xFF16A34A),
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      // Select Starting Slot (1 to maxSlots)
                      Text('Select Starting Slot (1 to ${tournament.maxSlots})', style: AppTextStyles.sectionTitle),
                      const SizedBox(height: 10),

                      SizedBox(
                        height: 52,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: tournament.maxSlots,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, idx) {
                            final slotNum = idx + 1;
                            final isTaken = takenSlots.contains(slotNum);
                            final isSelected = slotNum == selectedSlot;

                            return InkWell(
                              onTap: isTaken ? null : () => setModalState(() => selectedSlot = slotNum),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: isTaken
                                      ? AppColors.surfaceSoft
                                      : isSelected
                                          ? AppColors.primary
                                          : AppColors.surfaceBlueTile,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppColors.primaryDark : Colors.transparent,
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    '#$slotNum',
                                    style: AppTextStyles.monoCode.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: isTaken
                                          ? AppColors.textDisabled
                                          : isSelected
                                              ? Colors.white
                                              : AppColors.primaryDark,
                                      decoration: isTaken ? TextDecoration.lineThrough : null,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Notice
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Room ID & Password will be released inside your confirmed ticket 15 minutes before match start once broadcasted by the host coordinator.',
                              style: AppTextStyles.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Confirm Registration Button
                    TacticalButton(
                      label: isSubmitting
                          ? 'Confirming Slot...'
                          : canAfford
                              ? 'Pay ₹${tournament.entryFee.toStringAsFixed(0)} & Confirm ${isCs ? (selectedSlot == 1 ? "LEFT SIDE" : "RIGHT SIDE") : "Slot #$selectedSlot"}'
                              : 'Load Vault (Need ₹${(tournament.entryFee - walletBalance).toStringAsFixed(0)})',
                      variant: canAfford ? TacticalButtonVariant.primary : TacticalButtonVariant.outline,
                      isLoading: isSubmitting,
                      onPressed: () async {
                        if (!canAfford) {
                          Navigator.of(ctx).pop();
                          WalletModal.show(context);
                          return;
                        }

                        if (ignController.text.trim().isEmpty || uidController.text.trim().isEmpty) {
                          UiHelpers.showErrorBanner(context, 'Please enter your Captain/Player IGN and UID.');
                          return;
                        }

                        setModalState(() => isSubmitting = true);

                        try {
                          final repo = ref.read(tournamentRepoProvider);
                          String? teamName;
                          List<String> players = [];

                          if (isSolo) {
                            teamName = ignController.text.trim();
                            players = [ignController.text.trim()];
                          } else if (isDuo) {
                            teamName = teamNameController.text.trim().isNotEmpty
                                ? teamNameController.text.trim()
                                : 'Duo #$selectedSlot';
                            final p1 = ignController.text.trim();
                            final p2 = p2IgnController.text.trim().isNotEmpty ? p2IgnController.text.trim() : 'Partner';
                            players = [p1, p2];
                          } else if (isSquad) {
                            teamName = teamNameController.text.trim().isNotEmpty
                                ? teamNameController.text.trim()
                                : 'Squad #$selectedSlot';
                            final p1 = ignController.text.trim();
                            final p2 = p2IgnController.text.trim().isNotEmpty ? p2IgnController.text.trim() : 'Player 2';
                            final p3 = p3IgnController.text.trim().isNotEmpty ? p3IgnController.text.trim() : 'Player 3';
                            final p4 = p4IgnController.text.trim().isNotEmpty ? p4IgnController.text.trim() : 'Player 4';
                            players = [p1, p2, p3, p4];
                          }

                          await repo.registerForTournament(
                            tournament: tournament,
                            gameIgn: ignController.text.trim(),
                            gameUid: uidController.text.trim(),
                            teamName: teamName,
                            players: players,
                            slotNumber: selectedSlot,
                          );

                          await ref.read(authControllerProvider.notifier).refreshProfile();
                          ref.invalidate(freeFireTournamentsProvider);
                          ref.invalidate(userRegisteredTournamentIdsProvider);
                          ref.invalidate(walletTransactionsProvider);

                          if (context.mounted) {
                            Navigator.of(ctx).pop();
                            _showTicketVoucherDialog(
                              context,
                              tournament,
                              selectedSlot,
                              ignController.text.trim(),
                              uidController.text.trim(),
                            );
                          }
                        } catch (e) {
                          setModalState(() => isSubmitting = false);
                          if (context.mounted) {
                            UiHelpers.showErrorBanner(context, 'Registration error: ${e.toString()}');
                          }
                        }
                      },
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrizePodium(String rank, String prize, Color color) {
    return Column(
      children: [
        Text(rank, style: AppTextStyles.badge.copyWith(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Text(
          prize,
          style: AppTextStyles.monoCode.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  static Widget _buildCsRuleRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: iconColor, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10.5),
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
                TextSpan(text: desc),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showTicketVoucherDialog(
    BuildContext context,
    TournamentModel tournament,
    int slot,
    String ign,
    String uid,
  ) {
    final is1v1 = tournament.format.toLowerCase().contains('1v1');
    final is2v2 = tournament.format.toLowerCase().contains('2v2');
    final is4v4 = tournament.format.toLowerCase().contains('4v4');
    final isCs = is1v1 || is2v2 || is4v4 || tournament.format.toLowerCase().contains('cs') || tournament.format.toLowerCase().contains('clash');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
            maxWidth: 420,
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lobby Confirmed!', style: AppTextStyles.h3.copyWith(fontSize: 18)),
                        Text(
                          tournament.title,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Scrollable Ticket & Rules Body
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Pass & Side Badge Container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceBlueTile,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isCs
                                      ? 'ASSIGNED SIDE: ${slot == 1 ? "LEFT SIDE (TEAM 1)" : "RIGHT SIDE (TEAM 2)"}'
                                      : 'ASSIGNED SLOT: #$slot',
                                  style: AppTextStyles.tacticalHeader.copyWith(color: AppColors.primaryDark, fontSize: 12),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '₹${tournament.entryFee.toStringAsFixed(0)} PAID',
                                    style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 9.5),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('IGN: $ign • UID: $uid', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const Divider(color: AppColors.border, height: 14),
                            Row(
                              children: [
                                const Icon(Icons.schedule_rounded, color: AppColors.primaryDark, size: 14),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Room ID & Password unlock 15m prior to start time.',
                                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5, color: AppColors.textSecondary),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 2. Clash Squad Esports Rules (Shown right after buying the lobby)
                      if (isCs) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1527),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.gavel_rounded, color: Color(0xFF00E5FF), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'CLASH SQUAD RULES APPLIED',
                                          style: AppTextStyles.badge.copyWith(
                                            color: const Color(0xFF00E5FF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          'Strict adherence required during your match',
                                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              const Divider(color: Colors.white12, height: 1),
                              const SizedBox(height: 10),

                              _buildCsRuleRow(
                                icon: Icons.military_tech_rounded,
                                iconColor: const Color(0xFF38BDF8),
                                title: 'Level 40+ Requirement',
                                desc: 'Must play using Level 40+ account. Lower IDs are disqualified.',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.sports_esports_rounded,
                                iconColor: const Color(0xFF38BDF8),
                                title: 'Esports Custom Rules',
                                desc: 'Best of 7 rounds, 500 coin economy, competitive esports settings.',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.block_rounded,
                                iconColor: const Color(0xFFEF4444),
                                title: 'No Nade & No Throwables',
                                desc: 'Grenades, Smoke, Flashbangs & throwables are strictly prohibited.',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.gps_fixed_rounded,
                                iconColor: const Color(0xFFA855F7),
                                title: '1 Sniper Per Team',
                                desc: 'Maximum 1 sniper rifle allowed per team.',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFF00E5FF),
                                title: 'Unique Skills Only',
                                desc: 'Teammates must equip unique character skills (no duplicates).',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.warning_amber_rounded,
                                iconColor: const Color(0xFFF43F5E),
                                title: 'Backout / Quit Policy',
                                desc: 'If you back out or disconnect, opponent automatically wins.',
                              ),
                              const SizedBox(height: 6),
                              _buildCsRuleRow(
                                icon: Icons.lock_clock_rounded,
                                iconColor: const Color(0xFF94A3B8),
                                title: 'Strict No-Refund Policy',
                                desc: 'Entry fees are 100% non-refundable once registered.',
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pinned Bottom Actions
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Close', style: AppTextStyles.bodyMedium),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TacticalButton(
                      label: '🎮 Open Match Room',
                      height: 42,
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LobbyRoomScreen(tournament: tournament),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = ref.watch(connectivityStateProvider);
    final freeFireTournaments = ref.watch(freeFireTournamentsProvider);
    final profile = ref.watch(authControllerProvider).value;
    final walletBalance = profile?.walletBalance ?? 0.0;
    final registeredTournamentIds = ref.watch(userRegisteredTournamentIdsProvider).value ?? {};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onLongPress: () => HostAuthDialog.show(context),
          child: Text(
            'Free Fire Arenas',
            style: AppTextStyles.h3.copyWith(color: Colors.white),
          ),
        ),
        actions: [
          // Match History Button
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
            tooltip: 'Match & Prize History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MatchHistoryScreen()),
              );
            },
          ),

          // Live Wallet Pill
          InkWell(
            onTap: () => WalletModal.show(context),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '₹${walletBalance.toStringAsFixed(0)}',
                    style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: !isOnline
          ? JohnnyErrorWidget(
              onRetry: () async {
                final online = await ref.read(connectivityStateProvider.notifier).checkNow();
                if (online) {
                  ref.invalidate(freeFireTournamentsProvider);
                }
              },
            )
          : RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: () async {
          ref.invalidate(freeFireTournamentsProvider);
          ref.invalidate(userRegisteredTournamentIdsProvider);
          ref.invalidate(matchHistoryProvider);
          await ref.read(authControllerProvider.notifier).refreshProfile();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            // 1. MAIN MODE SELECTOR TABS (SOLO, DUO, SQUAD, CLASH SQUAD)
            Row(
              children: [
                _buildMainModeTab('SOLO', Icons.person_rounded, 'Solo BR'),
                const SizedBox(width: 6),
                _buildMainModeTab('DUO', Icons.group_rounded, 'Duo BR'),
                const SizedBox(width: 6),
                _buildMainModeTab('SQUAD', Icons.groups_rounded, 'Squad BR'),
                const SizedBox(width: 6),
                _buildMainModeTab('CLASH SQUAD', Icons.sports_martial_arts_rounded, 'Clash Squad'),
              ],
            ),

            const SizedBox(height: 16),

            // 2. SUB-TIER SELECTORS
            if (_selectedMainMode == 'SOLO') ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedSoloTier = 15),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedSoloTier == 15 ? AppColors.surfaceBlueTile : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedSoloTier == 15 ? AppColors.primary : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₹15 SOLO LOBBY',
                              style: AppTextStyles.badge.copyWith(
                                color: _selectedSoloTier == 15 ? AppColors.primaryDark : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹9 Per Kill • 48 Slots',
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedSoloTier = 20),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _selectedSoloTier == 20 ? AppColors.surfaceBlueTile : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedSoloTier == 20 ? AppColors.primary : AppColors.border,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '₹20 SOLO LOBBY',
                              style: AppTextStyles.badge.copyWith(
                                color: _selectedSoloTier == 20 ? AppColors.primaryDark : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹14 Per Kill • 48 Slots',
                              style: AppTextStyles.bodySmall.copyWith(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else if (_selectedMainMode == 'CLASH SQUAD') ...[
              Row(
                children: [
                  _buildCsSubTierTab('1v1', '1v1 DUEL', '2 Slots • ₹35 Pool', 20),
                  const SizedBox(width: 6),
                  _buildCsSubTierTab('2v2', '2v2 CLASH', '4 Slots • ₹35 Pool', 20),
                  const SizedBox(width: 6),
                  _buildCsSubTierTab('4v4', '4v4 SQUAD', '8 Slots • ₹35 Pool', 20),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 3. MODE BANNER SUMMARY CARD
            if (_selectedMainMode == 'DUO') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlueTile,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DUO TOURNAMENT POOL', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                        const SizedBox(height: 2),
                        Text('Top 1: ₹170 • Top 2: ₹130 • Top 3: ₹100', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('₹20 ENTRY', style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_selectedMainMode == 'SQUAD') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlueTile,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SQUAD TOURNAMENT POOL', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                        const SizedBox(height: 2),
                        Text('Top 1: ₹110 • Top 2: ₹90 • Top 3: ₹60', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('₹25 ENTRY', style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_selectedMainMode == 'CLASH SQUAD') ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBlueTile,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCsTier == '1v1'
                              ? '1v1 DUEL CLASH SQUAD'
                              : _selectedCsTier == '2v2'
                                  ? '2v2 DUO CLASH SQUAD'
                                  : '4v4 SQUAD CLASH SQUAD',
                          style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedCsTier == '1v1'
                              ? 'Winner: ₹35 • 2 Slots (1v1) • Best of 7'
                              : _selectedCsTier == '2v2'
                                  ? 'Winning Duo: ₹35 • 4 Slots (2v2) • Best of 7'
                                  : 'Winning Squad: ₹35 • 8 Slots (4v4) • Best of 7',
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '₹20 ENTRY',
                        style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. SEQUENTIAL LOBBIES FEED
            freeFireTournaments.when(
              loading: () => !isOnline
                  ? JohnnyErrorWidget(
                      onRetry: () async {
                        final online = await ref.read(connectivityStateProvider.notifier).checkNow();
                        if (online) {
                          ref.invalidate(freeFireTournamentsProvider);
                          ref.invalidate(userRegisteredTournamentIdsProvider);
                        }
                      },
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
                            SizedBox(height: 12),
                            Text(
                              'Loading Free Fire Arenas...',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
              error: (err, stack) => JohnnyErrorWidget(
                customMessage:
                    'No internet connection detected or failed to load Free Fire Arenas. Please check your network and retry.',
                onRetry: () async {
                  final online = await ref.read(connectivityStateProvider.notifier).checkNow();
                  if (online) {
                    ref.invalidate(freeFireTournamentsProvider);
                    ref.invalidate(userRegisteredTournamentIdsProvider);
                  }
                },
              ),
              data: (tournaments) {
                // 1. Filter tournaments based on active mode
                List<TournamentModel> activeTournaments = [];

                if (_selectedMainMode == 'SOLO') {
                  activeTournaments = tournaments
                      .where((t) => t.format.toLowerCase().contains('solo') && t.entryFee.toInt() == _selectedSoloTier)
                      .toList();
                } else if (_selectedMainMode == 'DUO') {
                  activeTournaments = tournaments
                      .where((t) => t.format.toLowerCase().contains('duo') && !t.format.toLowerCase().contains('2v2'))
                      .toList();
                } else if (_selectedMainMode == 'SQUAD') {
                  activeTournaments = tournaments
                      .where((t) => t.format.toLowerCase().contains('squad') && !t.format.toLowerCase().contains('4v4') && !t.format.toLowerCase().contains('clash'))
                      .toList();
                } else if (_selectedMainMode == 'CLASH SQUAD') {
                  activeTournaments = tournaments
                      .where((t) => t.format.toLowerCase().contains(_selectedCsTier.toLowerCase()))
                      .toList();
                }

                // 2. Filter visibility according to T69 dynamic rules:
                // - If the player joined this lobby -> ALWAYS visible so they can play and view Room ID/Pass.
                // - If the player did NOT join this lobby and it is LIVE / LOCKED / COMPLETED -> HIDE IT so next slot lobby appears.
                activeTournaments = activeTournaments.where((t) {
                  final isRegistered = registeredTournamentIds.contains(t.id);
                  return LobbyScheduleHelper.isLobbyVisibleToUser(
                    tournament: t,
                    isUserRegistered: isRegistered,
                  );
                }).toList();

                // 3. Sort by match schedule time ascending, then title
                activeTournaments.sort((a, b) {
                  final aTime = LobbyScheduleHelper.getEffectiveStartTime(a);
                  final bTime = LobbyScheduleHelper.getEffectiveStartTime(b);
                  final timeCmp = aTime.compareTo(bTime);
                  if (timeCmp != 0) return timeCmp;
                  return a.title.compareTo(b.title);
                });

                if (activeTournaments.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_filled_rounded, size: 38, color: AppColors.primary),
                        const SizedBox(height: 12),
                        Text('Next Match Lobby Preparing', style: AppTextStyles.h4),
                        const SizedBox(height: 6),
                        Text(
                          'Previous lobbies are completed or live. New lobbies for the upcoming schedule slot (12:00 AM, 12:00 PM, 3:00 PM, 6:00 PM, 9:00 PM) will open shortly.',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: activeTournaments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final t = entry.value;

                    final isMatchLive = (t.status.toLowerCase() == 'live') || (t.isIdpLocked && t.isClaimed);
                    final isMatchCompleted = t.status.toLowerCase() == 'completed';

                    // Sequential Unlock Rule:
                    // The first active lobby is always open.
                    // Subsequent lobbies unlock if the previous lobby reached maxSlots OR is LIVE / COMPLETED.
                    bool isUnlocked = false;
                    if (index == 0) {
                      isUnlocked = true;
                    } else {
                      final prevTournament = activeTournaments[index - 1];
                      final prevIsLiveOrDone = (prevTournament.status.toLowerCase() == 'live') ||
                          (prevTournament.isIdpLocked && prevTournament.isClaimed) ||
                          (prevTournament.status.toLowerCase() == 'completed');
                      final prevIsFull = prevTournament.filledSlots >= prevTournament.maxSlots;
                      isUnlocked = prevIsFull || prevIsLiveOrDone;
                    }

                    final isFull = t.filledSlots >= t.maxSlots;
                    final isRegistered = registeredTournamentIds.contains(t.id);
                    final isLateEntry = !isRegistered && LobbyScheduleHelper.isLateEntryAllowed(t);
                    final isKicked = !isRegistered && t.isUserKickedOrBanned(profile?.id, profile?.gameUid);
                    final kickInfo = isKicked ? t.getKickDetailsForUser(profile?.id, profile?.gameUid) : null;
                    final progress = (t.filledSlots / t.maxSlots).clamp(0.0, 1.0);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.white : AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRegistered
                              ? AppColors.success
                              : isKicked
                                  ? const Color(0xFFEF4444)
                                  : isMatchLive
                                      ? const Color(0xFFEF4444)
                                      : isLateEntry
                                          ? const Color(0xFFF59E0B)
                                          : isUnlocked
                                              ? isFull
                                                  ? AppColors.secondary
                                                  : AppColors.primary.withValues(alpha: 0.6)
                                              : AppColors.border,
                          width: (isRegistered || isKicked || isMatchLive || isLateEntry || isUnlocked) ? 1.5 : 1.0,
                        ),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Badges Row (Timing Badge + Status Badges)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      // Scheduled Time Badge
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.access_time_filled_rounded, color: Color(0xFF2563EB), size: 12),
                                            const SizedBox(width: 4),
                                            Text(
                                              LobbyScheduleHelper.formatSlotWithDay(LobbyScheduleHelper.getEffectiveStartTime(t)),
                                              style: AppTextStyles.monoCode.copyWith(
                                                color: const Color(0xFF1D4ED8),
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      if (isRegistered) ...[
                                        StatusBadge(
                                          label: isMatchLive ? 'MATCH LIVE // ROOM OPEN' : 'PASS CONFIRMED',
                                          type: BadgeType.success,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'MAP: ${t.mapName.toUpperCase()}',
                                            style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9),
                                          ),
                                        ),
                                      ] else if (isKicked) ...[
                                        const StatusBadge(
                                          label: '⛔ REMOVED FROM LOBBY',
                                          type: BadgeType.danger,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            'RE-ENTRY BLOCKED',
                                            style: AppTextStyles.badge.copyWith(color: const Color(0xFFDC2626), fontSize: 9),
                                          ),
                                        ),
                                      ] else if (isMatchLive) ...[
                                        const StatusBadge(
                                          label: 'MATCH IN PROGRESS // LIVE',
                                          type: BadgeType.danger,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            'MAP: ${t.mapName.toUpperCase()}',
                                            style: AppTextStyles.badge.copyWith(color: const Color(0xFFDC2626), fontSize: 9),
                                          ),
                                        ),
                                      ] else if (isMatchCompleted) ...[
                                        const StatusBadge(
                                          label: 'MATCH COMPLETED',
                                          type: BadgeType.neutral,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'MAP: ${t.mapName.toUpperCase()}',
                                            style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9),
                                          ),
                                        ),
                                      ] else if (isLateEntry) ...[
                                        const StatusBadge(
                                          label: '⚡ LATE ENTRY ACTIVE',
                                          type: BadgeType.warning,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'MAP: ${t.mapName.toUpperCase()}',
                                            style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9),
                                          ),
                                        ),
                                      ] else if (isUnlocked) ...[
                                        StatusBadge(
                                          label: isFull ? 'LOBBY FULL' : 'LOBBY #${index + 1} // OPEN',
                                          type: isFull ? BadgeType.danger : BadgeType.primary,
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceSoft,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            'MAP: ${t.mapName.toUpperCase()}',
                                            style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9),
                                          ),
                                        ),
                                      ] else ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.borderInput,
                                            borderRadius: BorderRadius.circular(14),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.lock_rounded, size: 12, color: AppColors.textSecondary),
                                              const SizedBox(width: 4),
                                              Text(
                                                'LOBBY #${index + 1} // LOCKED',
                                                style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 9.5),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (t.isClaimed && !isMatchLive && !isMatchCompleted) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceBlueTile,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                          ),
                                          child: Text(
                                            '👑 HOST ASSIGNED',
                                            style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 8.5),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${t.maxSlots} SLOTS',
                                  style: AppTextStyles.badge.copyWith(
                                    color: isUnlocked ? AppColors.primaryDark : AppColors.textTertiary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Lobby Title
                            Text(
                              t.title,
                              style: AppTextStyles.h3.copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: isUnlocked ? AppColors.textPrimary : AppColors.textSecondary,
                              ),
                            ),

                            const SizedBox(height: 14),

                            // 3 Key Metrics Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isUnlocked ? AppColors.surfaceBlueTile : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('ENTRY FEE', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${t.entryFee.toStringAsFixed(0)}',
                                        style: AppTextStyles.monoCode.copyWith(
                                          color: isUnlocked ? AppColors.primaryDark : AppColors.textSecondary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_selectedMainMode == 'SOLO') ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('PER KILL', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.accentOrange)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹${t.perKill.toStringAsFixed(0)} / Kill',
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: isUnlocked ? AppColors.accentOrange : AppColors.textSecondary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (_selectedMainMode == 'DUO') ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('TOP 3 PRIZES', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.accentOrange)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹170 / ₹130 / ₹100',
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: isUnlocked ? AppColors.accentOrange : AppColors.textSecondary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else if (_selectedMainMode == 'SQUAD') ...[
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('TOP 3 PRIZES', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.accentOrange)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '₹110 / ₹90 / ₹60',
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: isUnlocked ? AppColors.accentOrange : AppColors.textSecondary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('TOTAL POOL', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                                      const SizedBox(height: 2),
                                      Text(
                                        '₹${t.prizePool.toStringAsFixed(0)}',
                                        style: AppTextStyles.monoCode.copyWith(
                                          color: isUnlocked ? AppColors.success : AppColors.textSecondary,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Top 3 Prize Distribution Details Strip for Duo & Squad
                            if (_selectedMainMode == 'DUO') ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUnlocked ? Colors.white : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isUnlocked ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Text('🥇 1st: ₹170', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.accentOrange)),
                                    const Text('•', style: TextStyle(color: AppColors.borderInput)),
                                    Text('🥈 2nd: ₹130', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                                    const Text('•', style: TextStyle(color: AppColors.borderInput)),
                                    Text('🥉 3rd: ₹100', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.success)),
                                  ],
                                ),
                              ),
                            ] else if (_selectedMainMode == 'SQUAD') ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isUnlocked ? Colors.white : AppColors.surfaceSoft,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: isUnlocked ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Text('🥇 1st: ₹110', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.accentOrange)),
                                    const Text('•', style: TextStyle(color: AppColors.borderInput)),
                                    Text('🥈 2nd: ₹90', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                                    const Text('•', style: TextStyle(color: AppColors.borderInput)),
                                    Text('🥉 3rd: ₹60', style: AppTextStyles.monoCode.copyWith(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.success)),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Slots Progress, Late Entry Notice, or Live/Locked Banner
                            if (isMatchLive && !isRegistered) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.videogame_asset_rounded, color: Color(0xFFDC2626), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Custom room is LIVE in Free Fire. Registrations closed. Join the next open lobby!',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else if (isUnlocked) ...[
                              if (isLateEntry) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Host is preparing Room IDP • Late slot booking active!',
                                          style: AppTextStyles.bodySmall.copyWith(
                                            color: const Color(0xFF92400E),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${t.filledSlots} / ${t.maxSlots} ${_selectedMainMode == 'SQUAD' ? "Squads" : _selectedMainMode == 'DUO' ? "Teams" : "Players"} Joined',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    isFull ? 'Lobby Full' : '${t.maxSlots - t.filledSlots} slots left',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isFull ? AppColors.secondary : AppColors.primaryDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppColors.surfaceSoft,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    isFull
                                        ? AppColors.secondary
                                        : isLateEntry
                                            ? const Color(0xFFF59E0B)
                                            : AppColors.primary,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.lock_clock_rounded, size: 16, color: AppColors.textSecondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Unlocks automatically when previous lobby fills up or goes live.',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 16),

                            // Action Button
                            TacticalButton(
                              label: isRegistered
                                  ? '🎮 ENTER MATCH ROOM (ID & PASS)'
                                  : isKicked
                                      ? '⛔ REMOVED BY T69 TEAM (RE-ENTRY BLOCKED)'
                                      : isMatchLive
                                          ? '🔒 MATCH LIVE (REGISTRATIONS CLOSED)'
                                          : isMatchCompleted
                                              ? '🏁 MATCH COMPLETED'
                                              : isUnlocked
                                                  ? isFull
                                                      ? 'Lobby Full'
                                                      : isLateEntry
                                                          ? '⚡ Quick Register (₹${t.entryFee.toStringAsFixed(0)})'
                                                          : 'Register Lobby (₹${t.entryFee.toStringAsFixed(0)})'
                                                  : '🔒 Locked (Waiting for Previous Lobby)',
                              variant: isRegistered
                                  ? TacticalButtonVariant.primary
                                  : isKicked
                                      ? TacticalButtonVariant.danger
                                      : (!isMatchLive && !isMatchCompleted && isUnlocked && !isFull)
                                          ? isLateEntry
                                              ? TacticalButtonVariant.primary
                                              : TacticalButtonVariant.primary
                                          : TacticalButtonVariant.secondary,
                              height: 44,
                              onPressed: isRegistered
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => LobbyRoomScreen(tournament: t),
                                        ),
                                      )
                                  : isKicked
                                      ? () {
                                          final reason = kickInfo?['reason'] ?? 'Violation of lobby rules';
                                          showDialog(
                                            context: context,
                                            builder: (dCtx) => AlertDialog(
                                              backgroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                              title: Row(
                                                children: [
                                                  const Icon(Icons.gavel_rounded, color: AppColors.error, size: 24),
                                                  const SizedBox(width: 10),
                                                  Text('Removed from Lobby', style: AppTextStyles.h4.copyWith(color: AppColors.error)),
                                                ],
                                              ),
                                              content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'You were removed from this tournament lobby by T69 Team.',
                                                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceSoft,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: AppColors.border),
                                                    ),
                                                    child: Text(
                                                      'Reason: $reason',
                                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Re-entering this match lobby is blocked for fair play. If you believe this was an error, please contact T69 Team support.',
                                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ),
                                              actions: [
                                                TacticalButton(
                                                  label: 'Understood',
                                                  isFullWidth: false,
                                                  height: 38,
                                                  onPressed: () => Navigator.of(dCtx).pop(),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      : (!isMatchLive && !isMatchCompleted && isUnlocked && !isFull
                                          ? () => _showLobbyRegistrationModal(context, t)
                                          : null),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Center(
              child: InkWell(
                onTap: () => HostAuthDialog.show(context),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'T69 ESPORTS • MATCH COORDINATOR SYSTEM • v1.0.4',
                    style: AppTextStyles.badge.copyWith(
                      fontSize: 9.5,
                      color: AppColors.textTertiary.withValues(alpha: 0.5),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMainModeTab(String modeKey, IconData icon, String label) {
    final isSelected = _selectedMainMode == modeKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedMainMode = modeKey),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(icon, size: 19, color: isSelected ? Colors.white : AppColors.primaryDark),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.badge.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCsSubTierTab(String tierKey, String title, String subtitle, int entryFee) {
    final isSelected = _selectedCsTier == tierKey;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedCsTier = tierKey),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surfaceBlueTile : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: 1.2,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: AppTextStyles.badge.copyWith(
                  color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(fontSize: 9.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

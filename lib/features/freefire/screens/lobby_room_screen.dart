import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../tournaments/utils/lobby_schedule_helper.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../../core/services/rate_limiter_service.dart';
import '../widgets/freefire_final_standings_board.dart';
import '../widgets/clash_squad_duel_board.dart';

class LobbyRoomScreen extends ConsumerStatefulWidget {
  final TournamentModel tournament;

  const LobbyRoomScreen({super.key, required this.tournament});

  @override
  ConsumerState<LobbyRoomScreen> createState() => _LobbyRoomScreenState();
}

class _LobbyRoomScreenState extends ConsumerState<LobbyRoomScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  late TournamentModel _t;
  List<Map<String, dynamic>> _registrations = [];
  Map<String, dynamic>? _userRegistration;

  // Screenshot upload controller
  final _screenshotController = TextEditingController();
  bool _isUploadingProof = false;

  @override
  void initState() {
    super.initState();
    _t = widget.tournament;
    _tabController = TabController(length: 5, vsync: this);
    _loadLobbyDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _screenshotController.dispose();
    super.dispose();
  }

  Future<void> _loadLobbyDetails() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final refreshed = await repo.fetchTournamentById(_t.id);
      final regs = await repo.fetchTournamentRegistrations(_t.id);
      final userReg = await repo.fetchUserRegistrationForTournament(_t.id);

      if (mounted) {
        setState(() {
          if (refreshed != null) _t = refreshed;
          _registrations = regs;
          _userRegistration = userReg;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final profile = ref.watch(authControllerProvider).value;
    final isUserRegistered = _userRegistration != null;
    final userSlot = isUserRegistered ? (_userRegistration!['slot_number'] as int?) : null;
    final userIgn = isUserRegistered ? (_userRegistration!['game_ign'] ?? profile?.gameIgn ?? 'Player') : (profile?.gameIgn ?? 'Player');
    final userUid = isUserRegistered ? (_userRegistration!['game_uid'] ?? profile?.gameUid ?? 'N/A') : (profile?.gameUid ?? 'N/A');

    final isIdpRevealed = isUserRegistered && t.isIdpLocked && (t.roomId != null && t.roomId!.isNotEmpty);
    final roomId = isIdpRevealed ? t.roomId! : 'LOCKED (REGISTRATION REQUIRED)';
    final roomPassword = isIdpRevealed ? (t.roomPassword ?? '') : 'LOCKED (REGISTRATION REQUIRED)';
    final isClaimed = t.isClaimed;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lobby Room Terminal',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            Text(
              t.title,
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadLobbyDetails,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: _loadLobbyDetails,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // 0. Personal Kick / Ban Notice (if user was removed by host/admin)
            if (!isUserRegistered) ...[
              Builder(
                builder: (context) {
                  final myKick = t.getKickDetailsForUser(profile?.id, profile?.gameUid);
                  if (myKick == null || myKick.isEmpty) return const SizedBox.shrink();

                  final reason = myKick['reason'] ?? 'Violation of lobby rules';
                  final action = myKick['action'] ?? 'KICKED';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF450A0A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7F1D1D),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.gavel_rounded, color: Color(0xFFFCA5A5), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '⚠️ YOU WERE REMOVED FROM THIS LOBBY',
                                style: AppTextStyles.badge.copyWith(
                                  color: const Color(0xFFFCA5A5),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Reason: $reason',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Action: $action enforced by T69 Team',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],

            // 1. Official Host Coordinator Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isClaimed ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlueTile,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.verified_user_rounded, color: AppColors.primaryDark, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isClaimed ? 'OFFICIAL MATCH COORDINATOR' : 'AUTOMATED MATCH GATEWAY',
                          style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.primaryDark),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isClaimed ? '${t.hostName} (IGN: ${t.hostIgn})' : 'T69 Verified Esports Host',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                        Text(
                          isClaimed ? '⭐ 4.9 Host Rating • Level 40+ Certified' : 'Automated slot sync & result verification',
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 2. Confirmed Match Pass Ticket
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isUserRegistered
                      ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                      : const [Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isUserRegistered ? Icons.confirmation_number_outlined : Icons.lock_outline_rounded,
                            color: isUserRegistered ? AppColors.accentYellow : Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isUserRegistered ? 'CONFIRMED MATCH PASS' : 'LOBBY PASS • NOT REGISTERED',
                            style: AppTextStyles.badge.copyWith(
                              color: isUserRegistered ? AppColors.accentYellow : Colors.white70,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      StatusBadge(
                        label: isUserRegistered ? 'SLOT #$userSlot' : 'UNRESERVED',
                        type: isUserRegistered ? BadgeType.success : BadgeType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(
                    isUserRegistered ? userIgn : 'Spectator / Unregistered',
                    style: AppTextStyles.h2.copyWith(color: Colors.white, fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isUserRegistered ? 'Free Fire UID: $userUid' : 'Register for an available slot to receive your match pass',
                    style: AppTextStyles.monoCode.copyWith(color: Colors.white70, fontSize: 12),
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTicketStat('FORMAT', t.format.toUpperCase()),
                      _buildTicketStat('MAP', t.mapName.toUpperCase()),
                      _buildTicketStat('MATCH TIME', LobbyScheduleHelper.formatSlotTime(t.startTime)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. Custom Room Credentials Card (Zero Fake Data)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isIdpRevealed ? AppColors.success.withValues(alpha: 0.5) : AppColors.border,
                  width: isIdpRevealed ? 1.5 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              isIdpRevealed ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                              color: isIdpRevealed ? AppColors.success : AppColors.accentOrange,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                isIdpRevealed ? 'ROOM CREDENTIALS (LIVE)' : 'ROOM CREDENTIALS (LOCKED)',
                                style: AppTextStyles.badge.copyWith(
                                  color: isIdpRevealed ? AppColors.success : AppColors.accentOrange,
                                  fontSize: 9.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusBadge(
                        label: isIdpRevealed ? 'ROOM OPEN' : 'PENDING HOST',
                        type: isIdpRevealed ? BadgeType.success : BadgeType.warning,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Room ID Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isIdpRevealed ? AppColors.surfaceBlueTile : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isIdpRevealed ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('FREE FIRE ROOM ID', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                              const SizedBox(height: 2),
                              Text(
                                roomId,
                                style: AppTextStyles.monoCode.copyWith(
                                  fontSize: isIdpRevealed ? 18 : 13,
                                  fontWeight: FontWeight.w900,
                                  color: isIdpRevealed ? AppColors.primaryDark : AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TacticalButton(
                          label: isIdpRevealed ? 'Copy ID' : 'Locked',
                          icon: isIdpRevealed ? Icons.copy_rounded : Icons.lock_outline_rounded,
                          height: 36,
                          isFullWidth: false,
                          variant: isIdpRevealed ? TacticalButtonVariant.primary : TacticalButtonVariant.outline,
                          onPressed: isIdpRevealed
                              ? () {
                                  Clipboard.setData(ClipboardData(text: roomId));
                                  UiHelpers.showSuccessBanner(context, 'Room ID copied: $roomId');
                                }
                              : () {
                                  UiHelpers.showInfoBanner(context, 'Room ID will unlock 15m before match start once broadcasted by host.');
                                },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Room Password Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isIdpRevealed ? AppColors.surfaceBlueTile : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isIdpRevealed ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ROOM PASSWORD', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                              const SizedBox(height: 2),
                              Text(
                                roomPassword,
                                style: AppTextStyles.monoCode.copyWith(
                                  fontSize: isIdpRevealed ? 18 : 13,
                                  fontWeight: FontWeight.w900,
                                  color: isIdpRevealed ? AppColors.primaryDark : AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TacticalButton(
                          label: isIdpRevealed ? 'Copy Pass' : 'Locked',
                          icon: isIdpRevealed ? Icons.copy_rounded : Icons.lock_outline_rounded,
                          height: 36,
                          isFullWidth: false,
                          variant: isIdpRevealed ? TacticalButtonVariant.primary : TacticalButtonVariant.outline,
                          onPressed: isIdpRevealed
                              ? () {
                                  Clipboard.setData(ClipboardData(text: roomPassword));
                                  UiHelpers.showSuccessBanner(context, 'Password copied: $roomPassword');
                                }
                              : () {
                                  UiHelpers.showInfoBanner(context, 'Password will unlock 15m before match start once broadcasted by host.');
                                },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Strict Slot Instruction Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceBlueTile,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isIdpRevealed ? Icons.info_outline_rounded : Icons.schedule_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isIdpRevealed
                                ? 'Strictly sit in Slot #$userSlot inside Free Fire Custom Room. Occupying another slot will result in automatic kick/ban.'
                                : 'Credentials will be released 15 minutes before the match start time once the official host broadcasts credentials. No dummy data is shown.',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Live Host Disciplinary & Anti-Cheat Enforcement Feed
            if (t.kickedTeams.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Color(0xFFF87171), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'HOST DISCIPLINARY & SECURITY LOG',
                              style: AppTextStyles.badge.copyWith(
                                color: const Color(0xFFF87171),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${t.kickedTeams.length} KICKED / BANNED',
                            style: AppTextStyles.monoCode.copyWith(
                              color: const Color(0xFFFCA5A5),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...t.kickedTeams.map((kick) {
                      final slot = kick['slot'] ?? '?';
                      final team = kick['team_name'] ?? 'Team #$slot';
                      final reason = kick['reason'] ?? 'Violation';
                      final action = kick['action'] ?? 'KICKED';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7F1D1D),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'SLOT #$slot',
                                style: AppTextStyles.monoCode.copyWith(
                                  color: const Color(0xFFFCA5A5),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    team,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Reason: $reason (T69 Team)',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: const Color(0xFFFBBF24),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                '🚫 $action',
                                style: AppTextStyles.badge.copyWith(
                                  color: const Color(0xFFEF4444),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],

            // Live Host Announcements Feed
            if (t.chatMessages.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1B4B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFFBBF24), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'HOST LIVE ANNOUNCEMENT',
                          style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (t.chatMessages.last as Map)['message']?.toString() ?? '',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 4. Tab Bar for Roster / Leaderboard / Rules / Proof / Prizes
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: AppColors.primaryDark,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: AppTextStyles.badge.copyWith(fontSize: 10, fontWeight: FontWeight.w800),
                tabs: [
                  Tab(text: 'ROSTER (${_registrations.length})'),
                  const Tab(text: 'LEADERBOARD'),
                  const Tab(text: 'RULES'),
                  const Tab(text: 'PROOF'),
                  const Tab(text: 'PRIZES'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Content
            SizedBox(
              height: 480,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Live Registered Slots Roster
                  _buildRosterView(t, userSlot, isUserRegistered),

                  // Tab 2: Live 6-Match Esports Leaderboard
                  _buildLeaderboardView(t),

                  // Tab 3: Official Tournament Rules
                  _buildRulesView(t),

                  // Tab 4: Screenshot Proof Upload
                  _buildProofUploadView(t, userIgn, userSlot ?? 1),

                  // Tab 5: Prizes & Bounties
                  _buildPrizesView(t),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Return Back Button
            TacticalButton(
              label: '← Back to Free Fire Arenas',
              variant: TacticalButtonVariant.outline,
              height: 44,
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 1. Slot Roster View (All slots)
  Widget _buildRosterView(TournamentModel t, int? userSlot, bool isUserRegistered) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final Map<int, Map<String, dynamic>> slotMap = {};
    for (final reg in _registrations) {
      final s = reg['slot_number'] as int?;
      if (s != null) slotMap[s] = reg;
    }

    final Map<int, Map<String, dynamic>> scoreSlotMap = {};
    for (final s in t.scoresList) {
      if (s is Map) {
        final slotNum = (s['slot'] as num?)?.toInt();
        if (slotNum != null) {
          scoreSlotMap[slotNum] = Map<String, dynamic>.from(s);
        }
      }
    }

    final Map<int, Map<String, dynamic>> kickedSlotMap = {};
    for (final k in t.kickedTeams) {
      final s = (k['slot'] as num?)?.toInt();
      if (s != null) {
        kickedSlotMap[s] = k;
      }
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Dedicated Disciplinary / Kicked Teams Section
        if (t.kickedTeams.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF450A0A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'HOST DISCIPLINARY LOG (${t.kickedTeams.length} REMOVED)',
                          style: AppTextStyles.badge.copyWith(
                            color: const Color(0xFFFCA5A5),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'ENFORCED',
                        style: AppTextStyles.badge.copyWith(color: const Color(0xFFEF4444), fontSize: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...t.kickedTeams.map((k) {
                  final slot = k['slot'] ?? '?';
                  final team = k['team_name'] ?? 'Slot #$slot';
                  final reason = k['reason'] ?? 'Violation of tournament rules';
                  final action = k['action'] ?? 'Kicked';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'SLOT #$slot',
                            style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$team ($action by T69 Team)',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                'Reason: $reason',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: const Color(0xFFFBBF24),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        // Slot list
        ...List.generate(t.maxSlots, (index) {
          final slotNum = index + 1;
          final reg = slotMap[slotNum];
          final scoreData = scoreSlotMap[slotNum];
          final kickedInfo = kickedSlotMap[slotNum];
          final isFilled = reg != null || (scoreData != null && (scoreData['user_id']?.toString().isNotEmpty == true));
          final isUserSlot = isUserRegistered && userSlot != null && slotNum == userSlot;
          final isSlotKicked = kickedInfo != null;

          String displayName = 'AVAILABLE SLOT';
          String subtitle = 'Open for registration';

          if (isFilled) {
            final teamName = scoreData?['team_name'] ?? reg?['team_name'];
            final rawIgn = reg?['game_ign'] ?? scoreData?['captain_ign'] ?? 'Player';
            final uid = reg?['game_uid'] ?? scoreData?['uid'] ?? '';
            final players = (scoreData?['players'] as List?)?.map((p) => p.toString()).toList();

            if (teamName != null && teamName.isNotEmpty && teamName != 'Team #$slotNum') {
              displayName = teamName;
              if (players != null && players.isNotEmpty) {
                subtitle = 'Lineup: ${players.join(', ')} • UID: $uid';
              } else {
                subtitle = 'Captain: $rawIgn • UID: $uid';
              }
            } else {
              displayName = rawIgn;
              subtitle = uid.isNotEmpty ? 'UID: $uid' : 'Confirmed Slot';
            }
          } else if (isSlotKicked) {
            final kickReason = kickedInfo['reason'] ?? 'Violation';
            subtitle = 'Vacated (Slot #$slotNum previously kicked: "$kickReason")';
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isUserSlot
                  ? AppColors.surfaceBlueTile
                  : isFilled
                      ? Colors.white
                      : isSlotKicked
                          ? const Color(0xFFFEF2F2)
                          : AppColors.surfaceSoft.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isUserSlot
                    ? AppColors.primary
                    : isSlotKicked && !isFilled
                        ? const Color(0xFFFCA5A5)
                        : isFilled
                            ? AppColors.border
                            : AppColors.borderInput,
                width: isUserSlot ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isUserSlot
                        ? AppColors.primary
                        : isFilled
                            ? AppColors.primaryDark
                            : isSlotKicked
                                ? const Color(0xFFEF4444)
                                : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      '#$slotNum',
                      style: AppTextStyles.monoCode.copyWith(
                        color: isFilled || isUserSlot || isSlotKicked ? Colors.white : Colors.grey.shade600,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              displayName,
                              style: AppTextStyles.h4.copyWith(
                                fontSize: 14,
                                color: isFilled ? AppColors.textPrimary : AppColors.textTertiary,
                                fontWeight: isFilled ? FontWeight.w800 : FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isUserSlot) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'YOU',
                                style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 8.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: isSlotKicked && !isFilled
                              ? const Color(0xFFDC2626)
                              : isFilled
                                  ? AppColors.textSecondary
                                  : AppColors.textTertiary,
                          fontWeight: isSlotKicked && !isFilled ? FontWeight.w600 : FontWeight.normal,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                StatusBadge(
                  label: isFilled
                      ? 'JOINED'
                      : isSlotKicked
                          ? 'VACATED'
                          : 'OPEN',
                  type: isFilled
                      ? BadgeType.success
                      : isSlotKicked
                          ? BadgeType.warning
                          : BadgeType.info,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // 2. Live Esports Leaderboard View (Official Battle Arena Final Standings or Clash Squad Duel)
  Widget _buildLeaderboardView(TournamentModel t) {
    if (t.isCs) {
      // 1. Try cs_result or last_completed_match from hostMeta
      Map<String, dynamic>? csResult = (t.hostMeta['cs_result'] as Map?)?.cast<String, dynamic>() ??
          (t.hostMeta['last_completed_match'] as Map?)?.cast<String, dynamic>();

      // 2. Fallback to parsing live scoresList if cs_result is not directly set
      if (csResult == null && t.scoresList.isNotEmpty) {
        final score1 = t.scoresList.firstWhere(
          (s) => s is Map && (s['slot'] as num?)?.toInt() == 1,
          orElse: () => null,
        ) as Map?;
        final score2 = t.scoresList.firstWhere(
          (s) => s is Map && (s['slot'] as num?)?.toInt() == 2,
          orElse: () => null,
        ) as Map?;

        if (score1 != null || score2 != null) {
          final isSlot1Winner = score1?['is_winner'] == true;
          final isSlot2Winner = score2?['is_winner'] == true;
          final winningSide = isSlot1Winner ? 'LEFT SIDE' : (isSlot2Winner ? 'RIGHT SIDE' : '');

          csResult = {
            'winning_side': winningSide,
            'left_score': (score1?['rounds'] as num?)?.toInt() ?? 0,
            'right_score': (score2?['rounds'] as num?)?.toInt() ?? 0,
            'left_team_name': score1?['team_name'],
            'right_team_name': score2?['team_name'],
          };
        }
      }

      // 3. Fallback to match_history if available
      if (csResult == null) {
        final matchHist = (t.hostMeta['match_history'] as List?)?.whereType<Map>().toList();
        if (matchHist != null && matchHist.isNotEmpty) {
          final lastMatch = matchHist.first;
          csResult = Map<String, dynamic>.from(lastMatch);
        }
      }

      final leftRegs = _registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 1).toList();
      final rightRegs = _registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 2).toList();

      final leftPlayers = (csResult?['left_players'] as List?)?.map((p) => p.toString()).toList() ??
          leftRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 1').toList();
      final rightPlayers = (csResult?['right_players'] as List?)?.map((p) => p.toString()).toList() ??
          rightRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 2').toList();

      final leftName = csResult?['left_team_name']?.toString() ??
          (leftRegs.isNotEmpty ? (leftRegs.first['team_name'] ?? (leftPlayers.isNotEmpty ? leftPlayers.first : 'Left Side')) : 'Left Side (Team 1)');
      final rightName = csResult?['right_team_name']?.toString() ??
          (rightRegs.isNotEmpty ? (rightRegs.first['team_name'] ?? (rightPlayers.isNotEmpty ? rightPlayers.first : 'Right Side')) : 'Right Side (Team 2)');

      final winningSide = csResult?['winning_side']?.toString() ?? '';
      final leftScore = (csResult?['left_score'] as num?)?.toInt() ?? (winningSide.toUpperCase().contains('LEFT') ? 7 : 0);
      final rightScore = (csResult?['right_score'] as num?)?.toInt() ?? (winningSide.toUpperCase().contains('RIGHT') ? 7 : 0);

      final leftKick = t.kickedTeams.firstWhere(
        (k) => (k['slot'] as num?)?.toInt() == 1,
        orElse: () => <String, dynamic>{},
      );
      final rightKick = t.kickedTeams.firstWhere(
        (k) => (k['slot'] as num?)?.toInt() == 2,
        orElse: () => <String, dynamic>{},
      );

      final isLeftBanned = csResult?['left_banned'] == true || leftKick.isNotEmpty;
      final isRightBanned = csResult?['right_banned'] == true || rightKick.isNotEmpty;
      final leftBanReason = csResult?['left_ban_reason']?.toString() ?? (leftKick['reason']?.toString());
      final rightBanReason = csResult?['right_ban_reason']?.toString() ?? (rightKick['reason']?.toString());

      final matchData = {
        'winning_side': winningSide,
        'left_score': leftScore,
        'right_score': rightScore,
        'left_team_name': leftName,
        'right_team_name': rightName,
        'left_players': leftPlayers,
        'right_players': rightPlayers,
        'left_banned': isLeftBanned,
        'right_banned': isRightBanned,
        'left_ban_reason': leftBanReason,
        'right_ban_reason': rightBanReason,
        'prize_pool': t.prizePool > 0 ? t.prizePool : 85.0,
      };

      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          ClashSquadDuelBoard(
            matchData: matchData,
            isHost: false,
            tournamentTitle: t.title,
            onExpand: () {
              ClashSquadDuelBoard.showFullScreen(
                context,
                matchData: matchData,
                tournamentTitle: t.title,
              );
            },
          ),
          const SizedBox(height: 14),
          TacticalButton(
            label: '⛶ EXPAND FULLSCREEN SCORECARD',
            icon: Icons.fullscreen_rounded,
            variant: TacticalButtonVariant.outline,
            height: 44,
            onPressed: () {
              ClashSquadDuelBoard.showFullScreen(
                context,
                matchData: matchData,
                tournamentTitle: t.title,
              );
            },
          ),
          const SizedBox(height: 14),
        ],
      );
    }

    final kickedSlotMap = <int, Map<String, dynamic>>{};
    for (final k in t.kickedTeams) {
      final s = (k['slot'] as num?)?.toInt();
      if (s != null) kickedSlotMap[s] = k;
    }

    List<Map<String, dynamic>> standings = [];

    if (t.scoresList.isNotEmpty) {
      standings = List<Map<String, dynamic>>.from(t.scoresList.whereType<Map>().map((s) {
        final map = Map<String, dynamic>.from(s);
        final slotNum = (map['slot'] as num?)?.toInt();
        if (slotNum != null && kickedSlotMap.containsKey(slotNum)) {
          map['is_banned'] = true;
          map['ban_reason'] = map['ban_reason'] ?? kickedSlotMap[slotNum]?['reason'] ?? 'Violation of Tournament Rules';
        }
        return map;
      }));
    } else if (_registrations.isNotEmpty) {
      standings = _registrations.asMap().entries.map((entry) {
        final idx = entry.key;
        final reg = entry.value;
        final slot = (reg['slot_number'] as num?)?.toInt() ?? (idx + 1);
        final ign = reg['game_ign'] ?? 'Player';
        final teamName = reg['team_name'] ?? ign;
        final isBanned = kickedSlotMap.containsKey(slot);
        return {
          'slot': slot,
          'team_name': teamName,
          'matches_count': 0,
          'placement_pts': 0,
          'kills_sum': 0,
          'total': 0,
          if (isBanned) 'is_banned': true,
          if (isBanned) 'ban_reason': kickedSlotMap[slot]?['reason'] ?? 'Removed by Host',
        };
      }).toList();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        FreeFireFinalStandingsBoard(
          standings: standings,
          isHost: false,
          tournamentTitle: t.title,
          onExpand: () {
            FreeFireFinalStandingsBoard.showFullScreen(
              context,
              standings: standings,
              isHost: false,
              tournamentTitle: t.title,
            );
          },
        ),
        const SizedBox(height: 14),
        TacticalButton(
          label: '⛶ EXPAND FULLSCREEN FINAL STANDINGS',
          icon: Icons.fullscreen_rounded,
          variant: TacticalButtonVariant.outline,
          height: 44,
          onPressed: () {
            FreeFireFinalStandingsBoard.showFullScreen(
              context,
              standings: standings,
              isHost: false,
              tournamentTitle: t.title,
            );
          },
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // 3. Screenshot Proof Upload View
  Widget _buildProofUploadView(TournamentModel t, String userIgn, int userSlot) {
    if (!t.allowScreenshots) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_rounded, size: 44, color: AppColors.textTertiary),
            const SizedBox(height: 10),
            Text('Screenshot Uploads Disabled', style: AppTextStyles.h4),
            const SizedBox(height: 4),
            Text('The match host has disabled screenshot submissions for this lobby.', style: AppTextStyles.bodySmall),
          ],
        ),
      );
    }

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SUBMIT BOOYAH / RESULT PROOF', style: AppTextStyles.h4),
              const SizedBox(height: 4),
              Text('Submit your screenshot link or proof image for quick coordinator review.', style: AppTextStyles.bodySmall),
              const SizedBox(height: 14),

              TacticalTextField(
                controller: _screenshotController,
                label: 'Screenshot Image URL',
                hint: 'e.g. https://imgur.com/your_proof.png',
                prefixIcon: Icons.link_rounded,
              ),
              const SizedBox(height: 14),

              TacticalButton(
                label: _isUploadingProof ? 'Submitting...' : 'Upload Proof to Host Coordinator',
                icon: Icons.upload_file_rounded,
                isLoading: _isUploadingProof,
                onPressed: () async {
                  final url = _screenshotController.text.trim();
                  if (url.isEmpty) {
                    UiHelpers.showErrorBanner(context, 'Please enter a valid screenshot URL.');
                    return;
                  }

                  final profile = ref.read(authControllerProvider).value;
                  final userId = profile?.id ?? userIgn;

                  final rlCheck = await RateLimiterService.checkProofUpload(userId);
                  if (!rlCheck.isAllowed) {
                    UiHelpers.vibrateError();
                    if (!mounted) return;
                    UiHelpers.showErrorBanner(
                      context,
                      rlCheck.customMessage ?? 'Please wait ${rlCheck.formattedRetryAfter} before uploading another screenshot proof.',
                    );
                    return;
                  }

                  setState(() => _isUploadingProof = true);
                  try {
                    await RateLimiterService.recordProofUploadAttempt(userId);
                    final repo = ref.read(tournamentRepoProvider);
                    await repo.uploadPlayerScreenshotProof(
                      tournamentId: t.id,
                      playerName: userIgn,
                      slotNumber: userSlot.toString(),
                      screenshotUrl: url,
                    );

                    if (mounted) {
                      setState(() => _isUploadingProof = false);
                      _screenshotController.clear();
                      UiHelpers.showSuccessBanner(context, 'Screenshot proof submitted to host coordinator!');
                      _loadLobbyDetails();
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => _isUploadingProof = false);
                      UiHelpers.showErrorBanner(context, 'Upload failed: ${e.toString()}');
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Prizes View
  Widget _buildPrizesView(TournamentModel t) {
    final isCs = t.isCs;
    final isSolo = (t.format.toLowerCase().contains('solo') || t.title.toLowerCase().contains('solo')) && !isCs;
    final isDuo = (t.format.toLowerCase().contains('duo') || t.title.toLowerCase().contains('duo')) && !isCs;
    final isSquad = (t.format.toLowerCase().contains('squad') || t.title.toLowerCase().contains('squad')) && !isCs;

    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL ARENA POOL', style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(
                    '₹${(isCs ? 85.0 : t.prizePool).toStringAsFixed(0)}',
                    style: AppTextStyles.monoCode.copyWith(
                      color: AppColors.accentYellow,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text('ENTRY FEE', style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 9)),
                    Text(
                      '₹${t.entryFee.toStringAsFixed(0)}',
                      style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        if (isCs) ...[
          _buildPrizeRow('👑 Winner Takes All (Booyah)', '₹85', 'Winning player or team real vault payout', Icons.emoji_events_rounded, const Color(0xFFFFD700)),
          const SizedBox(height: 10),
          _buildPrizeRow('🎮 Host Compensation', '₹10', 'Official coordinator match payment', Icons.verified_user_rounded, AppColors.primary),
          const SizedBox(height: 10),
          _buildPrizeRow('🛡️ Match Format', 'Best of 7 Rounds', 'Custom Clash Squad duel mode', Icons.sports_martial_arts_rounded, const Color(0xFF00E5FF)),
        ] else if (isSolo) ...[
          _buildPrizeRow('Per Kill Bounty', '₹${t.perKill.toStringAsFixed(0)} / Kill', 'Earn on every confirmed elimination', Icons.gps_fixed_rounded, AppColors.secondary),
          const SizedBox(height: 10),
          _buildPrizeRow('Max Kill Earning', '₹${(t.perKill * 15).toStringAsFixed(0)}+', 'Kill more, earn unlimited vault rewards', Icons.military_tech_rounded, AppColors.accentYellow),
        ] else if (isDuo) ...[
          _buildPrizeRow('🥇 1st Place (Booyah)', '₹170', 'Champion Duo Payout', Icons.emoji_events_rounded, const Color(0xFFFFD700)),
          const SizedBox(height: 10),
          _buildPrizeRow('🥈 2nd Place (Runner-up)', '₹130', '2nd Position Duo Payout', Icons.military_tech_rounded, const Color(0xFFC0C0C0)),
          const SizedBox(height: 10),
          _buildPrizeRow('🥉 3rd Place (Podium)', '₹100', '3rd Position Duo Payout', Icons.military_tech_rounded, const Color(0xFFCD7F32)),
        ] else if (isSquad) ...[
          _buildPrizeRow('🥇 1st Place (Booyah)', '₹110', 'Champion Squad Payout', Icons.emoji_events_rounded, const Color(0xFFFFD700)),
          const SizedBox(height: 10),
          _buildPrizeRow('🥈 2nd Place (Runner-up)', '₹90', '2nd Position Squad Payout', Icons.military_tech_rounded, const Color(0xFFC0C0C0)),
          const SizedBox(height: 10),
          _buildPrizeRow('🥉 3rd Place (Podium)', '₹60', '3rd Position Squad Payout', Icons.military_tech_rounded, const Color(0xFFCD7F32)),
        ],
      ],
    );
  }

  Widget _buildTicketStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 9.5)),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _buildRulesView(TournamentModel t) {
    if (t.isCs) {
      return ListView(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1527),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.08),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.gavel_rounded, color: Color(0xFF00E5FF), size: 18),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CLASH SQUAD ESPORTS RULES',
                          style: AppTextStyles.badge.copyWith(
                            color: const Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'OFFICIAL',
                        style: AppTextStyles.badge.copyWith(color: const Color(0xFF00E5FF), fontSize: 8.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 12),

                _buildRuleItemCard('1', 'Level 40+ Requirement', 'Free Fire account level must be above 40. Lower level accounts are not permitted to compete.', Icons.military_tech_rounded, const Color(0xFFF59E0B)),
                _buildRuleItemCard('2', 'Esports Custom Settings', 'Match played under official competitive presets (Best of 7 Rounds, 500 Coin Economy, Limited Ammo).', Icons.sports_esports_rounded, const Color(0xFF38BDF8)),
                _buildRuleItemCard('3', 'No Nade & No Throwables', 'Grenades, Smoke Grenades, Flashbangs and all other throwables are strictly prohibited in the custom room.', Icons.block_rounded, const Color(0xFFEF4444)),
                _buildRuleItemCard('4', '1 Sniper Per Team Only', 'Maximum of one sniper rifle (e.g. AWM, M82B, Kar98k) is allowed per side. Dual snipers are strictly banned.', Icons.gps_fixed_rounded, const Color(0xFFA855F7)),
                _buildRuleItemCard('5', 'Unique Skills Only', 'Each player on a team must equip distinct/unique character skills. Duplicate active skills are not allowed.', Icons.bolt_rounded, const Color(0xFFEAB308)),
                _buildRuleItemCard('6', 'Backout / Disconnect Policy', 'If you or your teammate quit, disconnect, or back out during the match, the opponent team will automatically win.', Icons.warning_amber_rounded, const Color(0xFFF97316)),
                _buildRuleItemCard('7', 'Strict No-Refund Policy', 'All entry fees are final and non-refundable once registered or when the match commences.', Icons.lock_clock_rounded, const Color(0xFF94A3B8)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF38BDF8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'If the opponent violates any rule (throwables, 2 snipers, duplicate skills), capture screenshot/video and upload under the PROOF tab for host verification.',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Battle Royale (Solo/Duo/Squad) rules
    return ListView(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.rule_folder_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('BATTLE ROYALE ARENA RULES', style: AppTextStyles.h4),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 12),
              _buildRuleItemLight('1', 'Level 40+ Account', 'Players must use a valid Level 40+ Free Fire account matching registered IGN & UID.'),
              _buildRuleItemLight('2', 'Assigned Slot Only', 'Sit strictly in your assigned slot number. Occupying wrong slots will cause an instant kick/ban.'),
              _buildRuleItemLight('3', 'Fair Play & Anti-Teaming', 'Zero tolerance for teaming in Solo mode, emulators without permission, or third-party modifications.'),
              _buildRuleItemLight('4', 'Result Verification', 'Official host verifies kill scorecards and match placements for prize distribution.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRuleItemCard(String num, String title, String desc, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItemLight(String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceBlueTile,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              num,
              style: AppTextStyles.monoCode.copyWith(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrizeRow(String title, String reward, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            radius: 20,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.h4),
                Text(subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            reward,
            style: AppTextStyles.monoCode.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
            ),
          ),
        ],
      ),
    );
  }
}

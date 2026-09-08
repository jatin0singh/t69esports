import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../tournaments/utils/lobby_schedule_helper.dart';
import '../../auth/controllers/auth_controller.dart';
import '../widgets/host_rules_modal.dart';
import 'host_dashboard_screen.dart';

class HostLobbiesScreen extends ConsumerStatefulWidget {
  const HostLobbiesScreen({super.key});

  @override
  ConsumerState<HostLobbiesScreen> createState() => _HostLobbiesScreenState();
}

class _HostLobbiesScreenState extends ConsumerState<HostLobbiesScreen> {
  // Main Modes: 'SOLO', 'DUO', 'SQUAD', 'CLASH SQUAD'
  String _selectedMainMode = 'SOLO';

  // Solo Sub-Tier: 15 for ₹15 lobby, 20 for ₹20 lobby
  int _selectedSoloTier = 15;

  // Clash Squad Sub-Tier: '1v1', '2v2', '4v4'
  String _selectedCsTier = '1v1';

  bool _isLoading = false;
  List<TournamentModel> _allTournaments = [];

  @override
  void initState() {
    super.initState();
    _loadLobbies();
  }

  Future<void> _loadLobbies() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final list = await repo.fetchAllTournamentsForHost();
      if (mounted) {
        setState(() {
          _allTournaments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        UiHelpers.showErrorBanner(context, 'Failed to load host lobbies: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).value;
    final currentUserId = profile?.id ?? '';

    // Filter tournaments based on active mode
    List<TournamentModel> activeTournaments = [];
    if (_selectedMainMode == 'SOLO') {
      activeTournaments = _allTournaments
          .where((t) => t.format.toLowerCase().contains('solo') && t.entryFee.toInt() == _selectedSoloTier)
          .toList();
    } else if (_selectedMainMode == 'DUO') {
      activeTournaments = _allTournaments
          .where((t) => t.format.toLowerCase().contains('duo') && !t.format.toLowerCase().contains('2v2'))
          .toList();
    } else if (_selectedMainMode == 'SQUAD') {
      activeTournaments = _allTournaments
          .where((t) => t.format.toLowerCase().contains('squad') && !t.format.toLowerCase().contains('4v4') && !t.format.toLowerCase().contains('clash'))
          .toList();
    } else if (_selectedMainMode == 'CLASH SQUAD') {
      activeTournaments = _allTournaments
          .where((t) => t.format.toLowerCase().contains(_selectedCsTier.toLowerCase()))
          .toList();
    }

    // Sort by match start time ascending, then title
    activeTournaments.sort((a, b) {
      final aTime = LobbyScheduleHelper.getEffectiveStartTime(a);
      final bTime = LobbyScheduleHelper.getEffectiveStartTime(b);
      final timeCmp = aTime.compareTo(bTime);
      if (timeCmp != 0) return timeCmp;
      return a.title.compareTo(b.title);
    });

    int myHostedCount = 0;
    for (final t in _allTournaments) {
      if (t.hostId == currentUserId) myHostedCount++;
    }

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
              'Free Fire Host Arenas',
              style: AppTextStyles.h3.copyWith(color: Colors.white),
            ),
            Text(
              'Host & Manage Custom Rooms • Earn ₹30 / Match',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10.5),
            ),
          ],
        ),
        actions: [
          // My Claimed Matches Pill
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  '$myHostedCount Hosted',
                  style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadLobbies,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: Colors.white,
        onRefresh: _loadLobbies,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          children: [
            // 0. PARTNER MODE TOGGLE BAR (Like Ola/Uber Client vs Driver mode)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1B4B),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.sports_esports_rounded, color: Colors.white70, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '🎮 Switch to Player Mode',
                              style: AppTextStyles.badge.copyWith(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shield_rounded, color: Color(0xFFFBBF24), size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Host Partner Mode',
                            style: AppTextStyles.badge.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                        Text('₹400 Prize Pool', style: AppTextStyles.h3.copyWith(fontSize: 17)),
                        Text('₹25 Entry / Duo • 24 Teams', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'HOST REWARD: ₹30',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
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
                        Text('6-MATCH ESPORTS SQUAD POOL', style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark)),
                        const SizedBox(height: 2),
                        Text('₹260 Prize Pool', style: AppTextStyles.h3.copyWith(fontSize: 17)),
                        Text('₹30 Entry / Squad • 12 Squads', style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'HOST REWARD: ₹30',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
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
                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'HOST REWARD: ₹10',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // 4. LOBBY CARDS
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
            ] else if (activeTournaments.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text('No host lobbies configured in this mode.', style: AppTextStyles.bodyMedium),
                ),
              ),
            ] else ...[
              ...activeTournaments.asMap().entries.map((entry) {
                final index = entry.key;
                final t = entry.value;
                return _buildHostTournamentCard(t, index, currentUserId);
              }),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHostTournamentCard(TournamentModel t, int index, String currentUserId) {
    final isMyClaim = t.hostId == currentUserId;
    final isClaimed = t.isClaimed;
    final isFull = t.filledSlots >= t.maxSlots;
    final progress = (t.filledSlots / t.maxSlots).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMyClaim
              ? AppColors.primary
              : isClaimed
                  ? AppColors.success.withValues(alpha: 0.6)
                  : AppColors.primary.withValues(alpha: 0.6),
          width: isMyClaim ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Badges Row
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
                      if (isMyClaim) ...[
                        StatusBadge(
                          label: ((t.isIdpLocked && t.isClaimed) || t.status.toLowerCase() == 'live') ? 'MATCH LIVE // HOST PANEL' : 'HOSTED BY YOU',
                          type: BadgeType.success,
                        ),
                      ] else if (isClaimed) ...[
                        StatusBadge(
                          label: ((t.isIdpLocked && t.isClaimed) || t.status.toLowerCase() == 'live') ? 'HOSTED BOOKED (LIVE)' : 'HOSTED BOOKED',
                          type: BadgeType.neutral,
                        ),
                      ] else ...[
                        StatusBadge(
                          label: isFull ? 'LOBBY FULL // UNCLAIMED' : 'LOBBY #${index + 1} // OPEN TO HOST',
                          type: isFull ? BadgeType.danger : BadgeType.primary,
                        ),
                      ],
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${t.maxSlots} SLOTS',
                  style: AppTextStyles.badge.copyWith(
                    color: AppColors.primaryDark,
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
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 14),

            // 3 Key Metrics Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      Text('ENTRY FEE', style: AppTextStyles.badge.copyWith(fontSize: 9, color: AppColors.textTertiary)),
                      const SizedBox(height: 2),
                      Text(
                        '₹${t.entryFee.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(
                          color: AppColors.primaryDark,
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
                            color: AppColors.accentOrange,
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
                            color: AppColors.accentOrange,
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
                            color: AppColors.accentOrange,
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
                          color: AppColors.success,
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
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

            // Slots Progress Bar
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
                  isFull ? AppColors.secondary : AppColors.primary,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Host Reward Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMyClaim
                    ? AppColors.surfaceBlueTile
                    : isClaimed
                        ? const Color(0xFFFEF2F2)
                        : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMyClaim
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : isClaimed
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isMyClaim
                        ? Icons.verified_user_rounded
                        : isClaimed
                            ? Icons.lock_rounded
                            : Icons.monetization_on_rounded,
                    color: isMyClaim
                        ? AppColors.primaryDark
                        : isClaimed
                            ? const Color(0xFFDC2626)
                            : const Color(0xFFD97706),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isMyClaim
                          ? 'You are the official match coordinator (Reward: ₹${t.actualHostReward})'
                          : isClaimed
                              ? '🔒 HOSTED BOOKED • Claimed by ${t.hostName ?? "Official Host"} (IGN: ${t.hostIgn ?? "Host"})'
                              : 'Standard Host Compensation: Earn ₹${t.baseHostReward} upon match completion',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isMyClaim
                            ? AppColors.primaryDark
                            : isClaimed
                                ? const Color(0xFF991B1B)
                                : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Host Action Buttons (Instead of Register Lobby)
            if (isMyClaim) ...[
              TacticalButton(
                label: '⚡ OPEN HOST CONTROL PANEL',
                icon: Icons.dashboard_customize_rounded,
                height: 44,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HostDashboardScreen(tournament: t),
                  ),
                ),
              ),
            ] else if (isClaimed) ...[
              TacticalButton(
                label: '🔒 HOSTED BOOKED (${t.hostName?.toUpperCase() ?? "ASSIGNED"})',
                icon: Icons.lock_outline_rounded,
                variant: TacticalButtonVariant.secondary,
                height: 44,
                onPressed: null,
              ),
            ] else ...[
              TacticalButton(
                label: '⚡ HOST THIS LOBBY (EARN ₹${t.baseHostReward})',
                icon: Icons.assignment_turned_in_rounded,
                height: 44,
                onPressed: () => HostRulesModal.show(context, t, _loadLobbies),
              ),
            ],
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: AppTextStyles.badge.copyWith(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 10,
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

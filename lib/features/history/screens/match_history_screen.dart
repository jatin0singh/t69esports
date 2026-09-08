import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/johnny_error_widget.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../freefire/widgets/clash_squad_duel_board.dart';
import '../../freefire/screens/freefire_hub_screen.dart';

class MatchHistoryScreen extends ConsumerStatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  ConsumerState<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends ConsumerState<MatchHistoryScreen> {
  String _selectedFilter = 'ALL'; // 'ALL', 'MY PRIZES', 'CLASH SQUAD', 'BATTLE ROYALE'

  @override
  Widget build(BuildContext context) {
    final historyState = ref.watch(matchHistoryProvider);
    final profile = ref.watch(authControllerProvider).value;
    final userIgn = profile?.gameIgn?.toLowerCase() ?? '';
    final userId = profile?.id ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.headerBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Match & Prize History', style: AppTextStyles.h3.copyWith(color: Colors.white)),
            Text('Matches you played & real prizes won', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Refresh History',
            onPressed: () => ref.invalidate(matchHistoryProvider),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All My Matches', Icons.all_inclusive_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('MY PRIZES', 'Won & Prizes', Icons.emoji_events_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('CLASH SQUAD', 'Clash Squad Duels', Icons.sports_martial_arts_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('BATTLE ROYALE', 'Battle Royale', Icons.shield_outlined),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Match List
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: () async => ref.invalidate(matchHistoryProvider),
              child: historyState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (e, _) => JohnnyErrorWidget(
                  customMessage: 'Failed to load your match history. Please check your network and retry.',
                  onRetry: () => ref.invalidate(matchHistoryProvider),
                ),
                data: (allMatches) {
                  // Apply Filters
                  final filtered = allMatches.where((m) {
                    final type = m['type']?.toString().toLowerCase() ?? '';
                    final format = m['format']?.toString().toLowerCase() ?? '';
                    final isCs = type == 'clash_squad' || format.contains('cs') || format.contains('clash') || format.contains('1v1') || format.contains('2v2') || format.contains('4v4');

                    if (_selectedFilter == 'CLASH SQUAD') return isCs;
                    if (_selectedFilter == 'BATTLE ROYALE') return !isCs;
                    if (_selectedFilter == 'MY PRIZES') {
                      final winnerIds = (m['winner_ids'] as List?)?.map((id) => id.toString()).toSet() ?? {};
                      if (userId.isNotEmpty && winnerIds.contains(userId)) return true;

                      final participants = (m['participants'] as List?)?.whereType<Map>().toList() ?? [];
                      for (final p in participants) {
                        final pUid = p['user_id']?.toString() ?? '';
                        final pIgn = p['game_ign']?.toString().toLowerCase() ?? '';
                        final prize = (p['prize'] as num?)?.toDouble() ?? 0.0;
                        if ((pUid == userId || (userIgn.isNotEmpty && pIgn == userIgn)) && prize > 0) {
                          return true;
                        }
                      }

                      if (m['top1_user_id'] == userId || m['top2_user_id'] == userId || m['top3_user_id'] == userId) return true;
                      if (m['user_id'] == userId || m['winner_id'] == userId) return true;

                      // Clash squad winner side check
                      if (isCs) {
                        final winningSide = m['winning_side']?.toString().toUpperCase() ?? '';
                        final isLeftWinner = winningSide.contains('LEFT') || winningSide.contains('1');
                        final isRightWinner = winningSide.contains('RIGHT') || winningSide.contains('2');
                        final leftPlayers = (m['left_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];
                        final rightPlayers = (m['right_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];
                        if (userIgn.isNotEmpty) {
                          if (isLeftWinner && leftPlayers.any((p) => p == userIgn || p.contains(userIgn))) return true;
                          if (isRightWinner && rightPlayers.any((p) => p == userIgn || p.contains(userIgn))) return true;
                        }
                      }

                      // Host reward check
                      if (m['host_id'] == userId && ((m['host_reward'] as num?)?.toDouble() ?? 0.0) > 0) {
                        return true;
                      }

                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(22),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceBlueTile,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                                  ),
                                  child: const Icon(Icons.sports_esports_rounded, size: 52, color: AppColors.primary),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _selectedFilter == 'ALL'
                                      ? 'No Match History Found'
                                      : 'No $_selectedFilter Records Found',
                                  style: AppTextStyles.h3,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _selectedFilter == 'ALL'
                                      ? 'You have not played in any completed tournament matches yet. Join a live custom lobby to compete, earn Booyahs, and claim real cash prizes!'
                                      : _selectedFilter == 'MY PRIZES'
                                          ? 'You haven\'t won any match prize payouts yet. Join arenas to score kills, win Booyahs, and build your earnings history!'
                                          : 'No matches played in the $_selectedFilter category.',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                TacticalButton(
                                  label: '🎮 Browse Free Fire Arenas',
                                  height: 48,
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => const FreeFireHubScreen()),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, idx) {
                      final match = filtered[idx];
                      final type = match['type']?.toString().toLowerCase() ?? '';
                      final isSoloPerKill = type == 'solo_per_kill';
                      final isCs = (type == 'clash_squad') ||
                          (match['format']?.toString().toLowerCase().contains('cs') == true) ||
                          (match['format']?.toString().toLowerCase().contains('1v1') == true) ||
                          (match['format']?.toString().toLowerCase().contains('2v2') == true) ||
                          (match['format']?.toString().toLowerCase().contains('4v4') == true);

                      if (isCs) {
                        return _buildClashSquadHistoryCard(match, userId, userIgn);
                      } else if (isSoloPerKill) {
                        return _buildSoloPerKillHistoryCard(match, userId, userIgn);
                      } else {
                        return _buildBattleRoyaleHistoryCard(match, userId, userIgn);
                      }
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, IconData icon) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTextStyles.badge.copyWith(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClashSquadHistoryCard(Map<String, dynamic> match, String currentUserId, String currentUserIgn) {
    final title = match['title'] ?? 'Clash Squad Duel';
    final format = match['format'] ?? '1v1 Duel';
    final winningSide = match['winning_side']?.toString() ?? 'LEFT SIDE';
    final winningTeamName = match['winning_team_name'] ?? winningSide;
    final leftName = match['left_team_name'] ?? 'Side A';
    final rightName = match['right_team_name'] ?? 'Side B';
    final leftScore = (match['left_score'] as num?)?.toInt() ?? 7;
    final rightScore = (match['right_score'] as num?)?.toInt() ?? 3;
    final prizePool = (match['prize_pool'] as num?)?.toDouble() ?? 85.0;
    final hostName = match['host_name'] ?? 'T69 Team';
    final hostId = match['host_id']?.toString() ?? '';
    final hostReward = (match['host_reward'] as num?)?.toInt() ?? 10;
    final dateStr = match['completed_at'] != null
        ? DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.tryParse(match['completed_at'].toString())?.toLocal() ?? DateTime.now())
        : 'Completed';

    final isHost = currentUserId.isNotEmpty && hostId == currentUserId;
    final isLeftWinner = winningSide.toUpperCase().contains('LEFT') || winningSide.contains('1');
    final isRightWinner = winningSide.toUpperCase().contains('RIGHT') || winningSide.contains('2');

    final leftPlayers = (match['left_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];
    final rightPlayers = (match['right_players'] as List?)?.map((p) => p.toString().toLowerCase()).toList() ?? [];

    final isUserOnLeft = (currentUserIgn.isNotEmpty && leftPlayers.any((p) => p == currentUserIgn || p.contains(currentUserIgn)));
    final isUserOnRight = (currentUserIgn.isNotEmpty && rightPlayers.any((p) => p == currentUserIgn || p.contains(currentUserIgn)));

    final winnerIds = (match['winner_ids'] as List?)?.map((id) => id.toString()).toSet() ?? {};
    final isUserWinner = (currentUserId.isNotEmpty && winnerIds.contains(currentUserId)) ||
        (isUserOnLeft && isLeftWinner) ||
        (isUserOnRight && isRightWinner);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUserWinner
              ? const Color(0xFF10B981)
              : const Color(0xFF00E5FF).withValues(alpha: 0.5),
          width: isUserWinner ? 1.8 : 1.2,
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
          // Card Header Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isUserWinner
                    ? const [Color(0xFF064E3B), Color(0xFF047857)]
                    : const [Color(0xFF070E24), Color(0xFF0F1E4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isUserWinner ? Icons.emoji_events_rounded : Icons.sports_martial_arts_rounded,
                      color: isUserWinner ? const Color(0xFFFBBF24) : const Color(0xFF00E5FF),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isUserWinner
                          ? 'VICTORY • $format'
                          : 'CLASH SQUAD DUEL • $format',
                      style: AppTextStyles.badge.copyWith(
                        color: isUserWinner ? const Color(0xFFFBBF24) : const Color(0xFF00E5FF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Text(
                  dateStr,
                  style: AppTextStyles.monoCode.copyWith(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(title, style: AppTextStyles.h4.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
                    ),
                    if (isUserWinner)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981)),
                        ),
                        child: Text(
                          '🏆 YOU WON',
                          style: AppTextStyles.badge.copyWith(color: const Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      )
                    else if (isHost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF6366F1)),
                        ),
                        child: Text(
                          '🎮 HOST',
                          style: AppTextStyles.badge.copyWith(color: const Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.w900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Duel Versus Summary Row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceBlueTile,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      // Left Side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('LEFT SIDE', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textSecondary)),
                            Text(
                              leftName,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Score Center
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$leftScore - $rightScore',
                          style: AppTextStyles.monoCode.copyWith(
                            color: const Color(0xFF00E5FF),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      // Right Side
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('RIGHT SIDE', style: AppTextStyles.badge.copyWith(fontSize: 8.5, color: AppColors.textSecondary)),
                            Text(
                              rightName,
                              style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Winner & Prize Strip
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('WINNER & PRIZE PAYOUT', style: AppTextStyles.badge.copyWith(fontSize: 8, color: AppColors.textSecondary)),
                            Text(
                              '👑 $winningTeamName (₹${prizePool.toStringAsFixed(0)})',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: const Color(0xFF16A34A),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    TacticalButton(
                      label: 'Scorecard',
                      icon: Icons.fullscreen_rounded,
                      height: 34,
                      isFullWidth: false,
                      variant: TacticalButtonVariant.outline,
                      onPressed: () {
                        ClashSquadDuelBoard.showFullScreen(
                          context,
                          matchData: match,
                          tournamentTitle: title,
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Host: $hostName (₹$hostReward compensation paid)',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoloPerKillHistoryCard(Map<String, dynamic> match, String currentUserId, String currentUserIgn) {
    final title = match['title'] ?? 'Solo Free Fire Match';
    final format = match['format'] ?? 'Solo BR';
    final perKillRate = (match['per_kill_rate'] as num?)?.toDouble() ?? 9.0;
    final totalKills = (match['total_kills'] as num?)?.toInt() ?? 0;
    final totalPayout = (match['total_payout'] as num?)?.toDouble() ?? 0.0;
    final hostName = match['host_name'] ?? 'T69 Team';
    final hostId = match['host_id']?.toString() ?? '';
    final hostReward = (match['host_reward'] as num?)?.toInt() ?? 15;
    final dateStr = match['completed_at'] != null
        ? DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.tryParse(match['completed_at'].toString())?.toLocal() ?? DateTime.now())
        : 'Completed';

    final isHost = currentUserId.isNotEmpty && hostId == currentUserId;

    // Find current user's kills and prize from participants or leaderboard
    int userKills = 0;
    double userPrize = 0.0;

    final participants = (match['participants'] as List?)?.whereType<Map>().toList() ?? [];
    for (final p in participants) {
      final pUid = p['user_id']?.toString() ?? '';
      final pIgn = p['game_ign']?.toString().toLowerCase() ?? '';
      if (pUid == currentUserId || (currentUserIgn.isNotEmpty && pIgn == currentUserIgn)) {
        userKills = (p['kills'] as num?)?.toInt() ?? 0;
        userPrize = (p['prize'] as num?)?.toDouble() ?? (userKills * perKillRate);
      }
    }

    if (userKills == 0 && userPrize == 0.0) {
      final leaderboard = (match['leaderboard'] as List?)?.whereType<Map>().toList() ?? [];
      for (final p in leaderboard) {
        final pUid = p['user_id']?.toString() ?? '';
        final pIgn = (p['captain_ign'] ?? p['game_ign'] ?? p['team_name'])?.toString().toLowerCase() ?? '';
        if (pUid == currentUserId || (currentUserIgn.isNotEmpty && pIgn == currentUserIgn)) {
          userKills = (p['kills_sum'] as num?)?.toInt() ?? 0;
          userPrize = userKills * perKillRate;
        }
      }
    }

    final hasUserEarned = userPrize > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUserEarned ? const Color(0xFF10B981) : AppColors.border,
          width: hasUserEarned ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('💀 ${format.toUpperCase()}', style: AppTextStyles.badge.copyWith(color: AppColors.secondary, fontSize: 9.5, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(width: 8),
                    Text('₹${perKillRate.toStringAsFixed(0)}/Kill', style: AppTextStyles.badge.copyWith(color: AppColors.textSecondary, fontSize: 10)),
                  ],
                ),
                Text(dateStr, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: AppTextStyles.h4),
                ),
                if (hasUserEarned)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      '🏆 WON PRIZE',
                      style: AppTextStyles.badge.copyWith(color: const Color(0xFF059669), fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  )
                else if (isHost)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6366F1)),
                    ),
                    child: Text(
                      '🎮 HOST',
                      style: AppTextStyles.badge.copyWith(color: const Color(0xFF4F46E5), fontSize: 9, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (hasUserEarned) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'YOU GOT $userKills KILLS',
                          style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Text(
                      '₹${userPrize.toStringAsFixed(0)} EARNED',
                      style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFFBBF24), fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Eliminations: $totalKills Kills', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    '₹${totalPayout.toStringAsFixed(0)} Total Paid',
                    style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Host: $hostName (₹$hostReward compensation)',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattleRoyaleHistoryCard(Map<String, dynamic> match, String currentUserId, String currentUserIgn) {
    final title = match['title'] ?? 'Battle Royale Match';
    final format = match['format'] ?? 'Squad BR';
    final top1Name = match['top1_team'] ?? 'Champion';
    final top1Prize = (match['top1_prize'] as num?)?.toDouble() ?? 110.0;
    final top2Name = match['top2_team'];
    final top2Prize = (match['top2_prize'] as num?)?.toDouble() ?? 0.0;
    final top3Name = match['top3_team'];
    final top3Prize = (match['top3_prize'] as num?)?.toDouble() ?? 0.0;
    final hostName = match['host_name'] ?? 'T69 Team';
    final hostReward = (match['host_reward'] as num?)?.toInt() ?? 30;

    final dateStr = match['completed_at'] != null
        ? DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.tryParse(match['completed_at'].toString())?.toLocal() ?? DateTime.now())
        : 'Completed';

    final isTop1 = match['top1_user_id'] == currentUserId;
    final isTop2 = match['top2_user_id'] == currentUserId;
    final isTop3 = match['top3_user_id'] == currentUserId;
    final userWonPrize = isTop1 ? top1Prize : (isTop2 ? top2Prize : (isTop3 ? top3Prize : 0.0));
    final hasUserWon = userWonPrize > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasUserWon ? const Color(0xFF10B981) : AppColors.border,
          width: hasUserWon ? 1.8 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(format.toUpperCase(), style: AppTextStyles.badge.copyWith(color: AppColors.primaryDark, fontSize: 10, fontWeight: FontWeight.w900)),
                    if (hasUserWon) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isTop1 ? '🥇 1ST PLACE' : (isTop2 ? '🥈 2ND PLACE' : '🥉 3RD PLACE'),
                          style: AppTextStyles.badge.copyWith(color: const Color(0xFF059669), fontSize: 8.5, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(dateStr, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.h4),
            const SizedBox(height: 10),

            if (hasUserWon) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF064E3B), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isTop1 ? 'YOU WON 1ST PLACE' : (isTop2 ? 'YOU WON 2ND PLACE' : 'YOU WON 3RD PLACE'),
                          style: AppTextStyles.badge.copyWith(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    Text(
                      '₹${userWonPrize.toStringAsFixed(0)}',
                      style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFFBBF24), fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
              ),
            ],

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceBlueTile,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🥇 1st: $top1Name', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '₹${top1Prize.toStringAsFixed(0)}',
                        style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF16A34A), fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                  if (top2Name != null && top2Prize > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🥈 2nd: $top2Name', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('₹${top2Prize.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                  if (top3Name != null && top3Prize > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('🥉 3rd: $top3Name', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                        Text('₹${top3Prize.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(fontSize: 11)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Host: $hostName (₹$hostReward compensation)',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

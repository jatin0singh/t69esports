import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';

class ClashSquadDuelBoard extends StatelessWidget {
  final Map<String, dynamic> matchData;
  final bool isHost;
  final bool isFullScreen;
  final String tournamentTitle;
  final VoidCallback? onExpand;

  const ClashSquadDuelBoard({
    super.key,
    required this.matchData,
    this.isHost = false,
    this.isFullScreen = false,
    this.tournamentTitle = 'CLASH SQUAD DUEL (BEST OF 7)',
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final winningSide = matchData['winning_side']?.toString().toUpperCase() ?? '';
    final isLeftWinner = winningSide.contains('LEFT') || winningSide == 'SIDE A' || winningSide == '1' || winningSide == 'TEAM 1';
    final isRightWinner = winningSide.contains('RIGHT') || winningSide == 'SIDE B' || winningSide == '2' || winningSide == 'TEAM 2';
    final isSettled = isLeftWinner || isRightWinner;

    final leftScore = (matchData['left_score'] as num?)?.toInt() ?? (isLeftWinner ? 7 : 0);
    final rightScore = (matchData['right_score'] as num?)?.toInt() ?? (isRightWinner ? 7 : 0);

    final leftName = matchData['left_team_name']?.toString() ?? 'Player 1 (Left Side)';
    final rightName = matchData['right_team_name']?.toString() ?? 'Player 2 (Right Side)';

    final leftPlayers = (matchData['left_players'] as List?)?.map((p) => p.toString()).toList() ?? [];
    final rightPlayers = (matchData['right_players'] as List?)?.map((p) => p.toString()).toList() ?? [];

    final leftBanned = matchData['left_banned'] == true || leftName.toUpperCase().contains('BANNED');
    final rightBanned = matchData['right_banned'] == true || rightName.toUpperCase().contains('BANNED');
    final leftBanReason = matchData['left_ban_reason']?.toString() ?? '';
    final rightBanReason = matchData['right_ban_reason']?.toString() ?? '';
    final prizeAmount = (matchData['prize_pool'] as num?)?.toDouble() ?? 85.0;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF070E24), Color(0xFF0F1E4A), Color(0xFF060B1E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isFullScreen ? 0 : 20),
        border: isFullScreen ? null : Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. TOP HEADER BANNER
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)]),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.sports_martial_arts_rounded, color: Color(0xFF05112E), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CLASH SQUAD ARENA',
                              style: AppTextStyles.badge.copyWith(
                                color: const Color(0xFF00E5FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.0,
                              ),
                            ),
                            Text(
                              tournamentTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.monoCode.copyWith(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSettled ? const Color(0xFF052e16) : const Color(0xFF0D1B48),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSettled ? const Color(0xFF22c55e) : const Color(0xFF00E5FF).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        isSettled ? 'FINAL RESULT' : 'LIVE DUEL',
                        style: AppTextStyles.monoCode.copyWith(
                          color: isSettled ? const Color(0xFF4ade80) : const Color(0xFF00E5FF),
                          fontWeight: FontWeight.w900,
                          fontSize: 9.5,
                        ),
                      ),
                    ),
                    if (onExpand != null && !isFullScreen) ...[
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFF00E5FF), size: 22),
                        tooltip: 'Expand Fullscreen',
                        onPressed: onExpand,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // 2. DUAL MATCHUP CARDS & SCOREBOARD
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT SIDE (SIDE A / TEAM 1)
                Expanded(
                  child: _buildSideCard(
                    sideTitle: 'LEFT SIDE (TEAM 1)',
                    teamName: leftName,
                    roundsWon: leftScore,
                    isWinner: isLeftWinner,
                    isSettled: isSettled,
                    isBanned: leftBanned,
                    banReason: leftBanReason,
                    prizeText: isLeftWinner ? '₹${prizeAmount.toStringAsFixed(0)}' : '₹0',
                    players: leftPlayers,
                    isLeftSide: true,
                  ),
                ),

                // VS CENTER BADGE
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F1E4A),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: Text(
                          'VS',
                          style: AppTextStyles.monoCode.copyWith(
                            color: AppColors.accentOrange,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'BEST OF 7',
                        style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 8),
                      ),
                    ],
                  ),
                ),

                // RIGHT SIDE (SIDE B / TEAM 2)
                Expanded(
                  child: _buildSideCard(
                    sideTitle: 'RIGHT SIDE (TEAM 2)',
                    teamName: rightName,
                    roundsWon: rightScore,
                    isWinner: isRightWinner,
                    isSettled: isSettled,
                    isBanned: rightBanned,
                    banReason: rightBanReason,
                    prizeText: isRightWinner ? '₹${prizeAmount.toStringAsFixed(0)}' : '₹0',
                    players: rightPlayers,
                    isLeftSide: false,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. PRIZE POOL & ECONOMICS STRIP
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1E4A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF1E3A8A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events_rounded, color: Color(0xFFFBBF24), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'WINNER PRIZE: ₹${prizeAmount.toStringAsFixed(0)}',
                      style: AppTextStyles.monoCode.copyWith(
                        color: const Color(0xFFFBBF24),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Entry: ₹50/Side • Host: ₹10',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 4. CLASH SQUAD ESPORTS RULES TICKER
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF05112E),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'RULES',
                    style: AppTextStyles.badge.copyWith(color: const Color(0xFF00E5FF), fontSize: 8.5, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Level 40+ • No Nade/Throwables • 1 Sniper • Unique Skills • No Backout • No Refund',
                    style: AppTextStyles.monoCode.copyWith(color: Colors.white70, fontSize: 9.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildSideCard({
    required String sideTitle,
    required String teamName,
    required int roundsWon,
    required bool isWinner,
    required bool isSettled,
    required String prizeText,
    required List<String> players,
    required bool isLeftSide,
    bool isBanned = false,
    String banReason = '',
  }) {
    final badgeColor = isBanned
        ? const Color(0xFFEF4444)
        : isSettled
            ? (isWinner ? const Color(0xFF22C55E) : const Color(0xFF64748B))
            : const Color(0xFF38BDF8);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBanned
            ? const Color(0xFF3B0B0B)
            : isWinner
                ? const Color(0xFF0F2E2B)
                : const Color(0xFF131C38),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isBanned
              ? const Color(0xFFEF4444)
              : isWinner
                  ? const Color(0xFF10B981)
                  : (isSettled ? const Color(0xFF334155) : const Color(0xFF1E3A8A)),
          width: (isWinner || isBanned) ? 1.8 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Side Title
          Text(
            sideTitle,
            style: AppTextStyles.badge.copyWith(
              color: isBanned ? const Color(0xFFFCA5A5) : const Color(0xFFA5B4FC),
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),

          // Team Name
          Text(
            teamName,
            style: AppTextStyles.h4.copyWith(
              color: isBanned ? const Color(0xFFFCA5A5) : Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (isBanned && banReason.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Reason: $banReason',
              style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFF87171), fontSize: 9.5, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 8),

          // Big Round Score Block
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF090E20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Text(
                  '$roundsWon',
                  style: AppTextStyles.monoCode.copyWith(
                    color: isBanned ? const Color(0xFFEF4444) : (isWinner ? const Color(0xFF4ADE80) : Colors.white),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'ROUNDS WON',
                  style: AppTextStyles.badge.copyWith(
                    color: Colors.white54,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Status & Prize Badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            decoration: BoxDecoration(
              color: isBanned
                  ? const Color(0xFF991B1B)
                  : isWinner
                      ? const Color(0xFF16A34A)
                      : (isSettled ? const Color(0xFF334155) : const Color(0xFF0369A1)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isBanned
                  ? '🚫 DISQUALIFIED (₹0)'
                  : isSettled
                      ? (isWinner ? '👑 VICTORY ($prizeText)' : '❌ DEFEAT (₹0)')
                      : 'READY',
              style: AppTextStyles.monoCode.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 9.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          if (players.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 6),
            ...players.take(4).map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  '• $p',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static void showFullScreen(
    BuildContext context, {
    required Map<String, dynamic> matchData,
    String tournamentTitle = 'CLASH SQUAD DUEL FINAL STANDINGS',
  }) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: const Color(0xFF04060A),
          appBar: AppBar(
            backgroundColor: const Color(0xFF070E24),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Clash Squad Duel Standings', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                Text(tournamentTitle, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF00E5FF), fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF00E5FF)),
                tooltip: 'Copy Match Card',
                onPressed: () {
                  final winningSide = matchData['winning_side'] ?? 'TBD';
                  final left = matchData['left_team_name'] ?? 'Side A';
                  final right = matchData['right_team_name'] ?? 'Side B';
                  final lScore = matchData['left_score'] ?? 0;
                  final rScore = matchData['right_score'] ?? 0;
                  final prize = matchData['prize_pool'] ?? 85;

                  final buffer = StringBuffer();
                  buffer.writeln('🎮 T69 ESPORTS - CLASH SQUAD DUEL RESULT');
                  buffer.writeln('🏆 Match: $tournamentTitle');
                  buffer.writeln('⚔️ Score: $left ($lScore) vs $right ($rScore)');
                  buffer.writeln('👑 WINNER: $winningSide (Prize: ₹$prize)');

                  Clipboard.setData(ClipboardData(text: buffer.toString()));
                  UiHelpers.showSuccessBanner(context, 'Clash Squad result copied to clipboard!');
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: ClashSquadDuelBoard(
                matchData: matchData,
                isFullScreen: true,
                tournamentTitle: tournamentTitle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/utils/ui_helpers.dart';

class FreeFireFinalStandingsBoard extends StatelessWidget {
  final List<Map<String, dynamic>> standings;
  final bool isHost;
  final bool isFullScreen;
  final String tournamentTitle;
  final Function(int slot, String teamName, int matches, int placePts, int killPts)? onEditScore;
  final VoidCallback? onExpand;

  const FreeFireFinalStandingsBoard({
    super.key,
    required this.standings,
    this.isHost = false,
    this.isFullScreen = false,
    this.tournamentTitle = 'T69 ESPORTS ARENA',
    this.onEditScore,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isCompact = availableWidth < 520;
        final isVeryCompact = availableWidth < 380;

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF070E24), Color(0xFF0F1E4A), Color(0xFF060B1E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isFullScreen ? 0 : 16),
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
              // 1. TOP HEADER BANNER (Crest, Glowing Title & T69 Logo)
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 10 : 16, isCompact ? 12 : 16, isCompact ? 10 : 16, 10),
                child: Row(
                  children: [
                    // Left: Crest & Arena Subtitle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isCompact ? 4 : 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00B0FF), Color(0xFF00E5FF)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(Icons.shield_rounded, color: const Color(0xFF05112E), size: isCompact ? 16 : 20),
                        ),
                        const SizedBox(width: 6),
                        if (!isVeryCompact)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'T69 ESPORTS',
                                style: AppTextStyles.badge.copyWith(
                                  color: const Color(0xFF00E5FF),
                                  fontSize: isCompact ? 8.5 : 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                              Text(
                                'BATTLE ARENA',
                                style: AppTextStyles.monoCode.copyWith(
                                  color: Colors.white70,
                                  fontSize: isCompact ? 7.5 : 8.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    // Center: Big Bold Stylized "FINAL STANDINGS" Title
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [Color(0xFFE0F7FA), Color(0xFF80DEEA), Color(0xFF00E5FF)],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ).createShader(bounds),
                              child: Text(
                                'FINAL STANDINGS',
                                style: TextStyle(
                                  fontSize: isCompact ? 18 : 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: isCompact ? 1.2 : 2.0,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right: FREE FIRE Badge + Expand Button
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 3 : 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1B48),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'FREE FIRE',
                            style: AppTextStyles.monoCode.copyWith(
                              color: const Color(0xFF00E5FF),
                              fontWeight: FontWeight.w900,
                              fontSize: isCompact ? 8 : 9.5,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        if (onExpand != null && !isFullScreen) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.fullscreen_rounded, color: Color(0xFF00E5FF), size: 20),
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

              // 2. RESPONSIVE STANDINGS TABLE
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 12),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1E3A8A), width: 1.2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Column(
                      children: [
                        // TABLE HEADER ROW (Deep Royal Navy Blue)
                        Container(
                          color: const Color(0xFF0F1E4A),
                          padding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10, horizontal: isCompact ? 4 : 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: isCompact ? 30 : 44,
                                child: Text(
                                  '#',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.monoCode.copyWith(
                                    color: Colors.white,
                                    fontSize: isCompact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: isCompact ? 22 : 30,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    isCompact ? 'TEAM' : 'TEAM NAME',
                                    style: AppTextStyles.monoCode.copyWith(
                                      color: Colors.white,
                                      fontSize: isCompact ? 8.5 : 9.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: isCompact ? 7 : 12,
                                child: Text(
                                  isCompact ? 'M' : 'MATCHES',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.monoCode.copyWith(
                                    color: Colors.white,
                                    fontSize: isCompact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: isCompact ? 11 : 18,
                                child: Text(
                                  isCompact ? 'PLACE' : 'PLACE PTS',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.monoCode.copyWith(
                                    color: const Color(0xFF38BDF8),
                                    fontSize: isCompact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: isCompact ? 10 : 15,
                                child: Text(
                                  isCompact ? 'KILLS' : 'KILL PTS',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.monoCode.copyWith(
                                    color: const Color(0xFFFB923C),
                                    fontSize: isCompact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: isCompact ? 11 : 16,
                                child: Text(
                                  'TOTAL',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.monoCode.copyWith(
                                    color: const Color(0xFF4ADE80),
                                    fontSize: isCompact ? 8.5 : 9.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              if (isHost)
                                SizedBox(
                                  width: isCompact ? 26 : 38,
                                  child: Text(
                                    'EDIT',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.monoCode.copyWith(
                                      color: const Color(0xFFFBBF24),
                                      fontSize: isCompact ? 7.5 : 8.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // TABLE DATA ROWS
                        if (standings.isEmpty)
                          Container(
                            color: const Color(0xFF9CD5E4),
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'STANDBY: Awaiting Match Results & Points Scoring',
                                textAlign: TextAlign.center,
                                style: AppTextStyles.monoCode.copyWith(
                                  color: const Color(0xFF071435),
                                  fontWeight: FontWeight.w800,
                                  fontSize: isCompact ? 10.5 : 12,
                                ),
                              ),
                            ),
                          )
                        else
                          ...standings.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final row = entry.value;
                            final rank = idx + 1;
                            final teamName = (row['team_name']?.toString() ?? 'Team #$rank').toUpperCase();
                            final matches = (row['matches_count'] as num?)?.toInt() ?? (row['place'] is Map ? (row['place'] as Map).length : 1);
                            final placePts = (row['placement_pts'] as num?)?.toInt() ?? 0;
                            final kills = (row['kills_sum'] as num?)?.toInt() ?? 0;
                            final total = (row['total'] as num?)?.toInt() ?? (placePts + kills);
                            final slot = (row['slot'] as num?)?.toInt() ?? rank;

                            final isBanned = row['is_banned'] == true || teamName.contains('BANNED');
                            final banReason = row['ban_reason']?.toString() ?? '';

                            final isEven = idx % 2 == 0;
                            final rowBgColor = isBanned
                                ? const Color(0xFFFFE4E6)
                                : (isEven ? const Color(0xFFA6DBE8) : const Color(0xFFB7E4EF));

                            return Material(
                              color: rowBgColor,
                              child: InkWell(
                                onTap: isHost
                                    ? () => _showEditScoreModal(
                                          context,
                                          slot: slot,
                                          currentName: teamName,
                                          currentMatches: matches,
                                          currentPlacePts: placePts,
                                          currentKillPts: kills,
                                        )
                                    : null,
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: isCompact ? 6 : 7, horizontal: isCompact ? 4 : 8),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Color(0xFF88C9DB), width: 0.8)),
                                  ),
                                  child: Row(
                                    children: [
                                      // Rank Block (Dark Navy Badge or Red Ban Badge)
                                      Container(
                                        width: isCompact ? 30 : 44,
                                        height: isCompact ? 20 : 24,
                                        decoration: BoxDecoration(
                                          color: isBanned ? const Color(0xFF991B1B) : const Color(0xFF0D1B48),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Center(
                                          child: Text(
                                            isBanned ? '🚫' : '$rank',
                                            style: AppTextStyles.monoCode.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: isCompact ? (isBanned ? 9 : 10.5) : (isBanned ? 10 : 12),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Team Name
                                      Expanded(
                                        flex: isCompact ? 22 : 30,
                                        child: Padding(
                                          padding: const EdgeInsets.only(left: 6, right: 2),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                teamName,
                                                style: AppTextStyles.monoCode.copyWith(
                                                  color: isBanned ? const Color(0xFF991B1B) : const Color(0xFF08183A),
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: isCompact ? 11 : 12.5,
                                                  letterSpacing: 0.2,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (isBanned && banReason.isNotEmpty) ...[
                                                Text(
                                                  'Reason: $banReason',
                                                  style: AppTextStyles.monoCode.copyWith(
                                                    color: const Color(0xFFB91C1C),
                                                    fontSize: 8.5,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Matches
                                      Expanded(
                                        flex: isCompact ? 7 : 12,
                                        child: Text(
                                          '$matches',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: const Color(0xFF0A1E4A),
                                            fontSize: isCompact ? 11 : 12.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),

                                      // Placement Points
                                      Expanded(
                                        flex: isCompact ? 11 : 18,
                                        child: Text(
                                          '$placePts',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: const Color(0xFF0369A1),
                                            fontSize: isCompact ? 11 : 12.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),

                                      // Kill Points
                                      Expanded(
                                        flex: isCompact ? 10 : 15,
                                        child: Text(
                                          '$kills',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: const Color(0xFFC2410C),
                                            fontSize: isCompact ? 11 : 12.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),

                                      // Total Points (Highlighted Bold)
                                      Expanded(
                                        flex: isCompact ? 11 : 16,
                                        child: Text(
                                          '$total',
                                          textAlign: TextAlign.center,
                                          style: AppTextStyles.monoCode.copyWith(
                                            color: const Color(0xFF05112E),
                                            fontSize: isCompact ? 12 : 13.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),

                                      // Edit Button for Host
                                      if (isHost)
                                        SizedBox(
                                          width: isCompact ? 26 : 38,
                                          child: IconButton(
                                            icon: Icon(Icons.edit_note_rounded, size: isCompact ? 16 : 18, color: const Color(0xFF0D1B48)),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => _showEditScoreModal(
                                              context,
                                              slot: slot,
                                              currentName: teamName,
                                              currentMatches: matches,
                                              currentPlacePts: placePts,
                                              currentKillPts: kills,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. BOTTOM FOOTER BAR
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 10 : 12, 10, isCompact ? 10 : 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'TOTAL = PLACEMENT + KILLS',
                        style: AppTextStyles.monoCode.copyWith(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.85),
                          fontSize: isCompact ? 8 : 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isHost)
                      Flexible(
                        child: Text(
                          '✏️ Tap row to edit',
                          style: AppTextStyles.monoCode.copyWith(
                            color: const Color(0xFFFBBF24),
                            fontSize: isCompact ? 8 : 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditScoreModal(
    BuildContext context, {
    required int slot,
    required String currentName,
    required int currentMatches,
    required int currentPlacePts,
    required int currentKillPts,
  }) {
    final nameCtrl = TextEditingController(text: currentName);
    final matchesCtrl = TextEditingController(text: currentMatches.toString());
    final placeCtrl = TextEditingController(text: currentPlacePts.toString());
    final killCtrl = TextEditingController(text: currentKillPts.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final pPts = int.tryParse(placeCtrl.text.trim()) ?? 0;
          final kPts = int.tryParse(killCtrl.text.trim()) ?? 0;
          final totalPts = pPts + kPts;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.edit_note_rounded, color: Color(0xFF00E5FF), size: 24),
                        const SizedBox(width: 10),
                        Text('Edit Standings: Slot #$slot', style: AppTextStyles.h3.copyWith(color: Colors.white)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12),
                const SizedBox(height: 12),

                TacticalTextField(
                  label: 'Team Name',
                  controller: nameCtrl,
                  hint: 'e.g. Soul Esports',
                  prefixIcon: Icons.shield_outlined,
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Matches Played',
                        controller: matchesCtrl,
                        hint: 'e.g. 6',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.sports_esports_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TacticalTextField(
                        label: 'Placement Pts',
                        controller: placeCtrl,
                        hint: 'e.g. 100',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.emoji_events_outlined,
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TacticalTextField(
                        label: 'Kill Points',
                        controller: killCtrl,
                        hint: 'e.g. 104',
                        keyboardType: TextInputType.number,
                        prefixIcon: Icons.gps_fixed_rounded,
                        onChanged: (_) => setModalState(() {}),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 54,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('AUTO TOTAL', style: AppTextStyles.badge.copyWith(color: const Color(0xFF00E5FF), fontSize: 8)),
                            Text(
                              '$totalPts PTS',
                              style: AppTextStyles.monoCode.copyWith(
                                color: const Color(0xFF4ADE80),
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                TacticalButton(
                  label: 'Save & Recalculate Standings',
                  icon: Icons.check_circle_rounded,
                  onPressed: () {
                    final newName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : currentName;
                    final newMatches = int.tryParse(matchesCtrl.text.trim()) ?? currentMatches;
                    final newPlace = int.tryParse(placeCtrl.text.trim()) ?? currentPlacePts;
                    final newKills = int.tryParse(killCtrl.text.trim()) ?? currentKillPts;

                    Navigator.of(ctx).pop();
                    if (onEditScore != null) {
                      onEditScore!(slot, newName, newMatches, newPlace, newKills);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Full-Screen Expansion Dialog Method
  static void showFullScreen(
    BuildContext context, {
    required List<Map<String, dynamic>> standings,
    bool isHost = false,
    String tournamentTitle = 'T69 ESPORTS BATTLE ARENA',
    Function(int slot, String teamName, int matches, int placePts, int killPts)? onEditScore,
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
                Text('T69 Esports Final Standings', style: AppTextStyles.h4.copyWith(color: Colors.white)),
                Text(tournamentTitle, style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF00E5FF), fontSize: 11)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.copy_all_rounded, color: Color(0xFF00E5FF)),
                tooltip: 'Copy Standings Text',
                onPressed: () {
                  final buffer = StringBuffer();
                  buffer.writeln('🎮 T69 ESPORTS - FINAL STANDINGS');
                  buffer.writeln('🏆 Match: $tournamentTitle\n');
                  buffer.writeln('RANK | TEAM | MATCHES | PLACE PTS | KILLS | TOTAL');
                  buffer.writeln('--------------------------------------------------');
                  for (int i = 0; i < standings.length; i++) {
                    final row = standings[i];
                    final rank = i + 1;
                    final team = row['team_name'] ?? 'Team #$rank';
                    final matches = row['matches_count'] ?? (row['place'] is Map ? (row['place'] as Map).length : 1);
                    final place = row['placement_pts'] ?? 0;
                    final kills = row['kills_sum'] ?? 0;
                    final total = row['total'] ?? (place + kills);
                    buffer.writeln('#$rank | $team | $matches | $place | $kills | $total PTS');
                  }

                  Clipboard.setData(ClipboardData(text: buffer.toString()));
                  UiHelpers.showSuccessBanner(context, 'Leaderboard standings copied to clipboard!');
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 2.5,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FreeFireFinalStandingsBoard(
                  standings: standings,
                  isHost: isHost,
                  isFullScreen: true,
                  tournamentTitle: tournamentTitle,
                  onEditScore: onEditScore,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../core/widgets/tactical_button.dart';
import '../../../core/widgets/tactical_text_field.dart';
import '../../../core/widgets/status_badge.dart';
import '../../tournaments/controllers/tournament_controller.dart';
import '../../tournaments/models/tournament_model.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../freefire/widgets/freefire_final_standings_board.dart';
import '../../freefire/widgets/clash_squad_duel_board.dart';


class HostDashboardScreen extends ConsumerStatefulWidget {
  final TournamentModel tournament;

  const HostDashboardScreen({super.key, required this.tournament});

  @override
  ConsumerState<HostDashboardScreen> createState() => _HostDashboardScreenState();
}

class _HostDashboardScreenState extends ConsumerState<HostDashboardScreen> {
  late TournamentModel _t;
  bool _isLoading = false;
  List<Map<String, dynamic>> _registrations = [];

  // IDP Controllers
  late TextEditingController _roomIdController;
  late TextEditingController _roomPassController;
  late bool _allowScreenshots;

  // Scoring Sheet State
  int _activeMapIndex = 0;
  final List<Map<String, String>> _maps = const [
    {'name': 'Bermuda', 'icon': '⛰️'},
    {'name': 'Purgatory', 'icon': '🌋'},
    {'name': 'Kalahari', 'icon': '🏜️'},
    {'name': 'Alpine', 'icon': '❄️'},
    {'name': 'Nexterra', 'icon': '🌃'},
    {'name': 'Bermuda Remastered', 'icon': '🏝️'},
  ];

  // Team Scores: Map of Slot Number -> { 'team_name', 'user_id', 'kills': Map<int, int>, 'place': Map<int, int> }
  final Map<int, Map<String, dynamic>> _teamScores = {};

  // Clash Squad Duel State
  String _selectedCsWinner = 'LEFT SIDE';
  int _csLeftScore = 7;
  int _csRightScore = 3;

  // Chat Controller
  final _chatMsgController = TextEditingController();


  @override
  void initState() {
    super.initState();
    _t = widget.tournament;
    _roomIdController = TextEditingController(text: _t.roomId ?? '');
    _roomPassController = TextEditingController(text: _t.roomPassword ?? '');
    _allowScreenshots = _t.allowScreenshots;
    _initializeScoresFromMetadata();
    _loadMatchData();
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _roomPassController.dispose();
    _chatMsgController.dispose();
    super.dispose();
  }

  void _initializeScoresFromMetadata() {
    final existingScores = _t.scoresList;
    if (existingScores.isNotEmpty) {
      for (final s in existingScores) {
        if (s is Map) {
          final slot = (s['slot'] as num?)?.toInt() ?? 0;
          if (slot > 0) {
            _teamScores[slot] = {
              'team_name': s['team_name'] ?? 'Team #$slot',
              'user_id': s['user_id'] ?? '',
              'kills': Map<int, int>.from((s['kills'] as Map?)?.map((k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt())) ?? {}),
              'place': Map<int, int>.from((s['place'] as Map?)?.map((k, v) => MapEntry(int.parse(k.toString()), (v as num).toInt())) ?? {}),
            };
          }
        }
      }
    }
  }

  void _showEditTeamNameDialog(int slot, String currentName) {
    final nameCtrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Edit Slot #$slot Team Name', style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
        content: TacticalTextField(
          controller: nameCtrl,
          label: 'Team / Squad Name',
          hint: 'e.g. Team GodLike, Soul, Hydra',
          prefixIcon: Icons.shield_outlined,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.button.copyWith(color: Colors.white60)),
          ),
          TacticalButton(
            label: 'Save Name',
            isFullWidth: false,
            height: 38,
            onPressed: () {
              final newName = nameCtrl.text.trim();
              if (newName.isNotEmpty) {
                setState(() {
                  if (_teamScores.containsKey(slot)) {
                    _teamScores[slot]!['team_name'] = newName;
                  } else {
                    _teamScores[slot] = {
                      'team_name': newName,
                      'user_id': '',
                      'kills': <int, int>{},
                      'place': <int, int>{},
                    };
                  }
                });
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showBanTeamDialog({
    required int slotNumber,
    required String teamOrPlayerName,
    required String? userId,
    required String? uid,
  }) {
    String selectedReason = 'Using Hacks / Scripts / Aimbot';
    final List<String> reasonPresets = [
      'Using Hacks / Scripts / Aimbot',
      'Using Grenades / Throwables (CS Rule Violation)',
      'Using 2 Snipers (CS Rule Violation)',
      'Duplicate Character Skills (CS Rule Violation)',
      'Match Abandonment / AFK / Backout',
      'Wrong Slot Sitting / Impersonation',
      'Toxic Behavior / Abuse',
      'Other Rule Violation',
    ];
    final customReasonController = TextEditingController();
    bool removeAndKick = true;
    bool isBanning = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded, color: Color(0xFFFCA5A5), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host Anti-Cheat & Ban', style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                    Text('Slot #$slotNumber • $teamOrPlayerName', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFFCA5A5), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TARGET PLAYER / SQUAD:', style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 9)),
                      const SizedBox(height: 2),
                      Text(teamOrPlayerName, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                      if (uid != null && uid.isNotEmpty)
                        Text('UID: $uid', style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFA5B4FC), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text('VIOLATION REASON:', style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedReason,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF0F172A),
                      style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                      items: reasonPresets.map((r) => DropdownMenuItem(value: r, child: Text(r, maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (val) {
                        if (val != null) setDialogState(() => selectedReason = val);
                      },
                    ),
                  ),
                ),
                if (selectedReason == 'Other Rule Violation') ...[
                  const SizedBox(height: 8),
                  TacticalTextField(
                    label: 'Specify Reason',
                    controller: customReasonController,
                    hint: 'Explain rule breach...',
                  ),
                ],
                const SizedBox(height: 14),
                Text('ENFORCEMENT ACTION:', style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5)),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setDialogState(() => removeAndKick = true),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: removeAndKick ? const Color(0xFFEF4444).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: removeAndKick ? const Color(0xFFEF4444) : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          removeAndKick ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: removeAndKick ? const Color(0xFFEF4444) : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Kick & Free Slot (0 Refund)', style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                              Text('Removes player registration immediately and opens slot.', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => setDialogState(() => removeAndKick = false),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: !removeAndKick ? const Color(0xFFEF4444).withValues(alpha: 0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: !removeAndKick ? const Color(0xFFEF4444) : Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          !removeAndKick ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: !removeAndKick ? const Color(0xFFEF4444) : Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Disqualify on Leaderboard (0 Pts)', style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                              Text('Keeps slot on sheet marked as BANNED with 0 score.', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 10)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60)),
            ),
            TacticalButton(
              label: '🚫 Ban & Enforce',
              variant: TacticalButtonVariant.danger,
              isLoading: isBanning,
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                final finalReason = selectedReason == 'Other Rule Violation' && customReasonController.text.trim().isNotEmpty
                    ? customReasonController.text.trim()
                    : selectedReason;

                setDialogState(() => isBanning = true);
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  final profile = ref.read(authControllerProvider).value;
                  final hostName = profile?.fullName ?? _t.hostName ?? 'Certified Host';

                  await repo.banTeamAndDisqualify(
                    tournamentId: _t.id,
                    slotNumber: slotNumber,
                    teamOrPlayerName: teamOrPlayerName,
                    reason: finalReason,
                    hostName: hostName,
                    removeRegistration: removeAndKick,
                    userId: userId,
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  ref.invalidate(userRegisteredTournamentIdsProvider);
                  if (dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                  }
                  if (mounted) {
                    UiHelpers.showSuccessBanner(
                      context,
                      'Slot #$slotNumber ($teamOrPlayerName) has been banned. Lobby chat notified.',
                    );
                    await _loadMatchData();
                  }
                } catch (e) {
                  setDialogState(() => isBanning = false);
                  if (mounted) {
                    UiHelpers.showErrorBanner(context, 'Ban failed: ${e.toString()}');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMatchData() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(tournamentRepoProvider);
      final refreshed = await repo.fetchTournamentById(_t.id);
      final regs = await repo.fetchTournamentRegistrations(_t.id);

      if (mounted) {
        setState(() {
          _teamScores.clear();
          if (refreshed != null) {
            _t = refreshed;
            _roomIdController.text = _t.roomId ?? '';
            _roomPassController.text = _t.roomPassword ?? '';
            _allowScreenshots = _t.allowScreenshots;
            _initializeScoresFromMetadata();
          }
          _registrations = regs;

          // Initialize all slots up to maxSlots (12 for Squad, 24 for Duo, 48 for Solo)
          final totalSlots = _t.maxSlots > 0 ? _t.maxSlots : 12;
          for (int slot = 1; slot <= totalSlots; slot++) {
            if (!_teamScores.containsKey(slot)) {
              _teamScores[slot] = {
                'team_name': 'Team #$slot',
                'user_id': '',
                'kills': <int, int>{},
                'place': <int, int>{},
              };
            }
          }

          // Populate with registered player info
          for (final reg in _registrations) {
            final slot = (reg['slot_number'] as num?)?.toInt() ?? 1;
            final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? 'Slot #$slot';
            final userId = reg['user_id']?.toString() ?? '';
            final existingName = _teamScores[slot]?['team_name'];
            final nameToUse = (existingName != null && existingName != 'Team #$slot' && existingName.isNotEmpty)
                ? existingName
                : (reg['team_name'] ?? ign);

            _teamScores[slot] = {
              'team_name': nameToUse,
              'user_id': userId,
              'kills': _teamScores[slot]?['kills'] ?? <int, int>{},
              'place': _teamScores[slot]?['place'] ?? <int, int>{},
            };
          }

          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _getPlacementPoints(int rank) {
    switch (rank) {
      case 1:
        return 12;
      case 2:
        return 9;
      case 3:
        return 8;
      case 4:
        return 7;
      case 5:
        return 6;
      case 6:
        return 5;
      case 7:
        return 4;
      case 8:
        return 3;
      case 9:
        return 2;
      case 10:
        return 1;
      default:
        return 0;
    }
  }

  int _calculateTeamPlacementPts(int slot) {
    final entry = _teamScores[slot];
    if (entry == null) return 0;
    final placeMap = entry['place'] as Map<int, int>? ?? {};
    int total = 0;
    for (final p in placeMap.values) {
      total += _getPlacementPoints(p);
    }
    return total;
  }

  int _calculateTeamKillsSum(int slot) {
    final entry = _teamScores[slot];
    if (entry == null) return 0;
    final killsMap = entry['kills'] as Map<int, int>? ?? {};
    int total = 0;
    for (final k in killsMap.values) {
      total += k;
    }
    return total;
  }

  int _calculateTeamTotal(int slot) {
    return _calculateTeamPlacementPts(slot) + _calculateTeamKillsSum(slot);
  }

  void _handleHostEditScore(int slot, String teamName, int matches, int placePts, int killPts) {
    setState(() {
      _teamScores[slot] = {
        'team_name': teamName,
        'user_id': _teamScores[slot]?['user_id'] ?? '',
        'matches_count': matches,
        'placement_pts': placePts,
        'kills_sum': killPts,
        'total': placePts + killPts,
        'kills': _teamScores[slot]?['kills'] ?? <int, int>{},
        'place': _teamScores[slot]?['place'] ?? <int, int>{},
      };
    });
    UiHelpers.showSuccessBanner(context, 'Updated $teamName stats: ${placePts + killPts} total pts.');
  }

  List<Map<String, dynamic>> _getSortedLeaderboard() {
    final list = <Map<String, dynamic>>[];
    for (final entry in _teamScores.entries) {
      final slot = entry.key;
      final data = entry.value;
      final calculatedPlace = _calculateTeamPlacementPts(slot);
      final manualPlace = (data['placement_pts'] as num?)?.toInt() ?? 0;
      final placePts = calculatedPlace > 0 ? calculatedPlace : manualPlace;

      final calculatedKills = _calculateTeamKillsSum(slot);
      final manualKills = (data['kills_sum'] as num?)?.toInt() ?? 0;
      final killsSum = calculatedKills > 0 ? calculatedKills : manualKills;

      final total = placePts + killsSum;
      final matchesCount = (data['matches_count'] as num?)?.toInt() ?? (_activeMapIndex + 1);

      list.add({
        'slot': slot,
        'team_name': data['team_name'] ?? 'Team #$slot',
        'user_id': data['user_id'] ?? '',
        'matches_count': matchesCount,
        'placement_pts': placePts,
        'kills_sum': killsSum,
        'total': total,
        'kills': (data['kills'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
        'place': (data['place'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ?? {},
      });
    }

    list.sort((a, b) {
      final diff = (b['total'] as int).compareTo(a['total'] as int);
      if (diff != 0) return diff;
      final placeDiff = (b['placement_pts'] as int).compareTo(a['placement_pts'] as int);
      if (placeDiff != 0) return placeDiff;
      return (b['kills_sum'] as int).compareTo(a['kills_sum'] as int);
    });

    return list;
  }

  void _copyShareableCard() {
    final roomId = _t.roomId ?? 'Pending';
    final roomPass = _t.roomPassword ?? 'Pending';
    final startTimeStr = DateFormat('hh:mm a, dd MMM').format(_t.startTime.toLocal());

    final message = '''
🎮 *T69 ESPORTS - TOURNAMENT LOBBY CREDENTIALS*
🏆 *Match:* ${_t.title}
🗺️ *Map:* ${_t.mapName} | *Format:* ${_t.format}
⏰ *Match Time:* $startTimeStr

🔑 *CUSTOM ROOM CREDENTIALS:*
🆔 *Room ID:* $roomId
🔒 *Password:* $roomPass

⚠️ *OFFICIAL HOST RULES:*
1. Strictly sit in your designated Slot # on your match pass.
2. Room closes 5 minutes before match start.
3. Cheaters/Hackers are permanently banned.
''';

    Clipboard.setData(ClipboardData(text: message.trim()));
    UiHelpers.showSuccessBanner(context, 'Formatted match credentials copied to clipboard!');
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _t.isIdpLocked;
    final isLate = _t.isLatePenaltyApplied;
    final reward = _t.actualHostReward;
    final startTimeStr = DateFormat('hh:mm a, dd MMM').format(_t.startTime.toLocal());
    final leaderboard = _getSortedLeaderboard();

    return Scaffold(
      backgroundColor: const Color(0xFF04060A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Host Control Panel', style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
            Text('${_t.format} • $startTimeStr', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadMatchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
          : RefreshIndicator(
              color: const Color(0xFF4F46E5),
              backgroundColor: const Color(0xFF090D16),
              onRefresh: _loadMatchData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeaderBanner(isLate, reward),
                  const SizedBox(height: 18),
                  _buildIdpCard(isLocked),
                  const SizedBox(height: 18),
                  _buildRosterCard(),
                  const SizedBox(height: 18),
                  _buildScoringCard(leaderboard),
                  const SizedBox(height: 18),
                  _buildChatCard(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderBanner(bool isLate, int reward) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isLate
              ? [const Color(0xFF4C0519), const Color(0xFF881337)]
              : [const Color(0xFF1E1B4B), const Color(0xFF312E81)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLate ? const Color(0xFFF43F5E) : const Color(0xFF6366F1),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _t.title,
                  style: AppTextStyles.h4.copyWith(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ),
              StatusBadge(
                label: _t.status.toUpperCase(),
                type: _t.status == 'live' || _t.status == 'ongoing'
                    ? BadgeType.success
                    : _t.status == 'completed'
                        ? BadgeType.neutral
                        : BadgeType.primary,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLate
                      ? const Color(0xFFE11D48).withValues(alpha: 0.3)
                      : const Color(0xFF10B981).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      isLate ? Icons.warning_amber_rounded : Icons.monetization_on_rounded,
                      color: isLate ? const Color(0xFFFDA4AF) : const Color(0xFF34D399),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLate
                          ? 'Host Reward: ₹$reward (50% Late Penalty)'
                          : 'Host Compensation: ₹$reward',
                      style: AppTextStyles.monoCode.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Slots: ${_t.filledSlots}/${_t.maxSlots}',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIdpCard(bool isLocked) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isLocked ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFF334155),
          width: 1.2,
        ),
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
                    isLocked ? Icons.lock_rounded : Icons.broadcast_on_personal_rounded,
                    color: isLocked ? const Color(0xFF10B981) : const Color(0xFF818CF8),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isLocked ? 'ROOM CREDENTIALS LOCKED & LIVE' : 'BROADCAST ROOM ID & PASSWORD',
                    style: AppTextStyles.badge.copyWith(
                      color: isLocked ? const Color(0xFF34D399) : const Color(0xFFA5B4FC),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
              if (isLocked) ...[
                IconButton(
                  icon: const Icon(Icons.share_rounded, color: Color(0xFF10B981), size: 18),
                  tooltip: 'Copy Shareable Match Card',
                  onPressed: _copyShareableCard,
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: TacticalTextField(
                  controller: _roomIdController,
                  label: 'In-Game Room ID',
                  hint: 'e.g. 5849201',
                  enabled: !isLocked,
                  prefixIcon: Icons.tag_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TacticalTextField(
                  controller: _roomPassController,
                  label: 'Room Password',
                  hint: 'e.g. 1234',
                  enabled: !isLocked,
                  prefixIcon: Icons.lock_outline_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Toggle Screenshot Uploads
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Allow Player Screenshot Uploads',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              Switch(
                value: _allowScreenshots,
                activeThumbColor: const Color(0xFF4F46E5),
                onChanged: (val) async {
                  setState(() => _allowScreenshots = val);
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.toggleScreenshotUploads(tournamentId: _t.id, allow: val);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (!isLocked) ...[
            TacticalButton(
              label: '🔒 LOCK & BROADCAST IDP TO PLAYERS',
              icon: Icons.send_rounded,
              onPressed: () async {
                final roomId = _roomIdController.text.trim();
                final roomPass = _roomPassController.text.trim();

                if (roomId.isEmpty || roomPass.isEmpty) {
                  UiHelpers.showErrorBanner(context, 'Please enter both Room ID and Room Password.');
                  return;
                }

                try {
                  final repo = ref.read(tournamentRepoProvider);
                  await repo.lockAndBroadcastIdp(
                    tournamentId: _t.id,
                    roomId: roomId,
                    roomPassword: roomPass,
                    allowScreenshots: _allowScreenshots,
                  );

                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Credentials locked & broadcasted to all registered players!');
                    _loadMatchData();
                  }
                } catch (e) {
                  if (mounted) UiHelpers.showErrorBanner(context, 'Failed: ${e.toString()}');
                }
              },
            ),
          ] else ...[
            TacticalButton(
              label: '✏️ UNLOCK / EDIT ROOM ID & PASSWORD',
              variant: TacticalButtonVariant.outline,
              icon: Icons.lock_open_rounded,
              onPressed: () async {
                final repo = ref.read(tournamentRepoProvider);
                await repo.unlockIdp(tournamentId: _t.id);
                if (mounted) {
                  UiHelpers.showInfoBanner(context, 'IDP unlocked for editing.');
                  _loadMatchData();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRosterCard() {
    final Map<int, Map<String, dynamic>> scoreSlotMap = {};
    for (final s in _t.scoresList) {
      if (s is Map) {
        final slotNum = (s['slot'] as num?)?.toInt();
        if (slotNum != null) {
          scoreSlotMap[slotNum] = Map<String, dynamic>.from(s);
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTERED SQUAD ROSTER (${_registrations.length})',
                style: AppTextStyles.badge.copyWith(color: const Color(0xFFA5B4FC), fontSize: 10),
              ),
              if (_registrations.isNotEmpty) ...[
                InkWell(
                  onTap: () {
                    final lines = <String>[];
                    for (final reg in _registrations) {
                      final slot = reg['slot_number'] ?? '?';
                      final scoreData = scoreSlotMap[slot is int ? slot : 0];
                      final teamName = scoreData?['team_name'] ?? reg['team_name'];
                      final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? 'Player';
                      final uid = reg['game_uid'] ?? '';
                      final players = (scoreData?['players'] as List?)?.map((p) => p.toString()).toList();

                      if (players != null && players.isNotEmpty) {
                        lines.add('Slot #$slot ($teamName): ${players.join(', ')} (UID: $uid)');
                      } else {
                        lines.add('Slot #$slot: $ign (UID: $uid)');
                      }
                    }

                    Clipboard.setData(ClipboardData(text: lines.join('\n')));
                    UiHelpers.showSuccessBanner(context, 'Copied ${_registrations.length} squad rosters to clipboard!');
                  },
                  child: Text(
                    'Copy All Lineups',
                    style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF818CF8), fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          if (_registrations.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No squads registered yet.',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
                ),
              ),
            ),
          ] else ...[
            ..._registrations.map((reg) {
              final slot = reg['slot_number'] ?? 1;
              final scoreData = scoreSlotMap[slot is int ? slot : 0];
              final teamName = scoreData?['team_name'] ?? _teamScores[slot]?['team_name'] ?? reg['team_name'];
              final ign = reg['game_ign'] ?? reg['profiles']?['username'] ?? 'Captain';
              final uid = reg['game_uid'] ?? scoreData?['uid'] ?? 'N/A';
              final players = (scoreData?['players'] as List?)?.map((p) => p.toString()).toList();

              String titleText = (teamName != null && teamName.isNotEmpty && teamName != 'Team #$slot') ? teamName : ign;
              String subtitleText = 'UID: $uid';
              if (players != null && players.isNotEmpty) {
                subtitleText = 'Lineup: ${players.join(', ')} • UID: $uid';
              } else if (teamName != null && teamName.isNotEmpty && teamName != ign) {
                subtitleText = 'Captain: $ign • UID: $uid';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$slot',
                        style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(titleText, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                          Text(
                            subtitleText,
                            style: AppTextStyles.bodySmall.copyWith(color: Colors.white60, fontSize: 10.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => _showBanTeamDialog(
                        slotNumber: slot is int ? slot : 1,
                        teamOrPlayerName: titleText,
                        userId: reg['user_id']?.toString(),
                        uid: uid != 'N/A' ? uid : null,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.gavel_rounded, color: Color(0xFFEF4444), size: 15),
                            const SizedBox(width: 4),
                            Text(
                              'BAN',
                              style: AppTextStyles.badge.copyWith(
                                color: const Color(0xFFEF4444),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          if (_t.screenshotProofs.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white10),
            const SizedBox(height: 8),
            Text(
              'SUBMITTED RESULT SCREENSHOTS (${_t.screenshotProofs.length})',
              style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 70,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _t.screenshotProofs.length,
                itemBuilder: (context, idx) {
                  final proof = _t.screenshotProofs[idx] as Map;
                  final pName = proof['player_name'] ?? 'Player';

                  return Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 6),
                        Text('$pName Proof', style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool get _isSolo => _t.format.toLowerCase().contains('solo');
  bool get _isDuo => _t.format.toLowerCase().contains('duo') && !_isCs;
  bool get _isCs => _t.isCs;
  bool get _isSingleMatch => _isSolo || _isDuo || _isCs;

  Widget _buildMapRotationTabs() {
    if (_isSingleMatch) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_maps.length, (idx) {
          final isSelected = _activeMapIndex == idx;
          final mapData = _maps[idx];
          final icon = mapData['icon'] ?? '🗺️';
          final name = mapData['name'] ?? 'Map';

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeMapIndex = idx),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isSelected ? const Color(0xFF818CF8) : Colors.white10),
                ),
                child: Row(
                  children: [
                    Text(icon),
                    const SizedBox(width: 6),
                    Text(
                      'M${idx + 1}: $name',
                      style: AppTextStyles.badge.copyWith(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildScoringCard(List<Map<String, dynamic>> leaderboard) {
    if (_isCs) {
      return _buildClashSquadScoringCard();
    }
    final currentMapName = _isSingleMatch ? _t.mapName : (_maps[_activeMapIndex]['name'] ?? 'Map');
    final perKillRate = _t.perKill > 0 ? _t.perKill : (_t.entryFee >= 20 ? 15.0 : 10.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _isSolo
                      ? 'SOLO PER-KILL ARENA (1 MATCH)'
                      : _isCs
                          ? 'CLASH SQUAD DUEL (1 MATCH • BEST OF 7)'
                          : _isDuo
                              ? 'DUO CLASH TOURNAMENT (1 MATCH)'
                              : '6-MATCH ESPORTS TOURNAMENT SCORING GRID',
                  style: AppTextStyles.badge.copyWith(color: const Color(0xFF818CF8), fontSize: 10),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF312E81),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _isSolo
                      ? '₹${perKillRate.toStringAsFixed(0)} / Kill PP'
                      : _isCs
                          ? 'Winner Takes All ₹85 PP'
                          : _isDuo
                              ? 'Top 1, 2, 3 PP'
                              : 'Formula: Kills + Placement',
                  style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFA5B4FC), fontSize: 9.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_isSingleMatch)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Text('⛰️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MATCH 1: ${_t.mapName.toUpperCase()} (${_isSolo ? "SOLO 1-MATCH" : "DUO 1-MATCH"})',
                          style: AppTextStyles.badge.copyWith(color: const Color(0xFFA5B4FC), fontSize: 10),
                        ),
                        Text(
                          _isSolo
                              ? 'Enter kills for each player. Payout distributes ₹${perKillRate.toStringAsFixed(0)} per kill.'
                              : 'Enter placement & kills for each duo team for Top 1, 2, 3 PP payout.',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white70, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            _buildMapRotationTabs(),

          const SizedBox(height: 16),

          Text(
            'ENTER MATCH 1 RESULTS ($currentMapName):',
            style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
          ),
          const SizedBox(height: 10),

          if (_teamScores.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'Register players or squads to score matches.',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
                ),
              ),
            ),
          ] else ...[
            ..._teamScores.entries.map((entry) {
              final slot = entry.key;
              final data = entry.value;
              final teamName = data['team_name'] ?? 'Team #$slot';
              final killsMap = data['kills'] as Map<int, int>? ?? {};
              final placeMap = data['place'] as Map<int, int>? ?? {};

              final currentKills = killsMap[_activeMapIndex] ?? 0;
              final currentPlace = placeMap[_activeMapIndex] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '#$slot',
                          style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: InkWell(
                        onTap: () => _showEditTeamNameDialog(slot, teamName),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    teamName,
                                    style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.edit_rounded, color: Colors.white38, size: 12),
                              ],
                            ),
                            Text(
                              'Total: ${_calculateTeamTotal(slot)} pts',
                              style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFA5B4FC), fontSize: 9.5, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Kills Counter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: () {
                              if (currentKills > 0) {
                                setState(() {
                                  killsMap[_activeMapIndex] = currentKills - 1;
                                });
                              }
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Icon(Icons.remove_circle_outline, color: Colors.white54, size: 16),
                            ),
                          ),
                          Text(
                            '$currentKills',
                            style: AppTextStyles.monoCode.copyWith(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                killsMap[_activeMapIndex] = currentKills + 1;
                              });
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: Icon(Icons.add_circle_outline, color: Color(0xFF818CF8), size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Placement Rank
                    Column(
                      children: [
                        Text('RANK (P)', style: AppTextStyles.badge.copyWith(color: Colors.white60, fontSize: 8)),
                        DropdownButton<int>(
                          value: currentPlace > 0 ? currentPlace : null,
                          hint: Text('-', style: AppTextStyles.monoCode.copyWith(color: Colors.white60)),
                          dropdownColor: const Color(0xFF0F172A),
                          style: AppTextStyles.monoCode.copyWith(color: const Color(0xFFFBBF24), fontWeight: FontWeight.w800),
                          items: List.generate(12, (i) => i + 1).map((r) {
                            return DropdownMenuItem<int>(
                              value: r,
                              child: Text('${r}st (${_getPlacementPoints(r)}pts)'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                placeMap[_activeMapIndex] = val;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          const SizedBox(height: 14),

          // Official Battle Arena Final Standings Board (Editable by Host)
          FreeFireFinalStandingsBoard(
            standings: leaderboard,
            isHost: true,
            tournamentTitle: _t.title,
            onEditScore: _handleHostEditScore,
            onExpand: () {
              FreeFireFinalStandingsBoard.showFullScreen(
                context,
                standings: leaderboard,
                isHost: true,
                tournamentTitle: _t.title,
                onEditScore: _handleHostEditScore,
              );
            },
          ),

          const SizedBox(height: 14),

          // Action 1: Broadcast Leaderboard to Players
          TacticalButton(
            label: '📊 BROADCAST LEADERBOARD TO PLAYERS',
            icon: Icons.leaderboard_rounded,
            onPressed: () async {
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.saveAndBroadcastScores(
                  tournamentId: _t.id,
                  scores: leaderboard,
                );
                ref.invalidate(freeFireTournamentsProvider);
                await _loadMatchData();
                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Leaderboard standings updated & pushed to player devices!');
                }
              } catch (e) {
                if (mounted) UiHelpers.showErrorBanner(context, 'Broadcast failed: ${e.toString()}');
              }
            },
          ),

          const SizedBox(height: 10),

          // Action 2: Finish Match, Payout Winners & Reset Lobby (All-in-One)
          TacticalButton(
            label: '🏆 SUBMIT RESULTS, PAYOUT & RESET LOBBY',
            icon: Icons.emoji_events_rounded,
            variant: TacticalButtonVariant.primary,
            onPressed: () => _confirmFinishTournament(leaderboard),
          ),
        ],
      ),
    );
  }

  Widget _buildChatCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.forum_rounded, color: Color(0xFF818CF8), size: 20),
              const SizedBox(width: 8),
              Text(
                'HOST & PLAYER ROOM CHAT FEED',
                style: AppTextStyles.badge.copyWith(color: const Color(0xFFA5B4FC), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_t.chatMessages.isEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text(
                  'Post room coordination notices here for players.',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white60),
                ),
              ),
            ),
          ] else ...[
            ..._t.chatMessages.map((msg) {
              final m = msg as Map;
              final sender = m['sender'] ?? 'Host';
              final text = m['message'] ?? '';
              final isHost = m['isHost'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isHost ? const Color(0xFF312E81) : const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isHost ? const Color(0xFF6366F1) : Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHost ? '👑 $sender (HOST)' : sender,
                      style: AppTextStyles.badge.copyWith(
                        color: isHost ? const Color(0xFFFBBF24) : Colors.white70,
                        fontSize: 9.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(text, style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TacticalTextField(
                  label: '',
                  controller: _chatMsgController,
                  hint: 'Type a message to lobby players...',
                ),
              ),
              const SizedBox(width: 8),
              TacticalButton(
                label: 'Send',
                icon: Icons.send_rounded,
                height: 46,
                isFullWidth: false,
                onPressed: () async {
                  final text = _chatMsgController.text.trim();
                  if (text.isEmpty) return;

                  try {
                    final repo = ref.read(tournamentRepoProvider);
                    final profile = ref.read(authControllerProvider).value;
                    final hostDisplayName = profile?.fullName ?? _t.hostName ?? 'Host';

                    await repo.sendHostChatMessage(
                      tournamentId: _t.id,
                      senderName: hostDisplayName,
                      message: text,
                      isHost: true,
                    );

                    _chatMsgController.clear();
                    _loadMatchData();
                  } catch (e) {
                    if (mounted) UiHelpers.showErrorBanner(context, 'Chat failed: ${e.toString()}');
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmFinishTournament(List<Map<String, dynamic>> leaderboard) {
    if (leaderboard.isEmpty) {
      UiHelpers.showErrorBanner(context, 'Cannot finish tournament without scores.');
      return;
    }

    final hostReward = _t.actualHostReward;

    // A. SOLO LOBBY: PER-KILL PRIZE POOL PAYOUT
    if (_isSolo) {
      final perKillRate = _t.perKill > 0 ? _t.perKill : (_t.entryFee >= 20 ? 15.0 : 10.0);
      final killers = leaderboard.where((p) => ((p['kills_sum'] as num?)?.toInt() ?? 0) > 0).toList();
      final totalKillsCount = killers.fold<int>(0, (sum, p) => sum + ((p['kills_sum'] as num?)?.toInt() ?? 0));
      final totalKillPayout = totalKillsCount * perKillRate;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Row(
            children: [
              const Icon(Icons.gps_fixed_rounded, color: Color(0xFFFB923C), size: 24),
              const SizedBox(width: 10),
              Text('Submit Solo Per-Kill PP?', style: AppTextStyles.h4.copyWith(color: Colors.white)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solo 1-Match Rate: ₹${perKillRate.toStringAsFixed(0)} / Kill.\nConfirm player kill payouts to release prize pool:',
                  style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (killers.isEmpty)
                        Text('No kills recorded. Kills must be > 0 to credit prizes.', style: AppTextStyles.bodySmall.copyWith(color: Colors.white60))
                      else
                        ...killers.take(12).map((k) {
                          final kSum = (k['kills_sum'] as num?)?.toInt() ?? 0;
                          final name = k['team_name'] ?? 'Player';
                          final prize = kSum * perKillRate;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    '💀 $name ($kSum Kills)',
                                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '₹${prize.toStringAsFixed(0)}',
                                  style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF4ADE80), fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          );
                        }),
                      const Divider(color: Colors.white12, height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Kill Prize Pool:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                          Text('₹${totalKillPayout.toStringAsFixed(0)} ($totalKillsCount Kills)', style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF4ADE80), fontWeight: FontWeight.w900)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('🎮 Host Compensation: ₹$hostReward', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF34D399), fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60)),
            ),
            TacticalButton(
              label: '🏆 Submit Solo Payout & Reset Lobby',
              height: 40,
              isFullWidth: false,
              onPressed: () async {
                Navigator.of(ctx).pop();
                try {
                  final repo = ref.read(tournamentRepoProvider);
                  final profile = ref.read(authControllerProvider).value;
                  final hostId = profile?.id ?? _t.hostId ?? '';
                  final hostName = _t.hostName ?? profile?.fullName ?? 'Host';

                  await repo.finishSoloPerKillTournamentAndSubmitPayout(
                    tournamentId: _t.id,
                    perKillRate: perKillRate,
                    leaderboard: leaderboard,
                    hostReward: hostReward,
                    hostId: hostId,
                    hostName: hostName,
                    registrations: _registrations,
                  );

                  ref.invalidate(freeFireTournamentsProvider);
                  ref.invalidate(userRegisteredTournamentIdsProvider);
                  ref.invalidate(matchHistoryProvider);
                  ref.invalidate(walletTransactionsProvider);
                  ref.read(authControllerProvider.notifier).refreshProfile();
                  if (mounted) {
                    UiHelpers.showSuccessBanner(context, 'Solo Per-Kill PP credited! Host received ₹$hostReward. Lobby reset for next match.');
                    await _loadMatchData();
                  }
                } catch (e) {
                  if (mounted) UiHelpers.showErrorBanner(context, 'Submit failed: ${e.toString()}');
                }
              },
            ),
          ],
        ),
      );
      return;
    }

    // B. DUO, CS & SQUAD LOBBIES: WINNER / PODIUM PAYOUT
    final top1 = leaderboard.isNotEmpty ? leaderboard[0] : <String, dynamic>{};
    final top2 = leaderboard.length > 1 ? leaderboard[1] : <String, dynamic>{};
    final top3 = leaderboard.length > 2 ? leaderboard[2] : <String, dynamic>{};

    final top1Prize = _isCs ? 85.0 : (_isDuo ? 170.0 : (_t.prizePool > 0 ? 110.0 : 0.0));
    final top2Prize = _isCs ? 0.0 : (_isDuo ? 130.0 : (_t.prizePool > 0 ? 70.0 : 0.0));
    final top3Prize = _isCs ? 0.0 : (_isDuo ? 100.0 : (_t.prizePool > 0 ? 50.0 : 0.0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _isDuo
                    ? 'Submit Duo Payout & Reset Lobby?'
                    : 'Submit Payout & Reset Lobby?',
                style: AppTextStyles.h4.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isDuo
                  ? 'Confirm Duo match winners to release prize pool (PP), send ₹$hostReward host reward, save to match history, and reset the lobby for the next match:'
                  : 'Confirm tournament winners to release payouts, send ₹$hostReward host reward, save to match history, and reset the lobby for the next match:',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🥇 1st: ${top1['team_name']} — ${top1['total'] ?? 0} pts (${top1['placement_pts'] ?? 0} Pl + ${top1['kills_sum'] ?? 0} Kl) • ₹${top1Prize.toStringAsFixed(0)}', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFFBBF24), fontWeight: FontWeight.w800)),
                  if (!_isCs) ...[
                    const SizedBox(height: 4),
                    Text('🥈 2nd: ${top2['team_name'] ?? 'N/A'} — ${top2['total'] ?? 0} pts (${top2['placement_pts'] ?? 0} Pl + ${top2['kills_sum'] ?? 0} Kl) • ₹${top2Prize.toStringAsFixed(0)}', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('🥉 3rd: ${top3['team_name'] ?? 'N/A'} — ${top3['total'] ?? 0} pts (${top3['placement_pts'] ?? 0} Pl + ${top3['kills_sum'] ?? 0} Kl) • ₹${top3Prize.toStringAsFixed(0)}', style: AppTextStyles.bodySmall.copyWith(color: Colors.white)),
                  ],
                  const Divider(color: Colors.white12, height: 14),
                  Text('🎮 Host Compensation: ₹$hostReward', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF34D399), fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('🔄 Lobby Action: Auto Reset for Next Match', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60)),
          ),
          TacticalButton(
            label: '🏆 Submit Payout & Reset Lobby',
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                final profile = ref.read(authControllerProvider).value;
                final hostId = profile?.id ?? _t.hostId ?? '';
                final hostName = _t.hostName ?? profile?.fullName ?? 'Host';

                await repo.finishTournamentAndSubmitPayout(
                  tournamentId: _t.id,
                  top1: top1,
                  top2: top2,
                  top3: top3,
                  top1Prize: top1Prize,
                  top2Prize: top2Prize,
                  top3Prize: top3Prize,
                  hostReward: hostReward,
                  hostId: hostId,
                  hostName: hostName,
                  leaderboard: leaderboard,
                  registrations: _registrations,
                );

                ref.invalidate(freeFireTournamentsProvider);
                ref.invalidate(userRegisteredTournamentIdsProvider);
                ref.invalidate(matchHistoryProvider);
                ref.invalidate(walletTransactionsProvider);
                ref.read(authControllerProvider.notifier).refreshProfile();
                if (mounted) {
                  UiHelpers.showSuccessBanner(context, '${_isCs ? "Clash Squad Winner ₹${_t.prizePool.toStringAsFixed(0)}" : (_isDuo ? "Duo Top 3 prizes" : "Winner prizes")} & ₹$hostReward host compensation credited! Lobby refreshed.');
                  await _loadMatchData();
                }
              } catch (e) {
                if (mounted) UiHelpers.showErrorBanner(context, 'Submit failed: ${e.toString()}');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClashSquadScoringCard() {
    final leftRegs = _registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 1).toList();
    final rightRegs = _registrations.where((r) => (r['slot_number'] as num?)?.toInt() == 2).toList();

    final leftPlayers = leftRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 1').toList();
    final rightPlayers = rightRegs.map((r) => r['game_ign']?.toString() ?? r['profiles']?['username']?.toString() ?? 'Player 2').toList();

    final leftTeamName = _teamScores[1]?['team_name'] != null && _teamScores[1]!['team_name'] != 'Team #1'
        ? _teamScores[1]!['team_name'] as String
        : (leftRegs.isNotEmpty ? (leftRegs.first['team_name'] ?? leftPlayers.first) : 'Left Side (Team 1)');

    final rightTeamName = _teamScores[2]?['team_name'] != null && _teamScores[2]!['team_name'] != 'Team #2'
        ? _teamScores[2]!['team_name'] as String
        : (rightRegs.isNotEmpty ? (rightRegs.first['team_name'] ?? rightPlayers.first) : 'Right Side (Team 2)');

    final isLeftWinner = _selectedCsWinner == 'LEFT SIDE' || _selectedCsWinner == 'TEAM 1' || _selectedCsWinner == '1';
    final winnerPrize = 85.0;
    final hostReward = _t.actualHostReward > 0 ? _t.actualHostReward : 10;

    final matchData = {
      'winning_side': _selectedCsWinner,
      'left_score': _csLeftScore,
      'right_score': _csRightScore,
      'left_team_name': leftTeamName,
      'right_team_name': rightTeamName,
      'left_players': leftPlayers,
      'right_players': rightPlayers,
      'prize_pool': winnerPrize,
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.sports_martial_arts_rounded, color: Color(0xFF00E5FF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CLASH SQUAD DUEL SCORING',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.badge.copyWith(color: const Color(0xFF00E5FF), fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E4A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'Winner: ₹85 • Host: ₹$hostReward',
                  style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 1. Interactive Duel Scoreboard Preview
          ClashSquadDuelBoard(
            matchData: matchData,
            isHost: true,
            tournamentTitle: _t.title,
            onExpand: () {
              ClashSquadDuelBoard.showFullScreen(
                context,
                matchData: matchData,
                tournamentTitle: _t.title,
              );
            },
          ),

          const SizedBox(height: 18),
          const Divider(color: Colors.white12),
          const SizedBox(height: 14),

          // 2. Host Controls: Winner Selection & Score Adjuster
          Text(
            '1. SELECT WINNING MATCH SIDE:',
            style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // LEFT SIDE SELECTOR
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCsWinner = 'LEFT SIDE';
                      _csLeftScore = 7;
                      if (_csRightScore >= 7) _csRightScore = 3;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isLeftWinner ? const Color(0xFF0F2E2B) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isLeftWinner ? const Color(0xFF10B981) : Colors.white12,
                        width: isLeftWinner ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('LEFT SIDE (SLOT 1)', style: AppTextStyles.badge.copyWith(color: const Color(0xFFA5B4FC), fontSize: 8.5)),
                        const SizedBox(height: 4),
                        Text(
                          leftTeamName,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isLeftWinner ? const Color(0xFF16A34A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isLeftWinner ? '👑 DECLARED WINNER (₹85)' : 'CLICK TO SELECT',
                            style: AppTextStyles.monoCode.copyWith(
                              color: isLeftWinner ? Colors.white : Colors.white60,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // RIGHT SIDE SELECTOR
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCsWinner = 'RIGHT SIDE';
                      _csRightScore = 7;
                      if (_csLeftScore >= 7) _csLeftScore = 3;
                    });
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: !isLeftWinner ? const Color(0xFF0F2E2B) : const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: !isLeftWinner ? const Color(0xFF10B981) : Colors.white12,
                        width: !isLeftWinner ? 2.0 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text('RIGHT SIDE (SLOT 2)', style: AppTextStyles.badge.copyWith(color: const Color(0xFFA5B4FC), fontSize: 8.5)),
                        const SizedBox(height: 4),
                        Text(
                          rightTeamName,
                          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: !isLeftWinner ? const Color(0xFF16A34A) : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            !isLeftWinner ? '👑 DECLARED WINNER (₹85)' : 'CLICK TO SELECT',
                            style: AppTextStyles.monoCode.copyWith(
                              color: !isLeftWinner ? Colors.white : Colors.white60,
                              fontSize: 9,
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
          ),

          const SizedBox(height: 16),

          // 3. Best-of-7 Round Score Steppers
          Text(
            '2. ADJUST ROUND SCORES (BEST OF 7):',
            style: AppTextStyles.badge.copyWith(color: const Color(0xFFFBBF24), fontSize: 9.5),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Left Side Stepper
                Column(
                  children: [
                    Text('LEFT ROUNDS', style: AppTextStyles.badge.copyWith(color: Colors.white70, fontSize: 8.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                          onPressed: () {
                            if (_csLeftScore > 0) setState(() => _csLeftScore--);
                          },
                        ),
                        Text(
                          '$_csLeftScore',
                          style: AppTextStyles.monoCode.copyWith(
                            color: isLeftWinner ? const Color(0xFF4ADE80) : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF818CF8), size: 22),
                          onPressed: () {
                            if (_csLeftScore < 7) setState(() => _csLeftScore++);
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const Text(':', style: TextStyle(color: Colors.white38, fontSize: 24, fontWeight: FontWeight.bold)),

                // Right Side Stepper
                Column(
                  children: [
                    Text('RIGHT ROUNDS', style: AppTextStyles.badge.copyWith(color: Colors.white70, fontSize: 8.5)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.white70, size: 22),
                          onPressed: () {
                            if (_csRightScore > 0) setState(() => _csRightScore--);
                          },
                        ),
                        Text(
                          '$_csRightScore',
                          style: AppTextStyles.monoCode.copyWith(
                            color: !isLeftWinner ? const Color(0xFF4ADE80) : Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: Color(0xFF818CF8), size: 22),
                          onPressed: () {
                            if (_csRightScore < 7) setState(() => _csRightScore++);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Action 1: Broadcast CS Standings to Players
          TacticalButton(
            label: '📊 BROADCAST LIVE CS SCORECARD TO PLAYERS',
            icon: Icons.send_rounded,
            onPressed: () async {
              try {
                final repo = ref.read(tournamentRepoProvider);
                await repo.saveAndBroadcastScores(
                  tournamentId: _t.id,
                  scores: [
                    {
                      'slot': 1,
                      'team_name': leftTeamName,
                      'rounds': _csLeftScore,
                      'is_winner': isLeftWinner,
                    },
                    {
                      'slot': 2,
                      'team_name': rightTeamName,
                      'rounds': _csRightScore,
                      'is_winner': !isLeftWinner,
                    },
                  ],
                  csResult: matchData,
                );
                ref.invalidate(freeFireTournamentsProvider);
                await _loadMatchData();
                if (mounted) {
                  UiHelpers.showSuccessBanner(context, 'Clash Squad scores & winner broadcasted to player match rooms!');
                }
              } catch (e) {
                if (mounted) UiHelpers.showErrorBanner(context, 'Broadcast failed: ${e.toString()}');
              }
            },
          ),

          const SizedBox(height: 10),

          // Action 2: Finish Match, Payout Winner & Reset Lobby (All-in-One)
          TacticalButton(
            label: '🏆 SUBMIT CS RESULT, PAYOUT & RESET LOBBY',
            icon: Icons.emoji_events_rounded,
            variant: TacticalButtonVariant.primary,
            onPressed: () => _confirmFinishClashSquad(
              leftTeamName: leftTeamName,
              rightTeamName: rightTeamName,
              winnerPrize: winnerPrize,
              hostReward: hostReward,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmFinishClashSquad({
    required String leftTeamName,
    required String rightTeamName,
    required double winnerPrize,
    required int hostReward,
  }) {
    final isLeftWinner = _selectedCsWinner == 'LEFT SIDE' || _selectedCsWinner == 'TEAM 1' || _selectedCsWinner == '1';
    final winningTeamName = isLeftWinner ? leftTeamName : rightTeamName;
    final leftScore = _csLeftScore;
    final rightScore = _csRightScore;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded, color: Color(0xFFF59E0B), size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Submit Result, Payout & Reset Lobby?',
                style: AppTextStyles.h4.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submitting will immediately send ₹${winnerPrize.toStringAsFixed(0)} real vault payout to winning player/team ($winningTeamName), credit ₹$hostReward host compensation, record the match in history, and automatically reset this lobby for the next match.',
              style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('👑 Declared Winner:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      Text(_selectedCsWinner, style: AppTextStyles.badge.copyWith(color: const Color(0xFF4ADE80), fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Team / Player: $winningTeamName', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  Text('Final Score: $leftTeamName ($leftScore) - $rightTeamName ($rightScore)', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFA5B4FC), fontSize: 11)),
                  const Divider(color: Colors.white12, height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🏆 Winner Real Payout:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      Text('₹${winnerPrize.toStringAsFixed(0)}', style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF4ADE80), fontWeight: FontWeight.w900, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🎮 Host Compensation:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      Text('₹$hostReward', style: AppTextStyles.monoCode.copyWith(color: const Color(0xFF34D399), fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('🔄 Lobby Action:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                      Text('Auto Reset for Next Match', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF38BDF8), fontWeight: FontWeight.w800)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white60)),
          ),
          TacticalButton(
            label: '🏆 Submit Payout & Reset Lobby',
            height: 40,
            isFullWidth: false,
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final repo = ref.read(tournamentRepoProvider);
                final profile = ref.read(authControllerProvider).value;
                final hostId = profile?.id ?? _t.hostId ?? '';
                final hostName = _t.hostName ?? profile?.fullName ?? 'Host';

                await repo.finishClashSquadTournamentAndSubmitPayout(
                  tournamentId: _t.id,
                  winningSide: _selectedCsWinner,
                  leftScore: leftScore,
                  rightScore: rightScore,
                  leftTeamName: leftTeamName,
                  rightTeamName: rightTeamName,
                  winnerPrize: winnerPrize,
                  hostReward: hostReward,
                  hostId: hostId,
                  hostName: hostName,
                  registrations: _registrations,
                );

                ref.invalidate(freeFireTournamentsProvider);
                ref.invalidate(userRegisteredTournamentIdsProvider);
                ref.invalidate(matchHistoryProvider);
                ref.invalidate(walletTransactionsProvider);
                ref.read(authControllerProvider.notifier).refreshProfile();
                if (mounted) {
                  UiHelpers.showSuccessBanner(
                    context,
                    'Clash Squad Winner ₹${winnerPrize.toStringAsFixed(0)} & Host ₹$hostReward payouts credited! Lobby reset for next match.',
                  );
                  await _loadMatchData();
                }
              } catch (e) {
                if (mounted) UiHelpers.showErrorBanner(context, 'Submit failed: ${e.toString()}');
              }
            },
          ),
        ],
      ),
    );
  }
}

import 'dart:convert';

class TournamentModel {
  final String id;
  final String title;
  final String game;
  final String bannerUrl;
  final double entryFee;
  final double prizePool;
  final double perKill;
  final String format;
  final String mapName;
  final int maxSlots;
  final int filledSlots;
  final DateTime startTime;
  final String status;
  final String? rules;
  final String? roomId;
  final String? roomPassword;
  final DateTime? createdAt;

  const TournamentModel({
    required this.id,
    required this.title,
    required this.game,
    required this.bannerUrl,
    this.entryFee = 0.0,
    this.prizePool = 0.0,
    this.perKill = 0.0,
    this.format = 'Squad (Battle Royale)',
    this.mapName = 'Bermuda',
    this.maxSlots = 48,
    this.filledSlots = 0,
    required this.startTime,
    this.status = 'open',
    this.rules,
    this.roomId,
    this.roomPassword,
    this.createdAt,
  });

  bool get isFull => filledSlots >= maxSlots;
  double get slotsProgress => maxSlots > 0 ? (filledSlots / maxSlots).clamp(0.0, 1.0) : 0.0;

  // --- Host & Esports Controller Metadata ---
  Map<String, dynamic> get hostMeta {
    if (rules == null || rules!.isEmpty) return {};
    try {
      if (rules!.trim().startsWith('{')) {
        return jsonDecode(rules!) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {};
  }

  Map<String, dynamic> get meta => hostMeta;

  String? get hostId => hostMeta['host_id']?.toString();
  String? get hostName => hostMeta['host_name']?.toString();
  String? get hostMobile => hostMeta['host_mobile']?.toString();
  String? get hostIgn => hostMeta['host_ign']?.toString();
  String? get hostUid => hostMeta['host_uid']?.toString();
  double get hostRating => (hostMeta['host_rating'] as num?)?.toDouble() ?? 4.9;
  bool get isCs =>
      format.toLowerCase().contains('cs') ||
      format.toLowerCase().contains('1v1') ||
      format.toLowerCase().contains('2v2') ||
      format.toLowerCase().contains('4v4') ||
      format.toLowerCase().contains('clash');

  int get baseHostReward => (hostMeta['host_reward'] as num?)?.toInt() ?? (isCs ? 10 : 30);
  bool get allowScreenshots => hostMeta['allow_screenshots'] as bool? ?? true;
  bool get isIdpLocked => hostMeta['idp_locked'] as bool? ?? false;
  DateTime? get idpBroadcastedAt => hostMeta['idp_broadcasted_at'] != null ? DateTime.tryParse(hostMeta['idp_broadcasted_at'].toString()) : null;
  List<dynamic> get scoresList => (hostMeta['scores'] as List?) ?? [];
  List<dynamic> get chatMessages => (hostMeta['chat'] as List?) ?? [];
  List<dynamic> get screenshotProofs => (hostMeta['screenshot_proofs'] as List?) ?? [];
  List<Map<String, dynamic>> get kickedTeams {
    final list = hostMeta['kicked_teams'] as List?;
    if (list == null) return [];
    return list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
  }

  bool isUserKickedOrBanned(String? userId, String? gameUid) {
    if ((userId == null || userId.isEmpty) && (gameUid == null || gameUid.isEmpty)) return false;
    return kickedTeams.any((k) {
      final kUserId = k['user_id']?.toString();
      final kUid = k['game_uid']?.toString();
      if (userId != null && userId.isNotEmpty && kUserId == userId) return true;
      if (gameUid != null && gameUid.isNotEmpty && kUid == gameUid) return true;
      return false;
    });
  }

  Map<String, dynamic>? getKickDetailsForUser(String? userId, String? gameUid) {
    if ((userId == null || userId.isEmpty) && (gameUid == null || gameUid.isEmpty)) return null;
    try {
      return kickedTeams.firstWhere((k) {
        final kUserId = k['user_id']?.toString();
        final kUid = k['game_uid']?.toString();
        if (userId != null && userId.isNotEmpty && kUserId == userId) return true;
        if (gameUid != null && gameUid.isNotEmpty && kUid == gameUid) return true;
        return false;
      });
    } catch (_) {
      return null;
    }
  }

  bool get isClaimed => hostId != null && hostId!.isNotEmpty;

  // Automated Host Penalty Safeguard Logic:
  // Rule 1: >10 min late IDP submission -> 50% penalty (₹15 reward for standard / ₹5 for CS)
  // Rule 2: >20 min missing IDP -> Auto-cancelled & full refund
  bool get isLatePenaltyApplied {
    if (idpBroadcastedAt != null) {
      final diff = idpBroadcastedAt!.difference(startTime).inMinutes;
      return diff > 10;
    }
    final now = DateTime.now();
    if (now.isAfter(startTime.add(const Duration(minutes: 10))) && (roomId == null || roomId!.isEmpty)) {
      return true;
    }
    return false;
  }

  int get actualHostReward => isLatePenaltyApplied ? (baseHostReward ~/ 2) : baseHostReward;

  bool get isPastCancellationThreshold {
    final now = DateTime.now();
    return now.isAfter(startTime.add(const Duration(minutes: 20))) && (roomId == null || roomId!.isEmpty) && status != 'completed';
  }

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    return TournamentModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Esports Match',
      game: json['game'] as String? ?? 'FREE FIRE',
      bannerUrl: json['banner_url'] as String? ?? '',
      entryFee: (json['entry_fee'] as num?)?.toDouble() ?? 0.0,
      prizePool: (json['prize_pool'] as num?)?.toDouble() ?? 0.0,
      perKill: (json['per_kill'] as num?)?.toDouble() ?? 0.0,
      format: json['format'] as String? ?? 'Squad',
      mapName: json['map_name'] as String? ?? 'Bermuda',
      maxSlots: json['max_slots'] as int? ?? 48,
      filledSlots: json['filled_slots'] as int? ?? 0,
      startTime: DateTime.tryParse(json['start_time'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'open',
      rules: json['rules'] != null
          ? (json['rules'] is String ? json['rules'] as String : jsonEncode(json['rules']))
          : null,
      roomId: json['room_id'] as String?,
      roomPassword: json['room_password'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }

  TournamentModel copyWith({
    String? id,
    String? title,
    String? game,
    String? bannerUrl,
    double? entryFee,
    double? prizePool,
    double? perKill,
    String? format,
    String? mapName,
    int? maxSlots,
    int? filledSlots,
    DateTime? startTime,
    String? status,
    String? rules,
    String? roomId,
    String? roomPassword,
    DateTime? createdAt,
  }) {
    return TournamentModel(
      id: id ?? this.id,
      title: title ?? this.title,
      game: game ?? this.game,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      entryFee: entryFee ?? this.entryFee,
      prizePool: prizePool ?? this.prizePool,
      perKill: perKill ?? this.perKill,
      format: format ?? this.format,
      mapName: mapName ?? this.mapName,
      maxSlots: maxSlots ?? this.maxSlots,
      filledSlots: filledSlots ?? this.filledSlots,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      rules: rules ?? this.rules,
      roomId: roomId ?? this.roomId,
      roomPassword: roomPassword ?? this.roomPassword,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'game': game,
      'banner_url': bannerUrl,
      'entry_fee': entryFee,
      'prize_pool': prizePool,
      'per_kill': perKill,
      'format': format,
      'map_name': mapName,
      'max_slots': maxSlots,
      'filled_slots': filledSlots,
      'start_time': startTime.toIso8601String(),
      'status': status,
      'rules': rules,
      'room_id': roomId,
      'room_password': roomPassword,
    };
  }
}

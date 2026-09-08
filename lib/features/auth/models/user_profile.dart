class UserProfile {
  final String id;
  final String username;
  final String? fullName;
  final String? avatarUrl;
  final String? gameIgn;
  final String? gameUid;
  final String primaryGame;
  final String? phone;
  final String? discordTag;
  final String role;
  final double walletBalance;
  final double depositBalance;
  final double winningBalance;
  final bool isVerified;
  final bool isOnboarded;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    required this.username,
    this.fullName,
    this.avatarUrl,
    this.gameIgn,
    this.gameUid,
    this.primaryGame = 'BGMI',
    this.phone,
    this.discordTag,
    this.role = 'player',
    this.walletBalance = 0.0,
    this.depositBalance = 0.0,
    this.winningBalance = 0.0,
    this.isVerified = false,
    this.isOnboarded = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'Gamer',
      fullName: json['full_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      gameIgn: json['game_ign'] as String?,
      gameUid: json['game_uid'] as String?,
      primaryGame: json['primary_game'] as String? ?? 'BGMI',
      phone: json['phone'] as String?,
      discordTag: json['discord_tag'] as String?,
      role: json['role'] as String? ?? 'player',
      walletBalance: (json['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      depositBalance: (json['deposit_balance'] as num?)?.toDouble() ?? 0.0,
      winningBalance: (json['winning_balance'] as num?)?.toDouble() ?? 0.0,
      isVerified: json['is_verified'] as bool? ?? false,
      isOnboarded: json['is_onboarded'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'game_ign': gameIgn,
      'game_uid': gameUid,
      'primary_game': primaryGame,
      'phone': phone,
      'discord_tag': discordTag,
      'role': role,
      'wallet_balance': walletBalance,
      'deposit_balance': depositBalance,
      'winning_balance': winningBalance,
      'is_verified': isVerified,
      'is_onboarded': isOnboarded,
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? fullName,
    String? avatarUrl,
    String? gameIgn,
    String? gameUid,
    String? primaryGame,
    String? phone,
    String? discordTag,
    String? role,
    double? walletBalance,
    double? depositBalance,
    double? winningBalance,
    bool? isVerified,
    bool? isOnboarded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gameIgn: gameIgn ?? this.gameIgn,
      gameUid: gameUid ?? this.gameUid,
      primaryGame: primaryGame ?? this.primaryGame,
      phone: phone ?? this.phone,
      discordTag: discordTag ?? this.discordTag,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
      depositBalance: depositBalance ?? this.depositBalance,
      winningBalance: winningBalance ?? this.winningBalance,
      isVerified: isVerified ?? this.isVerified,
      isOnboarded: isOnboarded ?? this.isOnboarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

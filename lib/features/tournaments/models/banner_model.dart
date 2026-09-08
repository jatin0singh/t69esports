class BannerModel {
  final String id;
  final String title;
  final String? subtitle;
  final String imageUrl;
  final String actionType; // tournament, external_link, game_hub
  final String? actionTarget;
  final String tag;
  final bool isActive;
  final int orderIndex;

  const BannerModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.imageUrl,
    this.actionType = 'tournament',
    this.actionTarget,
    this.tag = 'FEATURED',
    this.isActive = true,
    this.orderIndex = 0,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Championship',
      subtitle: json['subtitle'] as String?,
      imageUrl: json['image_url'] as String? ?? '',
      actionType: json['action_type'] as String? ?? 'tournament',
      actionTarget: json['action_target'] as String?,
      tag: json['tag'] as String? ?? 'FEATURED',
      isActive: json['is_active'] as bool? ?? true,
      orderIndex: json['order_index'] as int? ?? 0,
    );
  }
}

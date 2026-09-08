class SponsorModel {
  final String id;
  final String name;
  final String logoUrl;
  final String? websiteUrl;
  final String tier; // title_sponsor, powered_by, partner
  final bool isActive;

  const SponsorModel({
    required this.id,
    required this.name,
    required this.logoUrl,
    this.websiteUrl,
    this.tier = 'partner',
    this.isActive = true,
  });

  factory SponsorModel.fromJson(Map<String, dynamic> json) {
    return SponsorModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Sponsor',
      logoUrl: json['logo_url'] as String? ?? '',
      websiteUrl: json['website_url'] as String?,
      tier: json['tier'] as String? ?? 'partner',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

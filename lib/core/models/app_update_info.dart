class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final int minSupportedBuild;
  final String apkUrl;
  final String updateNotes;
  final bool isForceUpdate;
  final DateTime? publishedAt;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.minSupportedBuild,
    required this.apkUrl,
    required this.updateNotes,
    this.isForceUpdate = false,
    this.publishedAt,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      buildNumber: (json['build_number'] as num?)?.toInt() ?? 1,
      minSupportedBuild: (json['min_supported_build'] as num?)?.toInt() ?? 1,
      apkUrl: json['apk_url']?.toString() ?? '',
      updateNotes: json['update_notes']?.toString() ?? 'Bug fixes and performance improvements.',
      isForceUpdate: json['is_force_update'] == true || json['force_update'] == true,
      publishedAt: json['published_at'] != null ? DateTime.tryParse(json['published_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'build_number': buildNumber,
      'min_supported_build': minSupportedBuild,
      'apk_url': apkUrl,
      'update_notes': updateNotes,
      'is_force_update': isForceUpdate,
      'published_at': (publishedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  bool isUpdateAvailable(int currentBuildNumber, String currentVersion) {
    if (buildNumber > currentBuildNumber) return true;
    return _compareSemver(latestVersion, currentVersion) > 0;
  }

  bool isRequired(int currentBuildNumber) {
    if (isForceUpdate) return true;
    if (currentBuildNumber < minSupportedBuild) return true;
    return false;
  }

  static int _compareSemver(String v1, String v2) {
    final clean1 = v1.replaceAll(RegExp(r'[^0-9.]'), '');
    final clean2 = v2.replaceAll(RegExp(r'[^0-9.]'), '');
    final p1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final p2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final n1 = i < p1.length ? p1[i] : 0;
      final n2 = i < p2.length ? p2[i] : 0;
      if (n1 > n2) return 1;
      if (n1 < n2) return -1;
    }
    return 0;
  }
}

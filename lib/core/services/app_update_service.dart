import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/app_update_info.dart';
import '../utils/ui_helpers.dart';
import '../widgets/app_update_dialog.dart';

class AppUpdateService {
  static PackageInfo? _cachedPackageInfo;
  static bool _hasPromptedThisSession = false;

  /// Get current app package metadata
  static Future<PackageInfo> getPackageInfo() async {
    if (_cachedPackageInfo != null) return _cachedPackageInfo!;
    try {
      _cachedPackageInfo = await PackageInfo.fromPlatform();
    } catch (_) {
      _cachedPackageInfo = PackageInfo(
        appName: 'T69 Esports',
        packageName: 'com.t69.esports',
        version: '1.0.0',
        buildNumber: '1',
      );
    }
    return _cachedPackageInfo!;
  }

  /// Fetch remote update config from Supabase
  static Future<AppUpdateInfo?> fetchLatestUpdateInfo({SupabaseClient? client}) async {
    final supa = client ?? SupabaseConfig.client;

    // 1. Primary: query from tournaments system row
    try {
      final tRes = await supa
          .from('tournaments')
          .select('rules, banner_url')
          .eq('title', '__APP_UPDATE_CONFIG__')
          .maybeSingle();

      if (tRes != null) {
        final rules = tRes['rules'];
        if (rules is Map) return AppUpdateInfo.fromJson(Map<String, dynamic>.from(rules));
        if (rules is String && rules.trim().startsWith('{')) {
          return AppUpdateInfo.fromJson(jsonDecode(rules) as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    // 2. Secondary: Try app_config table
    try {
      final res = await supa
          .from('app_config')
          .select()
          .eq('key', 'app_update')
          .maybeSingle();

      if (res != null) {
        final val = res['value'];
        if (val is Map) return AppUpdateInfo.fromJson(Map<String, dynamic>.from(val));
        if (val is String && val.trim().startsWith('{')) {
          return AppUpdateInfo.fromJson(jsonDecode(val) as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    // 3. Fallback: query from banners metadata row
    try {
      final bannerRes = await supa
          .from('banners')
          .select()
          .eq('title', '__APP_UPDATE_CONFIG__')
          .maybeSingle();

      if (bannerRes != null) {
        final link = bannerRes['subtitle']?.toString() ?? bannerRes['link_url']?.toString() ?? '';
        if (link.trim().startsWith('{')) {
          return AppUpdateInfo.fromJson(jsonDecode(link) as Map<String, dynamic>);
        }
      }
    } catch (_) {}

    return null;
  }

  /// Admin function: Publish / Save new app version config to Supabase
  static Future<void> publishNewVersion(
    AppUpdateInfo info, {
    SupabaseClient? client,
  }) async {
    final supa = client ?? SupabaseConfig.client;
    final jsonMap = info.toJson();
    final jsonStr = jsonEncode(jsonMap);

    // 1. Primary: Save to tournaments system config row
    try {
      final existing = await supa
          .from('tournaments')
          .select('id')
          .eq('title', '__APP_UPDATE_CONFIG__')
          .maybeSingle();

      if (existing != null) {
        await supa.from('tournaments').update({
          'rules': jsonStr,
          'banner_url': info.apkUrl,
          'status': 'open',
        }).eq('id', existing['id']);
      } else {
        await supa.from('tournaments').insert({
          'title': '__APP_UPDATE_CONFIG__',
          'game': 'SYSTEM',
          'entry_fee': 0,
          'prize_pool': 0,
          'per_kill': 0,
          'format': 'SOLO',
          'map_name': 'GLOBAL',
          'max_slots': 1,
          'filled_slots': 0,
          'start_time': DateTime.now().toIso8601String(),
          'status': 'open',
          'rules': jsonStr,
          'banner_url': info.apkUrl,
        });
      }
    } catch (_) {}

    // 2. Secondary: Try upserting into app_config table
    try {
      await supa.from('app_config').upsert({
        'key': 'app_update',
        'value': jsonMap,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {}
  }

  /// Check for update and prompt dialog if newer version is found.
  /// If isManual is true, provides immediate feedback banner if already up-to-date.
  static Future<bool> checkAndPromptUpdate(
    BuildContext context, {
    bool isManual = false,
  }) async {
    // If not manual, prompt only once per app session to avoid disturbing user
    if (!isManual && _hasPromptedThisSession) return false;

    try {
      final packageInfo = await getPackageInfo();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = int.tryParse(packageInfo.buildNumber) ?? 1;

      final updateInfo = await fetchLatestUpdateInfo();
      if (updateInfo == null) {
        if (isManual && context.mounted) {
          UiHelpers.showSuccessBanner(context, 'You are on the latest version (v$currentVersion+$currentBuildNumber).');
        }
        return false;
      }

      final isAvailable = updateInfo.isUpdateAvailable(currentBuildNumber, currentVersion);

      if (isAvailable) {
        _hasPromptedThisSession = true;
        if (context.mounted) {
          await AppUpdateDialog.show(
            context,
            updateInfo: updateInfo,
            installedVersion: currentVersion,
            installedBuildNumber: currentBuildNumber,
          );
        }
        return true;
      } else {
        if (isManual && context.mounted) {
          UiHelpers.showSuccessBanner(
            context,
            'App is up-to-date! Current version: v$currentVersion (Build $currentBuildNumber)',
          );
        }
        return false;
      }
    } catch (e) {
      if (isManual && context.mounted) {
        UiHelpers.showErrorBanner(context, 'Unable to check for updates: $e');
      }
      return false;
    }
  }
}

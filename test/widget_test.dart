import 'package:flutter_test/flutter_test.dart';
import 'package:t69esports/core/utils/validators.dart';
import 'package:t69esports/core/models/app_update_info.dart';

void main() {
  group('Validators Unit Tests', () {
    test('validateEmail validates correctly', () {
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('test@t69esports.com'), isNull);
    });

    test('validatePassword validates strong passwords', () {
      expect(Validators.validatePassword('weak'), isNotNull);
      expect(Validators.validatePassword('NoNumbers!'), isNotNull);
      expect(Validators.validatePassword('ValidPass123'), isNull);
    });

    test('validateUsername enforces esports gamer tag rules', () {
      expect(Validators.validateUsername('123abc'), isNotNull); // starts with number
      expect(Validators.validateUsername('a'), isNotNull); // too short
      expect(Validators.validateUsername('valid_tag99'), isNull);
    });
  });

  group('AppUpdateInfo Tests', () {
    test('isUpdateAvailable returns true when remote build is higher', () {
      final info = AppUpdateInfo(
        latestVersion: '1.0.1',
        buildNumber: 2,
        minSupportedBuild: 1,
        apkUrl: 'https://example.com/app.apk',
        updateNotes: 'New update',
        isForceUpdate: false,
      );

      // Current build is 1, remote is 2
      expect(info.isUpdateAvailable(1, '1.0.0'), isTrue);

      // Current build is 2, remote is 2
      expect(info.isUpdateAvailable(2, '1.0.1'), isFalse);

      // Current build is 3, remote is 2
      expect(info.isUpdateAvailable(3, '1.0.2'), isFalse);
    });

    test('isUpdateAvailable falls back to semver when build numbers are identical or 0', () {
      final info = AppUpdateInfo(
        latestVersion: '1.1.0',
        buildNumber: 1,
        minSupportedBuild: 1,
        apkUrl: 'https://example.com/app.apk',
        updateNotes: 'New feature release',
        isForceUpdate: false,
      );

      // Same build number, but semver 1.1.0 > 1.0.0
      expect(info.isUpdateAvailable(1, '1.0.0'), isTrue);

      // Same version
      expect(info.isUpdateAvailable(1, '1.1.0'), isFalse);
    });

    test('isRequired correctly handles force update and minimum supported build', () {
      // 1. Force update flag is explicitly set to true
      final forcedInfo = AppUpdateInfo(
        latestVersion: '2.0.0',
        buildNumber: 5,
        minSupportedBuild: 3,
        apkUrl: 'https://example.com/app.apk',
        updateNotes: 'Mandatory migration',
        isForceUpdate: true,
      );
      expect(forcedInfo.isRequired(1), isTrue);
      expect(forcedInfo.isRequired(4), isTrue);

      // 2. Force update is false, but user build is below minSupportedBuild
      final minBuildInfo = AppUpdateInfo(
        latestVersion: '1.5.0',
        buildNumber: 4,
        minSupportedBuild: 3,
        apkUrl: 'https://example.com/app.apk',
        updateNotes: 'Lobby protocol updated',
        isForceUpdate: false,
      );
      expect(minBuildInfo.isRequired(2), isTrue); // 2 < 3 -> required
      expect(minBuildInfo.isRequired(3), isFalse); // 3 >= 3 -> optional
      expect(minBuildInfo.isRequired(4), isFalse); // 4 >= 3 -> optional
    });

    test('JSON serialization & deserialization works seamlessly', () {
      final original = AppUpdateInfo(
        latestVersion: '1.0.4',
        buildNumber: 5,
        minSupportedBuild: 2,
        apkUrl: 'https://t69esports.com/release.apk',
        updateNotes: '• Major anti-cheat patches\n• Match history fix',
        isForceUpdate: true,
        publishedAt: DateTime(2026, 9, 7, 12, 0),
      );

      final json = original.toJson();
      final recovered = AppUpdateInfo.fromJson(json);

      expect(recovered.latestVersion, equals('1.0.4'));
      expect(recovered.buildNumber, equals(5));
      expect(recovered.minSupportedBuild, equals(2));
      expect(recovered.apkUrl, equals('https://t69esports.com/release.apk'));
      expect(recovered.isForceUpdate, isTrue);
      expect(recovered.updateNotes, contains('Major anti-cheat patches'));
    });
  });
}

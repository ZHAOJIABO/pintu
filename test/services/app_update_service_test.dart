import 'package:bobobeads/services/app_update_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requires an update when current version is lower than minimum', () {
    final policy = AppUpdatePolicy.fromConfig(const {
      'latestVersion': '1.0.1',
      'minimumVersion': '1.0.1',
    });

    expect(policy.isConfigured, isTrue);
    expect(policy.releaseNotes, isEmpty);
    expect(policy.appStoreId, isEmpty);
    expect(policy.requiresUpdate('1.0.0'), isTrue);
    expect(policy.hasOptionalUpdate('1.0.0'), isFalse);
  });

  test('offers optional update only between minimum and latest', () {
    final policy = AppUpdatePolicy.fromConfig(const {
      'latestVersion': '1.2.0',
      'minimumVersion': '1.1.0',
    });

    expect(policy.requiresUpdate('1.1.0'), isFalse);
    expect(policy.hasOptionalUpdate('1.1.0'), isTrue);
    expect(policy.hasOptionalUpdate('1.2.0'), isFalse);
  });

  test('reads update versions from the data payload when present', () {
    final policy = AppUpdatePolicy.fromConfig(const {
      'data': {
        'latestVersion': '1.0.1',
        'minimumVersion': '1.0.1',
        'releaseNotes': '修复已知问题。',
        'appStoreId': '1234567890',
      },
    });

    expect(policy.requiresUpdate('1.0.0'), isTrue);
    expect(policy.releaseNotes, '修复已知问题。');
    expect(policy.appStoreId, '1234567890');
  });
}

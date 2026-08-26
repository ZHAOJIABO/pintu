import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api/api_models.dart';

const fallbackAppVersion = '1.1.1';

class AppUpdatePolicy {
  final String latestVersion;
  final String minimumVersion;
  final String releaseNotes;
  final String appStoreId;
  final String appStoreUrl;

  const AppUpdatePolicy({
    required this.latestVersion,
    required this.minimumVersion,
    required this.releaseNotes,
    required this.appStoreId,
    required this.appStoreUrl,
  });

  factory AppUpdatePolicy.fromConfig(JsonMap response) {
    final configs = response['configs'];
    final data = response['data'];
    final values = configs is Map
        ? configs
        : data is Map
        ? data
        : const <Object?, Object?>{};
    String value(String key) =>
        (response[key] ?? values[key] ?? '').toString().trim();
    String firstValue(List<String> keys) {
      for (final key in keys) {
        final result = value(key);
        if (result.isNotEmpty) return result;
      }
      return '';
    }

    return AppUpdatePolicy(
      latestVersion: value('latestVersion'),
      minimumVersion: value('minimumVersion'),
      releaseNotes: value('releaseNotes'),
      appStoreId: firstValue(['appStoreId', 'iosAppStoreId']),
      appStoreUrl: firstValue(['appStoreUrl', 'iosAppStoreUrl', 'storeUrl']),
    );
  }

  bool get isConfigured =>
      _Version.tryParse(latestVersion) != null &&
      _Version.tryParse(minimumVersion) != null;

  bool requiresUpdate(String currentVersion) {
    final current = _Version.tryParse(currentVersion);
    final minimum = _Version.tryParse(minimumVersion);
    return current != null && minimum != null && current < minimum;
  }

  bool hasOptionalUpdate(String currentVersion) {
    final current = _Version.tryParse(currentVersion);
    final latest = _Version.tryParse(latestVersion);
    final minimum = _Version.tryParse(minimumVersion);
    return current != null &&
        latest != null &&
        minimum != null &&
        current >= minimum &&
        current < latest;
  }
}

/// Opens the release configured by the system-config response.
///
/// iOS requires its numeric App Store identifier when using the native store
/// listing API, so a missing value returns `false` rather than throwing.
class AppStoreUpdateService {
  const AppStoreUpdateService();

  Future<bool> open(AppUpdatePolicy policy) async {
    final storeUrl = Uri.tryParse(policy.appStoreUrl);
    if (storeUrl != null &&
        (storeUrl.scheme == 'https' || storeUrl.scheme == 'itms-apps')) {
      try {
        return await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }

    if (policy.appStoreId.isEmpty) return false;
    try {
      await InAppReview.instance.openStoreListing(
        appStoreId: policy.appStoreId,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AppVersionService {
  const AppVersionService();

  Future<String> currentVersion() async {
    try {
      final version = (await PackageInfo.fromPlatform()).version.trim();
      return _Version.tryParse(version) == null ? fallbackAppVersion : version;
    } catch (_) {
      return fallbackAppVersion;
    }
  }
}

class _Version implements Comparable<_Version> {
  final List<int> values;
  const _Version(this.values);

  static _Version? tryParse(String value) {
    final raw = value.trim().split('+').first.split('-').first;
    if (raw.isEmpty) return null;
    final values = raw.split('.').map(int.tryParse).toList();
    if (values.any((item) => item == null)) return null;
    return _Version(values.cast<int>());
  }

  @override
  int compareTo(_Version other) {
    final length = values.length > other.values.length
        ? values.length
        : other.values.length;
    for (var index = 0; index < length; index++) {
      final result = (index < values.length ? values[index] : 0).compareTo(
        index < other.values.length ? other.values[index] : 0,
      );
      if (result != 0) return result;
    }
    return 0;
  }

  bool operator <(_Version other) => compareTo(other) < 0;
  bool operator >=(_Version other) => compareTo(other) >= 0;
}

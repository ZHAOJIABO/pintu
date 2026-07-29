import 'dart:typed_data';

import 'api/api_client.dart';
import 'api/api_models.dart';
import 'api/api_repositories.dart';

enum ExportWatermarkMode { none, marketing, online }

class ExportWatermarkPolicy {
  const ExportWatermarkPolicy({required this.mode, required this.url});

  const ExportWatermarkPolicy.none()
    : mode = ExportWatermarkMode.none,
      url = '';

  final ExportWatermarkMode mode;
  final String url;

  bool get isEnabled => mode != ExportWatermarkMode.none;

  factory ExportWatermarkPolicy.fromConfigResponse(JsonMap response) {
    final rawConfigs = response['configs'];
    if (rawConfigs is! Map) return const ExportWatermarkPolicy.none();

    final configs = <String, String>{};
    for (final entry in rawConfigs.entries) {
      if (entry.key is String && entry.value is String) {
        configs[entry.key as String] = entry.value as String;
      }
    }
    return ExportWatermarkPolicy.fromConfigs(configs);
  }

  factory ExportWatermarkPolicy.fromConfigs(Map<String, String> configs) {
    final url = configs['export_watermark_url'];
    final mode = switch (configs['export_watermark_mode']) {
      'marketing' => ExportWatermarkMode.marketing,
      'online' => ExportWatermarkMode.online,
      _ => ExportWatermarkMode.none,
    };

    if (mode == ExportWatermarkMode.none || url == null || url.isEmpty) {
      return const ExportWatermarkPolicy.none();
    }
    return ExportWatermarkPolicy(mode: mode, url: url);
  }

  @override
  bool operator ==(Object other) {
    return other is ExportWatermarkPolicy &&
        other.mode == mode &&
        other.url == url;
  }

  @override
  int get hashCode => Object.hash(mode, url);
}

/// Resolves the current export watermark policy immediately before an export.
///
/// The server owns the active watermark image and sends its final public URL.
/// This class deliberately neither derives URLs from the mode nor caches a
/// policy, so a server-side switch applies to the next client export.
class ExportWatermarkService {
  const ExportWatermarkService({required this.system, required this.client});

  final SystemRepository system;
  final ApiClient client;

  Future<Uint8List?> loadWatermarkBytes() async {
    final response = await system.getConfig();
    final policy = ExportWatermarkPolicy.fromConfigResponse(response);
    if (!policy.isEnabled) return null;

    return client.getBytes(policy.url);
  }
}

import 'dart:async';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api/api_scope.dart';
import '../services/app_update_service.dart';
import '../services/style_thumbnail_cache.dart';
import '../widgets/app_toast.dart';
import 'upload_pattern_screen.dart';

const _settingsBackground = Color(0xFFF0F0F4);
const _settingsFontFamily = 'Alimama FangYuanTi VF';
const _settingsFontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];
final _privacyPolicyUrl = Uri.parse('https://appbobo.cn/privacy');
final _userAgreementUrl = Uri.parse('https://appbobo.cn/terms');
final _aboutUrl = Uri.parse('https://appbobo.cn/about');

typedef ExternalUrlLauncher = Future<bool> Function(Uri url);
typedef AppReviewRequester = Future<bool> Function();
typedef AppCacheClearer =
    Future<void> Function(StyleThumbnailCache? styleThumbnails);

/// Figma “设置”页。
class SettingsScreen extends StatefulWidget {
  final ExternalUrlLauncher launchExternalUrl;
  final AppReviewRequester requestAppReview;
  final AppCacheClearer clearAppCache;

  const SettingsScreen({
    super.key,
    this.launchExternalUrl = _launchExternalUrl,
    this.requestAppReview = _requestAppReview,
    this.clearAppCache = _clearAppCache,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BackendServices? _services;
  String _userId = '';
  String _appVersion = fallbackAppVersion;
  bool _hasOptionalUpdate = false;
  AppUpdatePolicy? _updatePolicy;
  bool _clearingCache = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = BackendScope.maybeOf(context);
    if (identical(services, _services)) return;
    _services = services;
    if (services != null) _loadUserId(services);
    unawaited(_loadVersionInfo(services));
  }

  Future<void> _loadVersionInfo(BackendServices? services) async {
    final version = await const AppVersionService().currentVersion();
    var hasOptionalUpdate = false;
    AppUpdatePolicy? updatePolicy;
    if (services != null) {
      try {
        updatePolicy = AppUpdatePolicy.fromConfig(
          await services.system.getConfig(),
        );
        hasOptionalUpdate =
            updatePolicy.isConfigured &&
            updatePolicy.hasOptionalUpdate(version);
      } catch (_) {}
    }
    if (!mounted || !identical(_services, services)) return;
    setState(() {
      _appVersion = version;
      _hasOptionalUpdate = hasOptionalUpdate;
      _updatePolicy = updatePolicy;
    });
  }

  Future<void> _openStoreListing() async {
    final policy = _updatePolicy;
    if (policy == null || !await const AppStoreUpdateService().open(policy)) {
      if (mounted) _showLaunchFailure();
    }
  }

  Future<void> _loadUserId(BackendServices services) async {
    final userId = (await services.store.readSession())?.user.userId ?? '';
    if (!mounted || !identical(_services, services)) return;
    setState(() => _userId = userId);
  }

  Future<void> _openExternalPage(Uri url) async {
    try {
      final launched = await widget.launchExternalUrl(url);
      if (!launched && mounted) {
        _showLaunchFailure();
      }
    } catch (_) {
      if (mounted) _showLaunchFailure();
    }
  }

  Future<void> _openAppReview() async {
    try {
      final requested = await widget.requestAppReview();
      if (!requested && mounted) {
        _showReviewFailure();
      }
    } catch (_) {
      if (mounted) _showReviewFailure();
    }
  }

  Future<void> _confirmAndClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _ClearCacheDialog(
        onCancel: () => Navigator.of(dialogContext).pop(false),
        onConfirm: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (confirmed != true || !mounted || _clearingCache) return;

    setState(() => _clearingCache = true);
    try {
      await widget.clearAppCache(_services?.styleThumbnails);
      if (mounted) {
        showAppToast(context, '缓存已清除');
      }
    } catch (_) {
      if (mounted) {
        showAppToast(context, '清除失败，请稍后重试');
      }
    } finally {
      if (mounted) setState(() => _clearingCache = false);
    }
  }

  void _showLaunchFailure() {
    showAppToast(context, '暂时无法打开页面');
  }

  void _showReviewFailure() {
    showAppToast(context, '暂时无法发起评分');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _settingsBackground,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Column(
              children: [
                _SettingsNavigationBar(
                  onBackTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 21),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-rate-app'),
                            iconAsset: 'assets/pin_icon/settings_rate.svg',
                            title: '给兔评分',
                            trailing: _SettingsChevron(),
                            onTap: () => unawaited(_openAppReview()),
                          ),
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-user-agreement'),
                            iconAsset: 'assets/pin_icon/settings_agreement.svg',
                            title: '用户协议',
                            trailing: _SettingsChevron(),
                            onTap: () =>
                                unawaited(_openExternalPage(_userAgreementUrl)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-privacy-policy'),
                            iconAsset: 'assets/pin_icon/settings_privacy.svg',
                            title: '隐私政策',
                            trailing: _SettingsChevron(),
                            onTap: () =>
                                unawaited(_openExternalPage(_privacyPolicyUrl)),
                          ),
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-about'),
                            iconAsset: 'assets/pin_icon/settings_about.svg',
                            iconContentSize: Size(15.3112, 15.109),
                            title: '关于我们',
                            trailing: _SettingsChevron(),
                            onTap: () =>
                                unawaited(_openExternalPage(_aboutUrl)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-clear-cache'),
                            iconAsset:
                                'assets/pin_icon/settings_clear_cache.svg',
                            iconContentSize: Size(12, 13.3347),
                            title: _clearingCache ? '清理中…' : '清除缓存',
                            trailing: const _SettingsChevron(),
                            onTap: _clearingCache
                                ? null
                                : () => unawaited(_confirmAndClearCache()),
                          ),
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_version.svg',
                            title: '当前版本',
                            trailing: _VersionTrailing(
                              version: _appVersion,
                              showUpdate: _hasOptionalUpdate,
                              onUpdate: () => unawaited(_openStoreListing()),
                            ),
                          ),
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_my_id.svg',
                            title: '我的ID',
                            trailing: _UserIdTrailing(userId: _userId),
                          ),
                        ],
                      ),
                      const SizedBox(height: 23),
                      _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            rowKey: const ValueKey('settings-upload-pattern'),
                            iconAsset:
                                'assets/pin_icon/settings_upload_pattern.svg',
                            title: '我要传图纸',
                            trailing: _SettingsChevron(),
                            onTap: () => Navigator.of(context).push<void>(
                              MaterialPageRoute(
                                builder: (_) => UploadPatternScreen(
                                  services: BackendScope.maybeOf(context),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> _launchExternalUrl(Uri url) {
  return launchUrl(url, mode: LaunchMode.externalApplication);
}

Future<bool> _requestAppReview() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) return false;
  await review.requestReview();
  return true;
}

Future<void> _clearAppCache(StyleThumbnailCache? styleThumbnails) {
  return Future.wait<void>([
    DefaultCacheManager().emptyCache(),
    if (styleThumbnails != null) styleThumbnails.clear(),
  ]);
}

class _ClearCacheDialog extends StatelessWidget {
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ClearCacheDialog({required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: const ValueKey('settings-clear-cache-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 21),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 333),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '清除缓存',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: _settingsFontFamily,
                  fontFamilyFallback: _settingsFontFallbacks,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                '将清除已缓存的图片和临时文件，不会删除图纸、成品和登录信息。',
                style: TextStyle(
                  color: Colors.black,
                  fontFamily: _settingsFontFamily,
                  fontFamilyFallback: _settingsFontFallbacks,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 20 / 15,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ClearCacheDialogButton(
                      label: '取消',
                      backgroundColor: _settingsBackground,
                      foregroundColor: Colors.black,
                      onTap: onCancel,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ClearCacheDialogButton(
                      key: const ValueKey('settings-clear-cache-confirm'),
                      label: '清除',
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      onTap: onConfirm,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearCacheDialogButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;

  const _ClearCacheDialogButton({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: backgroundColor,
        borderRadius: const BorderRadius.all(Radius.circular(44)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(44)),
          child: SizedBox(
            height: 52,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontFamily: _settingsFontFamily,
                  fontFamilyFallback: _settingsFontFallbacks,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsNavigationBar extends StatelessWidget {
  final VoidCallback onBackTap;

  const _SettingsNavigationBar({required this.onBackTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Semantics(
            button: true,
            label: '返回',
            child: InkResponse(
              onTap: onBackTap,
              radius: 24,
              child: const SizedBox(
                width: 80,
                height: 44,
                child: Align(
                  alignment: Alignment.center,
                  child: _SettingsSvgIcon(
                    asset: 'assets/pin_icon/settings_back.svg',
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          const Expanded(
            child: Text(
              '设置',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontFamily: _settingsFontFamily,
                fontFamilyFallback: _settingsFontFallbacks,
                fontSize: 18,
                fontWeight: FontWeight.w500,
                height: 22 / 18,
              ),
            ),
          ),
          const SizedBox(width: 80),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsRowData> rows;

  const _SettingsGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [for (final row in rows) _SettingsRow(data: row)],
        ),
      ),
    );
  }
}

class _SettingsRowData {
  final Key? rowKey;
  final String iconAsset;
  final Size? iconContentSize;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsRowData({
    this.rowKey,
    required this.iconAsset,
    this.iconContentSize,
    required this.title,
    required this.trailing,
    this.onTap,
  });
}

class _SettingsRow extends StatelessWidget {
  final _SettingsRowData data;

  const _SettingsRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: data.onTap != null,
      label: data.onTap == null ? null : data.title,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: SizedBox(
          key: data.rowKey,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _SettingsSvgIcon(
                  asset: data.iconAsset,
                  size: 16,
                  contentSize: data.iconContentSize,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.title,
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: _settingsFontFamily,
                      fontFamilyFallback: _settingsFontFallbacks,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 16 / 15,
                    ),
                  ),
                ),
                data.trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsChevron extends StatelessWidget {
  const _SettingsChevron();

  @override
  Widget build(BuildContext context) {
    return const _SettingsSvgIcon(
      asset: 'assets/pin_icon/settings_chevron.svg',
      size: 12,
    );
  }
}

class _VersionTrailing extends StatelessWidget {
  final String version;
  final bool showUpdate;
  final VoidCallback onUpdate;

  const _VersionTrailing({
    required this.version,
    required this.showUpdate,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('V$version', style: _settingsTrailingTextStyle),
        if (showUpdate) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onUpdate,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFFFF09A),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Text(
                  '更新',
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: _settingsFontFamily,
                    fontFamilyFallback: _settingsFontFallbacks,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 9 / 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _UserIdTrailing extends StatelessWidget {
  final String userId;

  const _UserIdTrailing({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();
    return Text(userId, style: _settingsTrailingTextStyle);
  }
}

class _SettingsSvgIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Size? contentSize;

  const _SettingsSvgIcon({
    required this.asset,
    required this.size,
    this.contentSize,
  });

  @override
  Widget build(BuildContext context) {
    final contentSize = this.contentSize;
    if (contentSize != null) {
      return SizedBox.square(
        dimension: size,
        child: Center(
          child: SvgPicture.asset(
            asset,
            width: contentSize.width,
            height: contentSize.height,
          ),
        ),
      );
    }
    return SvgPicture.asset(asset, width: size, height: size);
  }
}

const _settingsTrailingTextStyle = TextStyle(
  color: Colors.black,
  fontFamily: _settingsFontFamily,
  fontFamilyFallback: _settingsFontFallbacks,
  fontSize: 15,
  fontWeight: FontWeight.w500,
  height: 16 / 15,
);

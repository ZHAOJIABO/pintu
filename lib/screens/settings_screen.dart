import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../services/api/api_scope.dart';
import 'upload_pattern_screen.dart';

const _settingsBackground = Color(0xFFF0F0F4);
const _settingsFontFamily = 'Alimama FangYuanTi VF';
const _settingsFontFallbacks = ['PingFang SC', 'Heiti SC', 'Microsoft YaHei'];

/// Figma “设置”页。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  BackendServices? _services;
  String _userId = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final services = BackendScope.maybeOf(context);
    if (identical(services, _services)) return;
    _services = services;
    if (services != null) _loadUserId(services);
  }

  Future<void> _loadUserId(BackendServices services) async {
    final userId = (await services.store.readSession())?.user.userId ?? '';
    if (!mounted || !identical(_services, services)) return;
    setState(() => _userId = userId);
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
                      const _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_rate.svg',
                            title: '给兔评分',
                            trailing: _SettingsChevron(),
                          ),
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_agreement.svg',
                            title: '用户协议',
                            trailing: _SettingsChevron(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const _SettingsGroup(
                        rows: [
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_privacy.svg',
                            title: '隐私政策',
                            trailing: _SettingsChevron(),
                          ),
                          _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_about.svg',
                            iconContentSize: Size(15.3112, 15.109),
                            title: '关于我们',
                            trailing: _SettingsChevron(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _SettingsGroup(
                        rows: [
                          const _SettingsRowData(
                            iconAsset:
                                'assets/pin_icon/settings_clear_cache.svg',
                            iconContentSize: Size(12, 13.3347),
                            title: '清除缓存',
                            trailing: _SettingsChevron(),
                          ),
                          const _SettingsRowData(
                            iconAsset: 'assets/pin_icon/settings_version.svg',
                            title: '当前版本',
                            trailing: _VersionTrailing(),
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
  const _VersionTrailing();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('V1.1.1', style: _settingsTrailingTextStyle),
        SizedBox(width: 8),
        DecoratedBox(
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

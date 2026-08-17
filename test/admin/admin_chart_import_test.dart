import 'dart:convert';
import 'dart:typed_data';

import 'package:bobobeads/admin/admin_api.dart';
import 'package:bobobeads/admin/admin_app.dart';
import 'package:bobobeads/services/image_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// Hands the portal a synthesized chart so the import flow can run without the
/// platform image picker.
class _FakeImageService extends ImageService {
  final Uint8List bytes;

  _FakeImageService(this.bytes);

  @override
  Future<XFile?> pickFullResolutionImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    return XFile.fromData(bytes, name: 'chart.png', mimeType: 'image/png');
  }
}

void main() {
  /// A 3x2 chart of flat 24px cells, painted in colours that exist in Mard 221.
  Uint8List chartBytes() {
    const cellSize = 24;
    const colors = [
      [0xfa, 0xf4, 0xc8],
      [0x00, 0x00, 0x00],
      [0xff, 0xff, 0xff],
    ];
    final image = img.Image(width: 3 * cellSize, height: 2 * cellSize);
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        final color = colors[(col + row) % colors.length];
        img.fillRect(
          image,
          x1: col * cellSize,
          y1: row * cellSize,
          x2: col * cellSize + cellSize - 1,
          y2: row * cellSize + cellSize - 1,
          color: img.ColorRgb8(color[0], color[1], color[2]),
        );
      }
    }
    return Uint8List.fromList(img.encodePng(image));
  }

  Future<void> login(WidgetTester tester, Uint8List bytes) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      BoboBeadsAdminApp(
        imageService: _FakeImageService(bytes),
        api: AdminApi(
          baseUrl: 'http://api.example.test',
          httpClient: MockClient((request) async {
            switch (request.url.path) {
              case '/api/v1/admin/login':
                return _jsonResponse({'accessToken': 'admin-token'});
              case '/api/v1/admin/template-categories':
                return _jsonResponse({
                  'categories': [
                    {'categoryId': 1, 'name': '动物', 'templateCount': 0},
                  ],
                });
              default:
                throw StateError('Unexpected request: ${request.url}');
            }
          }),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'operator');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.text('进入工作台'));
    await tester.pumpAndSettle();
  }

  testWidgets('图纸导入页要求先选图并填写行列数', (tester) async {
    await login(tester, chartBytes());

    await tester.tap(find.text('图纸导入'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chart-import-cols')), findsOneWidget);
    expect(find.byKey(const ValueKey('chart-import-rows')), findsOneWidget);
    // Nothing to publish until a chart has actually been parsed.
    expect(find.byKey(const ValueKey('chart-import-use')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('chart-import-parse')));
    await tester.pumpAndSettle();
    expect(find.text('请先选择一张裁剪好的图纸图片'), findsOneWidget);

    await tester.tap(find.text('选择图纸图片'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chart-import-parse')));
    await tester.pumpAndSettle();
    expect(find.text('请填写正确的列数和行数'), findsOneWidget);
  });

  testWidgets('解析后可交给发布流程，且生成设置不会清掉导入的图纸', (tester) async {
    await login(tester, chartBytes());

    await tester.tap(find.text('图纸导入'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('选择图纸图片'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('chart-import-cols')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('chart-import-rows')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('chart-import-parse')));
    await tester.pumpAndSettle();

    expect(find.textContaining('已解析 3×2'), findsOneWidget);
    expect(find.textContaining('共 6 颗豆子'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chart-import-use')));
    await tester.pumpAndSettle();

    // Handing the pattern over jumps to the publish workspace and marks it.
    expect(find.text('图纸已导入，请填写信息后发布。'), findsOneWidget);
    final badge = find.byKey(const ValueKey('admin-import-badge'));
    expect(badge, findsOneWidget);
    expect(find.text('来自图纸导入 · 3×2'), findsOneWidget);

    // The five generation settings each null out `_pattern`, so they must be
    // locked while an imported chart is loaded.
    final toggle = find.byKey(const ValueKey('admin-remove-background-toggle'));
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNull);
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('生成拼豆图纸'),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNull,
    );

    // Clearing the import restores the photo-generation flow.
    await tester.tap(
      find.descendant(of: badge, matching: find.byIcon(Icons.close_rounded)),
    );
    await tester.pumpAndSettle();
    expect(badge, findsNothing);
    expect(tester.widget<SwitchListTile>(toggle).onChanged, isNotNull);
  });
}

http.Response _jsonResponse(Map<String, Object?> body) {
  return http.Response(
    jsonEncode({
      'header': {'code': 0, 'message': 'success'},
      ...body,
    }),
    200,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

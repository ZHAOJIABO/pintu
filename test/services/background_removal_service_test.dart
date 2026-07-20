import 'package:bobobeads/services/background_removal_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('bobobeads/background_removal');

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('skips Vision background removal on the iOS Simulator', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isSimulator') return true;
          throw PlatformException(code: 'unexpected_method');
        });
    final imageBytes = Uint8List.fromList([1, 2, 3]);

    final result = await const PlatformBackgroundRemovalService()
        .removeBackground(imageBytes);

    expect(result, orderedEquals(imageBytes));
    expect(calls, ['isSimulator']);
  });

  test('uses Vision on a physical iOS device', () async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          if (call.method == 'isSimulator') return false;
          if (call.method == 'removeBackground') return Uint8List.fromList([4]);
          throw PlatformException(code: 'unexpected_method');
        });

    final result = await const PlatformBackgroundRemovalService()
        .removeBackground(Uint8List.fromList([1, 2, 3]));

    expect(result, orderedEquals([4]));
    expect(calls, ['isSimulator', 'removeBackground']);
  });
}

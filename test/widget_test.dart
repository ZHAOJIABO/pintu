import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const BobobeadsApp());
    expect(find.text('照片转图纸'), findsAtLeastNWidgets(1));
    expect(find.text('上传照片'), findsOneWidget);
    expect(find.text('转换风格'), findsOneWidget);
    expect(find.text('转为插画'), findsNothing);
    expect(find.text('兔子的图库'), findsOneWidget);
  });
}

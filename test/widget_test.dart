import 'package:flutter_test/flutter_test.dart';
import 'package:bobobeads/main.dart';

void main() {
  testWidgets('App starts successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const BobobeadsApp());
    expect(find.bySemanticsLabel('照片转图纸制作流程'), findsOneWidget);
    expect(find.bySemanticsLabel('插画转图纸'), findsOneWidget);
    expect(find.text('兔子的图库'), findsOneWidget);
  });
}

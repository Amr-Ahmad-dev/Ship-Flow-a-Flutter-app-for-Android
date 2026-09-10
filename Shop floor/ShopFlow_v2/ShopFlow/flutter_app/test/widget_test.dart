import 'package:flutter_test/flutter_test.dart';
import 'package:shopflow/main.dart';

void main() {
  testWidgets('App boots', (tester) async {
    await tester.pumpWidget(const ShopFlowApp());
    expect(find.byType(ShopFlowApp), findsOneWidget);
  });
}

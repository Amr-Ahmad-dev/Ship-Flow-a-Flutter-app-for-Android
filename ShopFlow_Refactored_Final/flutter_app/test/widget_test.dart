// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shopflow/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ShopFlowApp());
    
    // Since this app starts with a SplashScreen and relies on 
    // SharedPreferences/API, we just verify it boots.
    expect(find.byType(ShopFlowApp), findsOneWidget);
  });
}

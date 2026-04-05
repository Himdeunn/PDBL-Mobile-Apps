import 'package:flutter_test/flutter_test.dart';
import 'package:wudi/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Basic check to ensure the app title or a key widget is present
    expect(find.byType(MyApp), findsOneWidget);
  });
}

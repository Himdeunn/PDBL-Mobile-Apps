import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wudi/features/ai_chat/screens/wudi_ai_screen.dart';
import 'package:wudi/features/ai_chat/widgets/wudi_ai_card.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: '.env');
  });

  testWidgets('WUDI AI card opens a task-focused entry surface', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: WudiAiCard(onTap: () => tapped = true)),
      ),
    );

    expect(find.text('WUDI AI Assistant'), findsOneWidget);
    expect(
      find.text('Ask AI about your tasks, deadlines, and priorities'),
      findsOneWidget,
    );

    await tester.tap(find.byType(WudiAiCard));
    expect(tapped, isTrue);
  });

  testWidgets('WUDI AI screen shows suggestions and stop-ready input', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: WudiAiScreen(loadHistory: false)),
    );

    expect(find.text('WUDI AI Assistant'), findsOneWidget);
    expect(find.text('Task-focused productivity assistant'), findsOneWidget);
    expect(find.text('What task is closest to deadline?'), findsOneWidget);
    expect(find.text('Summarize today tasks'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}

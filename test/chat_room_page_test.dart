import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wudi/core/models/user.dart';
import 'package:wudi/features/auth/services/auth_service.dart';
import 'package:wudi/features/chat/models/chat_models.dart';
import 'package:wudi/features/chat/pages/chat_room_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  testWidgets('chat list remains scrollable while composer text is selected', (
    tester,
  ) async {
    final user = User()
      ..id = 1
      ..name = 'Me'
      ..email = 'me@example.com'
      ..isGuest = true;

    await tester.pumpWidget(
      MaterialApp(
        home: ChatRoomPage(
          conversation: const ChatConversation(
            id: 1,
            type: 'personal',
            name: 'Chat',
            members: [
              ChatMember(id: 1, name: 'Me'),
              ChatMember(id: 2, name: 'Other'),
            ],
          ),
          currentUser: user,
          authService: AuthService(),
        ),
      ),
    );

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    editable.controller.value = const TextEditingValue(
      text: 'selected composer text',
      selection: TextSelection(baseOffset: 0, extentOffset: 8),
    );
    await tester.pump();

    final listView = tester.widget<ListView>(find.byType(ListView).first);

    expect(listView.physics, isNot(isA<NeverScrollableScrollPhysics>()));
  });
}

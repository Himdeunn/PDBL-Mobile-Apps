import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void test() {
  final me = Person(name: 'Me');
  final msg = Message('text', DateTime.now(), Person(name: 'Sender'));
  MessagingStyleInformation(me, messages: [msg]);
}

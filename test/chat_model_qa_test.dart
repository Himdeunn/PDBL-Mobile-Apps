import 'package:flutter_test/flutter_test.dart';
import 'package:wudi/features/chat/models/chat_models.dart';

void main() {
  test('chat action metadata survives API parsing and cache serialization', () {
    final original = ChatMessage.fromJson({
      'id': 1,
      'conversation_id': 9,
      'sender_id': 2,
      'sender_name': 'Sulistyo Fajar Pratama',
      'body': 'Hello @Sulistyo',
      'mentions_all': false,
      'mentioned_user_ids': [2],
      'created_at': '2026-05-15T12:00:00Z',
    });

    final reply = ChatMessage.fromJson({
      'id': 2,
      'conversation_id': 9,
      'sender_id': 3,
      'sender_name': 'Fajar',
      'body': 'Reply body',
      'mentions_all': true,
      'mentioned_user_ids': [2, 3],
      'reply_to_id': 1,
      'reply_sender_name': original.senderName,
      'reply_body': original.body,
      'edited_at': '2026-05-15T12:05:00Z',
      'created_at': '2026-05-15T12:06:00Z',
    });

    final deleted = reply.copyWith(
      body: 'This message was deleted',
      deletedAt: DateTime.utc(2026, 5, 15, 12, 7),
    );

    expect(reply.replyToId, 1);
    expect(reply.replySenderName, 'Sulistyo Fajar Pratama');
    expect(reply.replyBody, 'Hello @Sulistyo');
    expect(reply.isEdited, isTrue);
    expect(deleted.isDeleted, isTrue);
    expect(deleted.toJson()['body'], 'This message was deleted');
  });
}

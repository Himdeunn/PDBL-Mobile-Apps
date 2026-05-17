import '../models/ai_chat_message.dart';

class AiChatCache {
  static final List<AiChatMessage> _messages = [];
  static int? conversationId;
  static DateTime? lastRequestAt;

  static List<AiChatMessage> get messages => List.unmodifiable(_messages);

  static void replaceAll(List<AiChatMessage> messages) {
    _messages
      ..clear()
      ..addAll(messages.take(80));
  }

  static void add(AiChatMessage message) {
    _messages.add(message);
    if (_messages.length > 80) {
      _messages.removeRange(0, _messages.length - 80);
    }
  }

  static void replace(String id, AiChatMessage message) {
    final index = _messages.indexWhere((item) => item.id == id);
    if (index >= 0) {
      _messages[index] = message;
    }
  }
}

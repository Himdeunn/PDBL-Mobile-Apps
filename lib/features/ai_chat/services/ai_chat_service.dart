import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../cache/ai_chat_cache.dart';
import '../models/ai_chat_message.dart';

class AiChatResponse {
  final int? conversationId;
  final String requestId;
  final String content;
  final Map<String, dynamic>? action;

  const AiChatResponse({
    required this.conversationId,
    required this.requestId,
    required this.content,
    this.action,
  });
}

class AiChatService {
  final ApiClient _api = ApiClient();
  static const _uuid = Uuid();

  Future<List<AiChatMessage>> history() async {
    final response = await _api.get('ai/history');
    final data = response.data as Map<String, dynamic>;
    AiChatCache.conversationId = data['conversation_id'] as int?;
    final messages = ((data['messages'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => AiChatMessage.fromJson(item.cast<String, dynamic>()))
        .toList();
    AiChatCache.replaceAll(messages);

    return messages;
  }

  Future<AiChatResponse> send(
    String message, {
    CancelToken? cancelToken,
  }) async {
    final now = DateTime.now();
    final last = AiChatCache.lastRequestAt;
    if (last != null && now.difference(last).inMilliseconds < 900) {
      throw Exception('Please wait a moment before asking WUDI again.');
    }
    AiChatCache.lastRequestAt = now;

    final requestId = _uuid.v4();
    final response = await _api.post(
      'ai/chat',
      data: {
        'message': message,
        'conversation_id': AiChatCache.conversationId,
        'request_id': requestId,
      },
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    AiChatCache.conversationId = data['conversation_id'] as int?;
    final aiMessage = (data['message'] as Map?)?.cast<String, dynamic>();

    return AiChatResponse(
      conversationId: AiChatCache.conversationId,
      requestId: data['request_id']?.toString() ?? requestId,
      content:
          aiMessage?['content']?.toString() ??
          data['message']?.toString() ??
          '',
      action: (data['action'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Future<void> cancel(String requestId) async {
    await _api.post('ai/cancel', data: {'request_id': requestId});
  }
}

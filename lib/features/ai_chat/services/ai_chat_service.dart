import 'package:dio/dio.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../cache/ai_chat_cache.dart';
import '../models/ai_chat_message.dart';

class AiConversationSummary {
  final int id;
  final String title;
  final String? preview;
  final String? lastRole;
  final DateTime? lastMessageAt;

  const AiConversationSummary({
    required this.id,
    required this.title,
    this.preview,
    this.lastRole,
    this.lastMessageAt,
  });

  factory AiConversationSummary.fromJson(Map<String, dynamic> json) {
    return AiConversationSummary(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? 'WUDI AI Assistant',
      preview: json['preview']?.toString(),
      lastRole: json['last_role']?.toString(),
      lastMessageAt: DateTime.tryParse(
        json['last_message_at']?.toString() ?? '',
      ),
    );
  }
}

class AiChatResponse {
  final int? conversationId;
  final String requestId;
  final AiChatMessage? userMessage;
  final AiChatMessage? assistantMessage;
  final String content;
  final Map<String, dynamic>? action;

  const AiChatResponse({
    required this.conversationId,
    required this.requestId,
    this.userMessage,
    this.assistantMessage,
    required this.content,
    this.action,
  });
}

class AiChatService {
  final ApiClient _api = ApiClient();
  static const _uuid = Uuid();

  Future<List<AiChatMessage>> history({int? conversationId}) async {
    final response = await _api.get(
      'ai/history',
      queryParameters: conversationId == null
          ? null
          : {'conversation_id': conversationId},
    );
    final data = response.data as Map<String, dynamic>;
    AiChatCache.conversationId = data['conversation_id'] as int?;
    final messages = ((data['messages'] as List?) ?? [])
        .whereType<Map>()
        .map((item) => AiChatMessage.fromJson(item.cast<String, dynamic>()))
        .toList();
    AiChatCache.replaceAll(messages);

    return messages;
  }

  Future<List<AiConversationSummary>> conversations() async {
    final response = await _api.get('ai/conversations');
    final data = response.data as Map<String, dynamic>;

    return ((data['conversations'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (item) =>
              AiConversationSummary.fromJson(item.cast<String, dynamic>()),
        )
        .where((item) => item.id > 0)
        .toList();
  }

  Future<int?> newConversation() async {
    final response = await _api.post('ai/conversations');
    final data = response.data as Map<String, dynamic>;
    AiChatCache.clear(conversationId: data['conversation_id'] as int?);

    return AiChatCache.conversationId;
  }

  Future<AiChatResponse> send(
    String message, {
    CancelToken? cancelToken,
  }) async {
    final requestId = _uuid.v4();
    String? timezone;
    try {
      final dynamic locationInfo = await FlutterTimezone.getLocalTimezone();
      timezone = locationInfo is String ? locationInfo : locationInfo.name;
    } catch (_) {}

    final response = await _api.post(
      'ai/chat',
      data: {
        'message': message,
        'conversation_id': AiChatCache.conversationId,
        'request_id': requestId,
        'timezone': ?timezone,
        'local_hour': DateTime.now().hour,
      },
      cancelToken: cancelToken,
    );

    final data = response.data as Map<String, dynamic>;
    AiChatCache.conversationId = data['conversation_id'] as int?;
    final userMessage = (data['user_message'] as Map?)?.cast<String, dynamic>();
    final aiMessage = (data['message'] as Map?)?.cast<String, dynamic>();

    return AiChatResponse(
      conversationId: AiChatCache.conversationId,
      requestId: data['request_id']?.toString() ?? requestId,
      userMessage: userMessage == null
          ? null
          : AiChatMessage.fromJson(userMessage),
      assistantMessage: aiMessage == null
          ? null
          : AiChatMessage.fromJson(aiMessage),
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

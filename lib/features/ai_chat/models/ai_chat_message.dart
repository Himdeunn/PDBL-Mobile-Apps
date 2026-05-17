class AiChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;
  final bool failed;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.metadata,
    this.failed = false,
  });

  bool get isUser => role == 'user';

  AiChatMessage copyWith({String? content, bool? failed}) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      metadata: metadata,
      failed: failed ?? this.failed,
    );
  }

  factory AiChatMessage.fromJson(Map<String, dynamic> json) {
    return AiChatMessage(
      id:
          json['id']?.toString() ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

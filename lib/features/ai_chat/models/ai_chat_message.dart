class AiChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime createdAt;
  final int sortId;
  final Map<String, dynamic>? metadata;
  final bool failed;

  const AiChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    int? sortId,
    this.metadata,
    this.failed = false,
  }) : sortId = sortId ?? 0;

  bool get isUser => role == 'user';

  AiChatMessage copyWith({String? content, bool? failed}) {
    return AiChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      createdAt: createdAt,
      sortId: sortId,
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
      sortId: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

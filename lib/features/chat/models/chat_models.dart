import 'package:cloud_firestore/cloud_firestore.dart';

int? _readInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Iterable<int> _readIntList(dynamic value) {
  if (value is Iterable) {
    return value.map<int>((id) {
      if (id is num) return id.toInt();
      if (id is String) return int.parse(id);
      throw FormatException('Invalid integer list entry: $id');
    });
  }
  return const <int>[];
}

DateTime? _readApiDateTime(dynamic value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) return null;

  final hasTimezone =
      raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
  final normalized = hasTimezone ? raw : '${raw}Z';
  return DateTime.tryParse(normalized)?.toLocal();
}

class ChatMember {
  final int id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String? role;

  const ChatMember({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.role,
  });

  factory ChatMember.fromJson(Map<String, dynamic> json) => ChatMember(
    id: (json['id'] as num).toInt(),
    name: (json['name'] ?? json['display_name'] ?? 'Unknown').toString(),
    email: (json['email'] ?? json['email_address']) as String?,
    avatarUrl: (json['avatar_url'] ?? json['avatarUrl']) as String?,
    role: _readMemberRole(json),
  );

  static String? _readMemberRole(Map<dynamic, dynamic> json) {
    if (json['is_leader'] == true || json['isLeader'] == true) {
      return 'Team Leader';
    }
    final role = json['role']?.toString();
    if (role == null || role.isEmpty) return null;
    final normalized = role.toLowerCase().replaceAll('_', ' ').trim();
    if (normalized == 'leader' ||
        normalized == 'team leader' ||
        normalized == 'team owner' ||
        normalized == 'owner' ||
        normalized == 'admin') {
      return 'Team Leader';
    }
    if (normalized == 'member') return 'Member';
    return role;
  }

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'role': role,
  };

  factory ChatMember.fromFirestore(Map<String, dynamic> data) => ChatMember(
    id: (data['id'] as num).toInt(),
    name: (data['name'] ?? 'Unknown').toString(),
    email: data['email'] as String?,
    avatarUrl: data['avatarUrl'] as String?,
    role: _readMemberRole(data),
  );
}

class ChatConversation {
  final int id;
  final String type;
  final int? teamId;
  final String name;
  final String? avatarUrl;
  final List<ChatMember> members;
  final String? lastMessage;
  final String? lastSenderName;
  final DateTime? updatedAt;
  final int unreadCount;
  final bool lastMessageMentionsAll;
  final List<int> lastMessageMentionedUserIds;
  final bool hasUnreadMention;
  final bool canModerateMessages;

  const ChatConversation({
    required this.id,
    required this.type,
    required this.name,
    required this.members,
    this.teamId,
    this.avatarUrl,
    this.lastMessage,
    this.lastSenderName,
    this.updatedAt,
    this.unreadCount = 0,
    this.lastMessageMentionsAll = false,
    this.lastMessageMentionedUserIds = const [],
    this.hasUnreadMention = false,
    this.canModerateMessages = false,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    final lastMessage = json['last_message'] as Map<String, dynamic>?;
    return ChatConversation(
      id: (json['id'] as num).toInt(),
      type: (json['type'] ?? 'team').toString(),
      teamId: _readInt(json['team_id'] ?? json['teamId']),
      name: (json['name'] ?? 'Team Chat').toString(),
      avatarUrl: (json['avatar_url'] ?? json['avatarUrl']) as String?,
      members: ((json['members'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMember.fromJson)
          .toList(),
      lastMessage: (lastMessage?['body'] ?? json['lastMessage']) as String?,
      lastSenderName:
          (lastMessage?['sender_name'] ?? json['lastSenderName']) as String?,
      updatedAt: _readApiDateTime(json['updated_at'] ?? json['updatedAt']),
      unreadCount: _readInt(json['unread_count'] ?? json['unreadCount']) ?? 0,
      lastMessageMentionsAll:
          lastMessage?['mentions_all'] == true ||
          lastMessage?['mentionsAll'] == true ||
          json['lastMessageMentionsAll'] == true,
      lastMessageMentionedUserIds: _readIntList(
        lastMessage?['mentioned_user_ids'] ??
            lastMessage?['mentionedUserIds'] ??
            json['lastMessageMentionedUserIds'],
      ).toList(),
      hasUnreadMention:
          json['has_unread_mention'] == true ||
          json['hasUnreadMention'] == true,
      canModerateMessages:
          json['can_moderate_messages'] == true ||
          json['canModerateMessages'] == true,
    );
  }

  ChatConversation copyWith({
    int? id,
    String? type,
    int? teamId,
    String? name,
    String? avatarUrl,
    List<ChatMember>? members,
    String? lastMessage,
    String? lastSenderName,
    DateTime? updatedAt,
    int? unreadCount,
    bool? lastMessageMentionsAll,
    List<int>? lastMessageMentionedUserIds,
    bool? hasUnreadMention,
    bool? canModerateMessages,
  }) {
    return ChatConversation(
      id: id ?? this.id,
      type: type ?? this.type,
      teamId: teamId ?? this.teamId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      members: members ?? this.members,
      lastMessage: lastMessage ?? this.lastMessage,
      lastSenderName: lastSenderName ?? this.lastSenderName,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessageMentionsAll:
          lastMessageMentionsAll ?? this.lastMessageMentionsAll,
      lastMessageMentionedUserIds:
          lastMessageMentionedUserIds ?? this.lastMessageMentionedUserIds,
      hasUnreadMention: hasUnreadMention ?? this.hasUnreadMention,
      canModerateMessages: canModerateMessages ?? this.canModerateMessages,
    );
  }

  String get firestoreId => id.toString();

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'type': type,
    'teamId': teamId,
    'name': name,
    'avatarUrl': avatarUrl,
    'members': members.map((member) => member.toFirestore()).toList(),
    'memberIds': members.map((member) => member.id).toList(),
    'lastMessage': lastMessage,
    'lastSenderName': lastSenderName,
    'lastMessageMentionsAll': lastMessageMentionsAll,
    'lastMessageMentionedUserIds': lastMessageMentionedUserIds,
    'hasUnreadMention': hasUnreadMention,
    'updatedAt': updatedAt != null
        ? Timestamp.fromDate(updatedAt!)
        : FieldValue.serverTimestamp(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'teamId': teamId,
    'name': name,
    'avatarUrl': avatarUrl,
    'members': members.map((member) => member.toJson()).toList(),
    'lastMessage': lastMessage,
    'lastSenderName': lastSenderName,
    'lastMessageMentionsAll': lastMessageMentionsAll,
    'lastMessageMentionedUserIds': lastMessageMentionedUserIds,
    'hasUnreadMention': hasUnreadMention,
    'updatedAt': updatedAt?.toIso8601String(),
    'unreadCount': unreadCount,
    'canModerateMessages': canModerateMessages,
  };

  factory ChatConversation.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ChatConversation(
      id: (data['id'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0,
      type: (data['type'] ?? 'team').toString(),
      teamId: (data['teamId'] as num?)?.toInt(),
      name: (data['name'] ?? 'Team Chat').toString(),
      avatarUrl: data['avatarUrl'] as String?,
      members: ((data['members'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMember.fromFirestore)
          .toList(),
      lastMessage: data['lastMessage'] as String?,
      lastSenderName: data['lastSenderName'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate().toLocal(),
      unreadCount: _readInt(data['unreadCount'] ?? data['unread_count']) ?? 0,
      lastMessageMentionsAll: data['lastMessageMentionsAll'] == true,
      lastMessageMentionedUserIds: _readIntList(
        data['lastMessageMentionedUserIds'],
      ).toList(),
      hasUnreadMention: data['hasUnreadMention'] == true,
      canModerateMessages: data['canModerateMessages'] == true,
    );
  }
}

class ChatMessage {
  final int id;
  final int conversationId;
  final int senderId;
  final String senderName;
  final String? senderEmail;
  final String? senderAvatarUrl;
  final String body;
  final bool mentionsAll;
  final List<int> mentionedUserIds;
  final DateTime createdAt;
  final int? replyToId;
  final String? replySenderName;
  final String? replyBody;
  final DateTime? editedAt;
  final DateTime? deletedAt;
  final String? deleteReason;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.body,
    required this.mentionsAll,
    required this.mentionedUserIds,
    required this.createdAt,
    this.senderEmail,
    this.senderAvatarUrl,
    this.replyToId,
    this.replySenderName,
    this.replyBody,
    this.editedAt,
    this.deletedAt,
    this.deleteReason,
  });

  bool get isEdited => editedAt != null;
  bool get isDeleted => deletedAt != null;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: (json['id'] as num).toInt(),
    conversationId:
        _readInt(json['conversation_id'] ?? json['conversationId']) ?? 0,
    senderId: _readInt(json['sender_id'] ?? json['senderId']) ?? 0,
    senderName: (json['sender_name'] ?? json['senderName'] ?? 'Unknown')
        .toString(),
    senderEmail: (json['sender_email'] ?? json['senderEmail']) as String?,
    senderAvatarUrl:
        (json['sender_avatar_url'] ?? json['senderAvatarUrl']) as String?,
    body: (json['body'] ?? '').toString(),
    mentionsAll: json['mentions_all'] == true || json['mentionsAll'] == true,
    mentionedUserIds: _readIntList(
      json['mentioned_user_ids'] ?? json['mentionedUserIds'],
    ).toList(),
    replyToId: _readInt(json['reply_to_id'] ?? json['replyToId']),
    replySenderName:
        (json['reply_sender_name'] ?? json['replySenderName']) as String?,
    replyBody: (json['reply_body'] ?? json['replyBody']) as String?,
    editedAt: _readApiDateTime(json['edited_at'] ?? json['editedAt']),
    deletedAt: _readApiDateTime(json['deleted_at'] ?? json['deletedAt']),
    deleteReason: (json['delete_reason'] ?? json['deleteReason']) as String?,
    createdAt:
        _readApiDateTime(json['created_at'] ?? json['createdAt']) ??
        DateTime.now(),
  );

  ChatMessage copyWith({
    String? body,
    bool? mentionsAll,
    List<int>? mentionedUserIds,
    int? replyToId,
    String? replySenderName,
    String? replyBody,
    DateTime? editedAt,
    DateTime? deletedAt,
    String? deleteReason,
  }) => ChatMessage(
    id: id,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    senderEmail: senderEmail,
    senderAvatarUrl: senderAvatarUrl,
    body: body ?? this.body,
    mentionsAll: mentionsAll ?? this.mentionsAll,
    mentionedUserIds: mentionedUserIds ?? this.mentionedUserIds,
    createdAt: createdAt,
    replyToId: replyToId ?? this.replyToId,
    replySenderName: replySenderName ?? this.replySenderName,
    replyBody: replyBody ?? this.replyBody,
    editedAt: editedAt ?? this.editedAt,
    deletedAt: deletedAt ?? this.deletedAt,
    deleteReason: deleteReason ?? this.deleteReason,
  );

  Map<String, dynamic> toFirestore() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderEmail': senderEmail,
    'senderAvatarUrl': senderAvatarUrl,
    'body': body,
    'mentionsAll': mentionsAll,
    'mentionedUserIds': mentionedUserIds,
    'replyToId': replyToId,
    'replySenderName': replySenderName,
    'replyBody': replyBody,
    'editedAt': editedAt == null ? null : Timestamp.fromDate(editedAt!),
    'deletedAt': deletedAt == null ? null : Timestamp.fromDate(deletedAt!),
    'deleteReason': deleteReason,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'conversationId': conversationId,
    'senderId': senderId,
    'senderName': senderName,
    'senderEmail': senderEmail,
    'senderAvatarUrl': senderAvatarUrl,
    'body': body,
    'mentionsAll': mentionsAll,
    'mentionedUserIds': mentionedUserIds,
    'replyToId': replyToId,
    'replySenderName': replySenderName,
    'replyBody': replyBody,
    'editedAt': editedAt?.toIso8601String(),
    'deletedAt': deletedAt?.toIso8601String(),
    'deleteReason': deleteReason,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return ChatMessage(
      id: (data['id'] as num?)?.toInt() ?? int.tryParse(doc.id) ?? 0,
      conversationId: (data['conversationId'] as num?)?.toInt() ?? 0,
      senderId: (data['senderId'] as num?)?.toInt() ?? 0,
      senderName: (data['senderName'] ?? 'Unknown').toString(),
      senderEmail: data['senderEmail'] as String?,
      senderAvatarUrl: data['senderAvatarUrl'] as String?,
      body: (data['body'] ?? '').toString(),
      mentionsAll: data['mentionsAll'] == true,
      mentionedUserIds: _readIntList(data['mentionedUserIds']).toList(),
      replyToId: _readInt(data['replyToId']),
      replySenderName: data['replySenderName'] as String?,
      replyBody: data['replyBody'] as String?,
      editedAt: (data['editedAt'] as Timestamp?)?.toDate().toLocal(),
      deletedAt: (data['deletedAt'] as Timestamp?)?.toDate().toLocal(),
      deleteReason: data['deleteReason'] as String?,
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate().toLocal() ??
          DateTime.now(),
    );
  }
}

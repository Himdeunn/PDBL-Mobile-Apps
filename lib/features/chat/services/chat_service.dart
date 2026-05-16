import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../models/chat_models.dart';

class ChatService {
  final ApiClient _api = ApiClient();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _firestoreAvailable = true;
  static List<ChatConversation>? _conversationCache;
  static final Map<int, List<ChatMessage>> _messageCache = {};
  static DateTime? _lastSendAt;
  static const Duration _pollingInterval = Duration(seconds: 5);

  CollectionReference<Map<String, dynamic>> get _chatCollection =>
      _firestore.collection('chats');

  Future<int?> _currentUserId() async {
    final user = await SecureStorage.getUser();
    return user?.id;
  }

  Future<String?> _currentUserName() async {
    final user = await SecureStorage.getUser();
    return user?.name;
  }

  Future<List<ChatConversation>> getConversations() async {
    final conversations = <ChatConversation>[];
    final currentUserId = await _currentUserId();
    final currentUserName = await _currentUserName();

    try {
      final response = await _api.get('chat/conversations');
      conversations.addAll(
        ((response.data['conversations'] as List?) ?? [])
            .whereType<Map<String, dynamic>>()
            .map(ChatConversation.fromJson),
      );
    } catch (e) {
      if (_conversationCache != null) return _conversationCache!;
      // Don't suppress ANY errors so we can see exactly what the backend returns
      rethrow;
    }

    if (conversations.isEmpty) {
      conversations.addAll(await _getTeamConversationsFallback());
    }

    for (final conversation in conversations) {
      // Fire and forget so we don't hang if Firestore is disabled/offline
      syncConversation(conversation).catchError((_) {});
    }

    await _warmUnreadMentionMessages(conversations);

    final enriched = conversations
        .map(
          (conversation) => _withUnreadMentionState(
            conversation,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ),
        )
        .toList();

    _saveConversationCache(enriched);
    return enriched;
  }

  Future<void> _warmUnreadMentionMessages(
    List<ChatConversation> conversations,
  ) async {
    for (final conversation in conversations) {
      if (conversation.type != 'team' || conversation.unreadCount <= 0) {
        continue;
      }
      if (_cachedMessagesForConversation(conversation).isNotEmpty) continue;

      try {
        await _getMessagesFromApi(conversation.id);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Unread mention message warmup failed: $error');
        }
      }
    }
  }

  List<ChatMessage> _cachedMessagesForConversation(
    ChatConversation conversation,
  ) {
    return _messageCache[conversation.id] ??
        (conversation.id < 0 && conversation.teamId != null
            ? _messageCache[conversation.teamId]
            : null) ??
        const <ChatMessage>[];
  }

  ChatConversation _withUnreadMentionState(
    ChatConversation conversation, {
    required int? currentUserId,
    required String? currentUserName,
  }) {
    final previousConversation = _conversationCache
        ?.where((cached) => cached.id == conversation.id)
        .firstOrNull;

    if (conversation.type != 'team' || conversation.unreadCount <= 0) {
      return conversation.copyWith(hasUnreadMention: false);
    }

    final messages = _cachedMessagesForConversation(conversation);
    final recentUnread = messages.length <= conversation.unreadCount
        ? messages
        : messages.sublist(messages.length - conversation.unreadCount);
    final hasUnreadMention =
        conversation.hasUnreadMention ||
        previousConversation?.hasUnreadMention == true ||
        conversation.lastMessageMentionsAll ||
        (currentUserId != null &&
            conversation.lastMessageMentionedUserIds.contains(currentUserId)) ||
        recentUnread.any(
          (message) => _messageMentionsUser(
            message,
            currentUserId: currentUserId,
            currentUserName: currentUserName,
          ),
        );

    return conversation.copyWith(hasUnreadMention: hasUnreadMention);
  }

  bool _messageMentionsUser(
    ChatMessage message, {
    required int? currentUserId,
    required String? currentUserName,
  }) {
    if (message.mentionsAll) return true;
    if (currentUserId != null &&
        message.mentionedUserIds.contains(currentUserId)) {
      return true;
    }

    final body = message.body.toLowerCase();
    final name = currentUserName?.trim().toLowerCase();
    final firstName = name?.split(RegExp(r'\s+')).first;
    return body.contains('@all') ||
        (name != null && name.isNotEmpty && body.contains('@$name')) ||
        (firstName != null &&
            firstName.isNotEmpty &&
            body.contains('@$firstName'));
  }

  Future<List<ChatMessage>> _getMessagesFromApi(int conversationId) async {
    final resolvedId = await _resolveConversationId(conversationId);
    final response = await _api.get('chat/conversations/$resolvedId/messages');
    final messages = ((response.data['messages'] as List?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    _saveMessageCache(resolvedId, messages);
    _saveMessageCache(conversationId, messages);
    return messages;
  }

  Future<ChatConversation?> getConversation(int conversationId) async {
    final conversations = await getConversations();
    return conversations.where((chat) => chat.id == conversationId).firstOrNull;
  }

  Future<void> markConversationRead(int conversationId) async {
    final resolvedId = await _resolveConversationId(conversationId);
    await _api.post('chat/conversations/$resolvedId/read');
    final conversations = _conversationCache;
    if (conversations == null) return;

    _saveConversationCache([
      for (final chat in conversations)
        if (chat.id == resolvedId)
          ChatConversation(
            id: chat.id,
            type: chat.type,
            name: chat.name,
            members: chat.members,
            teamId: chat.teamId,
            avatarUrl: chat.avatarUrl,
            lastMessage: chat.lastMessage,
            lastSenderName: chat.lastSenderName,
            updatedAt: chat.updatedAt,
            canModerateMessages: chat.canModerateMessages,
          )
        else
          chat,
    ]);
  }

  Future<int> _resolveConversationId(int conversationId) async {
    if (conversationId > 0) return conversationId;

    final teamId = -conversationId;
    final conversations = await getConversations();
    final conversation = conversations.where((chat) {
      return chat.type == 'team' && chat.teamId == teamId && chat.id > 0;
    }).firstOrNull;

    if (conversation == null) {
      throw Exception(
        'Backend mengembalikan 404 (Route Not Found) untuk /api/chat/conversations. Berarti kode Laravel di Cloud Run BELUM ter-update dengan route chat.',
      );
    }

    return conversation.id;
  }

  Stream<List<ChatMessage>> watchMessagesWithFallback(
    int conversationId,
  ) async* {
    final cachedMessages = _messageCache[conversationId];
    if (cachedMessages != null) yield cachedMessages;
    if (cachedMessages == null) {
      final storedMessages = await _loadMessageCache(conversationId);
      if (storedMessages != null) yield storedMessages;
    }

    // The backend is the durable source after reinstall. Firestore can be empty
    // or unavailable even when other users already sent messages.
    while (true) {
      try {
        yield await _getMessagesFromApi(conversationId);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Chat polling fallback failed: $error');
        }
        final cached = _messageCache[conversationId];
        if (cached != null) yield cached;
        if (!_isTransientPollingError(error)) {
          yield* Stream.error(
            Exception(
              'Gagal terhubung ke backend REST API ($error). Pastikan backend di Cloud Run benar-benar sudah menggunakan kode terbaru.',
            ),
          );
        }
      }
      await Future<void>.delayed(_pollingInterval);
    }
  }

  Stream<List<ChatMessage>> cachedMessageStream(int conversationId) {
    return watchMessagesWithFallback(conversationId).distinct(_sameMessages);
  }

  Future<List<ChatConversation>> _getTeamConversationsFallback() async {
    final response = await _api.get('/teams');
    final teamsPart = response.data is Map ? response.data['teams'] : null;
    return _listFromApiPart(
      teamsPart,
    ).whereType<Map<String, dynamic>>().map(_teamToConversation).toList();
  }

  List<dynamic> _listFromApiPart(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['data'] is List) return value['data'] as List;
    if (value is Map) return value.values.toList();
    return const [];
  }

  ChatConversation _teamToConversation(Map<String, dynamic> team) {
    final teamId = (team['id'] as num).toInt();
    return ChatConversation(
      id: -teamId,
      type: 'team',
      teamId: teamId,
      name: (team['name'] ?? 'Team Chat').toString(),
      avatarUrl: team['avatar_url'] as String?,
      members: ((team['members'] as List?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChatMember.fromJson)
          .toList(),
      updatedAt: DateTime.tryParse(
        (team['updated_at'] ?? '').toString(),
      )?.toLocal(),
    );
  }

  Stream<List<ChatConversation>> watchConversations() async* {
    if (await _currentUserId() == null) {
      yield [];
      return;
    }

    final cachedConversations = _conversationCache;
    if (cachedConversations != null) yield cachedConversations;
    if (cachedConversations == null) {
      final storedConversations = await _loadConversationCache();
      if (storedConversations != null) yield storedConversations;
    }

    final bootstrap = await getConversations();
    yield bootstrap;

    // The backend owns unread counts and personal/team chat membership, so keep
    // the list refreshed from REST instead of trusting Firestore-only updates.
    while (true) {
      try {
        final polled = await getConversations();
        yield polled;
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Chat conversations polling fallback failed: $error');
        }
      }
      await Future<void>.delayed(_pollingInterval);
    }
  }

  bool _isTransientPollingError(Object error) {
    return error is DioException &&
        (error.response?.statusCode == 429 ||
            error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.sendTimeout ||
            error.type == DioExceptionType.receiveTimeout ||
            error.type == DioExceptionType.connectionError);
  }

  Stream<List<ChatMessage>> watchMessages(String conversationId) {
    return _chatCollection
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          final messages = snapshot.docs
              .map(ChatMessage.fromFirestore)
              .toList();
          final id = int.tryParse(conversationId);
          if (id != null) _saveMessageCache(id, messages);
          return messages;
        });
  }

  Future<List<ChatMessage>> getMessages(int conversationId) async {
    final snapshot = await _chatCollection
        .doc(conversationId.toString())
        .collection('messages')
        .orderBy('createdAt')
        .limit(100)
        .get();

    final messages = snapshot.docs.map(ChatMessage.fromFirestore).toList();
    _saveMessageCache(conversationId, messages);
    return messages;
  }

  Future<ChatMessage> sendMessage(
    int conversationId,
    String body, {
    int? replyToId,
  }) async {
    final now = DateTime.now();
    final lastSendAt = _lastSendAt;
    if (lastSendAt != null && now.difference(lastSendAt).inMilliseconds < 250) {
      throw Exception('Please wait before sending another message.');
    }
    _lastSendAt = now;

    final resolvedConversationId = await _resolveConversationId(conversationId);

    try {
      final data = <String, dynamic>{
        'body': body,
        'client_nonce':
            '${resolvedConversationId}_${now.microsecondsSinceEpoch}',
      };
      if (replyToId != null) data['reply_to_id'] = replyToId;

      final response = await _api.post(
        'chat/conversations/$resolvedConversationId/messages',
        data: data,
      );
      final message = ChatMessage.fromJson(
        response.data['message'] as Map<String, dynamic>,
      );
      _appendCachedMessage(resolvedConversationId, conversationId, message);
      _syncMessageToFirestore(
        resolvedConversationId,
        message,
      ).catchError((_) {});
      return message;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Chat REST send failed: $error');
      }
      rethrow;
    }
  }

  Future<ChatMessage> editMessage(
    int conversationId,
    ChatMessage message,
    String body,
  ) async {
    final resolvedConversationId = await _resolveConversationId(conversationId);
    final response = await _api.patch(
      'chat/conversations/$resolvedConversationId/messages/${message.id}',
      data: {'body': body},
    );
    final updated = ChatMessage.fromJson(
      response.data['message'] as Map<String, dynamic>,
    );
    _replaceCachedMessage(resolvedConversationId, conversationId, updated);
    _syncMessageToFirestore(resolvedConversationId, updated).catchError((_) {});
    return updated;
  }

  Future<ChatMessage?> deleteMessage(
    int conversationId,
    ChatMessage message, {
    required bool forEveryone,
  }) async {
    final resolvedConversationId = await _resolveConversationId(conversationId);
    final response = await _api.delete(
      'chat/conversations/$resolvedConversationId/messages/${message.id}',
      data: {'scope': forEveryone ? 'everyone' : 'me'},
    );

    final payload = response.data is Map ? response.data['message'] : null;
    if (payload is Map<String, dynamic>) {
      final updated = ChatMessage.fromJson(payload);
      _replaceCachedMessage(resolvedConversationId, conversationId, updated);
      _syncMessageToFirestore(
        resolvedConversationId,
        updated,
      ).catchError((_) {});
      return updated;
    }

    _removeCachedMessage(resolvedConversationId, conversationId, message.id);
    if (_firestoreAvailable) {
      _chatCollection
          .doc(resolvedConversationId.toString())
          .collection('messages')
          .doc(message.id.toString())
          .delete()
          .catchError((_) {});
    }
    return null;
  }

  Future<ChatConversation> startPrivateChat(int userId) async {
    final response = await _api.post('chat/private/$userId');
    final conversation = ChatConversation.fromJson(
      response.data['conversation'] as Map<String, dynamic>,
    );

    _upsertCachedConversation(conversation);

    if (_firestoreAvailable) {
      _chatCollection
          .doc(conversation.id.toString())
          .set(conversation.toFirestore(), SetOptions(merge: true))
          .timeout(const Duration(seconds: 3))
          .catchError((e) {
            if (e is Exception && _isFirestoreUnavailable(e)) {
              _firestoreAvailable = false;
            }
          });
    }

    return conversation;
  }

  Future<void> syncConversation(ChatConversation conversation) async {
    _upsertCachedConversation(conversation);
    await _chatCollection
        .doc(conversation.id.toString())
        .set(conversation.toFirestore(), SetOptions(merge: true));
  }

  Future<void> _syncMessageToFirestore(
    int conversationId,
    ChatMessage message,
  ) async {
    if (!_firestoreAvailable) return;

    try {
      final convoRef = _chatCollection.doc(conversationId.toString());
      await convoRef
          .collection('messages')
          .doc(message.id.toString())
          .set(message.toFirestore(), SetOptions(merge: true));
      await convoRef.set({
        'lastMessage': message.body,
        'lastSenderName': message.senderName,
        'lastMessageMentionsAll': message.mentionsAll,
        'lastMessageMentionedUserIds': message.mentionedUserIds,
        'updatedAt': Timestamp.fromDate(message.createdAt),
        'lastSenderId': message.senderId,
        'lastSentAt': Timestamp.fromDate(message.createdAt),
      }, SetOptions(merge: true));
    } catch (error) {
      if (_isFirestoreUnavailable(error)) {
        _firestoreAvailable = false;
      }
    }
  }

  void _appendCachedMessage(
    int resolvedConversationId,
    int requestedConversationId,
    ChatMessage message,
  ) {
    final existing = _messageCache[resolvedConversationId] ?? const [];
    final messages = [...existing, message];
    _saveMessageCache(resolvedConversationId, messages);
    _saveMessageCache(requestedConversationId, messages);
  }

  void _upsertCachedConversation(ChatConversation conversation) {
    final existing = _conversationCache ?? const [];
    _saveConversationCache([
      for (final cached in existing)
        if (cached.firestoreId != conversation.firestoreId) cached,
      conversation,
    ]);
  }

  Future<List<ChatConversation>?> _loadConversationCache() async {
    final raw = await SecureStorage.getChatConversationsCache();
    if (raw == null || raw.isEmpty) return null;
    final conversations = (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(ChatConversation.fromJson)
        .toList();
    _conversationCache = conversations;
    return conversations;
  }

  Future<List<ChatMessage>?> _loadMessageCache(int conversationId) async {
    final raw = await SecureStorage.getChatMessagesCache(conversationId);
    if (raw == null || raw.isEmpty) return null;
    final messages = (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
    _messageCache[conversationId] = messages;
    return messages;
  }

  void _saveConversationCache(List<ChatConversation> conversations) {
    _conversationCache = conversations;
    SecureStorage.saveChatConversationsCache(
      jsonEncode(conversations.map((chat) => chat.toJson()).toList()),
    ).catchError((_) {});
  }

  void _saveMessageCache(int conversationId, List<ChatMessage> messages) {
    _messageCache[conversationId] = messages;
    SecureStorage.saveChatMessagesCache(
      conversationId,
      jsonEncode(messages.map((message) => message.toJson()).toList()),
    ).catchError((_) {});
  }

  bool _isFirestoreUnavailable(Object error) {
    return error is FirebaseException &&
        (error.code == 'permission-denied' ||
            error.code == 'unavailable' ||
            error.code == 'failed-precondition');
  }

  void _replaceCachedMessage(
    int resolvedConversationId,
    int requestedConversationId,
    ChatMessage message,
  ) {
    for (final id in {resolvedConversationId, requestedConversationId}) {
      final current = _messageCache[id] ?? const <ChatMessage>[];
      final updated = [
        for (final cached in current)
          if (cached.id == message.id) message else cached,
      ];
      if (!updated.any((cached) => cached.id == message.id)) {
        updated.add(message);
      }
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _saveMessageCache(id, updated);
    }
  }

  void _removeCachedMessage(
    int resolvedConversationId,
    int requestedConversationId,
    int messageId,
  ) {
    for (final id in {resolvedConversationId, requestedConversationId}) {
      final current = _messageCache[id] ?? const <ChatMessage>[];
      _saveMessageCache(
        id,
        current.where((message) => message.id != messageId).toList(),
      );
    }
  }

  bool _sameMessages(List<ChatMessage> previous, List<ChatMessage> next) {
    if (previous.length != next.length) return false;
    for (var i = 0; i < previous.length; i++) {
      final a = previous[i];
      final b = next[i];
      if (a.id != b.id ||
          a.body != b.body ||
          a.editedAt != b.editedAt ||
          a.deletedAt != b.deletedAt) {
        return false;
      }
    }
    return true;
  }
}

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
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

  CollectionReference<Map<String, dynamic>> get _chatCollection =>
      _firestore.collection('chats');

  Future<int?> _currentUserId() async {
    final user = await SecureStorage.getUser();
    return user?.id;
  }

  Future<List<ChatConversation>> getConversations() async {
    final conversations = <ChatConversation>[];

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

    _saveConversationCache(conversations);
    return conversations;
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
        // Yield error so UI can display exactly why it's failing
        yield* Stream.error(
          Exception(
            'Gagal terhubung ke backend REST API ($error). Pastikan backend di Cloud Run benar-benar sudah menggunakan kode terbaru.',
          ),
        );
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
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
      await Future<void>.delayed(const Duration(seconds: 2));
    }
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

  Future<ChatMessage> sendMessage(int conversationId, String body) async {
    final resolvedConversationId = await _resolveConversationId(conversationId);

    try {
      final response = await _api.post(
        'chat/conversations/$resolvedConversationId/messages',
        data: {'body': body},
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
}

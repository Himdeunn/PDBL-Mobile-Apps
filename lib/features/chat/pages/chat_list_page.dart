import 'package:flutter/material.dart';

import '../../../../core/models/user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../../../core/widgets/auth_required_dialog.dart';
import '../../auth/services/auth_service.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../../group/services/team_service.dart';
import 'chat_room_page.dart';

class ChatListPage extends StatefulWidget {
  final AuthService authService;
  final int? initialConversationId;

  const ChatListPage({
    super.key,
    required this.authService,
    this.initialConversationId,
  });

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final TextEditingController _searchController = TextEditingController();
  final ChatService _chatService = ChatService();
  final TeamService _teamService = TeamService();
  late final Stream<List<ChatConversation>> _conversationStream;
  String _searchQuery = '';
  String _selectedFilter = 'Team';
  User? _currentUser;
  List<ChatConversation> _bootstrapChats = [];
  String? _errorMessage;
  bool _openedInitialConversation = false;
  bool _isGuest = false;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.authService.currentCachedUser;
    _conversationStream = _chatService.watchConversations();
    _bootstrapConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _bootstrapConversations() async {
    try {
      User? currentUser;
      try {
        currentUser = await widget.authService.getCachedUser();
      } catch (_) {
        currentUser = widget.authService.currentCachedUser;
      }

      final isGuest =
          currentUser?.isGuest ?? await widget.authService.isGuest();

      if (isGuest) {
        if (!mounted) return;
        setState(() {
          _currentUser = currentUser;
          _isGuest = true;
          _bootstrapChats = const [];
          _errorMessage = null;
        });
        return;
      }

      final rawData = await _teamService.getDashboardData();
      final teamsPart = rawData is Map ? rawData['teams'] : null;
      final bootstrapChats = _listFromApiPart(
        teamsPart,
      ).whereType<Map<String, dynamic>>().map(_teamToConversation).toList();

      if (!mounted) return;
      setState(() {
        _currentUser = currentUser;
        _isGuest = false;
        _bootstrapChats = bootstrapChats;
        _errorMessage = null;
      });

      try {
        final remoteChats = await _chatService.getConversations();
        final merged = <String, ChatConversation>{
          for (final chat in _bootstrapChats) chat.firestoreId: chat,
          for (final chat in remoteChats) chat.firestoreId: chat,
        };

        if (!mounted) return;
        setState(() {
          _bootstrapChats = merged.values.toList();
        });
        _openInitialConversationIfNeeded(_bootstrapChats);
      } catch (_) {
        // Keep team bootstrap visible even if chat bootstrap fails.
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load chats. Please check your connection.';
      });
      if (_bootstrapChats.isEmpty) {
        ErrorHandler.handleApiError(e);
      }
    }
  }

  List<dynamic> _listFromApiPart(dynamic value) {
    if (value is List) return value;
    if (value is Map && value['data'] is List) return value['data'] as List;
    if (value is Map) return value.values.toList();
    return const [];
  }

  int? _readInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
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
      unreadCount: _readInt(team['unread_count'] ?? team['unreadCount']) ?? 0,
    );
  }

  Future<void> _refresh() async {
    await _bootstrapConversations();
  }

  Future<void> _openInitialConversationIfNeeded(
    List<ChatConversation> conversations,
  ) async {
    if (_openedInitialConversation || widget.initialConversationId == null)
      return;
    ChatConversation? chat;
    for (final conversation in conversations) {
      if (conversation.id == widget.initialConversationId) {
        chat = conversation;
        break;
      }
    }
    final initialChat = chat;
    if (initialChat == null) return;

    _openedInitialConversation = true;
    final currentUser =
        _currentUser ?? await widget.authService.getCachedUser();
    if (!mounted || currentUser == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomPage(
          conversation: initialChat,
          currentUser: currentUser,
          authService: widget.authService,
        ),
      ),
    );
    await NotificationHelper.cancelChatNotification(initialChat.id);
    await _chatService.markConversationRead(initialChat.id);
  }

  @override
  Widget build(BuildContext context) {
    final fallbackChats = _bootstrapChats;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.chevron_left,
            color: AppColors.textPrimary,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'List Chat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          child: StreamBuilder<List<ChatConversation>>(
            stream: _isGuest ? null : _conversationStream,
            builder: (context, snapshot) {
              final conversations =
                  (snapshot.hasData && snapshot.data!.isNotEmpty)
                  ? snapshot.data!
                  : fallbackChats;
              _openInitialConversationIfNeeded(conversations);
              final filteredChats = conversations.where((chat) {
                final isTeam = chat.type == 'team';
                if (_selectedFilter == 'Personal' && isTeam) return false;
                if (_selectedFilter == 'Team' && !isTeam) return false;

                final query = _searchQuery.toLowerCase();
                return query.isEmpty ||
                    chat.name.toLowerCase().contains(query) ||
                    (chat.lastMessage ?? '').toLowerCase().contains(query);
              }).toList();

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search chat',
                      hintStyle: const TextStyle(color: AppColors.textTertiary),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.textTertiary,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _FilterBubble(
                        label: 'Team',
                        selected: _selectedFilter == 'Team',
                        onTap: () => setState(() => _selectedFilter = 'Team'),
                      ),
                      const SizedBox(width: 10),
                      _FilterBubble(
                        label: 'Personal',
                        selected: _selectedFilter == 'Personal',
                        onTap: () =>
                            setState(() => _selectedFilter = 'Personal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (_isGuest)
                    const _ChatLoginRequired()
                  else if (_errorMessage != null && conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'Could not load chats. Please check your connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  else if (filteredChats.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'No chats yet.',
                          style: TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                    )
                  else
                    ...filteredChats.map(
                      (chat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ChatTile(
                          data: chat,
                          onTap: () async {
                            if (_isGuest) {
                              AuthRequiredDialog.show(context);
                              return;
                            }
                            final currentUser =
                                _currentUser ??
                                await widget.authService.getCachedUser();
                            if (!context.mounted || currentUser == null) {
                              return;
                            }
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatRoomPage(
                                  conversation: chat,
                                  currentUser: currentUser,
                                  authService: widget.authService,
                                ),
                              ),
                            );
                            await NotificationHelper.cancelChatNotification(
                              chat.id,
                            );
                            await _chatService.markConversationRead(chat.id);
                          },
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FilterBubble extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterBubble({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatConversation data;
  final VoidCallback onTap;

  const _ChatTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final memberNames = data.members.take(3).map((member) => member.name);
    final preview = data.lastMessage == null
        ? 'Tap to start chatting'
        : '${data.lastSenderName ?? 'Someone'}: ${data.lastMessage}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFFD6C5B0),
              backgroundImage: data.avatarUrl != null
                  ? NetworkImage(data.avatarUrl!)
                  : null,
              child: data.avatarUrl == null
                  ? Icon(
                      data.type == 'team' ? Icons.groups_rounded : Icons.person,
                      color: AppColors.primaryDark,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              memberNames.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textTertiary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            data.updatedAt == null
                                ? '--:--'
                                : _formatChatDate(data.updatedAt!),
                            style: const TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12,
                            ),
                          ),
                          if (data.unreadCount > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D2438),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                data.unreadCount > 99
                                    ? '99+'
                                    : data.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Color(0xFFEADBC8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatChatDate(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (date == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
    return '${dateTime.day}/${dateTime.month}';
  }
}

class _ChatLoginRequired extends StatelessWidget {
  const _ChatLoginRequired();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: const [
            Icon(
              Icons.lock_outline_rounded,
              size: 48,
              color: AppColors.textTertiary,
            ),
            SizedBox(height: 16),
            Text(
              'Login required to use chat features',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

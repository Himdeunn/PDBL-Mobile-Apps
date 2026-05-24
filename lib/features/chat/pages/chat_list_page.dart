import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/models/user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/native_text_input.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_cache_manager.dart';
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
  static const int _chatsPerPage = 5;

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
  int _currentChatPage = 1;

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
          'Room Chat',
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
                if (_selectedFilter == 'Individu' && isTeam) return false;
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
                  NativeTextInput(
                    controller: _searchController,
                    onChanged: (value) => setState(() {
                      _searchQuery = value.trim();
                      _currentChatPage = 1;
                    }),
                    hintText: 'Search chat',
                    backgroundColor: AppColors.surface,
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    fallbackBuilder: (context) => TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() {
                        _searchQuery = value.trim();
                        _currentChatPage = 1;
                      }),
                      decoration: InputDecoration(
                        hintText: 'Search chat',
                        hintStyle: const TextStyle(
                          color: AppColors.textTertiary,
                        ),
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
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: Stack(
                      children: [
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          alignment: _selectedFilter == 'Team'
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          child: FractionallySizedBox(
                            widthFactor: 0.5,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(21),
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  _selectedFilter = 'Team';
                                  _currentChatPage = 1;
                                }),
                                child: Center(
                                  child: Text(
                                    'Team',
                                    style: TextStyle(
                                      color: _selectedFilter == 'Team'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() {
                                  _selectedFilter = 'Individu';
                                  _currentChatPage = 1;
                                }),
                                child: Center(
                                  child: Text(
                                    'Individu',
                                    style: TextStyle(
                                      color: _selectedFilter == 'Individu'
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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
                  else ...[
                    ..._paginatedChats(
                      filteredChats,
                    ).map((chat) => _buildChatTile(chat)),
                    if (_chatTotalPages(filteredChats) > 1) ...[
                      const SizedBox(height: 8),
                      _buildChatPaginationControl(
                        _chatTotalPages(filteredChats),
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<ChatConversation> _paginatedChats(List<ChatConversation> chats) {
    final totalPages = _chatTotalPages(chats);
    if (totalPages > 0 && _currentChatPage > totalPages) {
      _currentChatPage = totalPages;
    }
    if (_currentChatPage < 1) _currentChatPage = 1;

    final startIndex = (_currentChatPage - 1) * _chatsPerPage;
    final endIndex = startIndex + _chatsPerPage;
    return chats.sublist(
      startIndex,
      endIndex > chats.length ? chats.length : endIndex,
    );
  }

  int _chatTotalPages(List<ChatConversation> chats) {
    return (chats.length / _chatsPerPage).ceil();
  }

  Widget _buildChatTile(ChatConversation chat) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ChatTile(
        data: chat,
        currentUserId: _currentUser?.id,
        currentUserName: _currentUser?.name,
        onTap: () async {
          if (_isGuest) {
            AuthRequiredDialog.show(context);
            return;
          }
          final currentUser =
              _currentUser ?? await widget.authService.getCachedUser();
          if (!context.mounted || currentUser == null) return;
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
          await NotificationHelper.cancelChatNotification(chat.id);
          await _chatService.markConversationRead(chat.id);
        },
      ),
    );
  }

  Widget _buildChatPaginationControl(int totalPages) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ChatPageButton(
          text: '<<',
          onTap: _currentChatPage > 1
              ? () => setState(() => _currentChatPage = 1)
              : null,
          isActive: false,
        ),
        _ChatPageButton(
          icon: Icons.chevron_left,
          onTap: _currentChatPage > 1
              ? () => setState(() => _currentChatPage--)
              : null,
          isActive: false,
        ),
        ..._chatPageItems(totalPages).map(
          (page) => page == null
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '...',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : _ChatPageButton(
                  text: page.toString(),
                  onTap: () => setState(() => _currentChatPage = page),
                  isActive: page == _currentChatPage,
                ),
        ),
        _ChatPageButton(
          icon: Icons.chevron_right,
          onTap: _currentChatPage < totalPages
              ? () => setState(() => _currentChatPage++)
              : null,
          isActive: false,
        ),
        _ChatPageButton(
          text: '>>',
          onTap: _currentChatPage < totalPages
              ? () => setState(() => _currentChatPage = totalPages)
              : null,
          isActive: false,
        ),
      ],
    );
  }

  List<int?> _chatPageItems(int totalPages) {
    if (totalPages <= 6) {
      return List.generate(totalPages, (index) => index + 1);
    }

    if (_currentChatPage <= 5) {
      return [1, 2, 3, 4, 5, null, totalPages];
    }

    if (_currentChatPage >= totalPages - 3) {
      return [
        1,
        null,
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    }

    return [
      1,
      null,
      _currentChatPage - 1,
      _currentChatPage,
      _currentChatPage + 1,
      null,
      totalPages,
    ];
  }
}

class _ChatPageButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool isActive;

  const _ChatPageButton({
    this.text,
    this.icon,
    required this.onTap,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E1E1E) : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(
                icon,
                color: isEnabled ? AppColors.textPrimary : Colors.grey,
                size: 24,
              )
            : Text(
                text!,
                style: TextStyle(
                  color: isActive
                      ? Colors.white
                      : isEnabled
                      ? AppColors.textPrimary
                      : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
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
  final int? currentUserId;
  final String? currentUserName;
  final VoidCallback onTap;

  const _ChatTile({
    required this.data,
    required this.currentUserId,
    required this.currentUserName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final memberNames = data.members.take(3).map((member) => member.name);
    final preview = data.lastMessage == null
        ? 'Tap to start chatting'
        : '${data.lastSenderName ?? 'Someone'}: ${data.lastMessage}';
    final lastMessage = data.lastMessage?.toLowerCase() ?? '';
    final currentName = currentUserName?.trim().toLowerCase();
    final firstName = currentName?.split(RegExp(r'\s+')).first;
    final isMentionedByText =
        lastMessage.contains('@all') ||
        (currentName != null &&
            currentName.isNotEmpty &&
            lastMessage.contains('@$currentName')) ||
        (firstName != null &&
            firstName.isNotEmpty &&
            lastMessage.contains('@$firstName'));
    final isMentioned =
        data.type == 'team' &&
        data.unreadCount > 0 &&
        (data.lastMessageMentionsAll ||
            data.hasUnreadMention ||
            (currentUserId != null &&
                data.lastMessageMentionedUserIds.contains(currentUserId)) ||
            isMentionedByText);

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
              child: ClipOval(
                child: data.avatarUrl == null
                    ? Icon(
                        data.type == 'team'
                            ? Icons.groups_rounded
                            : Icons.person,
                        color: AppColors.primaryDark,
                      )
                    : CachedNetworkImage(
                        imageUrl: data.avatarUrl!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        cacheManager: WudiCacheManager(),
                        errorWidget: (context, url, error) => Icon(
                          data.type == 'team'
                              ? Icons.groups_rounded
                              : Icons.person,
                          color: AppColors.primaryDark,
                        ),
                      ),
              ),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 20,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
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
                                if (isMentioned) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 20,
                                    height: 20,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      '@',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ] else ...[
                            const SizedBox(height: 6),
                            const SizedBox(height: 20),
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

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/models/user.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/utils/image_cache_manager.dart';
import '../../../../core/utils/navigator_service.dart';
import '../../../../core/utils/notification_helper.dart';
import '../../../../core/widgets/auth_required_dialog.dart';
import '../../auth/services/auth_service.dart';
import '../models/chat_models.dart';
import '../services/chat_service.dart';
import '../../group/pages/member_detail_page.dart';

class ChatRoomPage extends StatefulWidget {
  final ChatConversation conversation;
  final User currentUser;
  final AuthService authService;

  const ChatRoomPage({
    super.key,
    required this.conversation,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<ChatRoomPage> createState() => _ChatRoomPageState();
}

class _ChatRoomPageState extends State<ChatRoomPage> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late Future<void> _bootstrapFuture;
  late final Stream<List<ChatMessage>> _messageStream;
  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isOffline = false;
  String _mentionQuery = '';

  bool _isAtBottom = true;
  int _unreadNewMessages = 0;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapMessages();
    _messageStream = _chatService.watchMessagesWithFallback(
      widget.conversation.id,
    );
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    NotificationHelper.setActiveChatConversationId(null);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final atBottom = currentScroll >= maxScroll - 50;

    if (atBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = atBottom;
        if (_isAtBottom) _unreadNewMessages = 0;
      });
    }
  }

  Future<void> _bootstrapMessages() async {
    if (widget.currentUser.isGuest) return;
    final isConnected = await ConnectionService().isConnected();
    if (!mounted) return;
    setState(() => _isOffline = !isConnected);
    NotificationHelper.setActiveChatConversationId(widget.conversation.id);
    await NotificationHelper.cancelChatNotification(widget.conversation.id);
    await _chatService.markConversationRead(widget.conversation.id);
  }

  Future<void> _sendMessage() async {
    final body = _messageController.text.trim();
    if (body.isEmpty || _isSending) return;

    if (widget.currentUser.isGuest) {
      AuthRequiredDialog.show(context);
      return;
    }

    if (!await ConnectionService().isConnected()) {
      if (mounted) setState(() => _isOffline = true);
      ErrorHandler.showErrorPopup('Chat is available online only.');
      return;
    }

    setState(() => _isSending = true);

    try {
      final sentMessage = await _chatService.sendMessage(
        widget.conversation.id,
        body,
      );
      if (!mounted) return;
      setState(() {
        _messages = [
          ..._messages.where((message) => message.id != sentMessage.id),
          sentMessage,
        ];
        _isAtBottom = true;
        _unreadNewMessages = 0;
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _handleMessageChanged(String value) {
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) {
      setState(() => _mentionQuery = '');
      return;
    }

    final safeCursor = cursor.clamp(0, value.length);
    final beforeCursor = value.substring(0, safeCursor);
    final match = RegExp(r'(^|\s)@([\w]*)$').firstMatch(beforeCursor);

    setState(() {
      _mentionQuery = match?.group(2) ?? '';
    });
  }

  List<ChatMember> get _mentionMatches {
    final query = _mentionQuery.trim().toLowerCase();
    final members = widget.conversation.members;
    if (query.isEmpty) return members;
    return members
        .where(
          (member) =>
              member.name.toLowerCase().contains(query) ||
              (member.email ?? '').toLowerCase().contains(query),
        )
        .toList();
  }

  void _insertMention(ChatMember member) {
    final text = _messageController.text;
    final selection = _messageController.selection;
    final cursor = selection.baseOffset < 0
        ? text.length
        : selection.baseOffset;
    final prefix = text.substring(0, cursor);
    final suffix = text.substring(cursor);
    final match = RegExp(r'(^|\s)@([\w]*)$').firstMatch(prefix);
    if (match == null) return;

    final start = match.start + (match.group(1)?.length ?? 0);
    final replacement = '@${member.name} ';
    final updated = prefix.replaceRange(start, cursor, replacement) + suffix;

    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );

    setState(() => _mentionQuery = '');
    _messageFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _showMemberProfile(ChatMember member) async {
    final pageContext = context;
    final action = await showModalBottomSheet<_MemberProfileAction>(
      context: pageContext,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MemberAvatar(member: member, radius: 34),
            const SizedBox(height: 12),
            Text(
              member.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (member.email != null) ...[
              const SizedBox(height: 4),
              Text(
                member.email!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (widget.currentUser.isGuest) {
                    Navigator.of(context).pop(_MemberProfileAction.login);
                    AuthRequiredDialog.show(pageContext);
                    return;
                  }
                  if (member.id == widget.currentUser.id) {
                    Navigator.of(context).pop();
                    ErrorHandler.showErrorPopup(
                      'You cannot private chat with yourself.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(_MemberProfileAction.privateChat);
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Private Chat'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(_MemberProfileAction.viewProfile);
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('View Profile'),
              ),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null || action == _MemberProfileAction.login) {
      return;
    }

    if (action == _MemberProfileAction.privateChat) {
      showDialog(
        context: pageContext,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
      try {
        final privateConversation = await _chatService.startPrivateChat(
          member.id,
        );
        if (!mounted) return;
        Navigator.of(pageContext).pop(); // dismiss loading dialog

        // Push the new chat room onto the current navigator
        await Navigator.push(
          pageContext,
          MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              conversation: privateConversation,
              currentUser: widget.currentUser,
              authService: widget.authService,
            ),
          ),
        );
      } catch (e) {
        if (mounted) Navigator.of(pageContext).pop(); // dismiss loading dialog
        ErrorHandler.handleApiError(e);
      }
      return;
    }

    await NavigatorService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => MemberDetailPage(
          teamId: widget.conversation.teamId ?? 0,
          member: {
            'id': member.id,
            'name': member.name,
            'email': member.email,
            'avatar_url': member.avatarUrl,
          },
          memberTasks: const [],
          teamMembers: widget.conversation.members
              .map(
                (m) => {
                  'id': m.id,
                  'name': m.name,
                  'email': m.email,
                  'avatar_url': m.avatarUrl,
                },
              )
              .toList(),
        ),
      ),
    );
  }

  void _showMembersSheet() {
    final members = widget.conversation.members;
    if (members.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.conversation.name} members',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: _MemberAvatar(member: member, radius: 20),
                      title: Text(member.name),
                      subtitle: member.email == null
                          ? null
                          : Text(member.email!),
                      onTap: () {
                        Navigator.pop(context);
                        _showMemberProfile(member);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberHeader() {
    final isPersonal = widget.conversation.type == 'personal';
    final members = widget.conversation.members;

    VoidCallback? handleTap;
    if (isPersonal) {
      if (members.isNotEmpty) {
        final otherMember = members.firstWhere(
          (m) => m.id != widget.currentUser.id,
          orElse: () => members.first,
        );
        handleTap = () => _showMemberProfile(otherMember);
      }
    } else {
      handleTap = _showMembersSheet;
    }

    final names = members.map((member) => member.name).toList();
    final hiddenCount = members.length > 5 ? members.length - 5 : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: handleTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Text(
                      '<',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _ConversationAvatar(
                  conversation: widget.conversation,
                  radius: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isPersonal) ...[
                        const SizedBox(height: 3),
                        Text(
                          names.isEmpty
                              ? 'No members'
                              : '${names.take(5).join(', ')}${hiddenCount > 0 ? ' +$hiddenCount' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!isPersonal && hiddenCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+$hiddenCount',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: const Color(0xFFFFE4E6),
                child: const Text(
                  'Chat is online only. Reconnect to send or receive messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12),
                ),
              ),
            _buildMemberHeader(),
            Expanded(
              child: FutureBuilder<void>(
                future: _bootstrapFuture,
                builder: (context, bootstrapSnapshot) {
                  return StreamBuilder<List<ChatMessage>>(
                    stream: _messageStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32.0,
                              vertical: 24.0,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.cloud_off_rounded,
                                  size: 64,
                                  color: AppColors.textTertiary.withOpacity(
                                    0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Connection Unstable',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Unable to load messages. Please check your internet connection and try again.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _bootstrapFuture = _bootstrapMessages();
                                      _messageStream = _chatService
                                          .watchMessagesWithFallback(
                                            widget.conversation.id,
                                          );
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Try Again',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final streamedMessages = snapshot.data;
                      final messages =
                          streamedMessages == null ||
                              _messages.length > streamedMessages.length
                          ? _messages
                          : streamedMessages;

                      final isInitialLoad =
                          _messages.isEmpty && messages.isNotEmpty;
                      final newCount = messages.length - _messages.length;

                      if (newCount > 0) {
                        if (isInitialLoad || _isAtBottom) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) _scrollToBottom();
                          });
                        } else {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _unreadNewMessages += newCount;
                              });
                            }
                          });
                        }
                      }

                      _messages = messages;

                      if (bootstrapSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          messages.isEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              final isMine =
                                  message.senderId == widget.currentUser.id;
                              final member = widget.conversation.members
                                  .firstWhere(
                                    (m) => m.id == message.senderId,
                                    orElse: () => ChatMember(
                                      id: message.senderId,
                                      name: message.senderName,
                                      email: message.senderEmail,
                                      avatarUrl: message.senderAvatarUrl,
                                    ),
                                  );
                              final showDate =
                                  index == 0 ||
                                  !_sameDate(
                                    messages[index - 1].createdAt,
                                    message.createdAt,
                                  );

                              return Column(
                                children: [
                                  if (showDate)
                                    _DateChip(date: message.createdAt),
                                  _MessageBubble(
                                    message: message,
                                    member: member,
                                    isMine: isMine,
                                    onMemberTap: () =>
                                        _showMemberProfile(member),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (!_isAtBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _unreadNewMessages = 0);
                                  _scrollToBottom();
                                },
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.1,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.keyboard_arrow_down,
                                        color: AppColors.primary,
                                        size: 28,
                                      ),
                                    ),
                                    if (_unreadNewMessages > 0)
                                      Positioned(
                                        top: -4,
                                        right: -4,
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: const BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            _unreadNewMessages > 99
                                                ? '99+'
                                                : _unreadNewMessages.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_mentionQuery.isNotEmpty)
              _MentionSuggestions(
                query: _mentionQuery,
                members: _mentionMatches,
                onPick: _insertMention,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      onChanged: _handleMessageChanged,
                      minLines: 1,
                      maxLines: 4,
                      enabled: !_isOffline,
                      decoration: InputDecoration(
                        hintText: _isOffline
                            ? 'Reconnect to chat'
                            : 'Type a message',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    backgroundColor: _isOffline
                        ? AppColors.textTertiary
                        : AppColors.primary,
                    child: IconButton(
                      onPressed: _isOffline || _isSending ? null : _sendMessage,
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DateChip extends StatelessWidget {
  final DateTime date;

  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${date.day}/${date.month}/${date.year}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

enum _MemberProfileAction { privateChat, viewProfile, login }

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final ChatMember member;
  final bool isMine;
  final VoidCallback onMemberTap;

  const _MessageBubble({
    required this.message,
    required this.member,
    required this.isMine,
    required this.onMemberTap,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.primary : AppColors.surface;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.72,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMine)
                GestureDetector(
                  onTap: onMemberTap,
                  child: _MemberAvatar(member: member, radius: 16),
                ),
              if (!isMine) const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isMine ? 18 : 4),
                      bottomRight: Radius.circular(isMine ? 4 : 18),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: onMemberTap,
                        child: Text(
                          member.name,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text.rich(
                        _buildHighlightedText(message.body, textColor),
                        style: TextStyle(color: textColor, fontSize: 14),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Text(
                          '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isMine) const SizedBox(width: 8),
              if (isMine)
                GestureDetector(
                  onTap: onMemberTap,
                  child: _MemberAvatar(member: member, radius: 16),
                ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(String body, Color baseColor) {
    final mentionPattern = RegExp(r'@\w+');
    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in mentionPattern.allMatches(body)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: body.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: body.substring(match.start, match.end),
          style: TextStyle(
            color: baseColor,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      );
      lastIndex = match.end;
    }

    if (lastIndex < body.length) {
      spans.add(TextSpan(text: body.substring(lastIndex)));
    }

    return TextSpan(
      style: TextStyle(color: baseColor),
      children: spans.isEmpty ? [TextSpan(text: body)] : spans,
    );
  }
}

class _ConversationAvatar extends StatelessWidget {
  final ChatConversation conversation;
  final double radius;

  const _ConversationAvatar({required this.conversation, required this.radius});

  @override
  Widget build(BuildContext context) {
    final firstMember = conversation.members.isNotEmpty
        ? conversation.members.first
        : null;
    final avatarUrl = conversation.type == 'team'
        ? conversation.avatarUrl
        : conversation.avatarUrl ?? firstMember?.avatarUrl;

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD6C5B0),
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                cacheManager: WudiCacheManager(),
                errorWidget: (_, __, ___) => Icon(
                  conversation.type == 'team' ? Icons.groups_rounded : Icons.person,
                  color: AppColors.primaryDark,
                ),
              )
            : Icon(
                conversation.type == 'team' ? Icons.groups_rounded : Icons.person,
                color: AppColors.primaryDark,
              ),
      ),
    );
  }
}

class _MentionSuggestions extends StatelessWidget {
  final String query;
  final List<ChatMember> members;
  final ValueChanged<ChatMember> onPick;

  const _MentionSuggestions({
    required this.query,
    required this.members,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final visible = members.take(6).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'No member found for @$query',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: visible.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final member = visible[index];
                    return ListTile(
                      dense: true,
                      leading: _MemberAvatar(member: member, radius: 18),
                      title: Text(member.name),
                      subtitle: member.email == null
                          ? null
                          : Text(member.email!),
                      onTap: () => onPick(member),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  final ChatMember member;
  final double radius;

  const _MemberAvatar({required this.member, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFD6C5B0),
      ),
      child: ClipOval(
        child: member.avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: member.avatarUrl!,
                fit: BoxFit.cover,
                cacheManager: WudiCacheManager(),
                errorWidget: (_, __, ___) => Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
              )
            : Center(
                child: Text(
                  member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.primaryDark),
                ),
              ),
      ),
    );
  }
}

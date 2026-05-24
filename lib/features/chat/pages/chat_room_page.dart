import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
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
import '../widgets/native_chat_composer.dart';
import '../../group/pages/member_detail_page.dart';

part 'chat_room_page_widgets.dart';
part 'chat_room_message_bubble.dart';
part 'chat_room_page_layout.dart';

const int _maxChatMessageLength = 65536;

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
  late Stream<List<ChatMessage>> _messageStream;
  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isOffline = false;
  String _mentionQuery = '';
  int _messageLength = 0;
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  final Set<int> _selectedMessageIds = {};
  DateTime? _lastActionAt;
  final Map<int, GlobalKey> _messageKeys = {};

  bool _isAtBottom = true;
  int _unreadNewMessages = 0;
  bool _hasPositionedInitialMessages = false;
  bool _isMessageTooLongPopupShowing = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrapMessages();
    _messageStream = _chatService.cachedMessageStream(widget.conversation.id);
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

  void _updateState(VoidCallback fn) => setState(fn);

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.offset;
    final atBottom = currentScroll <= 50;

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
    if (body.isEmpty || _isSending || _isActionCoolingDown()) return;

    if (body.length > _maxChatMessageLength) {
      _showMessageTooLongPopup();
      return;
    }

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
      final sentMessage = _editingMessage == null
          ? await _chatService.sendMessage(
              widget.conversation.id,
              body,
              replyToId: _replyingTo?.id,
            )
          : await _chatService.editMessage(
              widget.conversation.id,
              _editingMessage!,
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
        _replyingTo = null;
        _editingMessage = null;
        _messageLength = 0;
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
          _lastActionAt = DateTime.now();
        });
      }
    }
  }

  bool _isActionCoolingDown() {
    final last = _lastActionAt;
    return last != null && DateTime.now().difference(last).inMilliseconds < 500;
  }

  void _handleMessageChanged(String value) {
    if (value.length > _maxChatMessageLength) {
      _showMessageTooLongPopup();
    } else {
      _isMessageTooLongPopupShowing = false;
    }

    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) {
      if (_mentionQuery.isNotEmpty || _messageLength != value.length) {
        setState(() {
          _mentionQuery = '';
          _messageLength = value.length;
        });
      }
      return;
    }

    final safeCursor = cursor.clamp(0, value.length);
    final beforeCursor = value.substring(0, safeCursor);
    final match = RegExp(r'(^|\s)@([^@]*)$').firstMatch(beforeCursor);
    final rawMention = match?.group(2) ?? '';

    final nextMentionQuery = match == null || _isCompletedMention(rawMention)
        ? ''
        : '@$rawMention';
    if (nextMentionQuery != _mentionQuery || _messageLength != value.length) {
      setState(() {
        _mentionQuery = nextMentionQuery;
        _messageLength = value.length;
      });
    }
  }

  void _showMessageTooLongPopup() {
    if (_isMessageTooLongPopupShowing) return;
    _isMessageTooLongPopupShowing = true;
    ErrorHandler.showErrorPopup('Message too long.');
  }

  bool _isCompletedMention(String rawMention) {
    if (!rawMention.endsWith(' ')) return false;
    final mention = rawMention.trim().toLowerCase();
    if (mention == 'all') return true;
    return widget.conversation.members.any(
      (member) => member.name.trim().toLowerCase() == mention,
    );
  }

  List<ChatMember> get _mentionMatches {
    final rawQuery = _mentionQuery.startsWith('@')
        ? _mentionQuery.substring(1)
        : _mentionQuery;
    final query = rawQuery.trim().toLowerCase();
    final members = [
      if (widget.conversation.type == 'team')
        const ChatMember(id: 0, name: 'all'),
      ...widget.conversation.members,
    ];
    if (_mentionQuery == '@' || query.isEmpty) return members;
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
    final match = RegExp(r'(^|\s)@([^@]*)$').firstMatch(prefix);
    if (match == null) return;

    final start = match.start + (match.group(1)?.length ?? 0);
    final mentionName = member.name.trim();
    final replacement = '@$mentionName ';
    final updated = prefix.replaceRange(start, cursor, replacement) + suffix;

    _messageController.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );

    setState(() {
      _mentionQuery = '';
      _messageLength = updated.length;
    });
    _messageFocusNode.requestFocus();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      if (!animated) {
        _scrollController.jumpTo(0.0);
        return;
      }
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _scrollToMessage(int messageId) {
    final targetContext = _messageKeys[messageId]?.currentContext;
    if (targetContext != null) {
      _ensureMessageVisible(targetContext);
      return;
    }

    final targetIndexFromStart = _messages.indexWhere(
      (message) => message.id == messageId,
    );
    if (targetIndexFromStart == -1 || !_scrollController.hasClients) return;

    final targetIndex = _messages.length - 1 - targetIndexFromStart;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final targetOffset = _messages.length <= 1
        ? 0.0
        : (maxScroll * targetIndex / (_messages.length - 1))
              .clamp(0.0, maxScroll)
              .toDouble();

    _scrollController
        .animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
        .then((_) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final targetContext = _messageKeys[messageId]?.currentContext;
            if (targetContext != null) _ensureMessageVisible(targetContext);
          });
        });
  }

  void _ensureMessageVisible(BuildContext targetContext) {
    HapticFeedback.selectionClick();

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  void _startReply(ChatMessage message) {
    if (message.isDeleted) return;
    setState(() {
      _replyingTo = message;
      _editingMessage = null;
      _selectedMessageIds.clear();
    });
    _messageFocusNode.requestFocus();
  }

  void _startEdit(ChatMessage message) {
    if (!_canEdit(message)) return;
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _selectedMessageIds.clear();
      _messageLength = message.body.length;
      _messageController.text = message.body;
      _messageController.selection = TextSelection.collapsed(
        offset: message.body.length,
      );
    });
    _messageFocusNode.requestFocus();
  }

  bool _canEdit(ChatMessage message) {
    return message.senderId == widget.currentUser.id &&
        !message.isDeleted &&
        DateTime.now().difference(message.createdAt).inMinutes < 15;
  }

  bool _canDeleteForEveryone(ChatMessage message) {
    if (message.isDeleted) return false;
    final isWithinLimit =
        DateTime.now().difference(message.createdAt).inMinutes < 60;
    return isWithinLimit &&
        (message.senderId == widget.currentUser.id ||
            widget.conversation.canModerateMessages);
  }

  void _toggleSelection(ChatMessage message) {
    setState(() {
      if (_selectedMessageIds.contains(message.id)) {
        _selectedMessageIds.remove(message.id);
      } else {
        _selectedMessageIds.add(message.id);
      }
    });
  }

  void _clearSelection() {
    setState(() => _selectedMessageIds.clear());
  }

  List<ChatMessage> get _selectedMessages => _messages
      .where((message) => _selectedMessageIds.contains(message.id))
      .toList();

  bool get _canReplyToSelection =>
      _selectedMessages.length == 1 && !_selectedMessages.first.isDeleted;

  bool get _canEditSelection =>
      _selectedMessages.length == 1 && _canEdit(_selectedMessages.first);

  Future<void> _copyMessages(List<ChatMessage> messages) async {
    final text = messages.map((message) => message.body).join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    _clearSelection();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message copied')));
  }

  Future<void> _deleteMessages(List<ChatMessage> messages) async {
    final canEveryone = messages.every(_canDeleteForEveryone);
    final scope = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Delete Message',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          messages.length == 1
              ? 'Are you sure you want to delete this message?'
              : 'Are you sure you want to delete ${messages.length} messages?',
          style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
            ),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            child: const Text('Delete for Me'),
          ),
          if (canEveryone)
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Delete for Everyone'),
            ),
        ],
      ),
    );
    if (scope == null) return;

    final targetIds = messages.map((message) => message.id).toSet();

    setState(() {
      if (scope) {
        _messages = _messages
            .map(
              (message) => targetIds.contains(message.id)
                  ? message.copyWith(
                      body: message.senderId == widget.currentUser.id
                          ? 'This message was deleted'
                          : 'Message deleted by leader',
                      deletedAt: DateTime.now(),
                      deleteReason: message.senderId == widget.currentUser.id
                          ? 'sender'
                          : 'leader',
                    )
                  : message,
            )
            .toList();
      } else {
        _messages.removeWhere((message) => targetIds.contains(message.id));
      }
      _selectedMessageIds.removeAll(targetIds);
    });

    try {
      for (final message in messages) {
        await _chatService.deleteMessage(
          widget.conversation.id,
          message,
          forEveryone: scope,
        );
      }
      if (!mounted) return;
      setState(() => _selectedMessageIds.clear());
    } catch (e) {
      ErrorHandler.handleApiError(e);
    }
  }

  Future<void> _showMemberProfile(ChatMember member) async {
    final pageContext = context;
    final action = await showModalBottomSheet<_MemberProfileAction>(
      context: pageContext,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.paddingOf(context).bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _MemberAvatar(member: member, radius: 34),
            const SizedBox(height: 12),
            Text(
              member.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (member.email != null && member.email!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                member.email!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop(_MemberProfileAction.viewProfile);
                    },
                    icon: const Icon(Icons.person_outline),
                    label: const Text(
                      'View Profile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
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
                      Navigator.of(
                        context,
                      ).pop(_MemberProfileAction.privateChat);
                    },
                    icon: const Icon(Icons.send_outlined, size: 20),
                    label: const Text(
                      'Chat Private',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
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

  @override
  Widget build(BuildContext context) => _buildChatScaffold(context);
}

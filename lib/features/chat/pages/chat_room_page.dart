import 'package:cached_network_image/cached_network_image.dart';
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
  final ScrollController _inputScrollController = ScrollController();
  late Future<void> _bootstrapFuture;
  late Stream<List<ChatMessage>> _messageStream;
  List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isOffline = false;
  String _mentionQuery = '';
  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  final Set<int> _selectedMessageIds = {};
  DateTime? _lastActionAt;
  final Map<int, GlobalKey> _messageKeys = {};

  bool _isAtBottom = true;
  int _unreadNewMessages = 0;
  bool _hasPositionedInitialMessages = false;

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
    _inputScrollController.dispose();
    super.dispose();
  }

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

    if (body.length > 2000) {
      ErrorHandler.showErrorPopup('Message is too long.');
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
    final cursor = _messageController.selection.baseOffset;
    if (cursor < 0) {
      if (_mentionQuery.isNotEmpty) setState(() => _mentionQuery = '');
      return;
    }

    final safeCursor = cursor.clamp(0, value.length);
    final beforeCursor = value.substring(0, safeCursor);
    final match = RegExp(r'(^|\s)@([^@]*)$').firstMatch(beforeCursor);
    final rawMention = match?.group(2) ?? '';

    final nextMentionQuery = match == null || _isCompletedMention(rawMention)
        ? ''
        : '@$rawMention';
    if (nextMentionQuery != _mentionQuery) {
      setState(() => _mentionQuery = nextMentionQuery);
    }
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

    setState(() => _mentionQuery = '');
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

  Widget _buildMemberHeader() {
    Widget content;
    if (_selectedMessageIds.isNotEmpty) {
      final selected = _selectedMessages;
      content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                IconButton(
                  onPressed: _clearSelection,
                  icon: const Icon(Icons.close),
                ),
                Expanded(
                  child: Text(
                    '${_selectedMessageIds.length} selected',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_canReplyToSelection)
                  IconButton(
                    onPressed: () => _startReply(selected.first),
                    icon: const Icon(Icons.reply),
                  ),
                if (_canEditSelection)
                  IconButton(
                    onPressed: () => _startEdit(selected.first),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                IconButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => _copyMessages(selected),
                  icon: const Icon(Icons.copy),
                ),
                IconButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => _deleteMessages(selected),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
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

      content = Padding(
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
                ],
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(height: 88, child: content);
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
                              vertical: 12.0,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    size: 48,
                                    color: AppColors.textTertiary.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Connection Unstable',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Unable to load messages. Please check your internet connection and try again.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _bootstrapFuture = _bootstrapMessages();
                                        _messageStream = _chatService
                                            .cachedMessageStream(
                                              widget.conversation.id,
                                            );
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
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
                          !_hasPositionedInitialMessages &&
                          _messages.isEmpty &&
                          messages.isNotEmpty;
                      final newCount = messages.length - _messages.length;

                      if (newCount > 0) {
                        if (isInitialLoad) {
                          _hasPositionedInitialMessages = true;
                        } else if (_isAtBottom) {
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
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  messages[messages.length - 1 - index];
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
                                  index == messages.length - 1 ||
                                  !_sameDate(
                                    messages[messages.length - 1 - index]
                                        .createdAt,
                                    messages[messages.length - 1 - (index + 1)]
                                        .createdAt,
                                  );

                              return Column(
                                children: [
                                  if (showDate)
                                    _DateChip(date: message.createdAt),
                                  KeyedSubtree(
                                    key: _messageKeys.putIfAbsent(
                                      message.id,
                                      () => GlobalKey(),
                                    ),
                                    child: _MessageBubble(
                                      message: message,
                                      member: member,
                                      isMine: isMine,
                                      isSelected: _selectedMessageIds.contains(
                                        message.id,
                                      ),
                                      onReplyTap: message.replyToId == null
                                          ? null
                                          : () => _scrollToMessage(
                                              message.replyToId!,
                                            ),
                                      onSwipeReply: () => _startReply(message),
                                      onLongPress: () =>
                                          _toggleSelection(message),
                                      onTap: () {
                                        if (_selectedMessageIds.isNotEmpty) {
                                          _toggleSelection(message);
                                        }
                                      },
                                      onMemberTap: () =>
                                          _showMemberProfile(member),
                                      mentionMembers: [
                                        if (widget.conversation.type == 'team')
                                          const ChatMember(id: 0, name: 'all'),
                                        ...widget.conversation.members,
                                      ],
                                    ),
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
            if (_replyingTo != null || _editingMessage != null)
              _ComposerContextPreview(
                label: _editingMessage == null ? 'Replying to' : 'Editing',
                title:
                    _editingMessage?.senderName ??
                    _replyingTo?.senderName ??
                    '',
                body: _editingMessage?.body ?? _replyingTo?.body ?? '',
                onClose: () {
                  final wasEditing = _editingMessage != null;
                  setState(() {
                    _replyingTo = null;
                    _editingMessage = null;
                    if (wasEditing) _messageController.clear();
                  });
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: TextField(
                            controller: _messageController,
                            scrollController: _inputScrollController,
                            focusNode: _messageFocusNode,
                            onChanged: _handleMessageChanged,
                            keyboardType: TextInputType.multiline,
                            textAlignVertical: TextAlignVertical.top,
                            textInputAction: TextInputAction.newline,
                            maxLines: null,
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
                              counterText: '',
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _messageController,
                          builder: (context, value, _) {
                            final length = value.text.length;
                            return Text(
                              '$length/2000',
                              style: TextStyle(
                                color: length > 2000
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ],
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

class _ComposerContextPreview extends StatelessWidget {
  final String label;
  final String title;
  final String body;
  final VoidCallback onClose;

  const _ComposerContextPreview({
    required this.label,
    required this.title,
    required this.body,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$label $title',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final ChatMember member;
  final bool isMine;
  final bool isSelected;
  final VoidCallback onMemberTap;
  final VoidCallback? onReplyTap;
  final VoidCallback onSwipeReply;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;
  final List<ChatMember> mentionMembers;

  const _MessageBubble({
    required this.message,
    required this.member,
    required this.isMine,
    required this.isSelected,
    required this.onMemberTap,
    required this.onSwipeReply,
    required this.onLongPress,
    required this.mentionMembers,
    this.onReplyTap,
    this.onTap,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _isExpanded = false;
  double _horizontalDragDistance = 0;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final member = widget.member;
    final isMine = widget.isMine;
    final isSelected = widget.isSelected;
    final isLongMessage = !message.isDeleted && message.body.length > 280;
    final bubbleColor = message.isDeleted
        ? AppColors.surface
        : isMine
        ? AppColors.primary
        : AppColors.surface;
    final textColor = message.isDeleted
        ? AppColors.textSecondary
        : isMine
        ? Colors.white
        : AppColors.textPrimary;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: (_) => _horizontalDragDistance = 0,
        onHorizontalDragUpdate: (details) {
          _horizontalDragDistance += details.primaryDelta ?? 0;
        },
        onHorizontalDragEnd: (_) {
          if (_horizontalDragDistance > 64) {
            widget.onSwipeReply();
            HapticFeedback.selectionClick();
          }
          _horizontalDragDistance = 0;
        },
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
                    onTap: widget.onMemberTap,
                    child: _MemberAvatar(member: member, radius: 16),
                  ),
                if (!isMine) const SizedBox(width: 8),
                Flexible(
                  child: GestureDetector(
                    onTap: widget.onTap,
                    onLongPress: widget.onLongPress,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 60),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : bubbleColor,
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
                            onTap: widget.onMemberTap,
                            child: Text(
                              member.name,
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (message.replyToId != null) ...[
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: widget.onReplyTap,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color:
                                      (isMine
                                              ? Colors.white
                                              : AppColors.primary)
                                          .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.replySenderName ?? 'Message',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      message.replyBody ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: textColor.withValues(
                                          alpha: 0.75,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Text.rich(
                            _buildHighlightedText(
                              message.body,
                              textColor,
                              mentionColor: isMine
                                  ? const Color(0xFFEADBC8)
                                  : AppColors.primary,
                            ),
                            maxLines: isLongMessage && !_isExpanded ? 6 : null,
                            overflow: isLongMessage && !_isExpanded
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontStyle: message.isDeleted
                                  ? FontStyle.italic
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}${message.isEdited && !message.isDeleted ? ' · edited' : ''}',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (isLongMessage) ...[
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () {
                                setState(() => _isExpanded = !_isExpanded);
                              },
                              child: Text(
                                _isExpanded ? 'Read less' : 'Read more...',
                                style: TextStyle(
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.9)
                                      : AppColors.primary,
                                  fontSize: 12,
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
                if (isMine) const SizedBox(width: 8),
                if (isMine)
                  GestureDetector(
                    onTap: widget.onMemberTap,
                    child: _MemberAvatar(member: member, radius: 16),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextSpan _buildHighlightedText(
    String body,
    Color baseColor, {
    required Color mentionColor,
  }) {
    final matches = <RegExpMatch>[];
    for (final member in widget.mentionMembers) {
      final mention = member.name.trim();
      if (mention.isEmpty) continue;
      matches.addAll(
        RegExp(
          '@${RegExp.escape(mention)}',
          caseSensitive: false,
          unicode: true,
        ).allMatches(body),
      );
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var lastIndex = 0;

    for (final match in matches) {
      if (match.start < lastIndex) continue;
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: body.substring(lastIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: body.substring(match.start, match.end),
          style: TextStyle(color: mentionColor, fontWeight: FontWeight.w800),
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
                errorWidget: (context, url, error) => Icon(
                  conversation.type == 'team'
                      ? Icons.groups_rounded
                      : Icons.person,
                  color: AppColors.primaryDark,
                ),
              )
            : Icon(
                conversation.type == 'team'
                    ? Icons.groups_rounded
                    : Icons.person,
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
                errorWidget: (context, url, error) => Text(
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

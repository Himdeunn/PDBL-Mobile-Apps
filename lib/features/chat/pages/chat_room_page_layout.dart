part of 'chat_room_page.dart';

extension _ChatRoomPageLayout on _ChatRoomPageState {
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

      content = Material(
        color: AppColors.surface,
        child: InkWell(
          onTap: handleTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.chevron_left_rounded,
                      color: AppColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _ConversationAvatar(
                  conversation: widget.conversation,
                  radius: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      if (!isPersonal) ...[
                        const SizedBox(height: 1),
                        Text(
                          names.isEmpty ? 'No members' : names.join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
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
      );
    }
    return content;
  }

  Widget _buildChatScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            height: MediaQuery.paddingOf(context).top,
            color: AppColors.surface,
          ),
          Expanded(
            child: SafeArea(
              top: false,
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
                        style: TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 12,
                        ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.cloud_off_rounded,
                                          size: 48,
                                          color: AppColors.textTertiary
                                              .withValues(alpha: 0.5),
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
                                            _updateState(() {
                                              _bootstrapFuture =
                                                  _bootstrapMessages();
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
                                              borderRadius:
                                                  BorderRadius.circular(24),
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
                            final messages = streamedMessages == null
                                ? _messages
                                : _mergeMessages(_messages, streamedMessages);

                            final isInitialLoad =
                                !_hasPositionedInitialMessages &&
                                _messages.isEmpty &&
                                messages.isNotEmpty;
                            final newCount = messages.length - _messages.length;

                            if (newCount > 0) {
                              if (isInitialLoad) {
                                _hasPositionedInitialMessages = true;
                              } else if (_isAtBottom) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _scrollToBottom();
                                });
                              } else {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) {
                                    _updateState(() {
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
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            return Stack(
                              children: [
                                ListView.builder(
                                  controller: _scrollController,
                                  physics: const ClampingScrollPhysics(),
                                  reverse: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    12,
                                  ),
                                  itemCount:
                                      messages.length +
                                      (_isLoadingOlderMessages ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (_isLoadingOlderMessages &&
                                        index == messages.length) {
                                      return const Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        child: Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final message =
                                        messages[messages.length - 1 - index];
                                    final isMine =
                                        message.senderId ==
                                        widget.currentUser.id;
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
                                          messages[messages.length -
                                                  1 -
                                                  (index + 1)]
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
                                            isSelected: _selectedMessageIds
                                                .contains(message.id),
                                            onReplyTap:
                                                message.replyToId == null
                                                ? null
                                                : () => _scrollToMessage(
                                                    message.replyToId!,
                                                  ),
                                            onSwipeReply: () =>
                                                _startReply(message),
                                            onLongPress: () =>
                                                _toggleSelection(message),
                                            onTap: () {
                                              if (_selectedMessageIds
                                                  .isNotEmpty) {
                                                _toggleSelection(message);
                                              }
                                            },
                                            onMemberTap: () =>
                                                _showMemberProfile(member),
                                            mentionMembers: [
                                              if (widget.conversation.type ==
                                                  'team')
                                                const ChatMember(
                                                  id: 0,
                                                  name: 'all',
                                                ),
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
                                        _updateState(
                                          () => _unreadNewMessages = 0,
                                        );
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
                                                  color: Colors.black
                                                      .withValues(alpha: 0.1),
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
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                decoration: const BoxDecoration(
                                                  color: AppColors.primary,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  _unreadNewMessages > 99
                                                      ? '99+'
                                                      : _unreadNewMessages
                                                            .toString(),
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_mentionQuery.isNotEmpty)
                        _MentionSuggestions(
                          query: _mentionQuery,
                          members: _mentionMatches,
                          onPick: _insertMention,
                        ),
                      if (_replyingTo != null || _editingMessage != null)
                        _ComposerContextPreview(
                          label: _editingMessage == null
                              ? 'Replying to'
                              : 'Editing',
                          title:
                              _editingMessage?.senderName ??
                              _replyingTo?.senderName ??
                              '',
                          body:
                              _editingMessage?.body ?? _replyingTo?.body ?? '',
                          onClose: () {
                            final wasEditing = _editingMessage != null;
                            _updateState(() {
                              _replyingTo = null;
                              _editingMessage = null;
                              if (wasEditing) {
                                _messageController.clear();
                                _messageLength = 0;
                              }
                            });
                          },
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.surface,
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    child: TextSelectionTheme(
                                      data: TextSelectionThemeData(
                                        cursorColor: AppColors.primary,
                                        selectionColor: AppColors.primary
                                            .withValues(alpha: 0.26),
                                        selectionHandleColor: AppColors.primary,
                                      ),
                                      child: NativeChatComposer(
                                        key: const ValueKey(
                                          'chat_composer_text_field',
                                        ),
                                        controller: _messageController,
                                        focusNode: _messageFocusNode,
                                        onChanged: _handleMessageChanged,
                                        hintText: _isOffline
                                            ? 'Reconnect to chat'
                                            : 'Type a message',
                                        enabled: !_isOffline,
                                        height: 44,
                                        fallbackBuilder: (context) => TextField(
                                          controller: _messageController,
                                          focusNode: _messageFocusNode,
                                          onChanged: _handleMessageChanged,
                                          keyboardType: TextInputType.multiline,
                                          dragStartBehavior:
                                              DragStartBehavior.start,
                                          textAlignVertical:
                                              TextAlignVertical.center,
                                          textInputAction:
                                              TextInputAction.newline,
                                          autocorrect: true,
                                          enableSuggestions: true,
                                          smartDashesType:
                                              SmartDashesType.disabled,
                                          smartQuotesType:
                                              SmartQuotesType.disabled,
                                          minLines: 1,
                                          maxLines: 5,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                            color: AppColors.textPrimary,
                                          ),
                                          strutStyle: const StrutStyle(
                                            fontSize: 14,
                                            height: 1.3,
                                            forceStrutHeight: false,
                                          ),
                                          enabled: !_isOffline,
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: _isOffline
                                                ? 'Reconnect to chat'
                                                : 'Type a message',
                                            filled: false,
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 12,
                                                ),
                                            counterText: '',
                                          ),
                                        ),
                                      ),
                                    ),
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
                                onPressed: _isOffline || _isSending
                                    ? null
                                    : _sendMessage,
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
                    ], // Column(mainAxisSize.min) children
                  ), // Column
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

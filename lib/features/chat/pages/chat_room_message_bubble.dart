part of 'chat_room_page.dart';

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

class _MessageBubbleState extends State<_MessageBubble>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  double _dragOffset = 0;
  late final AnimationController _springController;
  late Animation<double> _springAnimation;
  bool _triggeredReply = false;

  static const double _replyThreshold = 64;
  static const double _maxDrag = 80;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _springAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.elasticOut),
    );
    _springController.addListener(() {
      setState(() => _dragOffset = _springAnimation.value);
    });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails _) {
    _springController.stop();
    _triggeredReply = false;
    setState(() => _dragOffset = 0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(-_maxDrag, _maxDrag);
    });
    final absOffset = _dragOffset.abs();
    if (absOffset >= _replyThreshold && !_triggeredReply) {
      _triggeredReply = true;
      HapticFeedback.selectionClick();
    }
  }

  void _onDragEnd(DragEndDetails _) {
    if (_triggeredReply) {
      widget.onSwipeReply();
    }
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0).animate(
      CurvedAnimation(parent: _springController, curve: Curves.easeOut),
    );
    _springController.forward(from: 0);
    _triggeredReply = false;
  }

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
        onHorizontalDragStart: _onDragStart,
        onHorizontalDragUpdate: _onDragUpdate,
        onHorizontalDragEnd: _onDragEnd,
        child: Stack(
          children: [
            // Reply icon — muncul saat di-swipe
            if (_dragOffset != 0)
              Positioned.fill(
                child: Align(
                  alignment: _dragOffset < 0
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Opacity(
                      opacity: (_dragOffset.abs() / _replyThreshold).clamp(
                        0.0,
                        1.0,
                      ),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isMine ? Icons.reply_rounded : Icons.reply_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(
              offset: Offset(_dragOffset, 0),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            message.replySenderName ??
                                                'Message',
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
                                  maxLines: isLongMessage && !_isExpanded
                                      ? 6
                                      : null,
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
                                      setState(
                                        () => _isExpanded = !_isExpanded,
                                      );
                                    },
                                    child: Text(
                                      _isExpanded
                                          ? 'Read less'
                                          : 'Read more...',
                                      style: TextStyle(
                                        color: isMine
                                            ? Colors.white.withValues(
                                                alpha: 0.9,
                                              )
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
          ],
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

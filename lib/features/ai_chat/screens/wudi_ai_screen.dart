import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/native_text_input.dart';
import '../../task/widgets/priority_badge.dart';
import '../cache/ai_chat_cache.dart';
import '../models/ai_chat_message.dart';
import '../services/ai_chat_service.dart';
import '../widgets/ai_typing_indicator.dart';

class WudiAiScreen extends StatefulWidget {
  final String? initialPrompt;
  final bool loadHistory;
  final bool isGuest;

  const WudiAiScreen({
    super.key,
    this.initialPrompt,
    this.loadHistory = true,
    this.isGuest = false,
  });

  @override
  State<WudiAiScreen> createState() => _WudiAiScreenState();
}

class _WudiAiScreenState extends State<WudiAiScreen> {
  final _service = AiChatService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  CancelToken? _cancelToken;
  String? _activeRequestId;
  bool _isGenerating = false;
  bool _isLoadingHistory = true;
  bool _showScrollToBottom = false;
  List<AiChatMessage> _messages = [];

  static const _suggestions = [
    'What task is closest to deadline?',
    'Summarize today tasks',
    'Summarize all tasks',
    'Show overdue tasks',
    'What should I prioritize?',
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    if (widget.isGuest) {
      _isLoadingHistory = false;
      return;
    }
    _messages = AiChatCache.messages;
    if (_messages.isEmpty) {
      _messages = [_welcomeMessage()];
    }
    if (widget.loadHistory) {
      _loadHistory();
    } else {
      _isLoadingHistory = false;
    }
    _scrollSoon(animated: false);
    if (widget.initialPrompt != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _send(widget.initialPrompt!),
      );
    }
  }

  AiChatMessage _welcomeMessage() {
    return AiChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      content:
          'Sure, ask away. I can help answer questions about your tasks, deadlines, priorities, progress, or which task you should do first.',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _service.history();
      if (!mounted) return;
      setState(() {
        _messages = _mergeHistory(history);
        _isLoadingHistory = false;
      });
      _scrollSoon(animated: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _startNewSession() async {
    if (_isGenerating) return;

    setState(() => _isLoadingHistory = true);
    try {
      await _service.newConversation();
      if (!mounted) return;
      setState(() {
        _messages = [_welcomeMessage()];
        _isLoadingHistory = false;
      });
      _scrollSoon(animated: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _openSession(AiConversationSummary conversation) async {
    if (_isGenerating) return;

    Navigator.pop(context);
    setState(() => _isLoadingHistory = true);
    try {
      final history = await _service.history(conversationId: conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = history.isEmpty ? [_welcomeMessage()] : history;
        _isLoadingHistory = false;
      });
      _scrollSoon(animated: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _showSessions() async {
    if (_isGenerating) return;

    final conversations = await _service.conversations();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _AiSessionSheet(
        conversations: conversations,
        currentConversationId: AiChatCache.conversationId,
        onNewSession: () {
          Navigator.pop(context);
          _startNewSession();
        },
        onOpenSession: _openSession,
      ),
    );
  }

  List<AiChatMessage> _mergeHistory(List<AiChatMessage> history) {
    final base = history.isEmpty ? <AiChatMessage>[] : [...history];
    for (final local in _messages) {
      final isWelcome =
          !local.isUser && local.content == _welcomeMessage().content;
      final exists = base.any(
        (item) =>
            item.id == local.id ||
            (item.role == local.role &&
                item.content == local.content &&
                item.createdAt.difference(local.createdAt).abs() <
                    const Duration(seconds: 5)),
      );
      if (!isWelcome && !exists) base.add(local);
    }
    base.sort((a, b) {
      final timeCompare = a.createdAt.compareTo(b.createdAt);
      if (timeCompare != 0) return timeCompare;
      return a.sortId.compareTo(b.sortId);
    });
    return base.isEmpty ? [_welcomeMessage()] : base.take(80).toList();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? forced]) async {
    final text = (forced ?? _controller.text).trim();
    if (text.isEmpty || _isGenerating) return;

    _controller.clear();
    final userMessage = AiChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: text,
      createdAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, userMessage];
      _isGenerating = true;
    });
    AiChatCache.add(userMessage);
    _scrollSoon();

    _cancelToken = CancelToken();
    try {
      final response = await _service.send(text, cancelToken: _cancelToken);
      _activeRequestId = response.requestId;
      final savedUserMessage = response.userMessage;
      final assistant =
          response.assistantMessage ??
          AiChatMessage(
            id: _uuid.v4(),
            role: 'assistant',
            content: response.content,
            createdAt: DateTime.now(),
            metadata: response.action,
          );
      if (!mounted) return;
      setState(() {
        final updatedMessages = [..._messages];
        if (savedUserMessage != null) {
          final userIndex = updatedMessages.indexWhere(
            (item) => item.id == userMessage.id,
          );
          if (userIndex >= 0) updatedMessages[userIndex] = savedUserMessage;
        }
        _messages = [...updatedMessages, assistant];
        _isGenerating = false;
      });
      if (savedUserMessage != null) {
        AiChatCache.replaceOrUpsert(userMessage.id, savedUserMessage);
      }
      AiChatCache.upsert(assistant);
      _scrollSoon();
    } catch (e) {
      if (!mounted) return;
      final wasCancelled = e is DioException && CancelToken.isCancel(e);
      final statusCode = e is DioException ? e.response?.statusCode : null;
      final failed = AiChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: _fallbackErrorText(text, wasCancelled, statusCode),
        createdAt: DateTime.now(),
        failed: !wasCancelled,
      );
      setState(() {
        _messages = [..._messages, failed];
        _isGenerating = false;
      });
      AiChatCache.add(failed);
    }
  }

  String _fallbackErrorText(String text, bool wasCancelled, int? statusCode) {
    if (wasCancelled) {
      return RegExp(
            r'\b(the|what|which|task|deadline|priority|show|pick|delete|edit|complete)\b',
            caseSensitive: false,
          ).hasMatch(text)
          ? 'Okay, I stopped here.'
          : 'Oke, aku berhenti di sini.';
    }
    if (statusCode == 429) {
      return RegExp(
            r'\b(the|what|which|task|deadline|priority|show|pick|delete|edit|complete)\b',
            caseSensitive: false,
          ).hasMatch(text)
          ? 'Too many quick messages. Please wait a few seconds, then send it again.'
          : 'Kebanyakan pesan terlalu cepat. Tunggu beberapa detik, lalu kirim lagi ya.';
    }
    return RegExp(
          r'\b(the|what|which|task|deadline|priority|show|pick|delete|edit|complete)\b',
          caseSensitive: false,
        ).hasMatch(text)
        ? 'Sorry, I can’t answer right now. Please send it again in a moment.'
        : 'Maaf, aku belum bisa jawab sekarang. Coba kirim lagi sebentar ya.';
  }

  Future<void> _stop() async {
    final requestId = _activeRequestId;
    _cancelToken?.cancel('Stopped by user');
    if (requestId != null) {
      await _service.cancel(requestId).catchError((_) {});
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    final shouldShow = distanceFromBottom > 180;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _jumpToBottomAfterLayout({required int remainingFrames}) {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    if (remainingFrames <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToBottomAfterLayout(remainingFrames: remainingFrames - 1);
    });
  }

  void _scrollSoon({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        _jumpToBottomAfterLayout(remainingFrames: 4);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isGuest) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              const Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Sorry, Please Login To Use This Feature',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                          itemCount: _messages.length + (_isGenerating ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isGenerating && index == _messages.length) {
                              return const AiTypingIndicator();
                            }
                            return _AiBubble(
                              message: _messages[index],
                              onTaskPicked: _send,
                              onRetry: _messages[index].failed && index > 0
                                  ? () => _send(_messages[index - 1].content)
                                  : null,
                            );
                          },
                        ),
                        Positioned(
                          right: 18,
                          bottom: 14,
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 180),
                            scale: _showScrollToBottom ? 1 : 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: _showScrollToBottom ? 1 : 0,
                              child: FloatingActionButton.small(
                                heroTag: 'wudi_scroll_down',
                                onPressed: _scrollSoon,
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            _buildSuggestions(),
            _buildInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      padding: const EdgeInsets.fromLTRB(4, 6, 10, 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints.tightFor(width: 38, height: 38),
            padding: EdgeInsets.zero,
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.42),
              foregroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
          ),
          const SizedBox(width: 6),
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Color(0xFFD5C4B0), // Cream yang sedikit lebih gelap
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(
                4.0,
              ), // Beri jarak agar logo pas di dalam lingkaran
              child: Image.asset(
                'assets/images/Wudi_AI_Icon.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WUDI AI Assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                    height: 1.0,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Task-focused productivity assistant',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          PopupMenuButton<_AiHeaderAction>(
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _AiHeaderAction.sessions:
                  _showSessions();
                case _AiHeaderAction.newChat:
                  _startNewSession();
              }
            },
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AiHeaderAction.sessions,
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Sessions'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AiHeaderAction.newChat,
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 19),
                    SizedBox(width: 10),
                    Text('New chat'),
                  ],
                ),
              ),
            ],
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.more_horiz_rounded,
                color: AppColors.primary,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        scrollDirection: Axis.horizontal,
        itemCount: _suggestions.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => ActionChip(
          onPressed: _isGenerating ? null : () => _send(_suggestions[index]),
          avatar: const Icon(Icons.bolt_rounded, size: 16),
          label: Text(_suggestions[index]),
          backgroundColor: AppColors.surface,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: NativeTextInput(
              controller: _controller,
              hintText: 'Ask something...',
              backgroundColor: AppColors.surface,
              borderRadius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              onSubmitted: (_) => _send(_controller.text),
              fallbackBuilder: (context) => TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask something...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _send(_controller.text),
              ),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: CircleAvatar(
              key: ValueKey(_isGenerating),
              backgroundColor: _isGenerating
                  ? AppColors.primaryDark
                  : AppColors.primary,
              child: IconButton(
                onPressed: _isGenerating ? _stop : _send,
                icon: Icon(
                  _isGenerating ? Icons.stop_rounded : Icons.send_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AiHeaderAction { sessions, newChat }

class _AiBubble extends StatelessWidget {
  final AiChatMessage message;
  final ValueChanged<String>? onTaskPicked;
  final VoidCallback? onRetry;

  const _AiBubble({required this.message, this.onTaskPicked, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.content));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied')));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(vertical: 6),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            color: isUser ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 6),
              bottomRight: Radius.circular(isUser ? 6 : 20),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FormattedAiText(text: message.content, isUser: isUser),
              if (!isUser && message.metadata != null) ...[
                const SizedBox(height: 12),
                _RichAiPayload(
                  metadata: message.metadata!,
                  onTaskPicked: onTaskPicked,
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RichAiPayload extends StatelessWidget {
  final Map<String, dynamic> metadata;
  final ValueChanged<String>? onTaskPicked;

  const _RichAiPayload({required this.metadata, this.onTaskPicked});

  @override
  Widget build(BuildContext context) {
    final kind = metadata['kind']?.toString();
    if (kind == 'summary') {
      return _SummaryChart(
        counts: (metadata['counts'] as Map?)?.cast<String, dynamic>() ?? {},
        title: 'Today summary',
        tasks: ((metadata['tasks'] as List?) ?? [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(),
      );
    }
    if (kind == 'monthly_summary') {
      return _SummaryChart(
        counts: (metadata['counts'] as Map?)?.cast<String, dynamic>() ?? {},
        priorityCounts:
            (metadata['priority_counts'] as Map?)?.cast<String, dynamic>() ??
            {},
        title: 'This month summary',
        subtitle: metadata['month']?.toString(),
        tasks: ((metadata['tasks'] as List?) ?? [])
            .whereType<Map>()
            .map((item) => item.cast<String, dynamic>())
            .toList(),
      );
    }
    if (kind == 'closest_deadline' || kind == 'priority_recommendation') {
      return _TaskInsightCard(
        title: kind == 'closest_deadline'
            ? 'Closest deadline'
            : 'Recommended priority',
        task: (metadata['task'] as Map?)?.cast<String, dynamic>() ?? {},
        icon: kind == 'closest_deadline'
            ? Icons.schedule_rounded
            : Icons.flag_rounded,
      );
    }
    if (kind == 'overdue_tasks') {
      final tasks = ((metadata['tasks'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      return _OverdueInsightCard(tasks: tasks, onTaskPicked: onTaskPicked);
    }
    if (kind == 'task_list') {
      final tasks = ((metadata['tasks'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      return _TaskListCard(
        title: 'Active tasks',
        tasks: tasks,
        icon: Icons.checklist_rounded,
      );
    }
    if (kind == 'task_candidates') {
      final tasks = ((metadata['tasks'] as List?) ?? [])
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
      return _TaskListCard(
        title: 'Pick a task',
        tasks: tasks,
        icon: Icons.touch_app_rounded,
        onTaskPicked: onTaskPicked,
      );
    }
    if (kind == 'task_updated') {
      return _TaskInsightCard(
        title: 'Updated task',
        task: (metadata['task'] as Map?)?.cast<String, dynamic>() ?? {},
        icon: Icons.edit_calendar_rounded,
      );
    }
    if (kind == 'empty_state') {
      return _MiniInfoCard(
        title: metadata['title']?.toString() ?? 'Nothing to show',
        icon: Icons.check_circle_outline_rounded,
      );
    }
    if (metadata['action'] == 'created_task' ||
        metadata['action'] == 'draft_task' ||
        metadata['action'] == 'cancelled_task_draft' ||
        metadata['action'] == 'deleted_task' ||
        metadata['action'] == 'completed_task' ||
        metadata['action'] == 'cancelled_task_action' ||
        metadata['action'] == 'clarify_task_edit') {
      return _MiniInfoCard(
        title: _actionTitle(metadata['action']?.toString()),
        icon: Icons.task_alt_rounded,
      );
    }

    return const SizedBox.shrink();
  }

  String _actionTitle(String? action) {
    switch (action) {
      case 'created_task':
        return 'Task saved';
      case 'draft_task':
        return 'Task draft is ready';
      case 'cancelled_task_draft':
        return 'Draft cancelled';
      case 'deleted_task':
        return 'Task deleted';
      case 'completed_task':
        return 'Task completed';
      case 'cancelled_task_action':
        return 'Action cancelled';
      case 'clarify_task_edit':
        return 'What should change?';
      default:
        return 'WUDI action';
    }
  }
}

class _AiSessionSheet extends StatelessWidget {
  final List<AiConversationSummary> conversations;
  final int? currentConversationId;
  final VoidCallback onNewSession;
  final ValueChanged<AiConversationSummary> onOpenSession;

  const _AiSessionSheet({
    required this.conversations,
    required this.currentConversationId,
    required this.onNewSession,
    required this.onOpenSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'WUDI AI sessions',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onNewSession,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (conversations.isNotEmpty) ...[
              const Text(
                'Past sessions are securely saved. WUDI remembers your important context.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final conversation = conversations[index];
                    final isActive = conversation.id == currentConversationId;

                    return Material(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => onOpenSession(conversation),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(13),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.mark_chat_read_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isActive
                                          ? 'Current session'
                                          : conversation.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      conversation.preview?.trim().isNotEmpty ==
                                              true
                                          ? conversation.preview!.trim()
                                          : 'Empty session',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FormattedAiText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _FormattedAiText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    const assistantColor = Color(0xFF5D544E);
    const assistantStrongColor = Color(0xFF4B4038);
    final color = isUser ? Colors.white : assistantColor;

    if (isUser) {
      return Text(
        text,
        style: TextStyle(color: color, height: 1.4, fontSize: 14),
      );
    }

    final lines = text.split('\n');
    final children = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        if (i < lines.length - 1) children.add(const SizedBox(height: 8));
        continue;
      }

      // Handle bullet points
      if (line.startsWith('* ') ||
          line.startsWith('- ') ||
          line.startsWith('• ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "• ",
                  style: TextStyle(
                    color: assistantStrongColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: _buildRichText(
                    line.substring(2),
                    assistantColor,
                    assistantStrongColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Handle numbered lists
      else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        final match = RegExp(r'^(\d+\.)\s').firstMatch(line)!;
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${match.group(1)} ",
                  style: TextStyle(
                    color: assistantStrongColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: _buildRichText(
                    line.substring(match.end),
                    assistantColor,
                    assistantStrongColor,
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Regular paragraph
      else {
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildRichText(line, assistantColor, assistantStrongColor),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildRichText(String text, Color color, Color strongColor) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*([\s\S]*?)\*\*');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(
          TextSpan(text: _cleanAiMarkdown(text.substring(cursor, match.start))),
        );
      }
      spans.add(
        TextSpan(
          text: _cleanAiMarkdown(match.group(1) ?? ''),
          style: TextStyle(color: strongColor, fontWeight: FontWeight.w800),
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: _cleanAiMarkdown(text.substring(cursor))));
    }

    if (spans.isEmpty) {
      return SelectableText(
        _cleanAiMarkdown(text),
        style: TextStyle(color: color, height: 1.5, fontSize: 14),
      );
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(color: color, height: 1.5, fontSize: 14),
        children: spans,
      ),
    );
  }

  String _cleanAiMarkdown(String value) {
    return value
        .replaceAll('**', '')
        .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
        .replaceAllMapped(
          RegExp(r'`([^`]*)`'),
          (match) => match.group(1) ?? '',
        );
  }
}

class _SummaryChart extends StatelessWidget {
  final Map<String, dynamic> counts;
  final Map<String, dynamic> priorityCounts;
  final String title;
  final String? subtitle;
  final List<Map<String, dynamic>> tasks;

  const _SummaryChart({
    required this.counts,
    required this.title,
    this.priorityCounts = const {},
    this.subtitle,
    this.tasks = const [],
  });

  @override
  Widget build(BuildContext context) {
    final unfinished = _intValue(counts['unfinished']);
    final overdue = _intValue(counts['overdue']);
    final completed = _intValue(counts['completed']);
    final total = unfinished + overdue + completed;
    final isEmpty = total == 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (!isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$total Tasks",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (isEmpty)
            _buildEmptyState()
          else ...[
            _buildChartSection(completed, unfinished, overdue, total),
            const SizedBox(height: 20),
            _buildMetricsGrid(completed, unfinished, overdue),
            if (priorityCounts.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _buildPrioritySection(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Icon(Icons.inbox_rounded, color: AppColors.iconAccent, size: 24),
          SizedBox(height: 8),
          Text(
            'No tasks found for this period',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(int completed, int open, int late, int total) {
    final chartTotal = total.clamp(1, 999999).toDouble();
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: 100,
              width: 100,
              child: CircularProgressIndicator(
                value: completed / chartTotal,
                strokeWidth: 10,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                strokeCap: StrokeCap.round,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${((completed / chartTotal) * 100).toInt()}%",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  "Done",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(label: 'Done', color: AppColors.primary),
            const SizedBox(width: 16),
            _LegendDot(label: 'Open', color: AppColors.calendarSelected),
            const SizedBox(width: 16),
            _LegendDot(label: 'Late', color: AppColors.errorText),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricsGrid(int completed, int open, int late) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Completed',
            value: completed,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Pending',
            value: open,
            color: AppColors.calendarSelected,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Overdue',
            value: late,
            color: AppColors.errorText,
          ),
        ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    final high = _intValue(priorityCounts['high']);
    final medium = _intValue(priorityCounts['medium']);
    final low = _intValue(priorityCounts['low']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "By Priority",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _PriorityPill(
              label: 'High',
              value: high,
              color: TaskPriorityVisuals.highColor,
            ),
            const SizedBox(width: 6),
            _PriorityPill(
              label: 'Med',
              value: medium,
              color: TaskPriorityVisuals.mediumColor,
            ),
            const SizedBox(width: 6),
            _PriorityPill(
              label: 'Low',
              value: low,
              color: TaskPriorityVisuals.lowColor,
            ),
          ],
        ),
      ],
    );
  }

  int _intValue(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _PriorityPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              "$label: $value",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarSegment extends StatelessWidget {
  final double value;
  final Color color;

  const _BarSegment({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Expanded(
      flex: (value * 100).round().clamp(1, 100),
      child: Container(height: 10, color: color),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TaskInsightCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> task;
  final IconData icon;

  const _TaskInsightCard({
    required this.title,
    required this.task,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final taskTitle = task['title']?.toString() ?? 'Untitled task';
    final priority = task['priority']?.toString() ?? 'medium';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              _PriorityBadge(priority: priority),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.06),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        taskTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          height: 1.2,
                        ),
                      ),
                      if (task['deadline'] != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.alarm_rounded,
                              size: 13,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task['deadline'].toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> tasks;
  final IconData icon;
  final ValueChanged<String>? onTaskPicked;

  const _TaskListCard({
    required this.title,
    required this.tasks,
    required this.icon,
    this.onTaskPicked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              if (tasks.length > 5)
                Text(
                  "Showing 5",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary.withValues(alpha: 0.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (final entry in tasks.take(5).indexed)
            _CompactTaskRow(
              task: entry.$2,
              pickLabel: 'number ${entry.$1 + 1}',
              onTaskPicked: onTaskPicked,
            ),
        ],
      ),
    );
  }
}

class _OverdueInsightCard extends StatelessWidget {
  final List<Map<String, dynamic>> tasks;
  final ValueChanged<String>? onTaskPicked;

  const _OverdueInsightCard({required this.tasks, this.onTaskPicked});

  @override
  Widget build(BuildContext context) {
    final high = tasks.where((task) => task['priority'] == 'high').length;
    final medium = tasks.where((task) => task['priority'] == 'medium').length;
    final low = tasks.where((task) => task['priority'] == 'low').length;
    final total = tasks.length;
    final urgent = total == 0 ? 0 : high;
    final riskLabel = total == 0
        ? 'Clear'
        : urgent > 0
        ? 'High risk'
        : 'Needs attention';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.errorText.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.errorText.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.errorText.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: AppColors.errorText,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Overdue tasks',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      '$total late • $riskLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$total',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.errorText,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                _PriorityBarSegment(
                  value: total == 0 ? 0 : high / total,
                  color: TaskPriorityVisuals.highColor,
                ),
                _PriorityBarSegment(
                  value: total == 0 ? 0 : medium / total,
                  color: TaskPriorityVisuals.mediumColor,
                ),
                _PriorityBarSegment(
                  value: total == 0 ? 0 : low / total,
                  color: TaskPriorityVisuals.lowColor,
                ),
                if (total == 0)
                  Expanded(
                    child: Container(height: 10, color: AppColors.surface),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _PriorityMiniChip(
                label: 'High',
                value: high,
                color: TaskPriorityVisuals.highColor,
              ),
              const SizedBox(width: 8),
              _PriorityMiniChip(
                label: 'Med',
                value: medium,
                color: TaskPriorityVisuals.mediumColor,
              ),
              const SizedBox(width: 8),
              _PriorityMiniChip(
                label: 'Low',
                value: low,
                color: TaskPriorityVisuals.lowColor,
              ),
            ],
          ),
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 16),
            for (final entry in tasks.take(5).indexed)
              _CompactTaskRow(
                task: entry.$2,
                pickLabel: 'number ${entry.$1 + 1}',
                onTaskPicked: onTaskPicked,
              ),
          ],
        ],
      ),
    );
  }
}

class _PriorityBarSegment extends StatelessWidget {
  final double value;
  final Color color;

  const _PriorityBarSegment({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();

    return Expanded(
      flex: (value * 100).round().clamp(1, 100),
      child: Container(height: 10, color: color),
    );
  }
}

class _PriorityMiniChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _PriorityMiniChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              '$label $value',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;
  final String? pickLabel;
  final ValueChanged<String>? onTaskPicked;

  const _CompactTaskRow({
    required this.task,
    this.pickLabel,
    this.onTaskPicked,
  });

  @override
  Widget build(BuildContext context) {
    final priority = task['priority']?.toString() ?? 'medium';
    final style = TaskPriorityVisuals.style(priority);
    final color = style.color;

    final title = task['title']?.toString() ?? 'Untitled task';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTaskPicked == null
            ? null
            : () => onTaskPicked!(pickLabel ?? title),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 32,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppColors.primary,
                        height: 1.2,
                      ),
                    ),
                    if (task['deadline'] != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        task['deadline'].toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _PriorityBadge(priority: priority),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final style = TaskPriorityVisuals.style(priority);
    final color = style.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MiniInfoCard extends StatelessWidget {
  final String title;
  final IconData icon;

  const _MiniInfoCard({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

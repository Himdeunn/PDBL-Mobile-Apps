import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../cache/ai_chat_cache.dart';
import '../models/ai_chat_message.dart';
import '../services/ai_chat_service.dart';
import '../widgets/ai_typing_indicator.dart';

class WudiAiScreen extends StatefulWidget {
  final String? initialPrompt;
  final bool loadHistory;

  const WudiAiScreen({super.key, this.initialPrompt, this.loadHistory = true});

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
    _messages = AiChatCache.messages;
    if (_messages.isEmpty) {
      _messages = [_welcomeMessage()];
    }
    if (widget.loadHistory) {
      _loadHistory();
    } else {
      _isLoadingHistory = false;
    }
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
          'Hi, aku WUDI. Aku bisa bantu cek deadline terdekat, overdue tasks, rangkum tugas hari ini, atau susun prioritasmu.',
      createdAt: DateTime.now(),
    );
  }

  Future<void> _loadHistory() async {
    try {
      final history = await _service.history();
      if (!mounted) return;
      setState(() {
        _messages = history.isEmpty ? [_welcomeMessage()] : history;
        _isLoadingHistory = false;
      });
      _scrollSoon();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
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
      final assistant = AiChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: response.content,
        createdAt: DateTime.now(),
        metadata: response.action,
      );
      if (!mounted) return;
      setState(() {
        _messages = [..._messages, assistant];
        _isGenerating = false;
      });
      AiChatCache.add(assistant);
      _scrollSoon();
    } catch (e) {
      if (!mounted) return;
      final wasCancelled = e is DioException && CancelToken.isCancel(e);
      final failed = AiChatMessage(
        id: _uuid.v4(),
        role: 'assistant',
        content: wasCancelled
            ? 'Oke, aku berhenti di sini.'
            : 'Maaf, aku belum bisa jawab sekarang. Coba kirim lagi sebentar ya.',
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

  Future<void> _stop() async {
    final requestId = _activeRequestId;
    _cancelToken?.cancel('Stopped by user');
    if (requestId != null) {
      await _service.cancel(requestId).catchError((_) {});
    }
    if (mounted) setState(() => _isGenerating = false);
  }

  void _scrollSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      itemCount: _messages.length + (_isGenerating ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isGenerating && index == _messages.length) {
                          return const AiTypingIndicator();
                        }
                        return _AiBubble(
                          message: _messages[index],
                          onRetry: _messages[index].failed && index > 0
                              ? () => _send(_messages[index - 1].content)
                              : null,
                        );
                      },
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
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.calendarSelected],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 20,
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
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.08),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 12, color: AppColors.primary),
                SizedBox(width: 3),
                Text(
                  'Private',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 4,
              enabled: !_isGenerating,
              decoration: InputDecoration(
                hintText: 'Ask about tasks or deadlines',
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

class _HeaderPill extends StatelessWidget {
  final String label;

  const _HeaderPill(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final AiChatMessage message;
  final VoidCallback? onRetry;

  const _AiBubble({required this.message, this.onRetry});

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
                _RichAiPayload(metadata: message.metadata!),
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

  const _RichAiPayload({required this.metadata});

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
      return _TaskListCard(
        title: 'Overdue tasks',
        tasks: tasks,
        icon: Icons.warning_amber_rounded,
      );
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

class _FormattedAiText extends StatelessWidget {
  final String text;
  final bool isUser;

  const _FormattedAiText({required this.text, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final color = isUser ? Colors.white : AppColors.textPrimary;
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    var cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: isUser ? Colors.white : AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(color: color, height: 1.45, fontSize: 14),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
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
    final total = _intValue(
      counts['total'],
    ).clamp(unfinished + completed, 9999);
    final chartTotal = total.clamp(1, 9999);
    final high = _intValue(priorityCounts['high']);
    final medium = _intValue(priorityCounts['medium']);
    final low = _intValue(priorityCounts['low']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.78),
            AppColors.surface.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.11)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
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
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Row(
              children: [
                _BarSegment(
                  value: completed / chartTotal,
                  color: AppColors.primary,
                ),
                _BarSegment(
                  value: unfinished / chartTotal,
                  color: AppColors.calendarSelected,
                ),
                _BarSegment(
                  value: overdue / chartTotal,
                  color: AppColors.errorText,
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const Row(
            children: [
              _LegendDot(label: 'Done', color: AppColors.primary),
              SizedBox(width: 10),
              _LegendDot(label: 'Open', color: AppColors.calendarSelected),
              SizedBox(width: 10),
              _LegendDot(label: 'Late', color: AppColors.errorText),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricPill(
                label: 'Done',
                value: completed,
                color: AppColors.primary,
              ),
              _MetricPill(
                label: 'Open',
                value: unfinished,
                color: AppColors.calendarSelected,
              ),
              _MetricPill(
                label: 'Overdue',
                value: overdue,
                color: AppColors.errorText,
              ),
            ],
          ),
          if (priorityCounts.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricPill(
                  label: 'High',
                  value: high,
                  color: AppColors.errorText,
                ),
                _MetricPill(
                  label: 'Medium',
                  value: medium,
                  color: AppColors.calendarSelected,
                ),
                _MetricPill(
                  label: 'Low',
                  value: low,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ],
          if (tasks.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final task in tasks.take(4)) _CompactTaskRow(task: task),
          ],
        ],
      ),
    );
  }

  int _intValue(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
}

class _BarSegment extends StatelessWidget {
  final double value;
  final Color color;

  const _BarSegment({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task['title']?.toString() ?? 'Untitled task',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (task['deadline'] != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    task['deadline'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          _PriorityBadge(priority: task['priority']?.toString() ?? 'medium'),
        ],
      ),
    );
  }
}

class _TaskListCard extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> tasks;
  final IconData icon;

  const _TaskListCard({
    required this.title,
    required this.tasks,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.09)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 17, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final task in tasks.take(5)) _CompactTaskRow(task: task),
        ],
      ),
    );
  }
}

class _CompactTaskRow extends StatelessWidget {
  final Map<String, dynamic> task;

  const _CompactTaskRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final priority = task['priority']?.toString() ?? 'medium';
    final color = priority == 'high'
        ? AppColors.errorText
        : priority == 'low'
        ? AppColors.textSecondary
        : AppColors.calendarSelected;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.11)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title']?.toString() ?? 'Untitled task',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    height: 1.25,
                  ),
                ),
                if (task['deadline'] != null)
                  Text(
                    task['deadline'].toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PriorityBadge(priority: priority),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;

  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = priority == 'high'
        ? AppColors.errorText
        : priority == 'low'
        ? AppColors.textSecondary
        : AppColors.calendarSelected;
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

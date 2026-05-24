part of 'chat_room_page.dart';

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
      decoration: BoxDecoration(
        color: const Color(0xFFD6C5B0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: avatarUrl != null
            ? CachedNetworkImage(
                imageUrl: avatarUrl,
                fit: BoxFit.cover,
                cacheManager: WudiCacheManager(),
                errorWidget: (context, url, error) => Icon(
                  conversation.type == 'team'
                      ? Icons.palette_rounded
                      : Icons.person_rounded,
                  color: AppColors.primaryDark,
                ),
              )
            : Icon(
                conversation.type == 'team'
                    ? Icons.palette_rounded
                    : Icons.person_rounded,
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

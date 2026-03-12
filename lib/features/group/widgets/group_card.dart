import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class GroupCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final double progress; // 0.0 to 1.0
  final int memberCount;
  final List<String> memberAvatars;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const GroupCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    this.iconBgColor = const Color(0xFFE0E7FF),
    this.iconColor = const Color(0xFF6366F1),
    required this.progress,
    this.memberCount = 0,
    this.memberAvatars = const [],
    this.onTap,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE5DDD5).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onMoreTap,
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildAvatarStack(),
                const Spacer(),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primaryDark,
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarStack() {
    int displayCount = memberCount > 3 ? 3 : memberCount;
    int extraCount = memberCount > 3 ? memberCount - 3 : 0;

    return SizedBox(
      height: 32,
      width:
          32.0 +
          (displayCount > 0 ? (displayCount - 1) * 20 : 0) +
          (extraCount > 0 ? 32 : 0),
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 20.0,
              child: _AvatarItem(
                index: i,
                color: i == 0
                    ? Colors.orange.shade200
                    : i == 1
                    ? Colors.blue.shade200
                    : Colors.teal.shade200,
              ),
            ),
          if (extraCount > 0)
            Positioned(
              left: displayCount * 20.0,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE5DDD5), width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$extraCount',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarItem extends StatelessWidget {
  final int index;
  final Color color;

  const _AvatarItem({required this.index, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5DDD5), width: 2),
      ),
      child: const Icon(Icons.person, size: 16, color: Colors.white),
    );
  }
}

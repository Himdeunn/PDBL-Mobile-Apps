import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/utils/network_utils.dart';
import '../../../../core/utils/image_cache_manager.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final bool isLoading;
  final bool isGuest;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;
  final int todayTarget;

  const HomeHeader({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.isLoading = false,
    this.isGuest = false,
    this.onNotificationTap,
    this.onProfileTap,
    this.todayTarget = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $displayName!',
                style: TextStyle(
                  fontSize: MediaQuery.of(context).size.width > 400 ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              Text(
                todayTarget > 0
                    ? 'Your goal today: $todayTarget tasks'
                    : 'Let\'s make today a productive day.',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textTertiary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textPrimary,
            size: 28,
          ),
          onPressed: onNotificationTap,
        ),
        const SizedBox(width: 4),
        // Avatar Profile
        GestureDetector(
          onTap: onProfileTap,
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surface,
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: avatarUrl!,
                      fit: BoxFit.cover,
                      cacheManager: WudiCacheManager(),
                      httpHeaders: getNetworkImageHeaders(avatarUrl!),
                      errorWidget: (_, __, ___) =>
                          const Icon(Icons.person, color: AppColors.primary),
                    )
                  : const Icon(Icons.person, color: AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }
}

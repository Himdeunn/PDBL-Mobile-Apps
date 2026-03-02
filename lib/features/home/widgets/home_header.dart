import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;
  final bool isLoading;
  final VoidCallback? onAvatarTap;

  const HomeHeader({
    super.key,
    required this.displayName,
    this.isLoading = false,
    this.onAvatarTap,
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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              const SizedBox(height: 4),
              const Text(
                'Mari kita manfaatkan hari ini dengan produktif.',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            offset: const Offset(0, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.white,
            onSelected: (value) {
              // Handle menu selection
              if (value == 'profile') {
                onAvatarTap?.call();
              } else if (value == 'notifications') {
                // TODO: Navigate to notifications
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline, color: AppColors.textPrimary),
                  title: Text(
                    'Edit Profile',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'notifications',
                child: ListTile(
                  leading: Icon(
                    Icons.notifications_none,
                    color: AppColors.textPrimary,
                  ),
                  title: Text(
                    'Notifications',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 24,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

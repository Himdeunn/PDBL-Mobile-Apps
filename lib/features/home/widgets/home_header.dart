import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String displayName;
  final bool isLoading;
  final bool isGuest;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onLogoutTap;
  final VoidCallback? onLoginTap;
  final VoidCallback? onRegisterTap;

  const HomeHeader({
    super.key,
    required this.displayName,
    this.isLoading = false,
    this.isGuest = false,
    this.onAvatarTap,
    this.onLogoutTap,
    this.onLoginTap,
    this.onRegisterTap,
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
                'Let\'s make today a productive day.',
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
              } else if (value == 'logout') {
                onLogoutTap?.call();
              } else if (value == 'login') {
                onLoginTap?.call();
              } else if (value == 'register') {
                onRegisterTap?.call();
              }
            },
            itemBuilder: (BuildContext context) {
              if (isGuest) {
                return <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'login',
                    child: ListTile(
                      leading: Icon(Icons.login, color: AppColors.primary),
                      title: Text(
                        'Login',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'register',
                    child: ListTile(
                      leading: Icon(
                        Icons.person_add_outlined,
                        color: AppColors.textPrimary,
                      ),
                      title: Text(
                        'Register',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ];
              }

              return <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: Icon(
                      Icons.person_outline,
                      color: AppColors.textPrimary,
                    ),
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
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout, color: AppColors.errorText),
                    title: Text(
                      'Logout',
                      style: TextStyle(color: AppColors.errorText),
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ];
            },
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

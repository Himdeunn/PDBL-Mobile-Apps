import '../../../../core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import '../../auth/services/auth_service.dart';
import '../../../../core/models/user.dart';
import '../../auth/pages/welcome_page.dart';

class ProfilePage extends StatefulWidget {
  final AuthService authService;

  const ProfilePage({super.key, required this.authService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await widget.authService.getCurrentUser();
    if (mounted) setState(() => _user = user);
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    await widget.authService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'User';
    final email = _user?.email ?? '';
    final isGuest = _user?.isGuest ?? false;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(color: AppColors.primary, width: 2.5),
              ),
              child: const Icon(
                Icons.person,
                color: AppColors.primary,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isGuest ? 'Guest Mode' : email,
              style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 32),
            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: _loggingOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout, size: 20),
                label: Text(_loggingOut ? 'Logging out...' : 'Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

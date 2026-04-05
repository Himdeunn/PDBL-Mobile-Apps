import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/profile_service.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/pages/welcome_page.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/services/connection_service.dart';


class ProfilePage extends StatefulWidget {
  final AuthService authService;

  const ProfilePage({super.key, required this.authService});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final ProfileService _profileService;
  final ImagePicker _picker = ImagePicker();
  User? _user;
  bool _loggingOut = false;
  bool _updatingAvatar = false;
  DateTime? _lastProfileUpdate;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(authService: widget.authService);
    _loadUser();
  }

  Future<void> _loadUser() async {
    // 1. Get cached user first for immediate display
    final cachedUser = await widget.authService.getCachedUser();
    if (mounted && cachedUser != null) {
      setState(() => _user = cachedUser);
    }

    // 2. Perform regular refresh (now faster due to AuthService caching)
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

  Future<void> _pickAndUploadImage() async {
    try {
      // Check network connection
      if (!await ConnectionService().isConnected()) {
        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (image == null) return;

      // Check file size (1MB = 1 * 1024 * 1024 bytes)
      final File file = File(image.path);
      final int sizeInBytes = await file.length();
      if (sizeInBytes > 1 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image size must be less than 1MB')),
        );
        return;
      }

      setState(() => _updatingAvatar = true);
      await _profileService.updateAvatar(image.path);
      await _loadUser();

      if (!mounted) return;
      ErrorHandler.showSuccessPopup('Profile picture updated successfully');
    } catch (e) {
      // Error handled by ProfileService
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  void _showChangeNameDialog() {
    final nameController = TextEditingController(text: _user?.name);
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Edit Profile Name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (nameController.text.trim().isEmpty) return;
                      
                      // Rate limit check (10 seconds)
                      if (_lastProfileUpdate != null && 
                          DateTime.now().difference(_lastProfileUpdate!).inSeconds < 10) {
                        ErrorHandler.showErrorPopup('Please wait a moment before updating again');
                        return;
                      }

                      // Check network connection
                      if (!await ConnectionService().isConnected()) {
                        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
                        return;
                      }

                      setDialogState(() => loading = true);
                      try {
                        await _profileService.updateProfile(
                          name: nameController.text.trim(),
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _lastProfileUpdate = DateTime.now();
                        _loadUser();
                        ErrorHandler.showSuccessPopup(
                            'Profile updated successfully');
                      } catch (e) {
                        setDialogState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Change Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
              ),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password'),
              ),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm New Password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      // Client-side validation
                      if (currentPasswordController.text.isEmpty) {
                        ErrorHandler.showErrorPopup('Current password is required');
                        return;
                      }
                      if (newPasswordController.text.length < 6) {
                        ErrorHandler.showErrorPopup('New password must be at least 6 characters');
                        return;
                      }
                      if (newPasswordController.text != confirmPasswordController.text) {
                        ErrorHandler.showErrorPopup('New passwords do not match');
                        return;
                      }
                      if (currentPasswordController.text == newPasswordController.text) {
                        ErrorHandler.showErrorPopup('New password must be different from current');
                        return;
                      }
                      // Check network connection
                      if (!await ConnectionService().isConnected()) {
                        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
                        return;
                      }

                      setDialogState(() => loading = true);
                      try {
                        await _profileService.updatePassword(
                          currentPassword: currentPasswordController.text,
                          newPassword: newPasswordController.text,
                          newPasswordConfirmation:
                              confirmPasswordController.text,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadUser();
                        ErrorHandler.showSuccessPopup('Password updated successfully');
                      } catch (e) {
                        setDialogState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final emailController = TextEditingController(text: _user?.email);
    final passwordController = TextEditingController();
    bool loading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Change Email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'New Email'),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Current Password',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
                        ErrorHandler.showErrorPopup('Please enter a valid email address');
                        return;
                      }
                      if (passwordController.text.isEmpty) {
                        ErrorHandler.showErrorPopup('Current password is required');
                        return;
                      }
                      // Check network connection
                      if (!await ConnectionService().isConnected()) {
                        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
                        return;
                      }

                      setDialogState(() => loading = true);
                      try {
                        await _profileService.updateEmail(
                          email: email,
                          currentPassword: passwordController.text,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadUser();
                        ErrorHandler.showSuccessPopup('Email updated successfully');
                      } catch (e) {
                        setDialogState(() => loading = false);
                      }
                    },
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'User';
    final email = _user?.email ?? '';
    final isGuest = _user?.isGuest ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Avatar
            Stack(
              children: [
                GestureDetector(
                  onTap: _updatingAvatar ? null : _pickAndUploadImage,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.primary, width: 2.5),
                    ),
                    child: _updatingAvatar
                        ? const Center(child: CircularProgressIndicator())
                        : _user?.avatarUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  _user!.avatarUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const Icon(
                                    Icons.person,
                                    color: AppColors.primary,
                                    size: 50,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.person,
                                color: AppColors.primary,
                                size: 50,
                              ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
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
            if (!isGuest) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Account Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildSettingTile(
                icon: Icons.person_outline,
                title: 'Change Name',
                onTap: _showChangeNameDialog,
              ),
              _buildSettingTile(
                icon: Icons.lock_outline,
                title: 'Change Password',
                onTap: _showChangePasswordDialog,
              ),
              _buildSettingTile(
                icon: Icons.email_outlined,
                title: 'Change Email',
                onTap: _showChangeEmailDialog,
              ),

              const SizedBox(height: 24),
            ],
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
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

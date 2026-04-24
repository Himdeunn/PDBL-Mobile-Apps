import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/image_cache_manager.dart';
import '../../../core/utils/network_utils.dart';
import 'notification_settings_page.dart';
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
import '../../../core/storage/secure_storage.dart';

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
  int _refreshNonce = DateTime.now().millisecondsSinceEpoch;
  bool? _isGoogleUser;
  bool _loggingOut = false;
  bool _updatingAvatar = false;
  bool _isPickingImage = false;
  DateTime? _lastProfileUpdate;
  String? _authToken;
  File? _localImageFile;

  @override
  void initState() {
    super.initState();
    _profileService = ProfileService(authService: widget.authService);
    _user = widget.authService.currentCachedUser;
    if (_user?.googleId != null) _isGoogleUser = true;
    _loadUser();
  }

  Future<void> _loadUser() async {
    if (!mounted) return;
    try {
      final user = await widget.authService.getCurrentUser(forceRefresh: true);
      final token = await SecureStorage.getToken();
      
      if (mounted && user != null) {
        setState(() {
          _user = user;
          _authToken = token;
          _refreshNonce = DateTime.now().millisecondsSinceEpoch;
          if (user.googleId != null) _isGoogleUser = true;
        });
      }
    } catch (e) {
      final cachedUser = await widget.authService.getCachedUser();
      if (mounted && cachedUser != null) {
        setState(() {
          _user = cachedUser;
          if (cachedUser.googleId != null) _isGoogleUser = true;
        });
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
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

  Future<void> _showImageSourcePicker() async {
    if (_isPickingImage) return;
    if (!await ConnectionService().isConnected()) {
      if (!mounted) return;
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }

    if (!mounted) return;
    setState(() => _isPickingImage = true);

    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Change Profile Photo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE9FE), child: Icon(Icons.camera_alt, color: AppColors.primary)),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFEDE9FE), child: Icon(Icons.photo_library, color: AppColors.primary)),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (source == null || !mounted) return;
      await _pickAndUploadImage(source);
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: source == ImageSource.camera ? 80 : null,
      );

      if (image == null) return;

      final File file = File(image.path);
      final int sizeInBytes = await file.length();
      final bool isGif = image.path.toLowerCase().endsWith('.gif');
      final int maxSize = isGif ? 2 * 1024 * 1024 : 1 * 1024 * 1024;

      if (sizeInBytes > maxSize) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File too large')));
        return;
      }

      if (mounted) setState(() {
        _localImageFile = file;
        _updatingAvatar = true;
      });

      final String? oldUrl = _user?.avatarUrl;
      await _profileService.updateAvatar(image.path, oldAvatarUrl: oldUrl);

      if (oldUrl != null) {
        await WudiCacheManager().removeFile(oldUrl);
        PaintingBinding.instance.imageCache.evict(
          CachedNetworkImageProvider(oldUrl, cacheManager: WudiCacheManager()),
        );
      }

      await _loadUser();

      if (!mounted) return;
      ErrorHandler.showSuccessPopup('Profile picture updated successfully');
    } catch (e) {
      if (mounted) setState(() => _localImageFile = null);
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
              TextField(controller: nameController, maxLength: 50, decoration: const InputDecoration(labelText: 'Full Name')),
              ElevatedButton(
                onPressed: loading ? null : () async {
                  if (nameController.text.trim().isEmpty) return;
                  if (_lastProfileUpdate != null && DateTime.now().difference(_lastProfileUpdate!).inSeconds < 10) {
                    ErrorHandler.showErrorPopup('Please wait a moment');
                    return;
                  }
                  if (!await ConnectionService().isConnected()) {
                    ErrorHandler.showErrorPopup('No connection');
                    return;
                  }
                  setDialogState(() => loading = true);
                  try {
                    await _profileService.updateProfile(name: nameController.text.trim());
                    if (!context.mounted) return;
                    Navigator.pop(context);
                    _lastProfileUpdate = DateTime.now();
                    _loadUser();
                    ErrorHandler.showSuccessPopup('Profile updated');
                  } catch (e) {
                    setDialogState(() => loading = false);
                  }
                },
                child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final curP = TextEditingController();
    final newP = TextEditingController();
    final conP = TextEditingController();
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
              TextField(controller: curP, obscureText: true, decoration: const InputDecoration(labelText: 'Current Password')),
              TextField(controller: newP, obscureText: true, decoration: const InputDecoration(labelText: 'New Password')),
              TextField(controller: conP, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm New Password')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (curP.text.isEmpty || newP.text.length < 6 || newP.text != conP.text) {
                  ErrorHandler.showErrorPopup('Invalid input');
                  return;
                }
                setDialogState(() => loading = true);
                try {
                  await _profileService.updatePassword(currentPassword: curP.text, newPassword: newP.text, newPasswordConfirmation: conP.text);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadUser();
                  ErrorHandler.showSuccessPopup('Password updated');
                } catch (e) {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final emailC = TextEditingController(text: _user?.email);
    final passC = TextEditingController();
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
              TextField(controller: emailC, decoration: const InputDecoration(labelText: 'New Email')),
              TextField(controller: passC, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  await _profileService.updateEmail(email: emailC.text.trim(), currentPassword: passC.text);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  _loadUser();
                  ErrorHandler.showSuccessPopup('Email updated');
                } catch (e) {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingTile({required IconData icon, required String title, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.withOpacity(0.1))),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'User';
    final email = _user?.email ?? '';
    final isGuest = _user?.isGuest ?? false;
    final isGoogleUser = _isGoogleUser == true;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: AppColors.textPrimary),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadUser,
          color: AppColors.primary,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _updatingAvatar ? null : _showImageSourcePicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.surface, border: Border.all(color: AppColors.primary, width: 2.5)),
                        child: (_updatingAvatar && _localImageFile == null)
                          ? const Center(child: CircularProgressIndicator())
                          : _user?.avatarUrl != null
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  key: ValueKey('${_user!.avatarUrl}_$_refreshNonce'),
                                  imageUrl: _user!.avatarUrl!,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  cacheManager: WudiCacheManager(),
                                  httpHeaders: getNetworkImageHeaders(_user!.avatarUrl!),
                                  imageBuilder: (context, imageProvider) {
                                    if (_localImageFile != null) {
                                      WidgetsBinding.instance.addPostFrameCallback((_) {
                                        if (mounted && _localImageFile != null) setState(() => _localImageFile = null);
                                      });
                                    }
                                    return Image(image: imageProvider, width: 100, height: 100, fit: BoxFit.cover);
                                  },
                                  placeholder: (context, url) => _localImageFile != null
                                    ? Image.file(_localImageFile!, width: 100, height: 100, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Center(child: CircularProgressIndicator()))
                                    : const Center(child: CircularProgressIndicator()),
                                  errorWidget: (context, url, error) => _localImageFile != null
                                    ? Image.file(_localImageFile!, width: 100, height: 100, fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.primary, size: 50))
                                    : const Icon(Icons.person, color: AppColors.primary, size: 50),
                                ),
                              )
                            : _localImageFile != null
                              ? ClipOval(
                                  child: Image.file(_localImageFile!, width: 100, height: 100, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppColors.primary, size: 50)),
                                )
                              : const Icon(Icons.person, color: AppColors.primary, size: 50),
                      ),
                      Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20))),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Tips: Image max 1MB, GIF max 2MB', style: TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(height: 12),
                Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(isGuest ? 'Guest Mode' : email, style: const TextStyle(fontSize: 14, color: AppColors.textTertiary)),
                const SizedBox(height: 32),
                if (!isGuest) ...[
                  const Align(alignment: Alignment.centerLeft, child: Text('Account Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                  const SizedBox(height: 16),
                  _buildSettingTile(icon: Icons.person_outline, title: 'Change Name', onTap: _showChangeNameDialog),
                  if (!isGoogleUser) ...[
                    _buildSettingTile(icon: Icons.lock_outline, title: 'Change Password', onTap: _showChangePasswordDialog),
                    _buildSettingTile(icon: Icons.email_outlined, title: 'Change Email', onTap: _showChangeEmailDialog),
                  ],
                  _buildSettingTile(icon: Icons.notifications_none_outlined, title: 'Notification Settings', onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsPage()));
                  }),
                  const SizedBox(height: 24),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: _loggingOut ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.logout, size: 20),
                    label: Text(_loggingOut ? 'Logging out...' : 'Logout'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

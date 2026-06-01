import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/network_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/image_cache_manager.dart';
import 'notification_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import '../services/profile_service.dart';
import '../../../core/models/user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/native_text_input.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/pages/welcome_page.dart';
import '../../task/pages/task_page.dart';
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
  static const int _maxImageBytes = 1 * 1024 * 1024;
  static const int _maxGifBytes = 2 * 1024 * 1024;
  static const int _profileImageLongestSide = 1080;

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
  String? _avatarStatusText;
  bool _localPreviewIsGif = false;
  String? _avatarCacheBuster;

  String _cacheBustedAvatarUrl(String url) {
    final separator = url.contains('?') ? '&' : '?';
    if (_avatarCacheBuster == null) return url;
    return '$url${separator}v=$_avatarCacheBuster';
  }

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
      final cachedUser = await widget.authService.getCachedUser();
      if (mounted && cachedUser != null) {
        setState(() {
          _user = cachedUser;
          _authToken = null;
          if (cachedUser.googleId != null) _isGoogleUser = true;
        });
      }

      final token = await SecureStorage.getToken();

      if (mounted) {
        setState(() {
          _authToken = token;
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text(
              'Yes, Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

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
    if (_user?.isGuest == true) return;
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
              const Text(
                'Change Profile Photo',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE9FE),
                  child: Icon(Icons.camera_alt, color: AppColors.primary),
                ),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEDE9FE),
                  child: Icon(Icons.photo_library, color: AppColors.primary),
                ),
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
      final isCamera = source == ImageSource.camera;
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: isCamera ? 65 : null,
        maxWidth: isCamera ? _profileImageLongestSide.toDouble() : null,
        maxHeight: isCamera ? _profileImageLongestSide.toDouble() : null,
      );

      if (image == null) return;

      File file = File(image.path);
      bool isGif = image.path.toLowerCase().endsWith('.gif');

      if (!isGif) {
        try {
          final raf = await file.open();
          final bytes = await raf.read(3);
          await raf.close();
          if (bytes.length >= 3 &&
              bytes[0] == 0x47 &&
              bytes[1] == 0x49 &&
              bytes[2] == 0x46) {
            isGif = true;
          }
        } catch (_) {}
      }

      if (isGif && !file.path.toLowerCase().endsWith('.gif')) {
        final newPath = '${file.path}.gif';
        file = await file.copy(newPath);
      }

      if (mounted) {
        setState(() => _avatarStatusText = 'Compressing image...');
      }

      final File uploadFile = await _compressProfileImage(file, isGif: isGif);
      final int maxSize = isGif ? _maxGifBytes : _maxImageBytes;

      if (await uploadFile.length() > maxSize) {
        if (!mounted) return;
        _showFileTooLargeError(isGif: isGif);
        return;
      }

      if (mounted) {
        setState(() {
          _localImageFile = uploadFile;
          _localPreviewIsGif = isGif;
          _updatingAvatar = true;
          _avatarStatusText = 'Loading image...';
        });
      }

      final String? oldUrl = _user?.avatarUrl;

      if (mounted) {
        setState(() => _avatarStatusText = 'Uploading image...');
      }

      final avatarUrl = await _profileService.updateAvatar(
        uploadFile.path,
        oldAvatarUrl: oldUrl,
      );

      if (mounted && avatarUrl != null) {
        setState(() {
          _user?.avatar = avatarUrl;
          _user?.avatarUrl = avatarUrl;
          _refreshNonce = DateTime.now().millisecondsSinceEpoch;
          _avatarCacheBuster = _refreshNonce.toString();
          _avatarStatusText = 'Loading image...';
        });

        final cleanUrl = ImageUtils.getAvatarUrl(avatarUrl);
        final avatarImageUrl = _cacheBustedAvatarUrl(cleanUrl);

        try {
          await precacheImage(
            CachedNetworkImageProvider(
              cleanUrl,
              cacheKey: avatarImageUrl,
              cacheManager: WudiCacheManager(),
              headers: getNetworkImageHeaders(cleanUrl),
            ),
            context,
          );

          if (mounted) {
            setState(() {
              _localImageFile = null;
              _avatarStatusText = null;
              _avatarCacheBuster = null;
            });
          }
        } catch (_) {
          // Keep the local preview visible if the remote image has not loaded yet.
        }
      }

      if (!mounted) return;
      ErrorHandler.showSuccessPopup('Profile picture updated successfully');
    } catch (e) {
      if (mounted) {
        setState(() {
          _localImageFile = null;
          _localPreviewIsGif = false;
          _avatarStatusText = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _updatingAvatar = false;
          if (_localImageFile == null) {
            _avatarStatusText = null;
          }
        });
      }
    }
  }

  void _showFileTooLargeError({required bool isGif}) {
    ErrorHandler.showErrorPopup(
      isGif
          ? 'The GIF is too large. Please choose a smaller file.'
          : 'The file is too large. Please use a smaller image.',
      title: 'File Too Large',
    );
  }

  Future<File> _compressProfileImage(
    File sourceFile, {
    required bool isGif,
  }) async {
    final originalBytes = Uint8List.fromList(await sourceFile.readAsBytes());
    if (originalBytes.length <= (isGif ? _maxGifBytes : _maxImageBytes)) {
      return sourceFile;
    }

    if (isGif) {
      return sourceFile;
    }

    return await _compressRasterImage(sourceFile, originalBytes) ?? sourceFile;
  }

  Future<File?> _compressRasterImage(File sourceFile, Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return null;

    final int longestSide = math.max(decoded.width, decoded.height);
    final double scale = longestSide > _profileImageLongestSide
        ? _profileImageLongestSide / longestSide
        : 1.0;
    final resized = scale < 1.0
        ? img.copyResize(
            decoded,
            width: (decoded.width * scale).round(),
            height: (decoded.height * scale).round(),
          )
        : decoded;

    var quality = 82;
    List<int> encoded = img.encodeJpg(resized, quality: quality);

    while (encoded.length > _maxImageBytes && quality > 38) {
      quality -= 7;
      encoded = img.encodeJpg(resized, quality: quality);
    }

    if (encoded.length > _maxImageBytes) {
      return null;
    }

    final output = File(
      '${sourceFile.parent.path}/profile_upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await output.writeAsBytes(encoded, flush: true);
    return output;
  }

  void _showChangeNameDialog() {
    if (_user?.isGuest == true) return;
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
              NativeTextInput(
                controller: nameController,
                maxLength: 50,
                hintText: 'Full Name',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: nameController,
                  maxLength: 50,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF2E2A36),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: loading
                        ? null
                        : () async {
                            if (nameController.text.trim().isEmpty) {
                              ErrorHandler.showErrorPopup('Name cannot be empty');
                              return;
                            }
                            if (_lastProfileUpdate != null &&
                                DateTime.now()
                                        .difference(_lastProfileUpdate!)
                                        .inSeconds <
                                    10) {
                              ErrorHandler.showErrorPopup(
                                'Please wait a moment',
                              );
                              return;
                            }
                            if (!await ConnectionService().isConnected()) {
                              ErrorHandler.showErrorPopup('No connection');
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
                              ErrorHandler.showSuccessPopup('Profile updated');
                            } catch (e) {
                              setDialogState(() => loading = false);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E2A36),
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    if (_user?.isGuest == true) return;
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
              NativeTextInput(
                controller: curP,
                obscureText: true,
                hintText: 'Current Password',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: curP,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NativeTextInput(
                controller: newP,
                obscureText: true,
                hintText: 'New Password',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: newP,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NativeTextInput(
                controller: conP,
                obscureText: true,
                hintText: 'Confirm New Password',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: conP,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF2E2A36),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (curP.text.isEmpty) {
                        ErrorHandler.showErrorPopup('Current password cannot be empty');
                        return;
                      }
                      if (newP.text.isEmpty) {
                        ErrorHandler.showErrorPopup('New password cannot be empty');
                        return;
                      }
                      if (newP.text.length < 6) {
                        ErrorHandler.showErrorPopup('New password must be at least 6 characters');
                        return;
                      }
                      if (newP.text != conP.text) {
                        ErrorHandler.showErrorPopup('Passwords do not match');
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        await _profileService.updatePassword(
                          currentPassword: curP.text,
                          newPassword: newP.text,
                          newPasswordConfirmation: conP.text,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadUser();
                        ErrorHandler.showSuccessPopup('Password updated');
                      } catch (e) {
                        setDialogState(() => loading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2A36),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeEmailDialog() {
    if (_user?.isGuest == true) return;
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
              NativeTextInput(
                controller: emailC,
                keyboardType: TextInputType.emailAddress,
                hintText: 'New Email',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: emailC,
                  decoration: const InputDecoration(
                    labelText: 'New Email',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              NativeTextInput(
                controller: passC,
                obscureText: true,
                hintText: 'Password',
                showUnderline: true,
                fallbackBuilder: (context) => TextField(
                  controller: passC,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF2E2A36),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: loading
                  ? null
                  : () async {
                      if (emailC.text.trim().isEmpty) {
                        ErrorHandler.showErrorPopup('Email cannot be empty');
                        return;
                      }
                      if (passC.text.isEmpty) {
                        ErrorHandler.showErrorPopup('Password cannot be empty');
                        return;
                      }
                      setDialogState(() => loading = true);
                      try {
                        await _profileService.updateEmail(
                          email: emailC.text.trim(),
                          currentPassword: passC.text,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        _loadUser();
                        ErrorHandler.showSuccessPopup('Email updated');
                      } catch (e) {
                        setDialogState(() => loading = false);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2A36),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
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
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
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

  @override
  Widget build(BuildContext context) {
    final displayName = _user?.name ?? 'User';
    final email = _user?.email ?? '';
    final isGuest = _user?.isGuest ?? false;
    final isGoogleUser = _isGoogleUser == true;
    const bottomNavReserve = 92.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            MediaQuery.paddingOf(context).bottom + bottomNavReserve,
          ),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _updatingAvatar ? null : _showImageSourcePicker,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          border: Border.all(
                            color: AppColors.primary,
                            width: 2.5,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _localImageFile != null
                                ? ClipOval(
                                    child: _localPreviewIsGif
                                        ? Container(
                                            width: 100,
                                            height: 100,
                                            color: AppColors.surface,
                                            child: const Icon(
                                              Icons.gif_box_outlined,
                                              color: AppColors.primary,
                                              size: 46,
                                            ),
                                          )
                                        : Image.file(
                                            _localImageFile!,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                                  Icons.person,
                                                  color: AppColors.primary,
                                                  size: 50,
                                                ),
                                          ),
                                  )
                                : _user?.avatarUrl != null
                                ? ClipOval(
                                    child: CachedNetworkImage(
                                      key: ValueKey(
                                        '${ImageUtils.getAvatarUrl(_user!.avatarUrl)}_${_avatarCacheBuster ?? ''}',
                                      ),
                                      cacheKey: _cacheBustedAvatarUrl(
                                        ImageUtils.getAvatarUrl(
                                          _user!.avatarUrl,
                                        ),
                                      ),
                                      imageUrl: ImageUtils.getAvatarUrl(
                                        _user!.avatarUrl,
                                      ),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                      cacheManager: WudiCacheManager(),
                                      httpHeaders: getNetworkImageHeaders(
                                        ImageUtils.getAvatarUrl(
                                          _user!.avatarUrl,
                                        ),
                                      ),
                                      placeholder: (context, url) =>
                                          const Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                      errorWidget: (context, url, error) =>
                                          const Icon(
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
                            if (_updatingAvatar)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.35),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: Text(
                                        _avatarStatusText ?? 'Loading image...',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isGuest)
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
                ),
                const SizedBox(height: 8),
                if (!isGuest)
                  const Text(
                    'Tips: Image max 1MB, GIF max 2MB',
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                const SizedBox(height: 12),
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
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSettingTile(
                  icon: Icons.checklist_rounded,
                  title: 'All Task',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TaskPage(authService: widget.authService),
                      ),
                    );
                  },
                ),
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
                  const SizedBox(height: 8),
                  _buildSettingTile(
                    icon: Icons.person_outline,
                    title: 'Change Name',
                    onTap: _showChangeNameDialog,
                  ),
                  if (!isGoogleUser) ...[
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
                  ],
                  _buildSettingTile(
                    icon: Icons.notifications_none_outlined,
                    title: 'Notification Settings',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationSettingsPage(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

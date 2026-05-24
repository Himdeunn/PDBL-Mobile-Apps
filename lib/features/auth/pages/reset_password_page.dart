import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/widgets/native_text_input.dart';
import '../services/auth_service.dart';
import 'login_page.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  final String otp;
  const ResetPasswordPage({super.key, required this.email, required this.otp});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onReset() async {
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty || confirm.isEmpty) {
      ErrorHandler.showErrorPopup('Please fill in all fields.');
      return;
    }
    if (password.length < 8) {
      ErrorHandler.showErrorPopup('Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      ErrorHandler.showErrorPopup('Passwords do not match.');
      return;
    }
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().resetPassword(
        email: widget.email,
        otp: widget.otp,
        password: password,
      );
      if (!mounted) return;
      ErrorHandler.showSuccessPopup(
        'Password reset successful! Please log in.',
      );
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (_) => false,
      );
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(50),
          ),
          child: NativeTextInput(
            controller: controller,
            obscureText: obscure,
            enabled: !_isLoading,
            height: 52,
            hintText: '••••••••',
            hintColor: AppColors.textTertiary,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            fallbackBuilder: (context) => TextField(
              controller: controller,
              obscureText: obscure,
              enabled: !_isLoading,
              decoration: InputDecoration(
                hintText: '••••••••',
                hintStyle: const TextStyle(color: AppColors.textTertiary),
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: AppColors.iconAccent,
                  size: 20,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.iconAccent,
                    size: 20,
                  ),
                  onPressed: onToggle,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Reset Password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 48),

                    const Text(
                      'Create New Password',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your new password must be different\nfrom previous passwords.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 40),

                    _buildField(
                      controller: _newPasswordController,
                      label: 'New Password',
                      obscure: _obscureNew,
                      onToggle: () =>
                          setState(() => _obscureNew = !_obscureNew),
                    ),

                    const SizedBox(height: 20),

                    _buildField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),

                    const SizedBox(height: 40),

                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.primary,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: _onReset,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                elevation: 6,
                                shadowColor: AppColors.primary.withValues(
                                  alpha: 0.4,
                                ),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 18),
                              label: const Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

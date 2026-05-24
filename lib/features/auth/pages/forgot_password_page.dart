import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../../../../core/widgets/native_text_input.dart';
import '../services/auth_service.dart';
import 'verify_otp_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _onSend() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ErrorHandler.showErrorPopup('Please enter your email.');
      return;
    }

    if (!email.contains('@')) {
      ErrorHandler.showErrorPopup('Please enter a valid email.');
      return;
    }

    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().forgotPassword(email);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => VerifyOtpPage(email: email)),
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      final status = (data is Map) ? data['status'] : null;
      if (status == 'google_account') {
        ErrorHandler.showErrorPopup(
          "Sorry, you can't reset your password. You signed in with Google.",
          title: "Google Account",
        );
      } else {
        ErrorHandler.handleApiError(e);
      }
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                      'Forget Password?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Enter your registered email address.\nWe\'ll send you a verification code.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 40),

                    const Text(
                      'Email Address',
                      style: TextStyle(
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
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        enabled: !_isLoading,
                        height: 52,
                        hintText: 'nama@gmail.com',
                        hintColor: AppColors.textTertiary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        fallbackBuilder: (context) => TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          enabled: !_isLoading,
                          decoration: const InputDecoration(
                            hintText: 'nama@gmail.com',
                            hintStyle: TextStyle(color: AppColors.textTertiary),
                            prefixIcon: Icon(
                              Icons.mail_outline,
                              color: AppColors.iconAccent,
                              size: 20,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
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
                              onPressed: _onSend,
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
                              label: const Text(
                                'Send Code',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              icon: const Icon(Icons.send_rounded, size: 18),
                            ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: const TextSpan(
                            text: 'Remember your password? ',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                            children: [
                              TextSpan(
                                text: 'Login',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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

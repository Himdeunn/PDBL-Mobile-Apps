import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../services/auth_service.dart';
import 'reset_password_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;
  bool _isResending = false;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _resendCooldown = seconds;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _onVerify() async {
    if (_otp.length < 4) {
      ErrorHandler.showErrorPopup('Please enter the 4-digit code.');
      return;
    }
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await AuthService().verifyOtp(widget.email, _otp);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordPage(email: widget.email, otp: _otp),
        ),
      );
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onResend() async {
    if (_isResending || _resendCooldown > 0) return;
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }
    setState(() => _isResending = true);
    try {
      await AuthService().forgotPassword(widget.email);
      if (!mounted) return;
      _startCooldown(60);
      ErrorHandler.showSuccessPopup('Code resent to ${widget.email}');
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 429) {
        final data = e.response?.data;
        final retryAfter = (data is Map ? data['retry_after'] as int? : null) ?? 60;
        _startCooldown(retryAfter);
      }
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 62,
      height: 62,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        maxLength: 1,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        onChanged: (val) {
          if (val.length == 1 && index < 3) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
        },
      ),
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),

                    const Text(
                      'Verification Code',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Enter the 4-digit code sent to\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),

                    const SizedBox(height: 48),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(4, (i) => _buildOtpBox(i)),
                    ),

                    const SizedBox(height: 48),

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
                              onPressed: _onVerify,
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
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Verify',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    GestureDetector(
                      onTap: (_resendCooldown > 0 || _isResending) ? null : _onResend,
                      child: _resendCooldown > 0
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.timer_outlined, size: 14, color: AppColors.textTertiary),
                                const SizedBox(width: 6),
                                Text(
                                  'Resend in ${_resendCooldown}s',
                                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary, fontStyle: FontStyle.italic),
                                ),
                              ],
                            )
                          : RichText(
                              text: TextSpan(
                                text: "Didn't receive the code? ",
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                                children: [
                                  TextSpan(
                                    text: _isResending ? 'Sending...' : 'Resend',
                                    style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontStyle: FontStyle.italic),
                                  ),
                                ],
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

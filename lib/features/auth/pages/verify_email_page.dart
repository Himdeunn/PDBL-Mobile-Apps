import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../services/auth_service.dart';
import '../pages/welcome_page.dart';
import '../../shell/pages/main_navigation.dart';

class VerifyEmailPage extends StatefulWidget {
  final String email;
  /// true  → user can press back / skip (came from register, verifying later)
  /// false → must verify before entering the app (splash redirect)
  final bool canSkip;

  const VerifyEmailPage({
    super.key,
    required this.email,
    this.canSkip = true,
  });

  @override
  State<VerifyEmailPage> createState() => _VerifyEmailPageState();
}

class _VerifyEmailPageState extends State<VerifyEmailPage> {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;

  // Countdown for resend cooldown
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

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

  Future<void> _onVerify() async {
    if (_otp.length < 4) {
      ErrorHandler.showErrorPopup('Please enter the 4-digit verification code.');
      return;
    }
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }

    setState(() => _isLoading = true);
    try {
final authService = AuthService();
      await authService.verifyEmail(widget.email, _otp);
      
      // CRITICAL: Freshly fetch user data after verification to update local cache
      // This ensures that login navigation guards see the updated verified status.
      await authService.getCurrentUser(forceRefresh: true);
      if (!mounted) return;
      ErrorHandler.showSuccessPopup('Email verified! Welcome to Wudi.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigation(authService: authService),
        ),
        (_) => false,
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
      final response = await AuthService().resendVerificationWithCooldown(widget.email);
      if (!mounted) return;
      final retryAfter = response['retry_after'] as int? ?? 60;
      _startCooldown(retryAfter);
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

  Future<void> _handleSwitchAccount() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out and switch to a different account?', style: TextStyle(color: AppColors.textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await AuthService().logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canSkip,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (widget.canSkip)
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: _handleSwitchAccount,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
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
                      const SizedBox(height: 16),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'We sent a verification code to your email. Please check your inbox (and spam folder).',
                                style: TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.mark_email_unread_rounded,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),

                      const SizedBox(height: 24),

                      const Text(
                        'Check Your Inbox',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We sent a 4-digit verification code to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),

                      const SizedBox(height: 40),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(4, (i) => _buildOtpBox(i)),
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
                                onPressed: _onVerify,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  elevation: 6,
                                  shadowColor:
                                      AppColors.primary.withValues(alpha: 0.4),
                                ),
                                icon: const Icon(
                                  Icons.verified_rounded,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Verify Email',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Resend with cooldown
                      GestureDetector(
                        onTap: (_resendCooldown > 0 || _isResending)
                            ? null
                            : _onResend,
                        child: _resendCooldown > 0
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 14,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Resend in ${_resendCooldown}s',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textTertiary,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            : RichText(
                                text: TextSpan(
                                  text: "Didn't receive the code? ",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: _isResending
                                          ? 'Sending...'
                                          : 'Resend',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),

                      if (widget.canSkip) ...[
                        const SizedBox(height: 24),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            "I'll verify later",
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textTertiary,
                              fontStyle: FontStyle.italic,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],

                      if (!widget.canSkip) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'You must verify your email to access Wudi.',
                                  style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

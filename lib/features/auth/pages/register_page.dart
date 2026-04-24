import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/logo.dart';
import '../../../../core/theme/secondary_button.dart';
import '../../../../core/theme/secondary_textfield.dart';
import '../services/auth_service.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import 'login_page.dart';
import 'verify_email_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Rate limiting: prevent spam registration attempts
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _onRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Rate limiting check
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      ErrorHandler.showErrorPopup(
        'Too many failed attempts. Please wait $remaining seconds.',
      );
      return;
    }

    if (mounted) setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check network connection
      if (!await ConnectionService().isConnected()) {
        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final authService = AuthService();
      await authService.register(
        name: _fullnameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _passwordController.text,
      );

      if (!mounted) return;
      _failedAttempts = 0;
      _lockoutUntil = null;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            email: _emailController.text.trim(),
            canSkip: true,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
        ErrorHandler.showErrorPopup(
          'Too many failed attempts. Please wait 30 seconds before trying again.',
        );
      } else {
        ErrorHandler.handleApiError(e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final horizontalPadding = screenWidth > 600 ? screenWidth * 0.15 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: isSmallScreen ? 32 : 52),

                  const WudiLogo(),

                  SizedBox(height: isSmallScreen ? 40 : 60),

                  const Text(
                    'Start your journey to better productivity\nwith FocusFlow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),

                  const SizedBox(height: 28),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.errorText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  AbsorbPointer(
                    absorbing: _isLoading,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          DarkTextField(
                            controller: _fullnameController,
                            label: 'Full Name',
                            enabled: !_isLoading,
                            isRequired: true,
                            hintText: 'Enter Your Fullname',
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              color: AppColors.iconAccent,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Full name is required';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          DarkTextField(
                            controller: _emailController,
                            label: 'Email',
                            enabled: !_isLoading,
                            isRequired: true,
                            hintText: 'Enter Your Email',
                            keyboardType: TextInputType.emailAddress,
                            prefixIcon: const Icon(
                              Icons.mail_outline,
                              color: AppColors.iconAccent,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email is required';
                              }
                              final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          DarkTextField(
                            controller: _passwordController,
                            label: 'Password',
                            enabled: !_isLoading,
                            isRequired: true,
                            hintText: 'Create Your Password',
                            obscureText: _obscurePassword,
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.iconAccent,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.contains(' ')) {
                                return 'Password cannot contain spaces';
                              }
                              if (value.length < 8) {
                                return 'Password must be at least 8 characters';
                              }
                              return null;
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.iconAccent,
                              ),
                              onPressed: _togglePasswordVisibility,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  _isLoading
                      ? const SizedBox(
                          height: 52,
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.primary),
                          ),
                        )
                      : SecondaryButton(label: 'Sign up', onPressed: _onRegister),

                  const SizedBox(height: 16),

                  AbsorbPointer(
                    absorbing: _isLoading,
                    child: GestureDetector(
                      onTap: _onLogin,
                      child: RichText(
                        text: const TextSpan(
                          text: 'Already Have An Account? ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          children: [
                            TextSpan(
                              text: 'Login',
                              style: TextStyle(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

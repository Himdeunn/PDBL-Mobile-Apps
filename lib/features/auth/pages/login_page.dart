import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/logo.dart';
import '../../../../core/theme/primary_button.dart';
import '../../../../core/theme/primary_textfield.dart';
import '../services/auth_service.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';
import 'verify_email_page.dart';
import '../../shell/pages/main_navigation.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  String? _errorMessage;
  // Rate limiting: prevent brute-force login attempts
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(seconds: 30);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  Future<void> _onLogin() async {
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

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Check network connection
      if (!await ConnectionService().isConnected()) {
        ErrorHandler.showErrorPopup('No internet connection. Please check your connection.');
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final authService = AuthService();
      await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      _failedAttempts = 0;
      _lockoutUntil = null;
      ErrorHandler.showSuccessPopup('Successfully logged in!');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigation(authService: authService),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;

      if (e is DioException && e.response?.statusCode == 403) {
        final data = e.response?.data;
        final status = data is Map ? data['status'] : null;
        final email = data is Map ? data['email'] as String? : null;

        if (status == 'email_not_verified' && email != null && email.isNotEmpty) {
          _failedAttempts = 0;
          _lockoutUntil = null;
          ErrorHandler.showSuccessPopup('Verification code sent to $email');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => VerifyEmailPage(
                email: email,
                canSkip: false,
              ),
            ),
          );
          return;
        }
      }

      // Only count failed attempts on credential errors (422)
      final isCredentialError = e is! DioException || e.response?.statusCode == 422;
      if (isCredentialError) {
        _failedAttempts++;
      }
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

  void _onSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
  }
  Future<void> _onGoogleSignIn() async {
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return;
      if (!mounted) return;
      final authService = AuthService();
      await authService.googleLogin(
        googleId: account.id,
        email: account.email,
        name: account.displayName ?? account.email,
        avatarUrl: account.photoUrl,
      );
      if (!mounted) return;
      if (authService.lastGoogleLoginConverted) {
        ErrorHandler.showSuccessPopup(
          'Your account has been linked to Google Sign-In. From now on, please use "Continue with Google" to log in.',
          title: 'Account Linked to Google',
        );
      } else {
        ErrorHandler.showSuccessPopup('Successfully logged in!');
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => MainNavigation(authService: authService)),
        (_) => false,
      );
    } catch (e) {
      ErrorHandler.handleApiError(e);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
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

                  SizedBox(height: isSmallScreen ? 48 : 72),

                  const Text(
                    'Sign in to continue your productivity\njourney with FocusFlow.',
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
                          CustomTextField(
                            controller: _emailController,
                            label: 'Email',
                            enabled: !_isLoading,
                            isRequired: true,
                            hintText: 'Enter Your Email',
                            keyboardType: TextInputType.emailAddress,
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

                          CustomTextField(
                            controller: _passwordController,
                            label: 'Password',
                            enabled: !_isLoading,
                            isRequired: true,
                            hintText: 'Enter Your Password',
                            obscureText: _obscurePassword,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password is required';
                              }
                              if (value.contains(' ')) {
                                return 'Password cannot contain spaces';
                              }
                              return null;
                            },
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textTertiary,
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
                      : PrimaryButton(label: 'Login', onPressed: _onLogin),

                  const SizedBox(height: 14),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage()),
                      ),
                      child: const Text(
                        'Forget Password?',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.calendarSelected,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.textTertiary)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('or',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textTertiary)),
                      ),
                      const Expanded(child: Divider(color: AppColors.textTertiary)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Google Sign-In
                  _isGoogleLoading
                      ? const SizedBox(
                          height: 54,
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: OutlinedButton.icon(
                            onPressed: _onGoogleSignIn,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.textTertiary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              backgroundColor: Colors.white,
                            ),
                            icon: Image.network(
                              'https://www.google.com/favicon.ico',
                              width: 20,
                              height: 20,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.g_mobiledata_rounded,
                                size: 24,
                                color: Colors.red,
                              ),
                            ),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),

                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: _onSignUp,
                    child: RichText(
                      text: const TextSpan(
                        text: "Don't Have An Account? ",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        children: [
                          TextSpan(
                            text: 'Sign-Up',
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

import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/logo.dart';
import '../../../../core/theme/secondary_button.dart';
import '../../../../core/theme/secondary_textfield.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import '../../shell/pages/main_navigation.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

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
    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (fullname.isEmpty || email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = AuthService();
      await authService.register(
        name: fullname,
        email: email,
        password: password,
        passwordConfirmation: password,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => MainNavigation(authService: authService),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
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
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: isSmallScreen ? 40 : 60),

                        // Logo
                        const WudiLogo(),

                        SizedBox(height: isSmallScreen ? 60 : 100),

                        // Subtitle
                        const Text(
                          'Start your journey to better productivity\nwith FocusFlow.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),

                        SizedBox(height: isSmallScreen ? 24 : 36),

                        // Error message
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

                        // Fullname Field
                        DarkTextField(
                          controller: _fullnameController,
                          hintText: 'Enter Your Fullname',
                          prefixIcon: const Icon(
                            Icons.person_outline,
                            color: AppColors.iconAccent,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Email Field
                        DarkTextField(
                          controller: _emailController,
                          hintText: 'Enter Your Email',
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(
                            Icons.mail_outline,
                            color: AppColors.iconAccent,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Password Field
                        DarkTextField(
                          controller: _passwordController,
                          hintText: 'Create Your Password',
                          obscureText: _obscurePassword,
                          prefixIcon: const Icon(
                            Icons.lock_outline,
                            color: AppColors.iconAccent,
                          ),
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

                        SizedBox(height: isSmallScreen ? 24 : 32),

                        // Register Button
                        _isLoading
                            ? const SizedBox(
                                height: 52,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : SecondaryButton(
                                label: 'Sign-Up',
                                onPressed: _onRegister,
                              ),

                        const SizedBox(height: 20),

                        // Login Link
                        GestureDetector(
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

                        const Spacer(),

                        SizedBox(height: isSmallScreen ? 20 : 40),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

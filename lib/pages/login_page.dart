import 'package:flutter/material.dart';
import '../../../core/theme/logo.dart';
import '../../../core/theme/primary_button.dart';
import '../../../core/theme/primary_textfield.dart';
import '../../../features/auth/pages/register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

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

  void _onLogin() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // TODO: Hubungkan ke AuthService
    debugPrint('Email: $email, Password: $password');
  }

  void _onSignUp() {
    // TODO: Navigate ke Register page
    Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const RegisterPage()),
  );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Logo
              const WudiLogo(),

              const SizedBox(height: 80),

              // Subtitle
              const Text(
                'Sign in to continue your productivity\njourney with Wudi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF555555),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 36),

              // Email Field
              CustomTextField(
                controller: _emailController,
                hintText: 'Enter Your Email',
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: 14),

              // Password Field
              CustomTextField(
                controller: _passwordController,
                hintText: 'Enter Your Password',
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF888888),
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),

              const SizedBox(height: 32),

              // Login Button
              PrimaryButton(label: 'Login', onPressed: _onLogin),

              const SizedBox(height: 20),

              // Sign Up Link
              GestureDetector(
                onTap: _onSignUp,
                child: RichText(
                  text: const TextSpan(
                    text: "Don't Have An Account? ",
                    style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                    children: [
                      TextSpan(
                        text: 'Sign-Up',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
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
    );
  }
}

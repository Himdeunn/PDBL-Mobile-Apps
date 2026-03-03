import 'package:flutter/material.dart';
import '../components/logo.dart';
import '../components/secondary_button.dart';
import '../components/secondary_textfield.dart';
import 'login_page.dart';

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

  void _onRegister() {
    final fullname = _fullnameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // TODO: Hubungkan ke AuthService
    debugPrint('Fullname: $fullname, Email: $email, Password: $password');
  }

  void _onLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
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

              const SizedBox(height: 35),

              // Subtitle
              const Text(
                'Sign up to continue your productivity\njourney with Wudi.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF555555),
                  height: 1.6,
                ),
              ),

              const SizedBox(height: 36),

              // Fullname Field
              DarkTextField(
                controller: _fullnameController,
                hintText: 'Enter Your Fullname',
                prefixIcon: const Icon(
                  Icons.person_outline,
                  color: Color(0xFFAAAAAA),
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
                  color: Color(0xFFAAAAAA),
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
                  color: Color(0xFFAAAAAA),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFFAAAAAA),
                  ),
                  onPressed: _togglePasswordVisibility,
                ),
              ),

              const SizedBox(height: 32),

              // Register Button
              // Login Button
              SecondaryButton(label: 'Register', onPressed: _onRegister),

              const SizedBox(height: 20),

              // Login Link
              GestureDetector(
                onTap: _onLogin,
                child: RichText(
                  text: const TextSpan(
                    text: 'Already Have An Account? ',
                    style: TextStyle(fontSize: 13, color: Color(0xFF555555)),
                    children: [
                      TextSpan(
                        text: 'Login',
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

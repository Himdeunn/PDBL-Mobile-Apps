import 'package:flutter/material.dart';
import '../components/primary_button.dart';
import '../components/secondary_button.dart';
import '../components/logo.dart';
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDE8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              const WudiLogo(),

              const Spacer(flex: 2),

              // Tagline
              const Text(
                'Master your time,\nachieve more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 24),

              // Subtitle
              const Text(
                'Solusi manajemen waktu untuk mahasiswa.\nBantu kamu mengatur aktivitas dengan\nlebih efektif.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF555555),
                  height: 1.6,
                ),
              ),

              const Spacer(flex: 3),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: 'Login',
                      onPressed: () {
                        // Navigate to Login page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SecondaryButton(
                      label: 'Register',
                      onPressed: () {
                        // Navigate to Register page
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RegisterPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

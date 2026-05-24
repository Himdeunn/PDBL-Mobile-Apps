import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/primary_button.dart';
import '../../../../core/theme/secondary_button.dart';
import '../../../../core/theme/logo.dart';
import '../../../../core/utils/error_handler.dart';
import '../../../../core/services/connection_service.dart';
import '../services/auth_service.dart';
import 'login_page.dart';
import 'register_page.dart';
import '../../shell/pages/main_navigation.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _isGoogleLoading = false;

  Future<void> _onGoogleSignIn() async {
    if (!await ConnectionService().isConnected()) {
      ErrorHandler.showErrorPopup('No internet connection.');
      return;
    }
    setState(() => _isGoogleLoading = true);
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
      final account = await googleSignIn.signIn();
      if (account == null) return; // user cancelled
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
        MaterialPageRoute(
          builder: (_) => MainNavigation(authService: authService),
        ),
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
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),

                        // Logo
                        const WudiLogo(),

                        const Spacer(flex: 2),

                        // Tagline
                        const Text(
                          'Master your time,\nachieve more.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Subtitle
                        const Text(
                          'A time management solution for students.\nHelping you organize your activities more\neffectively.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textTertiary,
                            fontStyle: FontStyle.italic,
                            height: 1.6,
                          ),
                        ),

                        const Spacer(flex: 3),

                        // Login / Register row
                        Row(
                          children: [
                            Expanded(
                              child: PrimaryButton(
                                label: 'Login',
                                onPressed: () {
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
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterPage(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Google Sign-In button
                        _isGoogleLoading
                            ? const SizedBox(
                                height: 54,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: AppColors.primary,
                                  ),
                                ),
                              )
                            : SizedBox(
                                width: double.infinity,
                                height: 54,
                                child: OutlinedButton.icon(
                                  onPressed: _onGoogleSignIn,
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: AppColors.textTertiary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                    backgroundColor: Colors.white,
                                  ),
                                  icon: Image.network(
                                    'https://www.google.com/favicon.ico',
                                    width: 20,
                                    height: 20,
                                    errorBuilder: (_, __, ___) => const Icon(
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

                        const SizedBox(height: 8),

                        // Guest button
                        TextButton(
                          onPressed: () async {
                            final authService = AuthService();
                            await authService.enterGuestMode();
                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    MainNavigation(authService: authService),
                              ),
                            );
                          },
                          child: const Text(
                            'Continue as Guest',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),
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

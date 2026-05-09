import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/remote_config_service.dart';
import '../../../core/widgets/maintenance_dialog.dart';
import '../../../core/widgets/update_dialog.dart';
import '../../../core/utils/widget_service.dart';
import '../../auth/services/auth_service.dart';
import '../../auth/pages/welcome_page.dart';
import '../../auth/pages/verify_email_page.dart';
import '../../shell/pages/main_navigation.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _controller.forward();
    _initializeApp();
  }

  Future<void> _ensureMinimumSplashDuration(DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime);
    final remaining = const Duration(milliseconds: 2500) - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  Future<void> _initializeApp() async {
    final startTime = DateTime.now();

    // Run auth check, remote config fetch, and package info in parallel
    final authService = AuthService();
    
    // We fetch remote config and package info in parallel
    final packageInfoFuture = PackageInfo.fromPlatform();
    
    final results = await Future.wait<dynamic>([
      authService.isLoggedIn(),
      packageInfoFuture,
      _ensureMinimumSplashDuration(startTime),
    ]);

    final bool isLoggedIn = results[0] as bool;
    final PackageInfo packageInfo = results[1] as PackageInfo;

    if (!mounted) return;

    // ── 1. Maintenance check (highest priority — blocks everything) ──────
    if (RemoteConfigService.maintenanceEnabled) {
      await MaintenanceDialog.show(
        context,
        title: RemoteConfigService.maintenanceTitle,
        message: RemoteConfigService.maintenanceMessage,
        estimatedEnd: RemoteConfigService.maintenanceEstimatedEnd,
      );
      // Dialog is non-dismissible — execution never reaches here
      return;
    }

    // ── 2. Version update check ──────────────────────────────────────────
    final currentVersion = packageInfo.version;
    final minVersion = RemoteConfigService.minVersion;
    final latestVersion = RemoteConfigService.latestVersion;
    final updateUrl = RemoteConfigService.updateUrlAndroid;

    final isBelowMin =
        RemoteConfigService.compareVersions(currentVersion, minVersion) < 0;
    final isBelowLatest =
        RemoteConfigService.compareVersions(currentVersion, latestVersion) < 0;

    // Force update: current < min_version
    if (RemoteConfigService.forceUpdateEnabled && isBelowMin) {
      await UpdateDialog.show(
        context,
        title: RemoteConfigService.updateTitle,
        message: RemoteConfigService.updateMessage,
        changelog: RemoteConfigService.updateChangelog,
        updateUrl: updateUrl,
        isForced: true,
      );
      // Non-dismissible — execution never reaches here
      return;
    }

    // Optional update: only when explicitly enabled in Firebase
    if (RemoteConfigService.optionalUpdateEnabled && isBelowLatest) {
      await UpdateDialog.show(
        context,
        title: RemoteConfigService.updateTitle,
        message: RemoteConfigService.updateMessage,
        changelog: RemoteConfigService.updateChangelog,
        updateUrl: updateUrl,
        isForced: false,
      );
      // User can press "Maybe Later" — continues to app
    }

    if (!mounted) return;

    // ── 3. Navigate ──────────────────────────────────────────────────────
    if (!isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
      );
      return;
    }

    // Logged in — get fresh user data from API to check verification status
    final currentUser = await authService.getCurrentUser(forceRefresh: true);
    
    if (currentUser != null && !currentUser.isEmailVerified) {
      if (!mounted) return;
      
      // Navigate to verification only if STILL unverified after fresh check
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailPage(
            email: currentUser.email ?? '',
            canSkip: false,
          ),
        ),
      );
      return;
    }

    final launchUri = WidgetService.claimPendingLaunchUri();
    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigation(
          authService: authService,
          initialWidgetUri: launchUri,
        ),
      ),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/wudi_logo.png',
                width: 120,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

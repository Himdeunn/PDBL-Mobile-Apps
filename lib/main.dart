import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:wudi/core/storage/local_database.dart';
import 'package:wudi/core/storage/secure_storage.dart';
import 'package:wudi/core/utils/notification_helper.dart';
import 'package:wudi/features/task/services/task_repository.dart';
import 'package:wudi/features/splash/pages/splash_page.dart';
import 'package:wudi/core/utils/navigator_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Set the background messaging handler early on, as a named top-level function
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Load environment variables before initializing services
  await dotenv.load(fileName: ".env");

  // Make status bar transparent for a more responsive and flush look
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize all remaining services in parallel
  await Future.wait([NotificationHelper.initialize(), LocalDatabase.init()]);

  // Listen for push notifications in foreground
  NotificationHelper.listenToForegroundMessages();

  // Re-schedule all task reminders on startup.
  // This ensures notifications survive device reboots and app updates.
  _rescheduleNotificationsOnStartup();

  runApp(const MyApp());
}

/// Best-effort reschedule — runs after runApp so it doesn't block UI launch.
void _rescheduleNotificationsOnStartup() {
  Future(() async {
    try {
      final email = await SecureStorage.getEmail();
      if (email == null || email.isEmpty) return;

      final repo = TaskRepository();
      await repo.rescheduleAllVisibleTasks(email);
    } catch (_) {
      // Silently fail on startup reschedule
    }
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduPlan PDBL',
      navigatorKey: NavigatorService.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF6366F1),
        textTheme: GoogleFonts.interTextTheme(),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashPage(),
    );
  }
}

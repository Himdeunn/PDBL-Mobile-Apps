import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:wudi/firebase_options.dart';
import '../../core/storage/secure_storage.dart';
import '../utils/notification_helper.dart';
import '../../features/auth/services/auth_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  if (message.notification != null || message.data.isNotEmpty) {
    NotificationHelper.showNotification(
      id: message.messageId.hashCode,
      title: message.notification?.title ?? message.data['title'] ?? 'WUDI Reminder',
      body: message.notification?.body ?? message.data['body'] ?? 'You have a task deadline approaching.',
      priority: message.data['priority'] ?? 'medium',
      description: message.data['description'] ?? message.data['deskripsi'],
      payload: message.data.toString(),
    );
  }
}

class FirebaseService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      // Get token
      String? token = await _messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }

      // Listen for token updates
      _messaging.onTokenRefresh.listen(_registerToken);

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Foreground message handler
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null && android != null) {
          NotificationHelper.showNotification(
            id: notification.hashCode,
            title: notification.title ?? '',
            body: notification.body ?? '',
            priority: message.data['priority'] ?? 'medium',
            description: message.data['description'] ?? message.data['deskripsi'],
            payload: message.data.toString(),
          );
        }
      });
    } catch (_) {
      // Silently fail on Firebase initialization error
    }
  }

  static Future<void> _registerToken(String token) async {
    try {
      // Only register FCM token if user is logged in (has a valid token)
      final sessionToken = await SecureStorage.getToken();
      if (sessionToken == null || sessionToken.isEmpty) {
        return;
      }

      // Delegate to AuthService to ensure deduplication logic is consistent
      await AuthService().syncFcmToken(fcmToken: token);
    } catch (_) {
      // Silently fail on FCM token registration error
    }
  }
}

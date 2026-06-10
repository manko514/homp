import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'staff_api_service.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background messages are handled by the system notification tray
  debugPrint('FCM background: ${message.messageId}');
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permission (Android 13+ requires this)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM permission granted');
      await _uploadToken();
    } else {
      debugPrint('FCM permission denied');
    }

    // Handle token refresh
    _messaging.onTokenRefresh.listen((token) async {
      await _saveAndUpload(token);
    });

    // Foreground messages — show in-app banner
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      // The notification is shown via the system tray on Android by default
    });
  }

  static Future<void> _uploadToken() async {
    final token = await _messaging.getToken();
    if (token != null) {
      await _saveAndUpload(token);
    }
  }

  static Future<void> _saveAndUpload(String token) async {
    try {
      await StaffApiService.saveFcmToken(token);
      debugPrint('FCM token uploaded');
    } catch (e) {
      debugPrint('FCM token upload failed: $e');
    }
  }
}

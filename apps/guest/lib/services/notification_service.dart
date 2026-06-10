import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'auth_service.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background messages are handled silently; the system tray shows the
  // notification automatically when data-only messages arrive on Android.
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  /// Set this in _AppShellState.initState() to handle notification taps.
  /// Called with (type, id) extracted from the FCM payload.
  static void Function(String type, String id)? onNotification;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  // Called once at app startup from main().
  Future<void> init() async {
    // Register the background handler before anything else.
    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    // Request permission (iOS + Android 13+).
    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Local notifications channel (Android 8+).
    if (!kIsWeb && Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        'homp_channel',
        'HOMP Alerts',
        description: 'Booking confirmations, order alerts and hotel updates',
        importance: Importance.high,
        playSound: true,
      );
      await _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }

    // Initialise flutter_local_notifications for foreground display.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // already requested above
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Register FCM token with our API (best-effort).
    await _registerToken();

    // Listen for token refreshes.
    _fcm.onTokenRefresh.listen((newToken) => AuthService.saveFcmToken(newToken));

    // Foreground messages: show a local notification.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);

    // Notification tap when app is in background (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    // App opened from a terminated state via notification.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleMessageOpen(initial);
  }

  // ── Token registration ────────────────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        await AuthService.saveFcmToken(token);
      }
    } catch (_) {
      // Not logged in yet — token will be saved after login via onTokenRefresh.
    }
  }

  /// Call this after a successful login so the token is immediately stored.
  Future<void> onLogin() => _registerToken();

  // ── Foreground display ────────────────────────────────────────────────────

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'homp_channel',
        'HOMP Alerts',
        channelDescription: 'Booking confirmations, order alerts and hotel updates',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    await _local.show(
      notification.hashCode,
      notification.title ?? 'HOMP',
      notification.body,
      details,
      payload: _payloadFrom(message),
    );
  }

  // ── Navigation on tap ─────────────────────────────────────────────────────

  void _onNotificationTap(NotificationResponse response) {
    _routeFromPayload(response.payload);
  }

  void _handleMessageOpen(RemoteMessage message) {
    _routeFromPayload(_payloadFrom(message));
  }

  void _routeFromPayload(String? payload) {
    if (payload == null) return;
    // payload format: "type:id"  e.g. "booking:abc123"
    final sep   = payload.indexOf(':');
    final type  = sep == -1 ? payload : payload.substring(0, sep);
    final id    = sep == -1 ? '' : payload.substring(sep + 1);
    onNotification?.call(type, id);
  }

  String? _payloadFrom(RemoteMessage message) {
    final data = message.data;
    if (data.containsKey('type')) {
      return '${data['type']}:${data['id'] ?? ''}';
    }
    return null;
  }

  // ── Manual send helpers (for testing from the API) ────────────────────────

  /// Push a local notification directly — used by other services
  /// to simulate push when the API can't reach FCM (dev mode).
  Future<void> showLocal({
    required String title,
    required String body,
    String? payload,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'homp_channel',
        'HOMP Alerts',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

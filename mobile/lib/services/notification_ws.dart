import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Real-time notification listener via WebSocket + FCM + local notifications.
///
/// Handles 3 notification channels:
/// 1. **WebSocket** — real-time push when app is open (instant UI refresh)
/// 2. **FCM foreground** — shows local notification when app is open
/// 3. **FCM background** — shows system notification when app is closed/background
class NotificationWebSocket {
  static final NotificationWebSocket _instance = NotificationWebSocket._internal();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isConnected = false;

  /// Callback invoked when a notification arrives — use this to refresh UI.
  VoidCallback? onNotification;

  /// Local notifications plugin
  final FlutterLocalNotificationsPlugin _localNotif = FlutterLocalNotificationsPlugin();
  bool _localNotifInitialized = false;

  NotificationWebSocket._internal();
  factory NotificationWebSocket() => _instance;

  /// Initialize local notifications (call once in main).
  Future<void> initLocalNotifications() async {
    if (_localNotifInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotif.initialize(initSettings);
    _localNotifInitialized = true;
    debugPrint('🔔 Local notifications initialized');
  }

  /// Connect to the WebSocket notification endpoint + setup FCM.
  Future<void> connect() async {
    final auth = AuthService();
    if (!auth.isTokenValid || auth.currentUser == null) return;

    // Request notification permission (Android 13+)
    if (_localNotifInitialized) {
      final androidPlugin = _localNotif.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    }

    // ── Setup FCM ──
    await _setupFCM();

    // ── Setup WebSocket ──
    await _connectWebSocket();
  }

  /// Register FCM token with backend and listen for foreground messages.
  Future<void> _setupFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Get FCM token and register with backend
      final fcmToken = await messaging.getToken();
      if (fcmToken != null) {
        debugPrint('🔥 [FCM] Token: ${fcmToken.substring(0, 20)}...');
        await _registerFcmToken(fcmToken);
      }

      // Listen for token refresh
      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔥 [FCM] Token refreshed');
        await _registerFcmToken(newToken);
      });

      // Handle foreground FCM messages — show local notification
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('🔥 [FCM] Foreground message: ${message.notification?.title}');

        final notification = message.notification;
        if (notification != null) {
          _showLocalNotification(notification.title ?? 'Thông báo', notification.body ?? '');
        }

        // Trigger UI refresh
        onNotification?.call();
      });

      // Handle when user taps notification while app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔥 [FCM] Notification tapped: ${message.notification?.title}');
        onNotification?.call();
      });

      debugPrint('🔥 [FCM] Setup complete');
    } catch (e) {
      debugPrint('🔥 [FCM] Setup error: $e');
    }
  }

  /// Register FCM token with backend API.
  Future<void> _registerFcmToken(String token) async {
    try {
      final auth = AuthService();
      if (!auth.isTokenValid) return;

      await ApiService().post(
        '/notifications/register-token',
        body: {'fcm_token': token},
        token: auth.token,
      );
      debugPrint('🔥 [FCM] Token registered with backend');
    } catch (e) {
      debugPrint('🔥 [FCM] Failed to register token: $e');
    }
  }

  /// Connect WebSocket for real-time updates.
  Future<void> _connectWebSocket() async {
    final auth = AuthService();
    if (!auth.isTokenValid || auth.currentUser == null) return;

    // Build WS URL: http://host:8000/api/v1 → ws://host:8000/ws/notifications/{user_id}
    final baseUrl = ApiService().baseUrl;
    final hostUrl = baseUrl.replaceAll('/api/v1', '');
    final wsHost = hostUrl.replaceFirst('http', 'ws');
    final userId = auth.currentUser!.id;
    final wsUrl = '$wsHost/ws/notifications/$userId';

    debugPrint('🔔 [WS] Connecting to: $wsUrl');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;

      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message),
        onDone: () {
          debugPrint('🔔 [WS] Connection closed, scheduling reconnect...');
          _isConnected = false;
          _scheduleReconnect();
        },
        onError: (error) {
          debugPrint('🔔 [WS] Error: $error');
          _isConnected = false;
          _scheduleReconnect();
        },
      );

      // Ping every 30s to keep alive
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_isConnected) {
          try {
            _channel?.sink.add('ping');
          } catch (_) {}
        }
      });

      debugPrint('🔔 [WS] Connected successfully');
    } catch (e) {
      debugPrint('🔔 [WS] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _handleMessage(dynamic message) {
    debugPrint('🔔 [WS] Received: $message');
    try {
      jsonDecode(message as String); // validate JSON

      // Chỉ refresh UI — FCM foreground đã hiển thị notification rồi
      onNotification?.call();
    } catch (e) {
      debugPrint('🔔 [WS] Parse error: $e');
    }
  }

  Future<void> _showLocalNotification(String title, String body) async {
    if (!_localNotifInitialized) return;

    const androidDetails = AndroidNotificationDetails(
      'techhub_oos',
      'Sản phẩm hết hàng',
      channelDescription: 'Thông báo khi sản phẩm trong giỏ hàng hết hàng',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isConnected) _connectWebSocket();
    });
  }

  /// Disconnect and cleanup.
  void disconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    debugPrint('🔔 [WS] Disconnected');
  }
}

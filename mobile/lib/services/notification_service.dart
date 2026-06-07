import 'dart:convert';
import '../models/notification_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Singleton service for notification-related API calls.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  NotificationService._internal();
  factory NotificationService() => _instance;

  /// Fetch all notifications for the current user.
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final response = await _apiService.get(
      '/notifications',
      queryParams: {'limit': '$limit'},
      token: _authService.token,
    );

    final data = jsonDecode(response) as Map<String, dynamic>;
    final List list = data['data'] as List? ?? [];

    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get unread notification count.
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.get(
        '/notifications/unread-count',
        token: _authService.token,
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      return data['unread_count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mark a single notification as read.
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _apiService.put(
        '/notifications/$notificationId/read',
        body: {},
        token: _authService.token,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllAsRead() async {
    try {
      await _apiService.put(
        '/notifications/read-all',
        body: {},
        token: _authService.token,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

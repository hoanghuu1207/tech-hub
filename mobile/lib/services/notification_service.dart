import '../models/notification_model.dart';
import '../core/network/api_client.dart';

/// Singleton service for notification-related API calls.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final ApiClient _apiClient = ApiClient();

  NotificationService._internal();
  factory NotificationService() => _instance;

  /// Fetch all notifications for the current user.
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final response = await _apiClient.dio.get(
      '/notifications',
      queryParameters: {'limit': '$limit'},
    );

    final data = response.data as Map<String, dynamic>;
    final List list = data['data'] as List? ?? [];

    return list
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get unread notification count.
  Future<int> getUnreadCount() async {
    try {
      final response = await _apiClient.dio.get('/notifications/unread-count');
      final data = response.data as Map<String, dynamic>;
      return data['unread_count'] ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Mark a single notification as read.
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _apiClient.dio.put(
        '/notifications/$notificationId/read',
        data: {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Mark all notifications as read.
  Future<bool> markAllAsRead() async {
    try {
      await _apiClient.dio.put(
        '/notifications/read-all',
        data: {},
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

import 'dart:convert';
import '../models/order_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Singleton service for order-related API calls.
class OrderService {
  static final OrderService _instance = OrderService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  OrderService._internal();
  factory OrderService() => _instance;

  /// Fetch all orders for the current user.
  /// Returns newest-first.
  Future<List<Order>> getUserOrders({int limit = 20}) async {
    final response = await _apiService.get(
      '/orders',
      queryParams: {'limit': '$limit'},
      token: _authService.token,
    );

    final data = jsonDecode(response) as Map<String, dynamic>;
    final List list = data['data'] as List? ?? [];

    final orders = list
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();

    // Sort newest first
    orders.sort((a, b) {
      final aDate = a.createdAt ?? DateTime(2000);
      final bDate = b.createdAt ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return orders;
  }

  /// Fetch a single order by ID.
  Future<Order?> getOrderDetail(String orderId) async {
    try {
      final response = await _apiService.get(
        '/orders/$orderId',
        token: _authService.token,
      );

      final data = jsonDecode(response) as Map<String, dynamic>;
      return Order.fromJson(data['data'] as Map<String, dynamic>);
    } catch (e) {
      return null;
    }
  }

  /// Cancel an order — POST /orders/{id}/cancel.
  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await _apiService.post(
        '/orders/$orderId/cancel',
        body: {},
        token: _authService.token,
      );
      final data = jsonDecode(response) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

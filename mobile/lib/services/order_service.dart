import 'dart:convert';
import '../models/index.dart';
import 'api_service.dart';
import 'auth_service.dart';

class OrderService {
  static final OrderService _instance = OrderService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  OrderService._internal();

  factory OrderService() {
    return _instance;
  }

  /// Create order
  Future<Order> createOrder({
    required List<CartItem> items,
    required String shippingAddress,
    required String shippingPhone,
    required String paymentMethod,
  }) async {
    try {
      final orderItems = items
          .map((item) => {
                'product_id': item.product.id,
                'quantity': item.quantity,
              })
          .toList();

      final response = await _apiService.post(
        '/orders',
        body: {
          'items': orderItems,
          'shipping_address': shippingAddress,
          'shipping_phone': shippingPhone,
          'payment_method': paymentMethod,
        },
        token: _authService.token,
      );

      final data = jsonDecode(response);
      return Order.fromJson(data['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Get user orders
  Future<List<Order>> getUserOrders({
    int page = 1,
    int limit = 10,
    String? status,
  }) async {
    try {
      final response = await _apiService.get(
        '/orders',
        queryParams: {
          'page': page,
          'limit': limit,
          if (status != null) 'status': status,
        },
        token: _authService.token,
      );

      final data = jsonDecode(response);
      return (data['results'] as List)
          .map((item) => Order.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get order by ID
  Future<Order> getOrderById(String orderId) async {
    try {
      final response = await _apiService.get(
        '/orders/$orderId',
        token: _authService.token,
      );

      final data = jsonDecode(response);
      return Order.fromJson(data['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Cancel order
  Future<Order> cancelOrder(String orderId) async {
    try {
      final response = await _apiService.put(
        '/orders/$orderId/cancel',
        body: {},
        token: _authService.token,
      );

      final data = jsonDecode(response);
      return Order.fromJson(data['order']);
    } catch (e) {
      rethrow;
    }
  }

  /// Update shipping address
  Future<Order> updateShippingAddress(
    String orderId,
    String address,
  ) async {
    try {
      final response = await _apiService.put(
        '/orders/$orderId/shipping-address',
        body: {'address': address},
        token: _authService.token,
      );

      final data = jsonDecode(response);
      return Order.fromJson(data['order']);
    } catch (e) {
      rethrow;
    }
  }
}

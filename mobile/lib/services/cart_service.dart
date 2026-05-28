import 'dart:convert';
import 'api_service.dart';
import 'auth_service.dart';
import '../models/cart_model.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  CartService._internal();
  factory CartService() => _instance;

  Cart _parseCartResponse(String responseStr) {
    final data = jsonDecode(responseStr) as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      final itemsList = data['data'] as List;
      final items = itemsList.map((x) => CartItem.fromJson(x as Map<String, dynamic>)).toList();
      return Cart(items: items);
    }
    return Cart(items: []);
  }

  /// Get current cart from server — GET /api/v1/cart
  Future<Cart> getCart() async {
    if (!_authService.isAuthenticated) return Cart(items: []);
    try {
      final response = await _apiService.get(
        '/cart',
        token: _authService.token,
      );
      return _parseCartResponse(response);
    } catch (e) {
      return Cart(items: []);
    }
  }

  /// Add item to backend cart — POST /api/v1/cart
  Future<Cart> addToCart({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    if (!_authService.isAuthenticated) return Cart(items: []);
    final response = await _apiService.post(
      '/cart',
      body: {
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'quantity': quantity,
      },
      token: _authService.token,
    );
    return _parseCartResponse(response);
  }

  /// Update item quantity — PUT /api/v1/cart/{id}
  Future<Cart> updateQuantity(String cartItemId, int quantity) async {
    if (!_authService.isAuthenticated) return Cart(items: []);
    final response = await _apiService.put(
      '/cart/$cartItemId',
      body: {
        'quantity': quantity,
      },
      token: _authService.token,
    );
    return _parseCartResponse(response);
  }

  /// Remove item from cart — DELETE /api/v1/cart/{id}
  Future<Cart> removeCartItem(String cartItemId) async {
    if (!_authService.isAuthenticated) return Cart(items: []);
    final response = await _apiService.delete(
      '/cart/$cartItemId',
      token: _authService.token,
    );
    return _parseCartResponse(response);
  }

  /// Clear entire cart — DELETE /api/v1/cart
  Future<Cart> clearCart() async {
    if (!_authService.isAuthenticated) return Cart(items: []);
    final response = await _apiService.delete(
      '/cart',
      token: _authService.token,
    );
    return _parseCartResponse(response);
  }

  /// Create order (checkout) — POST /api/v1/orders
  Future<Map<String, dynamic>> createOrder({
    required List<CartItem> items,
    String? addressId,
    ShippingAddress? shippingAddress,
    String? note,
    String paymentMethod = 'payos',
  }) async {
    final body = <String, dynamic>{
      'items': items.map((item) => <String, dynamic>{
        'product_id': item.productId,
        if (item.variantId != null) 'variant_id': item.variantId,
        'quantity': item.quantity,
      }).toList(),
      'payment_method': paymentMethod,
      if (note != null && note.isNotEmpty) 'note': note,
      if (addressId != null) 'address_id': addressId,
      if (shippingAddress != null && addressId == null)
        'shipping_address': shippingAddress.toJson(),
    };

    final response = await _apiService.post(
      '/orders',
      body: body,
      token: _authService.token,
    );

    final data = jsonDecode(response) as Map<String, dynamic>;
    if (data['success'] == true && data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Checkout failed');
  }

  /// Get user orders — GET /api/v1/orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _apiService.get(
      '/orders',
      token: _authService.token,
    );
    final data = jsonDecode(response) as Map<String, dynamic>;
    if (data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }

  /// Cancel order — POST /api/v1/orders/{id}/cancel
  Future<bool> cancelOrder(String orderId) async {
    final response = await _apiService.post(
      '/orders/$orderId/cancel',
      body: {},
      token: _authService.token,
    );
    final data = jsonDecode(response) as Map<String, dynamic>;
    return data['success'] == true;
  }
}

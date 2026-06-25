import '../models/cart_model.dart';
import '../core/network/api_client.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  final ApiClient _apiClient = ApiClient();

  CartService._internal();
  factory CartService() => _instance;

  /// Parse the Dio response data (already decoded JSON map)
  Cart _parseCartData(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (responseData['success'] == true && data != null && data is List) {
        final items = data
            .map((x) => CartItem.fromJson(x as Map<String, dynamic>))
            .toList();
        return Cart(items: items);
      }
    }
    return Cart(items: []);
  }

  /// Get current cart from server — GET /api/v1/cart
  Future<Cart> getCart() async {
    try {
      final response = await _apiClient.dio.get('/cart');
      return _parseCartData(response.data);
    } catch (e) {
      return Cart(items: []);
    }
  }

  /// Get product variants — GET /api/v1/cart/variants/{productId}
  Future<List<Map<String, dynamic>>> getProductVariants(String productId) async {
    try {
      final response = await _apiClient.dio.get('/cart/variants/$productId');
      final data = response.data;
      if (data is Map<String, dynamic> &&
          data['success'] == true &&
          data['data'] != null) {
        return List<Map<String, dynamic>>.from(data['data'] as List);
      }
      return [];
    } catch (e) {
      print('❌ getProductVariants error: $e');
      return [];
    }
  }

  /// Add item to backend cart — POST /api/v1/cart
  Future<Cart> addToCart({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final response = await _apiClient.dio.post(
      '/cart',
      data: {
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'quantity': quantity,
      },
    );
    return _parseCartData(response.data);
  }

  /// Update item quantity — PUT /api/v1/cart/{id}
  Future<Cart> updateQuantity(String cartItemId, int quantity) async {
    final response = await _apiClient.dio.put(
      '/cart/$cartItemId',
      data: {'quantity': quantity},
    );
    return _parseCartData(response.data);
  }

  /// Remove item from cart — DELETE /api/v1/cart/{id}
  Future<Cart> removeCartItem(String cartItemId) async {
    final response = await _apiClient.dio.delete('/cart/$cartItemId');
    return _parseCartData(response.data);
  }

  /// Clear entire cart — DELETE /api/v1/cart
  Future<Cart> clearCart() async {
    final response = await _apiClient.dio.delete('/cart');
    return _parseCartData(response.data);
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

    final response = await _apiClient.dio.post('/orders', data: body);
    final data = response.data;
    if (data is Map<String, dynamic> &&
        data['success'] == true &&
        data['data'] != null) {
      return data['data'] as Map<String, dynamic>;
    }
    throw Exception(data['error'] ?? data['message'] ?? 'Checkout failed');
  }

  /// Get user orders — GET /api/v1/orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    final response = await _apiClient.dio.get('/orders');
    final data = response.data;
    if (data is Map<String, dynamic> && data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['data'] as List);
    }
    return [];
  }

  /// Cancel order — POST /api/v1/orders/{id}/cancel
  Future<bool> cancelOrder(String orderId) async {
    try {
      final response = await _apiClient.dio.post('/orders/$orderId/cancel', data: {});
      final data = response.data;
      return data is Map<String, dynamic> && data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}

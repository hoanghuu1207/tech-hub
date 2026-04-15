import 'dart:convert';
import '../models/index.dart';
import 'api_service.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  final ApiService _apiService = ApiService();

  ProductService._internal();

  factory ProductService() {
    return _instance;
  }

  /// Get trending products
  Future<List<Product>> getTrendingProducts() async {
    try {
      final response = await _apiService.get('/products/trending');
      final data = jsonDecode(response);
      
      return (data['results'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get products by category
  Future<List<Product>> getProductsByCategory(
    String categoryName, {
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? filterSpecs,
  }) async {
    try {
      final response = await _apiService.get(
        '/products',
        queryParams: {
          'category': categoryName,
          'page': page,
          'limit': limit,
          if (sortBy != null) 'sort_by': sortBy,
          if (filterSpecs != null) 'filter_specs': filterSpecs,
        },
      );

      final data = jsonDecode(response);
      return (data['results'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Search products
  Future<List<Product>> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiService.get(
        '/products/search',
        queryParams: {
          'q': query,
          'page': page,
          'limit': limit,
        },
      );

      final data = jsonDecode(response);
      return (data['results'] as List)
          .map((item) => Product.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Get product by ID
  Future<Product> getProductById(String productId) async {
    try {
      final response = await _apiService.get('/products/$productId');
      final data = jsonDecode(response);
      
      return Product.fromJson(data['product']);
    } catch (e) {
      rethrow;
    }
  }

  /// Get product reviews
  Future<List<Review>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _apiService.get(
        '/products/$productId/reviews',
        queryParams: {'page': page, 'limit': limit},
      );

      final data = jsonDecode(response);
      return (data['results'] as List)
          .map((item) => Review.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  /// Compare products
  Future<Map<String, dynamic>> compareProducts(List<String> productIds) async {
    try {
      final response = await _apiService.post(
        '/products/compare',
        body: {'product_ids': productIds},
      );

      return jsonDecode(response);
    } catch (e) {
      rethrow;
    }
  }

  /// Get categories
  Future<List<Category>> getCategories() async {
    try {
      final response = await _apiService.get('/categories');
      final data = jsonDecode(response);
      
      return (data['results'] as List)
          .map((item) => Category.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }
}

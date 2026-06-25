import '../models/index.dart';
import '../core/network/api_client.dart';
import '../core/network/exceptions.dart';

class ProductService {
  static final ProductService _instance = ProductService._internal();
  final ApiClient _apiClient = ApiClient();

  ProductService._internal();

  factory ProductService() {
    return _instance;
  }

  /// Get trending/featured products using AI search
  /// Since backend has no /products endpoint, we use /ai/search with a broad query
  Future<List<Product>> getTrendingProducts() async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/search',
        data: {
          'query': 'sản phẩm công nghệ nổi bật bán chạy',
          'limit': 20,
        },
      );
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> results = data['data']['products'] ?? [];
        return results
            .map((item) => Product.fromAISearch(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get products by category using AI search with category filter
  Future<List<Product>> getProductsByCategory(
    String categoryName, {
    int page = 1,
    int limit = 20,
    String? sortBy,
    String? filterSpecs,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/search',
        data: {
          'query': categoryName,
          'filters': {
            'category': categoryName,
          },
          'limit': limit,
        },
      );

      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> results = data['data']['products'] ?? [];
        return results
            .map((item) => Product.fromAISearch(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Search products using AI semantic search
  Future<List<Product>> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/search',
        data: {
          'query': query,
          'limit': limit,
        },
      );

      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> results = data['data']['products'] ?? [];
        return results
            .map((item) => Product.fromAISearch(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  /// Get product by ID - not available in current API, use search by name
  Future<Product> getProductById(String productId) async {
    try {
      final response = await _apiClient.dio.post(
        '/ai/search',
        data: {
          'query': productId,
          'limit': 1,
        },
      );
      final data = response.data;

      if (data['success'] == true && data['data'] != null) {
        final List<dynamic> results = data['data']['products'] ?? [];
        if (results.isNotEmpty) {
          return Product.fromAISearch(results.first as Map<String, dynamic>);
        }
      }
      throw NotFoundException('Product not found');
    } catch (e) {
      rethrow;
    }
  }

  /// Get product reviews - not available in current API
  Future<List<Review>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  }) async {
    // API doesn't have reviews endpoint yet
    return [];
  }

  /// Compare products
  Future<Map<String, dynamic>> compareProducts(List<String> productIds) async {
    try {
      final response = await _apiClient.dio.post(
        '/products/compare',
        data: {'product_ids': productIds},
      );

      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  /// Get categories - derived from AI search results since no dedicated endpoint
  /// Returns hardcoded categories matching the scraped data
  Future<List<Category>> getCategories() async {
    // Backend doesn't have a /categories endpoint
    // Return known categories from the scraped product data
    return [
      Category(id: 'dien-thoai', name: 'Điện thoại', icon: 'phone', description: 'Smartphone', itemCount: 0),
      Category(id: 'laptop', name: 'Laptop', icon: 'laptop', description: 'Laptop', itemCount: 0),
      Category(id: 'tablet', name: 'Tablet', icon: 'tablet', description: 'Máy tính bảng', itemCount: 0),
      Category(id: 'tai-nghe', name: 'Tai nghe', icon: 'headphone', description: 'Tai nghe', itemCount: 0),
      Category(id: 'dong-ho', name: 'Đồng hồ', icon: 'watch', description: 'Smartwatch', itemCount: 0),
      Category(id: 'phu-kien', name: 'Phụ kiện', icon: 'accessory', description: 'Phụ kiện', itemCount: 0),
    ];
  }
}

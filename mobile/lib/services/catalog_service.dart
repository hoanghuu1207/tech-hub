import '../models/catalog_models.dart';
import '../core/network/api_client.dart';

/// Singleton service for the /catalog/* browsing endpoints.
class CatalogService {
  static final CatalogService _instance = CatalogService._internal();
  final ApiClient _apiClient = ApiClient();

  CatalogService._internal();

  factory CatalogService() => _instance;

  // ── GET /catalog/products ──
  Future<List<ProductCompact>> getAllProducts({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/catalog/products',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = response.data;
    final List<dynamic> items = data['data']?['products'] ?? [];
    return items
        .map((e) => ProductCompact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Total product count from the last getAllProducts call.
  Future<int> getAllProductsTotal() async {
    final response = await _apiClient.dio.get(
      '/catalog/products',
      queryParameters: {'limit': '1', 'offset': '0'},
    );
    final data = response.data;
    return (data['data']?['total'] as num?)?.toInt() ?? 0;
  }

  // ── GET /catalog/categories ──
  Future<List<CatalogCategory>> getCategories() async {
    final response = await _apiClient.dio.get('/catalog/categories');
    final data = response.data;
    final List<dynamic> items = data['data'] ?? [];
    return items
        .map((e) => CatalogCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── GET /catalog/categories/{id} ──
  Future<({List<CatalogBrand> brands, List<ProductCompact> products, int total})>
      getCategoryProducts(
    String categoryId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/catalog/categories/$categoryId',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = response.data['data'];
    return (
      brands: (data['brands'] as List<dynamic>?)
              ?.map((b) => CatalogBrand.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
      products: (data['products'] as List<dynamic>?)
              ?.map(
                  (p) => ProductCompact.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── GET /catalog/categories/{cat}/brands/{brand} ──
  Future<
      ({
        List<CatalogProductLine> lines,
        List<ProductCompact> products,
        int total,
      })> getBrandProducts(
    String categoryId,
    String brandId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/catalog/categories/$categoryId/brands/$brandId',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = response.data['data'];
    return (
      lines: (data['product_lines'] as List<dynamic>?)
              ?.map((l) =>
                  CatalogProductLine.fromJson(l as Map<String, dynamic>))
              .toList() ??
          [],
      products: (data['products'] as List<dynamic>?)
              ?.map(
                  (p) => ProductCompact.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── GET /catalog/product-lines/{id} ──
  Future<({List<ProductCompact> products, int total})> getLineProducts(
    String lineId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.dio.get(
      '/catalog/product-lines/$lineId',
      queryParameters: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = response.data['data'];
    return (
      products: (data['products'] as List<dynamic>?)
              ?.map(
                  (p) => ProductCompact.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      total: (data['total'] as num?)?.toInt() ?? 0,
    );
  }

  // ── GET /catalog/products/{productId} ──
  Future<ProductDetail> getProductDetail(String productId) async {
    final response = await _apiClient.dio.get('/catalog/products/$productId');
    final data = response.data;
    if (data['success'] == true && data['data'] != null) {
      return ProductDetail.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw Exception('Product not found');
  }
}

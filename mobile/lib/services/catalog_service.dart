import 'dart:convert';
import '../models/catalog_models.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Singleton service for the /catalog/* browsing endpoints.
class CatalogService {
  static final CatalogService _instance = CatalogService._internal();
  final ApiService _apiService = ApiService();
  final AuthService _authService = AuthService();

  CatalogService._internal();

  factory CatalogService() => _instance;

  // ── GET /catalog/products ──
  Future<List<ProductCompact>> getAllProducts({
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiService.get(
      '/catalog/products',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = jsonDecode(response);
    final List<dynamic> items = data['data']?['products'] ?? [];
    return items
        .map((e) => ProductCompact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Total product count from the last getAllProducts call.
  Future<int> getAllProductsTotal() async {
    final response = await _apiService.get(
      '/catalog/products',
      queryParams: {'limit': '1', 'offset': '0'},
    );
    final data = jsonDecode(response);
    return (data['data']?['total'] as num?)?.toInt() ?? 0;
  }

  // ── GET /catalog/categories ──
  Future<List<CatalogCategory>> getCategories() async {
    final response = await _apiService.get('/catalog/categories');
    final data = jsonDecode(response);
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
    final response = await _apiService.get(
      '/catalog/categories/$categoryId',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = jsonDecode(response)['data'];
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
    final response = await _apiService.get(
      '/catalog/categories/$categoryId/brands/$brandId',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = jsonDecode(response)['data'];
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
    final response = await _apiService.get(
      '/catalog/product-lines/$lineId',
      queryParams: {'limit': '$limit', 'offset': '$offset'},
    );
    final data = jsonDecode(response)['data'];
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
    final response = await _apiService.get(
      '/catalog/products/$productId',
      token: _authService.isAuthenticated ? _authService.token : null,
    );
    final data = jsonDecode(response);
    if (data['success'] == true && data['data'] != null) {
      return ProductDetail.fromJson(data['data'] as Map<String, dynamic>);
    }
    throw NotFoundException('Product not found');
  }
}

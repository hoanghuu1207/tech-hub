/// Catalog browsing models — separate from the AI-search-based Product model.
/// These match the /catalog/* API endpoints.

class CatalogBrand {
  final String id;
  final String name;
  final String slug;
  final String? logoUrl;

  const CatalogBrand({
    required this.id,
    required this.name,
    required this.slug,
    this.logoUrl,
  });

  factory CatalogBrand.fromJson(Map<String, dynamic> json) {
    return CatalogBrand(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      logoUrl: json['logo_url'] as String?,
    );
  }
}

class CatalogProductLine {
  final String id;
  final String name;
  final String slug;
  final String brandId;
  final String categoryId;

  const CatalogProductLine({
    required this.id,
    required this.name,
    required this.slug,
    required this.brandId,
    required this.categoryId,
  });

  factory CatalogProductLine.fromJson(Map<String, dynamic> json) {
    return CatalogProductLine(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      brandId: json['brand_id'] as String? ?? '',
      categoryId: json['category_id'] as String? ?? '',
    );
  }
}

class CatalogCategory {
  final String id;
  final String name;
  final String slug;
  final String? iconUrl;
  final String? description;
  final int sortOrder;
  final List<CatalogBrand> brands;

  const CatalogCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.iconUrl,
    this.description,
    this.sortOrder = 0,
    this.brands = const [],
  });

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      iconUrl: json['icon_url'] as String?,
      description: json['description'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      brands: (json['brands'] as List<dynamic>?)
              ?.map((b) => CatalogBrand.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class ProductCompact {
  final String id;
  final String name;
  final String slug;
  final double basePrice;
  final double? salePrice;
  final String? primaryImage;
  final String? brandName;
  final String? categoryName;
  final String? lineName;
  final double ratingAvg;
  final int soldCount;

  const ProductCompact({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    this.salePrice,
    this.primaryImage,
    this.brandName,
    this.categoryName,
    this.lineName,
    this.ratingAvg = 0.0,
    this.soldCount = 0,
  });

  double get displayPrice => salePrice ?? basePrice;
  bool get hasDiscount => salePrice != null && salePrice! < basePrice;
  double get discountPercent =>
      hasDiscount ? ((basePrice - salePrice!) / basePrice * 100) : 0;

  factory ProductCompact.fromJson(Map<String, dynamic> json) {
    return ProductCompact(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      primaryImage: json['primary_image'] as String?,
      brandName: json['brand_name'] as String?,
      categoryName: json['category_name'] as String?,
      lineName: json['line_name'] as String?,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
    );
  }
}


// ─── Product Detail Models ────────────────────────────────

class ProductVariantDetail {
  final String id;
  final String colorName;
  final String? colorHex;
  final double? priceOverride;
  final double? salePriceOverride;
  final int stockQuantity;

  bool get inStock => stockQuantity > 0;

  const ProductVariantDetail({
    required this.id,
    required this.colorName,
    this.colorHex,
    this.priceOverride,
    this.salePriceOverride,
    this.stockQuantity = 0,
  });

  factory ProductVariantDetail.fromJson(Map<String, dynamic> json) {
    return ProductVariantDetail(
      id: json['id'] as String,
      colorName: json['color_name'] as String? ?? '',
      colorHex: json['color_hex'] as String?,
      priceOverride: (json['price_override'] as num?)?.toDouble(),
      salePriceOverride: (json['sale_price_override'] as num?)?.toDouble(),
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
    );
  }
}


class ProductImageDetail {
  final String id;
  final String imageUrl;
  final bool isPrimary;
  final int sortOrder;

  const ProductImageDetail({
    required this.id,
    required this.imageUrl,
    this.isPrimary = false,
    this.sortOrder = 0,
  });

  factory ProductImageDetail.fromJson(Map<String, dynamic> json) {
    return ProductImageDetail(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      isPrimary: json['is_primary'] as bool? ?? false,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}


class ProductDetail {
  final String id;
  final String name;
  final String slug;
  final double basePrice;
  final double? salePrice;
  final String? description;
  final List<String> highlightFeatures;
  final double ratingAvg;
  final int ratingCount;
  final int soldCount;
  final String status;
  final Map<String, dynamic>? brand;
  final Map<String, dynamic>? category;
  final Map<String, dynamic>? line;
  final List<ProductVariantDetail> variants;
  final List<ProductImageDetail> images;
  final Map<String, dynamic> specs;

  // Computed properties
  String get brandName => brand?['name'] as String? ?? '';
  String get categoryName => category?['name'] as String? ?? '';
  String get lineName => line?['name'] as String? ?? '';
  double get displayPrice => salePrice ?? basePrice;
  bool get hasDiscount => salePrice != null && salePrice! < basePrice;
  int get discountPercent =>
      hasDiscount ? ((basePrice - salePrice!) / basePrice * 100).round() : 0;

  String? get primaryImage => images.isNotEmpty
      ? (images.cast<ProductImageDetail?>().firstWhere(
            (i) => i!.isPrimary,
            orElse: () => images.first,
          ))!.imageUrl
      : null;

  int get totalStock => variants.fold(0, (sum, v) => sum + v.stockQuantity);

  /// Get the effective price for a specific variant
  double getVariantPrice(ProductVariantDetail variant) {
    return variant.salePriceOverride ??
        variant.priceOverride ??
        salePrice ??
        basePrice;
  }

  const ProductDetail({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    this.salePrice,
    this.description,
    this.highlightFeatures = const [],
    this.ratingAvg = 0.0,
    this.ratingCount = 0,
    this.soldCount = 0,
    this.status = 'new',
    this.brand,
    this.category,
    this.line,
    this.variants = const [],
    this.images = const [],
    this.specs = const {},
  });

  factory ProductDetail.fromJson(Map<String, dynamic> json) {
    return ProductDetail(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String? ?? '',
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      description: json['description'] as String?,
      highlightFeatures: List<String>.from(json['highlight_features'] ?? []),
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'new',
      brand: json['brand'] as Map<String, dynamic>?,
      category: json['category'] as Map<String, dynamic>?,
      line: json['line'] as Map<String, dynamic>?,
      variants: (json['variants'] as List<dynamic>?)
              ?.map((e) =>
                  ProductVariantDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      images: (json['images'] as List<dynamic>?)
              ?.map((e) =>
                  ProductImageDetail.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      specs: json['specs'] as Map<String, dynamic>? ?? {},
    );
  }
}

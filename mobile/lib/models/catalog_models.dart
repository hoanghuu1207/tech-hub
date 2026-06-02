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

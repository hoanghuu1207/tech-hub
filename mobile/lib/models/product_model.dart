enum ProductCategory { phone, laptop, tablet, headphone, smartwatch, accessory }

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final double rating;
  final int reviewCount;
  final int stock;
  final List<String> images;
  final ProductCategory category;
  final Map<String, dynamic> specs;
  final String sellerId;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.stock,
    required this.images,
    required this.category,
    required this.specs,
    required this.sellerId,
    required this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      originalPrice: json['original_price'] != null 
          ? (json['original_price'] as num).toDouble() 
          : null,
      rating: (json['rating'] as num).toDouble(),
      reviewCount: json['review_count'] as int,
      stock: json['stock'] as int,
      images: List<String>.from(json['images'] as List),
      category: ProductCategory.values.byName(json['category'] as String),
      specs: json['specs'] as Map<String, dynamic>,
      sellerId: json['seller_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Factory from AI Search API response (AIProductResult schema)
  factory Product.fromAISearch(Map<String, dynamic> json) {
    final basePrice = json['base_price'] != null ? (json['base_price'] as num).toDouble() : 0.0;
    final salePrice = json['sale_price'] != null ? (json['sale_price'] as num).toDouble() : null;
    final primaryImage = json['primary_image'] as String? ?? '';
    final categorySlug = (json['category_slug'] as String? ?? '').toLowerCase();

    ProductCategory cat = ProductCategory.phone;
    if (categorySlug.contains('laptop')) cat = ProductCategory.laptop;
    else if (categorySlug.contains('tablet')) cat = ProductCategory.tablet;
    else if (categorySlug.contains('tai-nghe') || categorySlug.contains('headphone')) cat = ProductCategory.headphone;
    else if (categorySlug.contains('dong-ho') || categorySlug.contains('watch')) cat = ProductCategory.smartwatch;
    else if (categorySlug.contains('phu-kien') || categorySlug.contains('accessory')) cat = ProductCategory.accessory;

    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['brand_name'] as String? ?? '',
      price: salePrice ?? basePrice,
      originalPrice: salePrice != null && salePrice < basePrice ? basePrice : null,
      rating: json['rating_avg'] != null ? (json['rating_avg'] as num).toDouble() : 4.5,
      reviewCount: json['sold_count'] as int? ?? 0,
      stock: 100, // AI search doesn't return stock, assume in stock
      images: primaryImage.isNotEmpty ? [primaryImage] : [],
      category: cat,
      specs: {},
      sellerId: json['brand_slug'] as String? ?? '',
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'original_price': originalPrice,
      'rating': rating,
      'review_count': reviewCount,
      'stock': stock,
      'images': images,
      'category': category.name,
      'specs': specs,
      'seller_id': sellerId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  double get discount {
    if (originalPrice == null) return 0;
    return ((originalPrice! - price) / originalPrice! * 100);
  }

  bool get inStock => stock > 0;
}

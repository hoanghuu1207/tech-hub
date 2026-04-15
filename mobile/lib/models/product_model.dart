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

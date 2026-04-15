class Review {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String userAvatar;
  final double rating;
  final String title;
  final String content;
  final List<String> images;
  final int helpful;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.rating,
    required this.title,
    required this.content,
    required this.images,
    required this.helpful,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userAvatar: json['user_avatar'] as String,
      rating: (json['rating'] as num).toDouble(),
      title: json['title'] as String,
      content: json['content'] as String,
      images: List<String>.from(json['images'] as List? ?? []),
      helpful: json['helpful'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'user_name': userName,
      'user_avatar': userAvatar,
      'rating': rating,
      'title': title,
      'content': content,
      'images': images,
      'helpful': helpful,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

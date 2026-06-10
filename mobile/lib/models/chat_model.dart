enum ChatMessageRole { user, assistant }

class ChatVariant {
  final String variantId;
  final String colorName;
  final String colorHex;
  final double price;
  final int stockQuantity;

  ChatVariant({
    required this.variantId,
    required this.colorName,
    required this.colorHex,
    required this.price,
    required this.stockQuantity,
  });

  factory ChatVariant.fromJson(Map<String, dynamic> json) {
    return ChatVariant(
      variantId: json['variant_id'] ?? '',
      colorName: json['color_name'] ?? '',
      colorHex: json['color_hex'] ?? '#888888',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stockQuantity: json['stock_quantity'] ?? 0,
    );
  }
}

class ChatActionData {
  final String action;
  final Map<String, dynamic> _raw;

  ChatActionData({required this.action, required Map<String, dynamic> raw}) : _raw = raw;

  factory ChatActionData.fromJson(Map<String, dynamic> json) {
    return ChatActionData(action: json['action'] ?? '', raw: json);
  }

  /// Expose the raw map for navigation data passing
  Map<String, dynamic> get rawData => _raw;

  // Helpers
  List<ChatVariant>? get variants {
    final list = _raw['variants'] as List?;
    return list?.map((v) => ChatVariant.fromJson(v as Map<String, dynamic>)).toList();
  }

  String? get checkoutUrl => _raw['checkout_url'];
  String? get productName => _raw['product_name'];
  String? get productId => _raw['product_id'];
  String? get productSlug => _raw['product_slug'];
  String? get colorName => _raw['color_name'];
  int? get orderCode => _raw['order_code'];
  double? get totalAmount => (_raw['total_amount'] as num?)?.toDouble();
  int? get totalItems => _raw['total_items'];
  String? get orderId => _raw['order_id'];
  int? get quantity => _raw['quantity'];
  List<String>? get productIds => (_raw['product_ids'] as List?)?.cast<String>();
  List<String>? get orderIds => (_raw['order_ids'] as List?)?.cast<String>();
}

class ChatMessage {
  final String id;
  final ChatMessageRole role;
  final String content;
  final DateTime timestamp;
  final bool isLoading;
  final String? intentType;
  final ChatActionData? actionData;
  final List<dynamic>? products;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    this.isLoading = false,
    this.intentType,
    this.actionData,
    this.products,
  });

  ChatMessage copyWith({String? content, bool? isLoading}) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      timestamp: timestamp,
      isLoading: isLoading ?? this.isLoading,
      intentType: intentType,
      actionData: actionData,
      products: products,
    );
  }
}

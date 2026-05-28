class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String? variantId;
  final String? colorName;
  final String? colorHex;
  int quantity;
  final double unitPrice;
  final String? imageUrl;

  CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.variantId,
    this.colorName,
    this.colorHex,
    required this.quantity,
    required this.unitPrice,
    this.imageUrl,
  });

  double get subtotal => unitPrice * quantity;

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      variantId: json['variant_id'],
      colorName: json['color_name'],
      colorHex: json['color_hex'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      imageUrl: json['product_image'] ?? json['image_url'],
    );
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      productId: productId,
      productName: productName,
      variantId: variantId,
      colorName: colorName,
      colorHex: colorHex,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      imageUrl: imageUrl,
    );
  }
}

class ShippingAddress {
  final String? id;
  final String recipientName;
  final String phone;
  final String? province;
  final String? district;
  final String? ward;
  final String? street;

  ShippingAddress({
    this.id,
    required this.recipientName,
    required this.phone,
    this.province,
    this.district,
    this.ward,
    this.street,
  });

  String get fullAddress {
    return [street, ward, district, province]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }

  Map<String, dynamic> toJson() => {
    'recipient_name': recipientName,
    'phone': phone,
    'province': province,
    'district': district,
    'ward': ward,
    'street': street,
  };

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      id: json['id'],
      recipientName: json['recipient_name'] ?? '',
      phone: json['phone'] ?? '',
      province: json['province'],
      district: json['district'],
      ward: json['ward'],
      street: json['street'],
    );
  }
}

class Cart {
  final List<CartItem> items;

  Cart({required this.items});

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Cart removeItem(String itemId) {
    return Cart(items: items.where((i) => i.id != itemId).toList());
  }

  Cart updateQuantity(String itemId, int quantity) {
    return Cart(
      items: items.map((item) {
        return item.id == itemId ? item.copyWith(quantity: quantity) : item;
      }).toList(),
    );
  }
}

import 'product_model.dart';

class CartItem {
  final String id;
  final Product product;
  int quantity;
  final DateTime addedAt;

  CartItem({
    required this.id,
    required this.product,
    required this.quantity,
    required this.addedAt,
  });

  double get subtotal => product.price * quantity;

  CartItem copyWith({
    String? id,
    Product? product,
    int? quantity,
    DateTime? addedAt,
  }) {
    return CartItem(
      id: id ?? this.id,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] as String,
      product: Product.fromJson(json['product'] as Map<String, dynamic>),
      quantity: json['quantity'] as int,
      addedAt: DateTime.parse(json['added_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product': product.toJson(),
      'quantity': quantity,
      'added_at': addedAt.toIso8601String(),
    };
  }
}

class Cart {
  final List<CartItem> items;
  final DateTime updatedAt;

  Cart({
    required this.items,
    required this.updatedAt,
  });

  double get total => items.fold(0, (sum, item) => sum + item.subtotal);

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Cart addItem(CartItem item) {
    final existingIndex = items.indexWhere((i) => i.product.id == item.product.id);
    List<CartItem> updated = List.from(items);
    
    if (existingIndex >= 0) {
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + item.quantity,
      );
    } else {
      updated.add(item);
    }
    
    return Cart(items: updated, updatedAt: DateTime.now());
  }

  Cart removeItem(String itemId) {
    return Cart(
      items: items.where((item) => item.id != itemId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Cart updateQuantity(String itemId, int quantity) {
    return Cart(
      items: items.map((item) {
        return item.id == itemId ? item.copyWith(quantity: quantity) : item;
      }).toList(),
      updatedAt: DateTime.now(),
    );
  }

  Cart clear() {
    return Cart(items: [], updatedAt: DateTime.now());
  }
}

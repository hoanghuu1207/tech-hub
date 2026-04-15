import 'product_model.dart';

enum OrderStatus { pending, confirmed, shipped, delivered, cancelled }
enum PaymentStatus { pending, paid, failed }

class OrderItem {
  final String productId;
  final String productName;
  final double price;
  final int quantity;
  final String productImage;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.productImage,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      price: (json['price'] as num).toDouble(),
      quantity: json['quantity'] as int,
      productImage: json['product_image'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'product_name': productName,
      'price': price,
      'quantity': quantity,
      'product_image': productImage,
    };
  }
}

class Order {
  final String id;
  final String userId;
  final List<OrderItem> items;
  final double subtotal;
  final double shippingFee;
  final double tax;
  final double total;
  final String shippingAddress;
  final String shippingPhone;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final String? paymentMethod;
  final String? trackingNumber;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.subtotal,
    required this.shippingFee,
    required this.tax,
    required this.total,
    required this.shippingAddress,
    required this.shippingPhone,
    required this.status,
    required this.paymentStatus,
    this.paymentMethod,
    this.trackingNumber,
    required this.createdAt,
    this.deliveredAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      items: List<OrderItem>.from(
        (json['items'] as List).map((item) => OrderItem.fromJson(item as Map<String, dynamic>)),
      ),
      subtotal: (json['subtotal'] as num).toDouble(),
      shippingFee: (json['shipping_fee'] as num).toDouble(),
      tax: (json['tax'] as num).toDouble(),
      total: (json['total'] as num).toDouble(),
      shippingAddress: json['shipping_address'] as String,
      shippingPhone: json['shipping_phone'] as String,
      status: OrderStatus.values.byName(json['status'] as String),
      paymentStatus: PaymentStatus.values.byName(json['payment_status'] as String),
      paymentMethod: json['payment_method'] as String?,
      trackingNumber: json['tracking_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      deliveredAt: json['delivered_at'] != null 
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'shipping_fee': shippingFee,
      'tax': tax,
      'total': total,
      'shipping_address': shippingAddress,
      'shipping_phone': shippingPhone,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod,
      'tracking_number': trackingNumber,
      'created_at': createdAt.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
    };
  }
}

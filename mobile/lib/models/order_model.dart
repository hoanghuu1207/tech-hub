/// Order models — matched to actual API response shape.

class OrderAddress {
  final String id;
  final String recipientName;
  final String phone;
  final String? province;
  final String? district;
  final String? ward;
  final String? street;

  OrderAddress({
    required this.id,
    required this.recipientName,
    required this.phone,
    this.province,
    this.district,
    this.ward,
    this.street,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      id: json['id'] as String,
      recipientName: json['recipient_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      province: json['province'] as String?,
      district: json['district'] as String?,
      ward: json['ward'] as String?,
      street: json['street'] as String?,
    );
  }

  /// Join non-null address parts into a single string.
  String get fullAddress {
    return [street, ward, district, province]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
  }
}

class OrderItem {
  final String id;
  final String productId;
  final String? variantId;
  final String? productName;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double subtotal;

  OrderItem({
    required this.id,
    required this.productId,
    this.variantId,
    this.productName,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String?,
      productName: json['product_name'] as String?,
      productImage: json['product_image'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
    );
  }
}

class Order {
  final String id;
  final int? orderCode;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final double discountAmount;
  final double shippingFee;
  final String? paymentMethod;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;
  final OrderAddress? address;

  Order({
    required this.id,
    this.orderCode,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    this.discountAmount = 0,
    this.shippingFee = 0,
    this.paymentMethod,
    this.note,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.address,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderCode: json['order_code'] as int?,
      status: json['status'] as String? ?? 'pending_payment',
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
      shippingFee: (json['shipping_fee'] as num?)?.toDouble() ?? 0,
      paymentMethod: json['payment_method'] as String?,
      note: json['note'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)?.toLocal()
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)?.toLocal()
          : null,
      items: (json['items'] as List?)
              ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      address: json['address'] != null
          ? OrderAddress.fromJson(json['address'] as Map<String, dynamic>)
          : null,
    );
  }

  // ── Helpers ──

  String get displayOrderCode =>
      '#${orderCode ?? id.substring(0, 8).toUpperCase()}';

  int get totalItemCount =>
      items.fold<int>(0, (sum, i) => sum + i.quantity);

  String get statusLabel {
    switch (status) {
      case 'pending_payment':
        return 'Chờ thanh toán';
      case 'paid':
        return 'Đã thanh toán';
      case 'processing':
        return 'Đang xử lý';
      case 'completed':
        return 'Hoàn thành';
      case 'cancelled':
        return 'Đã hủy';
      default:
        return status;
    }
  }

  String get paymentMethodLabel {
    switch (paymentMethod) {
      case 'payos':
        return 'PayOS';
      case 'cod':
        return 'COD (Thanh toán khi nhận hàng)';
      default:
        return paymentMethod ?? 'Không xác định';
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/cart_bloc.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';

// ── Theme constants ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFFBBF24);
  static const rose = Color(0xFFF43F5E);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

/// Screen to display products returned from the chatbot's product search.
class ChatProductListScreen extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String? title;

  const ChatProductListScreen({
    Key? key,
    required this.products,
    this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _C.surface,
              shape: BoxShape.circle,
              border: Border.all(color: _C.divider),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: _C.textPrimary, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title ?? 'Kết quả tìm kiếm',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary,
              ),
            ),
            Text(
              '${products.length} sản phẩm',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: _C.textMuted,
              ),
            ),
          ],
        ),
      ),
      body: products.isEmpty
          ? _buildEmptyState()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                padding: const EdgeInsets.only(top: 16, bottom: 100),
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.52,
                ),
                itemBuilder: (context, index) {
                  return _ChatProductCard(product: products[index]);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _C.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined, color: _C.primary, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            'Không tìm thấy sản phẩm',
            style: GoogleFonts.outfit(
              color: _C.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Thử tìm kiếm với từ khóa khác',
            style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Product card for chatbot search results — matches the style of ProductsTab cards.
class _ChatProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  const _ChatProductCard({required this.product});

  @override
  State<_ChatProductCard> createState() => _ChatProductCardState();
}

class _ChatProductCardState extends State<_ChatProductCard> {
  Map<String, dynamic> get p => widget.product;

  String get _id => (p['id'] ?? '').toString();
  String get _name => p['name'] ?? '';
  String? get _image => p['primary_image'] as String?;
  String? get _brandName => p['brand_name'] as String?;
  double get _basePrice => (p['base_price'] as num?)?.toDouble() ?? 0;
  double? get _salePrice => (p['sale_price'] as num?)?.toDouble();
  double get _displayPrice => _salePrice ?? _basePrice;
  bool get _hasDiscount => _salePrice != null && _salePrice! < _basePrice;
  int get _discountPercent =>
      _hasDiscount ? ((_basePrice - _salePrice!) / _basePrice * 100).toInt() : 0;
  double get _ratingAvg => (p['rating_avg'] as num?)?.toDouble() ?? 0;
  int get _soldCount => (p['sold_count'] as num?)?.toInt() ?? 0;

  void _onAddToCart() async {
    if (!AuthService().isTokenValid) {
      AppSnackbars.showError(context, 'Vui lòng đăng nhập để thêm vào giỏ');
      return;
    }

    final variants = await CartService().getProductVariants(_id);

    if (variants.isEmpty) {
      if (!mounted) return;
      context.read<CartBloc>().add(CartAddItem(productId: _id, quantity: 1));
      AppSnackbars.showSuccess(context, '$_name đã thêm vào giỏ');
      return;
    }

    if (!mounted) return;
    final selectedVariantId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantPickerSheet(
        productName: _name,
        variants: variants,
        productImage: _image,
      ),
    );

    if (selectedVariantId != null && mounted) {
      context.read<CartBloc>().add(CartAddItem(
        productId: _id,
        variantId: selectedVariantId,
        quantity: 1,
      ));
      final picked = variants.firstWhere((v) => v['id'] == selectedVariantId);
      AppSnackbars.showSuccess(context, '$_name (${picked['color_name']}) đã thêm vào giỏ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/product-detail', arguments: _id),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: _image != null
                          ? CachedNetworkImage(
                              imageUrl: _image!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.image_outlined, color: _C.textMuted, size: 40),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image_outlined, color: _C.textMuted, size: 40),
                            ),
                    ),
                  ),
                  // Discount badge
                  if (_hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.rose,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-$_discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // ── Content ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand
                  if (_brandName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        _brandName!.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: _C.textMuted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  // Name
                  Text(
                    _name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _C.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Rating + sold
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: _C.amber),
                      const SizedBox(width: 2),
                      Text(
                        _ratingAvg.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.textSecondary,
                        ),
                      ),
                      if (_soldCount > 0)
                        Expanded(
                          child: Text(
                            ' • Đã bán $_soldCount',
                            style: GoogleFonts.outfit(fontSize: 10, color: _C.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price + Add to cart
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_hasDiscount)
                              Text(
                                AppFormatters.formatCurrency(_basePrice),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: _C.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              AppFormatters.formatCurrency(_displayPrice),
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _C.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _onAddToCart,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _C.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Variant Picker (reused pattern) ──
class _VariantPickerSheet extends StatefulWidget {
  final String productName;
  final List<Map<String, dynamic>> variants;
  final String? productImage;

  const _VariantPickerSheet({
    required this.productName,
    required this.variants,
    this.productImage,
  });

  @override
  State<_VariantPickerSheet> createState() => _VariantPickerSheetState();
}

class _VariantPickerSheetState extends State<_VariantPickerSheet> {
  int _selectedIndex = 0;

  Color _hex(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  String _fmtPrice(double p) => '${NumberFormat('#,###', 'vi_VN').format(p)}đ';

  @override
  Widget build(BuildContext context) {
    final v = widget.variants[_selectedIndex];
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (widget.productImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    widget.productImage!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF273548),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.devices, color: Color(0xFF64748B), size: 24),
                    ),
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFF8FAFC)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fmtPrice((v['price'] as num).toDouble()),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _C.emerald),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Chọn màu sắc',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: widget.variants.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final variant = widget.variants[index];
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _C.primary.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? _C.primary : const Color(0xFF334155),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: _hex(variant['color_hex']),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          variant['color_name'] ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? _C.primary : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, v['id']),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text(
                'Thêm vào giỏ hàng',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

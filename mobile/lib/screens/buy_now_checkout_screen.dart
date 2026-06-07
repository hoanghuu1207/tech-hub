import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/cart_model.dart';
import '../models/catalog_models.dart';
import '../services/cart_service.dart';
import 'payment_webview_screen.dart';
import 'payment_result_screen.dart';

// ── Design tokens (same as cart_screen) ──
class _K {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceLight = Color(0xFF273548);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const rose = Color(0xFFF43F5E);
  static const amber = Color(0xFFFBBF24);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

class BuyNowCheckoutScreen extends StatefulWidget {
  final ProductDetail product;
  final ProductVariantDetail? variant;
  final int initialQuantity;

  const BuyNowCheckoutScreen({
    Key? key,
    required this.product,
    this.variant,
    this.initialQuantity = 1,
  }) : super(key: key);

  @override
  State<BuyNowCheckoutScreen> createState() => _BuyNowCheckoutScreenState();
}

class _BuyNowCheckoutScreenState extends State<BuyNowCheckoutScreen> {
  late int _quantity;
  String _paymentMethod = 'payos';
  bool _isCheckingOut = false;

  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController(text: 'TP. Hồ Chí Minh');
  final _districtController = TextEditingController();
  final _wardController = TextEditingController();
  final _streetController = TextEditingController();

  double get _unitPrice {
    if (widget.variant != null) {
      return widget.variant!.salePriceOverride ??
          widget.variant!.priceOverride ??
          widget.product.salePrice ??
          widget.product.basePrice;
    }
    return widget.product.salePrice ?? widget.product.basePrice;
  }

  int get _stockQuantity => widget.variant?.stockQuantity ?? 999;
  double get _subtotal => _unitPrice * _quantity;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  @override
  void dispose() {
    _noteController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _wardController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _K.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductItem(),
                    const SizedBox(height: 24),
                    _buildShippingSection(),
                    const SizedBox(height: 24),
                    _buildNoteSection(),
                    const SizedBox(height: 24),
                    _buildPaymentSelector(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            _buildOrderSummary(),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
      decoration: BoxDecoration(
        color: _K.bg,
        border: Border(bottom: BorderSide(color: _K.divider.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, color: _K.textPrimary),
          ),
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _K.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.flash_on_rounded, color: _K.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mua ngay', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _K.textPrimary)),
              Text('Thanh toán nhanh', style: GoogleFonts.outfit(fontSize: 12, color: _K.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  // ── PRODUCT ITEM ──
  Widget _buildProductItem() {
    final product = widget.product;
    final variant = widget.variant;
    final isAtMax = _quantity >= _stockQuantity;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _K.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _K.primary.withOpacity(0.6)),
      ),
      child: Row(
        children: [
          // Product Image
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: product.primaryImage != null
                ? Image.network(product.primaryImage!, width: 72, height: 72, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImagePlaceholder())
                : _buildImagePlaceholder(),
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _K.textPrimary, height: 1.3)),
                const SizedBox(height: 4),
                if (variant != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 12, height: 12,
                        decoration: BoxDecoration(
                          color: _parseHex(variant.colorHex ?? '#888888'),
                          shape: BoxShape.circle,
                          border: Border.all(color: _K.textMuted, width: 1),
                        )),
                      const SizedBox(width: 6),
                      Text(variant.colorName, style: GoogleFonts.outfit(fontSize: 11, color: _K.textSecondary)),
                    ]),
                  ),
                Text(_formatPrice(_unitPrice), style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _K.emerald)),
                const SizedBox(height: 2),
                Text('Kho: $_stockQuantity', style: GoogleFonts.outfit(fontSize: 11, color: _K.textMuted)),
              ],
            ),
          ),
          // Quantity
          Column(children: [
            _buildQtyButton(Icons.add, isAtMax ? () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Chỉ còn $_stockQuantity sản phẩm trong kho',
                  style: GoogleFonts.outfit(color: Colors.white)),
                backgroundColor: _K.amber,
                duration: const Duration(seconds: 2),
              ));
            } : () {
              setState(() => _quantity++);
            }),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('$_quantity', style: GoogleFonts.outfit(
                fontSize: 16, fontWeight: FontWeight.w700, color: _K.textPrimary)),
            ),
            _buildQtyButton(Icons.remove, _quantity > 1 ? () {
              setState(() => _quantity--);
            } : null),
          ]),
        ],
      ),
    );
  }

  Widget _buildQtyButton(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: onTap != null ? _K.surfaceLight : _K.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _K.divider),
        ),
        child: Icon(icon, size: 16, color: onTap != null ? _K.textPrimary : _K.textMuted),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(color: _K.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.devices_rounded, color: _K.textMuted, size: 32),
    );
  }

  // ── SHIPPING ──
  Widget _buildShippingSection() {
    return _buildSection('Địa chỉ giao hàng', Icons.location_on_rounded, child: Column(
      children: [
        _buildInputField(_nameController, 'Họ và tên người nhận', Icons.person_outline_rounded),
        const SizedBox(height: 10),
        _buildInputField(_phoneController, 'Số điện thoại', Icons.phone_outlined, keyboardType: TextInputType.phone),
        const SizedBox(height: 10),
        _buildInputField(_provinceController, 'Tỉnh / Thành phố', Icons.location_city_rounded),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _buildInputField(_districtController, 'Quận / Huyện', null)),
          const SizedBox(width: 10),
          Expanded(child: _buildInputField(_wardController, 'Phường / Xã', null)),
        ]),
        const SizedBox(height: 10),
        _buildInputField(_streetController, 'Số nhà, đường, ngõ...', Icons.home_outlined),
      ],
    ));
  }

  // ── NOTE ──
  Widget _buildNoteSection() {
    return _buildSection('Ghi chú giao hàng', Icons.edit_note_rounded, child:
      _buildInputField(_noteController, 'Giao giờ hành chính, gọi trước...', null, maxLines: 2),
    );
  }

  // ── PAYMENT ──
  Widget _buildPaymentSelector() {
    return _buildSection('Phương thức thanh toán', Icons.payment_rounded, child: Row(
      children: [
        Expanded(child: _buildPaymentOption('payos', 'PayOS', Icons.qr_code_scanner_rounded, 'QR / Chuyển khoản')),
        const SizedBox(width: 10),
        Expanded(child: _buildPaymentOption('cod', 'COD', Icons.local_shipping_rounded, 'Thanh toán khi nhận')),
      ],
    ));
  }

  Widget _buildPaymentOption(String value, String title, IconData icon, String subtitle) {
    final isSelected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMethod = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _K.primary.withOpacity(0.1) : _K.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _K.primary : _K.divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected ? [BoxShadow(color: _K.primary.withOpacity(0.15), blurRadius: 12)] : [],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: isSelected ? _K.primary : _K.textMuted, size: 22),
                const Spacer(),
                if (isSelected)
                  Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: _K.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700,
                    color: isSelected ? _K.textPrimary : _K.textSecondary)),
                  Text(subtitle, style: GoogleFonts.outfit(fontSize: 11, color: _K.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ORDER SUMMARY (Sticky bottom) ──
  Widget _buildOrderSummary() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: _K.surface,
        border: Border(top: BorderSide(color: _K.divider.withOpacity(0.5))),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSummaryRow('Tạm tính ($_quantity sản phẩm)', _formatPrice(_subtotal)),
          const SizedBox(height: 6),
          _buildSummaryRow('Phí vận chuyển', 'Miễn phí', valueColor: _K.emerald),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _K.divider.withOpacity(0.5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: _K.textPrimary)),
              Text(_formatPrice(_subtotal), style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w800, color: _K.emerald,
              )),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isCheckingOut ? null : () => _checkout(),
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.primary,
                disabledBackgroundColor: _K.primary.withOpacity(0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isCheckingOut
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.lock_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text('Đặt hàng & Thanh toán', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700)),
                    ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 14, color: _K.textSecondary)),
        Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? _K.textPrimary)),
      ],
    );
  }

  // ── REUSABLE SECTION WRAPPER ──
  Widget _buildSection(String title, IconData icon, {required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, color: _K.primary, size: 18),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: _K.textPrimary)),
        ]),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  Widget _buildInputField(TextEditingController controller, String hint, IconData? icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: _K.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _K.divider),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.outfit(fontSize: 14, color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 14, color: _K.textMuted),
          prefixIcon: icon != null ? Icon(icon, color: _K.textMuted, size: 20) : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: icon != null ? 0 : 14, vertical: 12),
        ),
      ),
    );
  }

  // ── CHECKOUT ──
  void _checkout() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Vui lòng nhập họ tên và số điện thoại', style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: _K.amber,
      ));
      return;
    }

    // Show confirm dialog
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: _K.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _K.primary.withOpacity(0.15),
                ),
                child: const Icon(Icons.shopping_bag_outlined, color: _K.primary, size: 32),
              ),
              const SizedBox(height: 20),
              Text('Xác nhận đặt hàng',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('$_quantity sản phẩm • ${_formatPrice(_subtotal)}',
                style: GoogleFonts.outfit(color: _K.emerald, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Thanh toán qua: ${_paymentMethod == "payos" ? "PayOS" : "COD"}',
                style: GoogleFonts.outfit(color: _K.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Hủy', style: GoogleFonts.outfit(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // close dialog
                        _performCheckout();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _K.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Đồng ý',
                        style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performCheckout() async {
    setState(() => _isCheckingOut = true);

    try {
      // Build a temporary CartItem to pass to the CartService.createOrder
      final cartItem = CartItem(
        id: '', // not used for checkout
        productId: widget.product.id,
        productName: widget.product.name,
        variantId: widget.variant?.id,
        colorName: widget.variant?.colorName,
        colorHex: widget.variant?.colorHex,
        quantity: _quantity,
        unitPrice: _unitPrice,
        imageUrl: widget.product.primaryImage,
        stockQuantity: _stockQuantity,
      );

      final result = await CartService().createOrder(
        items: [cartItem],
        shippingAddress: ShippingAddress(
          recipientName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          province: _provinceController.text.trim(),
          district: _districtController.text.trim(),
          ward: _wardController.text.trim(),
          street: _streetController.text.trim(),
        ),
        note: _noteController.text.trim(),
        paymentMethod: _paymentMethod,
      );

      if (!mounted) return;

      final checkoutUrl = result['checkout_url'] as String?;
      final orderId = result['order_id']?.toString();

      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        // PayOS → open WebView
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            checkoutUrl: checkoutUrl,
            orderId: orderId ?? '',
          ),
        ));
      } else if (orderId != null) {
        // COD → direct success
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PaymentResultScreen(
            isSuccess: true,
            orderId: orderId,
          ),
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCheckingOut = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.toString(), style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: _K.rose,
      ));
    }
  }

  // ── HELPERS ──
  Color _parseHex(String hex) {
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  String _formatPrice(double price) {
    final f = NumberFormat('#,###', 'vi_VN');
    return '${f.format(price)}đ';
  }
}

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../bloc/cart_bloc.dart';
import '../../models/cart_model.dart';
import '../../services/auth_service.dart';
import 'payment_webview_screen.dart';
import 'payment_result_screen.dart';

// ── Design tokens ──
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

class CartScreen extends StatefulWidget {
  final VoidCallback? onContinueShopping;
  const CartScreen({Key? key, this.onContinueShopping}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  String _paymentMethod = 'payos';
  final Set<String> _selectedIds = {};
  final _noteController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _provinceController = TextEditingController(text: 'TP. Hồ Chí Minh');
  final _districtController = TextEditingController();
  final _wardController = TextEditingController();
  final _streetController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartBloc>().add(const CartFetch());
    });
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
    return BlocConsumer<CartBloc, CartState>(
      listener: (context, state) {
        if (state.checkoutUrl != null && state.checkoutUrl!.isNotEmpty) {
          // PayOS → open WebView
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PaymentWebViewScreen(
              checkoutUrl: state.checkoutUrl!,
              orderId: state.lastOrderId ?? '',
            ),
          ));
        }
        if (state.checkoutError != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.checkoutError!, style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: _K.rose,
          ));
        }
        if (state.lastOrderId != null && state.checkoutUrl == null && !state.isCheckingOut) {
          // COD → direct success
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PaymentResultScreen(
              isSuccess: true,
              orderId: state.lastOrderId!,
            ),
          ));
        }
      },
      builder: (context, state) {
        final user = AuthService().currentUser;
        if (user != null) {
          if (_nameController.text.isEmpty && user.fullName.isNotEmpty) {
            _nameController.text = user.fullName;
          }
          if (_phoneController.text.isEmpty && (user.phone ?? '').isNotEmpty) {
            _phoneController.text = user.phone!;
          }
        }

        if (state.cart.items.isEmpty && state.lastOrderId == null) {
          return _buildEmptyState();
        }
        return Scaffold(
          backgroundColor: _K.bg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(state.cart.itemCount),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCartItems(state.cart.items),
                        const SizedBox(height: 24),
                        _buildShippingSection(),
                        const SizedBox(height: 24),
                        _buildNoteSection(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
                _buildOrderSummary(state),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── HEADER ──
  Widget _buildHeader(int itemCount) {
    final hasSelection = _selectedIds.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: _K.bg,
        border: Border(bottom: BorderSide(color: _K.divider.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: _K.surface, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.shopping_bag_rounded, color: _K.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Giỏ hàng', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w800, color: _K.textPrimary)),
              Text(hasSelection ? 'Đã chọn ${_selectedIds.length}/$itemCount' : '$itemCount sản phẩm',
                style: GoogleFonts.outfit(fontSize: 12, color: _K.textSecondary)),
            ],
          ),
          const Spacer(),
          if (itemCount > 0)
            GestureDetector(
              onTap: hasSelection ? () {
                context.read<CartBloc>().add(CartDeleteSelected(_selectedIds.toList()));
                setState(() => _selectedIds.clear());
              } : null,
              child: AnimatedOpacity(
                opacity: hasSelection ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _K.rose.withOpacity(hasSelection ? 0.15 : 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: hasSelection ? _K.rose : _K.textMuted),
                    const SizedBox(width: 4),
                    Text('Xoá', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600,
                      color: hasSelection ? _K.rose : _K.textMuted)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── CHECKBOX ──
  Widget _buildCheckbox(bool checked) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: checked ? _K.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: checked ? _K.primary : _K.textMuted, width: 1.5),
      ),
      child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }

  // ── CART ITEMS ──
  Widget _buildCartItems(List<CartItem> items) {
    // Sort: in-stock first (server order = newest first), then OOS at bottom
    final inStock = items.where((i) => !i.isOutOfStock).toList();
    final outOfStock = items.where((i) => i.isOutOfStock).toList();
    final sorted = [...inStock, ...outOfStock];

    final selectableItems = inStock;
    final allSelected = selectableItems.isNotEmpty && selectableItems.every((i) => _selectedIds.contains(i.id));

    return Column(
      children: [
        // Select All row (only for in-stock items)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: GestureDetector(
            onTap: () => setState(() {
              if (allSelected) { _selectedIds.clear(); } else { _selectedIds.addAll(selectableItems.map((i) => i.id)); }
            }),
            child: Row(children: [
              _buildCheckbox(allSelected),
              const SizedBox(width: 10),
              Text('Chọn tất cả (${selectableItems.length})',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _K.textSecondary)),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        ...sorted.map((item) => _buildCartItemCard(item)),
      ],
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    final isOOS = item.isOutOfStock;
    final isChecked = !isOOS && _selectedIds.contains(item.id);

    // Auto-remove OOS items from selection
    if (isOOS && _selectedIds.contains(item.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() => _selectedIds.remove(item.id));
      });
    }

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        _selectedIds.remove(item.id);
        context.read<CartBloc>().add(CartRemoveItem(item.id));
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: _K.rose.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: _K.rose, size: 28),
      ),
      child: GestureDetector(
        onTap: isOOS ? null : () => setState(() {
          if (isChecked) { _selectedIds.remove(item.id); } else { _selectedIds.add(item.id); }
        }),
        child: Opacity(
          opacity: isOOS ? 0.5 : 1.0,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _K.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOOS
                    ? _K.rose.withOpacity(0.3)
                    : isChecked
                        ? _K.primary.withOpacity(0.6)
                        : _K.divider.withOpacity(0.5),
              ),
            ),
            child: Stack(
              children: [
                Row(
                  children: [
                    // Checkbox
                    _buildCheckbox(isChecked),
                    const SizedBox(width: 10),
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                          ? Image.network(item.imageUrl!, width: 72, height: 72, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildImagePlaceholder())
                          : _buildImagePlaceholder(),
                    ),
                    const SizedBox(width: 10),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.productName, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _K.textPrimary, height: 1.3)),
                          const SizedBox(height: 4),
                          if (item.colorName != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 12, height: 12,
                                  decoration: BoxDecoration(
                                    color: _parseHex(item.colorHex ?? '#888888'),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: _K.textMuted, width: 1),
                                  )),
                                const SizedBox(width: 6),
                                Text(item.colorName!, style: GoogleFonts.outfit(fontSize: 11, color: _K.textSecondary)),
                              ]),
                            ),
                          Text(_formatPrice(item.unitPrice), style: GoogleFonts.outfit(
                            fontSize: 14, fontWeight: FontWeight.w700, color: isOOS ? _K.textMuted : _K.emerald)),
                        ],
                      ),
                    ),
                    // Quantity
                    Column(children: [
                      _buildQtyButton(Icons.add, isOOS ? null : (item.quantity >= item.stockQuantity ? () {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Chỉ còn ${item.stockQuantity} sản phẩm trong kho',
                            style: GoogleFonts.outfit(color: Colors.white)),
                          backgroundColor: _K.amber,
                          duration: const Duration(seconds: 2),
                        ));
                      } : () {
                        context.read<CartBloc>().add(CartUpdateQuantity(item.id, item.quantity + 1));
                      })),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('${item.quantity}', style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w700, color: _K.textPrimary)),
                      ),
                      _buildQtyButton(Icons.remove, isOOS ? null : (item.quantity > 1 ? () {
                        context.read<CartBloc>().add(CartUpdateQuantity(item.id, item.quantity - 1));
                      } : null)),
                    ]),
                  ],
                ),
                // "Hết hàng" badge
                if (isOOS)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _K.rose,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Hết hàng',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
      width: 80, height: 80,
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



  // ── ORDER SUMMARY (Sticky bottom) ──
  Widget _buildOrderSummary(CartState state) {
    final selectedItems = state.cart.items.where((i) => _selectedIds.contains(i.id)).toList();
    final selectedTotal = selectedItems.fold<double>(0, (sum, i) => sum + i.subtotal);
    final hasSelection = selectedItems.isNotEmpty;
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
          _buildSummaryRow('Tạm tính (${selectedItems.length} sản phẩm)', _formatPrice(selectedTotal)),
          const SizedBox(height: 6),
          _buildSummaryRow('Phí vận chuyển', hasSelection ? 'Miễn phí' : '--', valueColor: _K.emerald),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: _K.divider.withOpacity(0.5)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: _K.textPrimary)),
              Text(_formatPrice(selectedTotal), style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w800, color: hasSelection ? _K.emerald : _K.textMuted,
              )),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: state.isCheckingOut || !hasSelection ? null : () => _checkout(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _K.primary,
                disabledBackgroundColor: _K.primary.withOpacity(0.4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: state.isCheckingOut
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

  // ── EMPTY STATE ──
  Widget _buildEmptyState() {
    final isLoggedIn = AuthService().isTokenValid;
    return Scaffold(
      backgroundColor: _K.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: _K.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _K.primary.withOpacity(0.2), width: 2),
                ),
                child: const Icon(Icons.shopping_cart_outlined, color: _K.primary, size: 44),
              ),
              const SizedBox(height: 24),
              Text(
                isLoggedIn ? 'Giỏ hàng trống' : 'Chưa đăng nhập',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: _K.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                isLoggedIn
                    ? 'Hãy khám phá và thêm sản phẩm yêu thích!'
                    : 'Đăng nhập để xem giỏ hàng và mua sắm.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: _K.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              // Continue Shopping button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (widget.onContinueShopping != null) {
                      widget.onContinueShopping!();
                    }
                  },
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: Text('Tiếp tục mua sắm', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _K.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              // Login button (only when not logged in)
              if (!isLoggedIn) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed('/login'),
                    icon: const Icon(Icons.login_rounded, size: 18),
                    label: Text('Đăng nhập', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _K.primary,
                      side: BorderSide(color: _K.primary.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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

  // ── ACTIONS ──
  void _checkout(BuildContext context) {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Vui lòng nhập họ tên và số điện thoại', style: GoogleFonts.outfit(color: Colors.white)),
        backgroundColor: _K.amber,
      ));
      return;
    }

    final bloc = context.read<CartBloc>();
    final selectedItems = bloc.state.cart.items.where((i) => _selectedIds.contains(i.id)).toList();
    final selectedTotal = selectedItems.fold<double>(0, (sum, i) => sum + i.subtotal);

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
              Text('${selectedItems.length} sản phẩm • ${_formatPrice(selectedTotal)}',
                style: GoogleFonts.outfit(color: _K.emerald, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Thanh toán: Chuyển khoản QR PayOS',
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
                        _performCheckout(context, selectedItems);
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

  void _performCheckout(BuildContext context, List<CartItem> selectedItems) {
    final bloc = context.read<CartBloc>();
    bloc.add(CartCheckoutRequested(
      items: selectedItems,
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
    ));

    setState(() => _selectedIds.clear());
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


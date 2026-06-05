import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';

// ── Theme Constants ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const rose = Color(0xFFEF4444);
  static const blue = Color(0xFF3B82F6);
  static const divider = Color(0xFF334155);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class OrderDetailScreen extends StatefulWidget {
  final Order order;
  const OrderDetailScreen({Key? key, required this.order}) : super(key: key);

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order;
  bool _isCancelling = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _C.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Đơn hàng ${_order.displayOrderCode}',
          style: GoogleFonts.outfit(
              fontSize: 16, fontWeight: FontWeight.w700, color: _C.textPrimary),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        child: Column(
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            if (_order.address != null) ...[
              _buildAddressCard(),
              const SizedBox(height: 16),
            ],
            _buildItemsCard(),
            const SizedBox(height: 16),
            _buildPriceCard(),
            if (_order.note != null && _order.note!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNoteCard(),
            ],
            const SizedBox(height: 24),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  1. STATUS CARD
  // ═══════════════════════════════════════════

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          // ── Icon + label ──
          _buildStatusIcon(),
          const SizedBox(height: 12),
          Text(
            _order.statusLabel,
            style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _statusColor),
          ),
          const SizedBox(height: 4),
          if (_order.updatedAt != null)
            Text(
              'Cập nhật: ${AppFormatters.formatDateTime(_order.updatedAt!)}',
              style: GoogleFonts.outfit(fontSize: 12, color: _C.textMuted),
            ),
          const SizedBox(height: 24),
          // ── Timeline ──
          _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    final isCancelled = _order.status == 'cancelled';
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.15),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _statusColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Icon(
        isCancelled ? Icons.close_rounded : _statusIcon,
        size: 28,
        color: _statusColor,
      ),
    );
  }

  Color get _statusColor {
    switch (_order.status) {
      case 'pending_payment':
        return _C.blue;
      case 'paid':
        return _C.emerald;
      case 'cancelled':
        return _C.rose;
      default:
        return _C.textMuted;
    }
  }

  IconData get _statusIcon {
    switch (_order.status) {
      case 'pending_payment':
        return Icons.payment_rounded;
      case 'paid':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.close_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  int get _currentStep {
    switch (_order.status) {
      case 'pending_payment':
        return 0;
      case 'paid':
        return 1;
      case 'cancelled':
        return -1; // special case
      default:
        return 0;
    }
  }

  Widget _buildTimeline() {
    final isCancelled = _order.status == 'cancelled';
    final steps = ['Chờ thanh toán', 'Đã thanh toán'];
    final step = _currentStep;

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final lineStep = i ~/ 2;
          final isCompleted = isCancelled ? false : lineStep < step;
          return Expanded(
            child: Container(
              height: 2,
              color: isCancelled
                  ? _C.rose.withOpacity(0.3)
                  : isCompleted
                      ? _C.emerald
                      : _C.divider,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isCompleted = isCancelled ? false : stepIndex <= step;
        final isCurrent = !isCancelled && stepIndex == step;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCancelled
                    ? _C.rose.withOpacity(0.15)
                    : isCompleted
                        ? _C.emerald
                        : _C.bg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCancelled
                      ? _C.rose
                      : isCompleted
                          ? _C.emerald
                          : _C.divider,
                  width: 2,
                ),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: _C.emerald.withOpacity(0.4),
                          blurRadius: 8,
                        )
                      ]
                    : null,
              ),
              child: isCompleted && !isCancelled
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : isCancelled
                      ? const Icon(Icons.close, size: 12, color: _C.rose)
                      : null,
            ),
            const SizedBox(height: 6),
            Text(
              steps[stepIndex],
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isCompleted ? FontWeight.w600 : FontWeight.w400,
                color: isCancelled
                    ? _C.rose.withOpacity(0.6)
                    : isCompleted
                        ? _C.textSecondary
                        : _C.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }

  // ═══════════════════════════════════════════
  //  2. ADDRESS CARD
  // ═══════════════════════════════════════════

  Widget _buildAddressCard() {
    final addr = _order.address!;
    return _buildSection(
      icon: Icons.location_on_rounded,
      iconColor: _C.rose,
      title: 'Địa chỉ nhận hàng',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(addr.recipientName,
              style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _C.textPrimary)),
          const SizedBox(height: 4),
          Text(addr.phone,
              style: GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary)),
          const SizedBox(height: 2),
          Text(addr.fullAddress,
              style: GoogleFonts.outfit(
                  fontSize: 13, color: _C.textSecondary, height: 1.4)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  3. ORDER ITEMS CARD
  // ═══════════════════════════════════════════

  Widget _buildItemsCard() {
    return _buildSection(
      icon: Icons.shopping_bag_rounded,
      iconColor: _C.primary,
      title: 'Sản phẩm (${_order.items.length})',
      child: Column(
        children: List.generate(_order.items.length, (i) {
          final item = _order.items[i];
          return Column(
            children: [
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                      height: 1, color: _C.divider.withOpacity(0.4)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: item.productImage != null
                        ? CachedNetworkImage(
                            imageUrl: item.productImage!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                                width: 64, height: 64, color: _C.bg),
                            errorWidget: (_, __, ___) => Container(
                              width: 64,
                              height: 64,
                              color: _C.bg,
                              child: const Icon(Icons.image,
                                  color: _C.textMuted, size: 24),
                            ),
                          )
                        : Container(
                            width: 64,
                            height: 64,
                            color: _C.bg,
                            child: const Icon(Icons.devices,
                                color: _C.textMuted, size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName ?? 'Sản phẩm',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _C.textPrimary,
                              height: 1.3),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Số lượng: ${item.quantity}',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: _C.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppFormatters.formatCurrency(item.unitPrice),
                          style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.emerald),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  4. PRICE BREAKDOWN CARD
  // ═══════════════════════════════════════════

  Widget _buildPriceCard() {
    final subtotal =
        _order.items.fold<double>(0, (sum, i) => sum + i.subtotal);

    return _buildSection(
      icon: Icons.receipt_rounded,
      iconColor: _C.emerald,
      title: 'Chi tiết thanh toán',
      child: Column(
        children: [
          _priceRow('Tạm tính', subtotal),
          const SizedBox(height: 8),
          if (_order.discountAmount > 0) ...[
            _priceRow('Giảm giá', -_order.discountAmount),
            const SizedBox(height: 8),
          ],
          _priceRow('Phí vận chuyển', _order.shippingFee),
          const SizedBox(height: 12),
          Container(height: 1, color: _C.divider),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tổng cộng',
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary)),
              Text(AppFormatters.formatCurrency(_order.totalAmount),
                  style: GoogleFonts.outfit(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _C.emerald)),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: _C.divider.withOpacity(0.4)),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payment_rounded,
                  size: 16, color: _C.textMuted),
              const SizedBox(width: 8),
              Text('Thanh toán: ${_order.paymentMethodLabel}',
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, double amount) {
    final isDiscount = amount < 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: GoogleFonts.outfit(fontSize: 14, color: _C.textSecondary)),
        Text(
          isDiscount
              ? '-${AppFormatters.formatCurrency(amount.abs())}'
              : AppFormatters.formatCurrency(amount),
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDiscount ? _C.rose : _C.textPrimary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  //  5. NOTE CARD
  // ═══════════════════════════════════════════

  Widget _buildNoteCard() {
    return _buildSection(
      icon: Icons.note_rounded,
      iconColor: _C.amber,
      title: 'Ghi chú',
      child: Text(
        _order.note!,
        style: GoogleFonts.outfit(
            fontSize: 14, color: _C.textSecondary, height: 1.5),
      ),
    );
  }

  // ═══════════════════════════════════════════
  //  6. ACTION BUTTONS
  // ═══════════════════════════════════════════

  Widget _buildActionButtons() {
    switch (_order.status) {
      case 'pending_payment':
        return Column(
          children: [
            // Cancel button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _C.rose,
                  side: const BorderSide(color: _C.rose),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _C.rose),
                      )
                    : Text('Hủy đơn hàng',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        );

      case 'cancelled':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // TODO: re-order
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Đặt lại đơn hàng',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        );

      case 'paid':
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () {
              // TODO: open support
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: _C.textSecondary,
              side: const BorderSide(color: _C.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Liên hệ hỗ trợ',
                style: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Future<void> _cancelOrder() async {
    // Confirm dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hủy đơn hàng?',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: _C.textPrimary)),
        content: Text(
          'Bạn có chắc muốn hủy đơn hàng ${_order.displayOrderCode}?',
          style: GoogleFonts.outfit(color: _C.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                Text('Không', style: GoogleFonts.outfit(color: _C.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hủy đơn',
                style: GoogleFonts.outfit(
                    color: _C.rose, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isCancelling = true);

    final success = await OrderService().cancelOrder(_order.id);

    if (!mounted) return;

    if (success) {
      AppSnackbars.showSuccess(context, 'Đã hủy đơn hàng thành công');
      Navigator.of(context).pop(true); // signal refresh
    } else {
      AppSnackbars.showError(context, 'Không thể hủy đơn hàng. Vui lòng thử lại.');
      setState(() => _isCancelling = false);
    }
  }

  // ═══════════════════════════════════════════
  //  SHARED SECTION BUILDER
  // ═══════════════════════════════════════════

  Widget _buildSection({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(title,
                  style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary)),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _C.divider.withOpacity(0.4)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

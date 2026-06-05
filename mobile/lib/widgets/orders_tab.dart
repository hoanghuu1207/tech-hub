import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../services/auth_service.dart';
import '../bloc/order_bloc.dart';
import '../models/order_model.dart';
import '../screens/order_detail_screen.dart';
import '../utils/formatters.dart';

// ── Theme Constants ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const divider = Color(0xFF334155);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
}

class OrdersTab extends StatelessWidget {
  const OrdersTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService().isTokenValid;
    if (!isLoggedIn) {
      return _buildLoginPrompt(context);
    }
    return BlocProvider(
      create: (_) => OrderBloc()..add(const OrdersFetchRequested()),
      child: const _OrdersContent(),
    );
  }

  Widget _buildLoginPrompt(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _C.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.divider),
                  ),
                  child: const Icon(Icons.receipt_long_rounded,
                      size: 40, color: _C.divider),
                ),
                const SizedBox(height: 24),
                Text(
                  'Đăng nhập để xem đơn hàng',
                  style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _C.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Theo dõi đơn hàng và lịch sử mua hàng',
                  style: GoogleFonts.outfit(
                      fontSize: 14, color: _C.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _C.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text('Đăng nhập',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  ORDERS CONTENT (logged-in view)
// ═══════════════════════════════════════════

class _OrdersContent extends StatelessWidget {
  const _OrdersContent();

  static const _statusFilters = <_StatusFilter>[
    _StatusFilter('Tất cả', null),
    _StatusFilter('Chờ thanh toán', 'pending_payment'),
    _StatusFilter('Đã thanh toán', 'paid'),
    _StatusFilter('Đã hủy', 'cancelled'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Text(
                'Đơn hàng',
                style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary),
              ),
            ),
            // ── Filter bar ──
            _buildFilterBar(context),
            // ── Order list ──
            Expanded(child: _buildOrderList(context)),
          ],
        ),
      ),
    );
  }

  // ── Filter bar ──
  Widget _buildFilterBar(BuildContext context) {
    return SizedBox(
      height: 56,
      child: BlocBuilder<OrderBloc, OrdersState>(
        buildWhen: (prev, curr) =>
            prev.selectedStatus != curr.selectedStatus,
        builder: (context, state) {
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: _statusFilters.length,
            itemBuilder: (context, index) {
              final filter = _statusFilters[index];
              final isSelected = state.selectedStatus == filter.value;
              return GestureDetector(
                onTap: () => context
                    .read<OrderBloc>()
                    .add(OrdersFilterChanged(filter.value)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? _C.primary : _C.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _C.primary : _C.divider,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      filter.label,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : _C.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Order list ──
  Widget _buildOrderList(BuildContext context) {
    return BlocBuilder<OrderBloc, OrdersState>(
      builder: (context, state) {
        if (state.status == OrdersStatus.loading) {
          return _buildShimmerList();
        }
        if (state.status == OrdersStatus.error) {
          return _buildErrorState(context, state.errorMessage);
        }
        if (state.filteredOrders.isEmpty) {
          return _buildEmptyState(context);
        }
        return RefreshIndicator(
          color: _C.primary,
          backgroundColor: _C.surface,
          onRefresh: () async {
            context
                .read<OrderBloc>()
                .add(const OrdersRefreshRequested());
            // small delay for UX
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: state.filteredOrders.length,
            itemBuilder: (context, index) {
              return _OrderCard(order: state.filteredOrders[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _C.surface,
                shape: BoxShape.circle,
                border: Border.all(color: _C.divider),
              ),
              child: const Icon(Icons.shopping_bag_outlined,
                  size: 40, color: _C.divider),
            ),
            const SizedBox(height: 20),
            Text('Chưa có đơn hàng nào',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const SizedBox(height: 8),
            Text('Hãy bắt đầu mua sắm ngay!',
                style: GoogleFonts.outfit(fontSize: 14, color: _C.textMuted)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String? msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: _C.textMuted),
            const SizedBox(height: 16),
            Text('Không thể tải đơn hàng',
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary)),
            const SizedBox(height: 8),
            Text(msg ?? '', style: GoogleFonts.outfit(fontSize: 13, color: _C.textMuted)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  context.read<OrderBloc>().add(const OrdersFetchRequested()),
              style: ElevatedButton.styleFrom(
                backgroundColor: _C.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Thử lại',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: _C.surface,
      highlightColor: _C.divider,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: 4,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 180,
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _StatusFilter {
  final String label;
  final String? value;
  const _StatusFilter(this.label, this.value);
}

// ═══════════════════════════════════════════
//  ORDER CARD
// ═══════════════════════════════════════════

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final shouldRefresh = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order),
          ),
        );
        if (shouldRefresh == true && context.mounted) {
          context.read<OrderBloc>().add(const OrdersRefreshRequested());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: order code + status badge ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(order.displayOrderCode,
                    style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _C.textPrimary)),
                _StatusBadge(status: order.status, label: order.statusLabel),
              ],
            ),
            const SizedBox(height: 4),
            // ── Date ──
            Text(
              order.createdAt != null
                  ? AppFormatters.formatDate(order.createdAt!)
                  : '',
              style: GoogleFonts.outfit(fontSize: 12, color: _C.textMuted),
            ),
            const SizedBox(height: 12),
            // ── Divider ──
            Container(height: 1, color: _C.divider.withOpacity(0.5)),
            const SizedBox(height: 12),
            // ── Product thumbnails + count ──
            Row(
              children: [
                ...order.items.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: item.productImage != null
                          ? CachedNetworkImage(
                              imageUrl: item.productImage!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                width: 44,
                                height: 44,
                                color: _C.bg,
                              ),
                              errorWidget: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: _C.bg,
                                child: const Icon(Icons.image,
                                    color: _C.textMuted, size: 20),
                              ),
                            )
                          : Container(
                              width: 44,
                              height: 44,
                              color: _C.bg,
                              child: const Icon(Icons.devices,
                                  color: _C.textMuted, size: 20),
                            ),
                    ),
                  ),
                ),
                if (order.items.length > 3)
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _C.divider),
                    ),
                    child: Center(
                      child: Text(
                        '+${order.items.length - 3}',
                        style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _C.textSecondary),
                      ),
                    ),
                  ),
                const Spacer(),
                Text(
                  '${order.totalItemCount} sản phẩm',
                  style: GoogleFonts.outfit(
                      fontSize: 13, color: _C.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Total amount ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tổng tiền:',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: _C.textSecondary)),
                Text(AppFormatters.formatCurrency(order.totalAmount),
                    style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _C.emerald)),
              ],
            ),
            const SizedBox(height: 10),
            // ── View detail link ──
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem chi tiết',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _C.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: _C.primary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════
//  STATUS BADGE
// ═══════════════════════════════════════════

class _StatusBadge extends StatelessWidget {
  final String status;
  final String label;
  const _StatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
            fontSize: 11, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'pending_payment':
        return const Color(0xFF3B82F6);
      case 'paid':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

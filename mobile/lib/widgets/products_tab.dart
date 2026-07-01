import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../bloc/catalog_bloc.dart';
import '../bloc/cart_bloc.dart';
import '../models/catalog_models.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';

// ── Theme constants matching the app ──
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

class ProductsTab extends StatelessWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onNotificationTap;

  const ProductsTab({
    Key? key,
    this.onProfileTap,
    this.onCartTap,
    this.onNotificationTap,
  }) : super(key: key);

  Future<void> _onRefresh(BuildContext context) {
    final bloc = context.read<CatalogBloc>();
    bloc.add(const CatalogRefresh());
    // Wait for the bloc to finish refreshing
    final completer = Completer<void>();
    late StreamSubscription<CatalogState> sub;
    sub = bloc.stream.listen((state) {
      if (state.status != CatalogStatus.loading) {
        completer.complete();
        sub.cancel();
      }
    });
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: BlocBuilder<CatalogBloc, CatalogState>(
        builder: (context, state) {
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollEndNotification &&
                  notification.metrics.extentAfter < 300 &&
                  state.hasMore &&
                  state.status != CatalogStatus.loading) {
                context.read<CatalogBloc>().add(const CatalogLoadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              color: _C.primary,
              backgroundColor: _C.surface,
              onRefresh: () => _onRefresh(context),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1) Header (avatar, name, icons)
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  // 2) Category bar (pinned)
                  _buildCategoryBar(context, state),
                  // 3) Secondary filter bar (pinned, hidden when no category)
                  if (state.selectedCategoryId != null)
                    _buildSecondaryFilterBar(context, state),
                  // 4) Breadcrumb + count
                  _buildBreadcrumbRow(context, state),
                  // 5) Product grid
                  _buildBody(context, state),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 1) HEADER (replaces SliverAppBar)
  // ═══════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    final user = AuthService().currentUser;
    final cartState = context.watch<CartBloc>().state;
    final cartCount = cartState.cart.activeItemCount;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: onProfileTap,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(colors: [_C.primary, Color(0xFF22D3EE)]),
                  boxShadow: [BoxShadow(color: _C.primary.withOpacity(0.4), blurRadius: 12)],
                ),
                child: user?.avatarUrl != null
                    ? ClipOval(child: CachedNetworkImage(imageUrl: user!.avatarUrl!, fit: BoxFit.cover))
                    : const Icon(Icons.person, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TechHub', style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w800, color: _C.textPrimary, letterSpacing: -0.5,
                  )),
                  Text(
                    user != null ? 'Xin chào, ${user.fullName.split(' ').last} 👋' : 'Khám phá công nghệ',
                    style: GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary),
                  ),
                ],
              ),
            ),
            // ── Notification bell ──
            GestureDetector(
              onTap: onNotificationTap,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _C.surface, shape: BoxShape.circle,
                  border: Border.all(color: _C.divider),
                ),
                child: const Icon(Icons.notifications_outlined, color: _C.textPrimary, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // ── Cart icon ──
            GestureDetector(
              onTap: onCartTap,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _C.surface, shape: BoxShape.circle,
                  border: Border.all(color: _C.divider),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: _C.textPrimary, size: 22),
                    if (cartCount > 0)
                      Positioned(
                        top: 6, right: 6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: _C.rose, shape: BoxShape.circle),
                          child: Text(
                            cartCount > 9 ? '9+' : '$cartCount',
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 2) CATEGORY BAR (pinned)
  // ═══════════════════════════════════════════
  Widget _buildCategoryBar(BuildContext context, CatalogState state) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _FixedHeightDelegate(
        height: 64,
        child: Container(
          color: _C.bg,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: state.categories.isEmpty
              ? _buildChipShimmer()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _buildCategoryChip(
                        context: context,
                        label: 'Tất cả',
                        icon: Icons.grid_view_rounded,
                        isSelected: state.selectedCategoryId == null,
                        onTap: () => context
                            .read<CatalogBloc>()
                            .add(const CatalogCategorySelected(null)),
                      );
                    }
                    final cat = state.categories[index - 1];
                    return _buildCategoryChip(
                      context: context,
                      label: cat.name,
                      icon: _categoryIcon(cat.name),
                      isSelected: state.selectedCategoryId == cat.id,
                      onTap: () => context
                          .read<CatalogBloc>()
                          .add(CatalogCategorySelected(cat.id)),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _C.primary : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _C.primary : _C.divider),
          boxShadow: isSelected
              ? [BoxShadow(color: _C.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _C.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _C.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 3) SECONDARY FILTER BAR (brands / lines)
  // ═══════════════════════════════════════════
  Widget _buildSecondaryFilterBar(BuildContext context, CatalogState state) {
    // Show product lines if a brand is selected, otherwise show brands
    final bool showLines =
        state.selectedBrandId != null && state.productLines.isNotEmpty;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _FixedHeightDelegate(
        height: 54,
        child: Container(
          color: _C.bg,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: showLines
                ? state.productLines.length + 1
                : state.brands.length + 1,
            itemBuilder: (context, index) {
              if (showLines) {
                if (index == 0) {
                  return _buildSecondaryChip(
                    label: 'Tất cả',
                    isSelected: state.selectedLineId == null,
                    onTap: () => context.read<CatalogBloc>().add(
                          CatalogBrandSelected(
                              state.selectedCategoryId!, state.selectedBrandId),
                        ),
                  );
                }
                final line = state.productLines[index - 1];
                return _buildSecondaryChip(
                  label: line.name,
                  isSelected: state.selectedLineId == line.id,
                  onTap: () => context
                      .read<CatalogBloc>()
                      .add(CatalogLineSelected(line.id)),
                );
              } else {
                if (index == 0) {
                  return _buildSecondaryChip(
                    label: 'Tất cả',
                    isSelected: state.selectedBrandId == null,
                    onTap: () => context.read<CatalogBloc>().add(
                          CatalogBrandSelected(state.selectedCategoryId!, null),
                        ),
                  );
                }
                final brand = state.brands[index - 1];
                return _buildSecondaryChip(
                  label: brand.name,
                  isSelected: state.selectedBrandId == brand.id,
                  onTap: () => context.read<CatalogBloc>().add(
                        CatalogBrandSelected(
                            state.selectedCategoryId!, brand.id),
                      ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _C.primary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _C.primary : _C.divider,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? _C.primary : _C.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // 4) BREADCRUMB + COUNT
  // ═══════════════════════════════════════════
  Widget _buildBreadcrumbRow(BuildContext context, CatalogState state) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: Row(
          children: [
            Expanded(child: _buildBreadcrumb(context, state)),
            if (state.status == CatalogStatus.loaded)
              Text(
                '${AppFormatters.formatNumber(state.total)} sản phẩm',
                style: GoogleFonts.outfit(fontSize: 13, color: _C.textMuted),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumb(BuildContext context, CatalogState state) {
    final segments = <_BreadcrumbSegment>[];

    if (state.selectedCategoryName != null) {
      segments.add(_BreadcrumbSegment(
        label: state.selectedCategoryName!,
        onTap: () => context
            .read<CatalogBloc>()
            .add(CatalogCategorySelected(state.selectedCategoryId)),
      ));
    }
    if (state.selectedBrandName != null) {
      segments.add(_BreadcrumbSegment(
        label: state.selectedBrandName!,
        onTap: () => context.read<CatalogBloc>().add(
              CatalogBrandSelected(
                  state.selectedCategoryId!, state.selectedBrandId),
            ),
      ));
    }
    if (state.selectedLineName != null) {
      segments.add(_BreadcrumbSegment(label: state.selectedLineName!));
    }

    if (segments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (int i = 0; i < segments.length; i++) ...[
          if (i > 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.chevron_right, size: 14, color: _C.textMuted),
            ),
          GestureDetector(
            onTap: segments[i].onTap,
            child: Text(
              segments[i].label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: i == segments.length - 1
                    ? _C.textSecondary
                    : _C.textMuted,
                fontWeight: i == segments.length - 1
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // 5) BODY — Grid / Loading / Empty / Error
  // ═══════════════════════════════════════════
  Widget _buildBody(BuildContext context, CatalogState state) {
    if (state.status == CatalogStatus.loading && state.products.isEmpty) {
      return _buildShimmerGrid();
    }

    if (state.status == CatalogStatus.error) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _C.rose.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_off_rounded, color: _C.rose, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Không thể tải sản phẩm',
                  style: GoogleFonts.outfit(
                      color: _C.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  state.errorMessage ?? 'Đã có lỗi xảy ra',
                  style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () =>
                      context.read<CatalogBloc>().add(const CatalogStarted()),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text('Thử lại',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.products.isEmpty && state.status == CatalogStatus.loaded) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
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
                child: const Icon(Icons.inventory_2_outlined,
                    color: _C.primary, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Không tìm thấy sản phẩm',
                style: GoogleFonts.outfit(
                    color: _C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Thử chọn danh mục hoặc thương hiệu khác',
                style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index < state.products.length) {
              return ProductCardWidget(product: state.products[index]);
            }
            // Loading indicator at the bottom
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child:
                    CircularProgressIndicator(strokeWidth: 2, color: _C.primary),
              ),
            );
          },
          childCount: state.products.length + (state.hasMore ? 1 : 0),
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.49,
        ),
      ),
    );
  }

  // ── Shimmer grid ──
  Widget _buildShimmerGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => _ShimmerCard(),
          childCount: 6,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.49,
        ),
      ),
    );
  }

  // ── Chip shimmer ──
  Widget _buildChipShimmer() {
    return Shimmer.fromColors(
      baseColor: _C.surface,
      highlightColor: _C.divider,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (_, __) => Container(
          width: 90,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
  IconData _categoryIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('phone') || n.contains('điện thoại')) return Icons.phone_android;
    if (n.contains('laptop')) return Icons.laptop_mac;
    if (n.contains('tablet') || n.contains('máy tính bảng')) return Icons.tablet_mac;
    if (n.contains('headphone') || n.contains('tai nghe')) return Icons.headphones;
    if (n.contains('watch') || n.contains('đồng hồ')) return Icons.watch;
    if (n.contains('accessory') || n.contains('phụ kiện')) return Icons.cable;
    return Icons.devices_other;
  }
}

// ═══════════════════════════════════════════════════════════════
// ── PRODUCT CARD WIDGET ──
// ═══════════════════════════════════════════════════════════════

class ProductCardWidget extends StatefulWidget {
  final ProductCompact product;
  const ProductCardWidget({Key? key, required this.product}) : super(key: key);

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget> {
  ProductCompact get product => widget.product;

  void _onAddToCart() async {
    if (!AuthService().isTokenValid) {
      // Not logged in — show snackbar hint
      AppSnackbars.showError(context, 'Vui lòng đăng nhập để thêm vào giỏ');
      return;
    }

    // Fetch variants
    final variants = await CartService().getProductVariants(product.id);

    if (variants.isEmpty) {
      if (!mounted) return;
      context.read<CartBloc>().add(CartAddItem(productId: product.id, quantity: 1));
      AppSnackbars.showSuccess(context, '${product.name} đã thêm vào giỏ');
      return;
    }

    if (!mounted) return;
    final selectedVariantId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantPickerSheet(
        productName: product.name,
        variants: variants,
        productImage: product.primaryImage,
      ),
    );

    if (selectedVariantId != null && mounted) {
      context.read<CartBloc>().add(CartAddItem(
        productId: product.id,
        variantId: selectedVariantId,
        quantity: 1,
      ));
      final picked = variants.firstWhere((v) => v['id'] == selectedVariantId);
      AppSnackbars.showSuccess(
          context, '${product.name} (${picked['color_name']}) đã thêm vào giỏ');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/product-detail', arguments: product.id),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image section ──
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: _C.bg,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(16)),
                      child: product.primaryImage != null
                          ? CachedNetworkImage(
                              imageUrl: product.primaryImage!,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _C.primary),
                              ),
                              errorWidget: (_, __, ___) => const Center(
                                child: Icon(Icons.image_outlined,
                                    color: _C.textMuted, size: 40),
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.image_outlined,
                                  color: _C.textMuted, size: 40),
                            ),
                    ),
                  ),
                  // Discount badge
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _C.rose,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${product.discountPercent.toInt()}%',
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
            // ── Content section ──
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand name
                  if (product.brandName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        product.brandName!.toUpperCase(),
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
                  // Product name
                  Text(
                    product.name,
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
                  // Rating + sold count
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 13, color: _C.amber),
                      const SizedBox(width: 2),
                      Text(
                        product.ratingAvg.toStringAsFixed(1),
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _C.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          ' • Đã bán ${product.soldCount}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: _C.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Price row + Add to cart button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.hasDiscount)
                              Text(
                                AppFormatters.formatCurrency(product.basePrice),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: _C.textMuted,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              AppFormatters.formatCurrency(product.displayPrice),
                              style: GoogleFonts.outfit(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _C.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add to cart button
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

// ═══════════════════════════════════════════════════════════════
// ── VARIANT PICKER BOTTOM SHEET ──
// ═══════════════════════════════════════════════════════════════

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
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          // Product info row
          Row(children: [
            if (widget.productImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.productImage!, width: 56, height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 56, height: 56,
                        decoration: BoxDecoration(
                            color: const Color(0xFF273548),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.devices,
                            color: Color(0xFF64748B), size: 24))),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFF8FAFC))),
                    const SizedBox(height: 4),
                    Text(_fmtPrice((v['price'] as num).toDouble()),
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF10B981))),
                  ]),
            ),
          ]),
          const SizedBox(height: 20),
          // Label
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Chọn màu sắc',
                style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF94A3B8))),
          ),
          const SizedBox(height: 12),
          // Color options
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: List.generate(widget.variants.length, (i) {
              final vr = widget.variants[i];
              final isSel = i == _selectedIndex;
              final inStock = (vr['stock_quantity'] as int? ?? 0) > 0;
              return GestureDetector(
                onTap: inStock ? () => setState(() => _selectedIndex = i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF6366F1).withOpacity(0.15)
                        : const Color(0xFF273548),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel
                          ? const Color(0xFF6366F1)
                          : const Color(0xFF334155),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: inStock ? 1.0 : 0.4,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: _hex(vr['color_hex'] as String?),
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: Colors.white24, width: 1.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(vr['color_name'] as String,
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? const Color(0xFFF8FAFC)
                                  : const Color(0xFF94A3B8))),
                      if (!inStock) ...[
                        const SizedBox(width: 6),
                        Text('Hết hàng',
                            style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: const Color(0xFFF43F5E))),
                      ],
                    ]),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(
                  context, widget.variants[_selectedIndex]['id'] as String),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shopping_cart_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text('Thêm vào giỏ hàng',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// ── SHIMMER CARD ──
// ═══════════════════════════════════════════════════════════════

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: _C.surface,
      highlightColor: _C.divider,
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _C.bg,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _C.divider,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _C.divider,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                        color: _C.divider,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 16,
                    decoration: BoxDecoration(
                        color: _C.divider,
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 90,
                    height: 10,
                    decoration: BoxDecoration(
                        color: _C.divider,
                        borderRadius: BorderRadius.circular(4)),
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

// ═══════════════════════════════════════════════════════════════
// ── FIXED HEIGHT SLIVER DELEGATE ──
// ═══════════════════════════════════════════════════════════════

class _FixedHeightDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _FixedHeightDelegate({required this.height, required this.child});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(covariant _FixedHeightDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

// ═══════════════════════════════════════════════════════════════
// ── BREADCRUMB SEGMENT ──
// ═══════════════════════════════════════════════════════════════

class _BreadcrumbSegment {
  final String label;
  final VoidCallback? onTap;
  const _BreadcrumbSegment({required this.label, this.onTap});
}

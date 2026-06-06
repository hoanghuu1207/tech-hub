import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../bloc/index.dart';
import '../models/index.dart';
import '../services/auth_service.dart';
import '../services/product_service.dart';
import '../services/cart_service.dart';
import '../services/notification_service.dart';
import '../utils/index.dart';

// ── Premium Dark Colors ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const cyan = Color(0xFF22D3EE);
  static const amber = Color(0xFFFBBF24);
  static const rose = Color(0xFFF43F5E);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

class PremiumHomeTab extends StatefulWidget {
  final VoidCallback? onProfileTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProductsTap;
  final VoidCallback? onNotificationTap;

  const PremiumHomeTab({
    Key? key,
    this.onProfileTap,
    this.onCartTap,
    this.onSearchTap,
    this.onProductsTap,
    this.onNotificationTap,
  }) : super(key: key);

  @override
  State<PremiumHomeTab> createState() => _PremiumHomeTabState();
}

class _PremiumHomeTabState extends State<PremiumHomeTab> {
  final ProductService _productService = ProductService();
  final NotificationService _notificationService = NotificationService();

  // ── Local state (independent of Bloc single-state issue) ──
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _isLoadingProducts = true;
  bool _isLoadingCategories = true;
  String? _productError;
  String _selectedCategory = '';
  int _promoIndex = 0;
  int _unreadNotifCount = 0;
  late final PageController _promoController;

  @override
  void initState() {
    super.initState();
    _promoController = PageController(viewportFraction: 0.92);
    _loadAllData();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _loadProducts(),
      _loadCategories(),
      _loadUnreadCount(),
    ]);
  }

  Future<void> _loadUnreadCount() async {
    if (!AuthService().isTokenValid) return;
    try {
      final count = await _notificationService.getUnreadCount();
      if (mounted) setState(() => _unreadNotifCount = count);
    } catch (_) {}
  }

  Future<void> _loadProducts({String? category}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingProducts = true;
      _productError = null;
    });
    try {
      List<Product> products;
      if (category != null && category.isNotEmpty) {
        products = await _productService.getProductsByCategory(category);
      } else {
        products = await _productService.getTrendingProducts();
      }
      if (mounted) setState(() { _products = products; _isLoadingProducts = false; });
    } catch (e) {
      if (mounted) setState(() { _productError = e.toString(); _isLoadingProducts = false; });
    }
  }

  Future<void> _loadCategories() async {
    if (!mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final categories = await _productService.getCategories();
      if (mounted) setState(() { _categories = categories; _isLoadingCategories = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _C.primary,
          backgroundColor: _C.surface,
          onRefresh: _loadAllData,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildPromoBanners()),
              SliverToBoxAdapter(child: _buildCategorySection()),
              SliverToBoxAdapter(child: _buildProductSectionTitle()),
              _buildProductGrid(),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    final user = AuthService().currentUser;
    final cartState = context.watch<CartBloc>().state;
    final cartCount = cartState.cart.itemCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_C.primary, _C.cyan]),
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
            onTap: widget.onNotificationTap,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _C.surface, shape: BoxShape.circle,
                border: Border.all(color: _C.divider),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_outlined, color: _C.textPrimary, size: 22),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: _C.rose, shape: BoxShape.circle),
                        child: Text(
                          _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Cart icon ──
          GestureDetector(
            onTap: widget.onCartTap,
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
    );
  }

  // ── SEARCH BAR ──
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: GestureDetector(
        onTap: widget.onSearchTap ?? () => Navigator.of(context).pushNamed('/search'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _C.surface, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _C.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text('Tìm kiếm sản phẩm...', style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 15))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _C.primary.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.mic_rounded, color: _C.primary, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PROMO BANNERS ──
  Widget _buildPromoBanners() {
    final banners = [
      _PromoBanner('iPhone 16 Pro Max', 'Sale up to 10%', const [Color(0xFF312E81), Color(0xFF4F46E5)], Icons.phone_iphone),
      _PromoBanner('Laptop Lenovo', 'Giảm đến 2 triệu', const [Color(0xFF065F46), Color(0xFF10B981)], Icons.laptop_mac),
      _PromoBanner('Tai nghe Premium', 'Mua 1 tặng 1', const [Color(0xFF7C2D12), Color(0xFFF59E0B)], Icons.headphones),
    ];

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PageView.builder(
            controller: _promoController,
            itemCount: banners.length,
            onPageChanged: (i) => setState(() => _promoIndex = i),
            itemBuilder: (context, index) {
              final b = banners[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: b.gradient),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(color: b.gradient.first.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.bolt, color: _C.amber, size: 14),
                                const SizedBox(width: 4),
                                Text('HOT DEAL', style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(b.title, style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.1)),
                          const SizedBox(height: 6),
                          Text(b.subtitle, style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.8), fontSize: 14)),
                        ],
                      ),
                    ),
                    Icon(b.icon, color: Colors.white.withOpacity(0.25), size: 72),
                  ],
                ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _promoIndex == i ? 24 : 8, height: 8,
            decoration: BoxDecoration(color: _promoIndex == i ? _C.primary : _C.divider, borderRadius: BorderRadius.circular(4)),
          )),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── CATEGORIES ──
  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Danh mục', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _C.textPrimary)),
              GestureDetector(
                onTap: () {},
                child: Text('Xem tất cả', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _C.primary)),
              ),
            ],
          ),
        ),
        _isLoadingCategories
            ? SizedBox(
                height: 48,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: 5,
                  itemBuilder: (_, __) => Container(
                    width: 90, height: 36,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              )
            : SizedBox(
                height: 48,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _categories.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return _buildCategoryChip('Tất cả', '', Icons.grid_view_rounded);
                    final cat = _categories[index - 1];
                    return _buildCategoryChip(cat.name, cat.id, _categoryIcon(cat.name));
                  },
                ),
              ),
      ],
    );
  }

  Widget _buildCategoryChip(String name, String id, IconData icon) {
    final isSelected = _selectedCategory == id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = id);
        _loadProducts(category: id.isEmpty ? null : name);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? _C.primary : _C.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _C.primary : _C.divider),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _C.textSecondary),
            const SizedBox(width: 6),
            Text(name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : _C.textSecondary)),
          ],
        ),
      ),
    );
  }

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

  // ── PRODUCT SECTION TITLE ──
  Widget _buildProductSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sản phẩm nổi bật', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w700, color: _C.textPrimary)),
              Text('Được đề xuất cho bạn', style: GoogleFonts.outfit(fontSize: 13, color: _C.textMuted)),
            ],
          ),
          GestureDetector(
            onTap: widget.onProductsTap ?? () => Navigator.of(context).pushNamed('/products'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(border: Border.all(color: _C.divider), borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Xem tất cả', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _C.primary)),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios, size: 10, color: _C.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── PRODUCT GRID ──
  Widget _buildProductGrid() {
    if (_isLoadingProducts) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((_, __) => _buildShimmerCard(), childCount: 4),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.49,
          ),
        ),
      );
    }

    if (_productError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.wifi_off_rounded, color: _C.textMuted, size: 48),
              const SizedBox(height: 12),
              Text('Không thể tải sản phẩm', style: GoogleFonts.outfit(color: _C.textSecondary, fontSize: 15)),
              const SizedBox(height: 4),
              Text(_productError!, style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 12), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => _loadProducts(category: _selectedCategory.isEmpty ? null : _selectedCategory),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text('Thử lại', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.inventory_2_outlined, color: _C.textMuted, size: 48),
              const SizedBox(height: 12),
              Text('Chưa có sản phẩm', style: GoogleFonts.outfit(color: _C.textSecondary)),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildProductCard(_products[index]),
          childCount: _products.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.49,
        ),
      ),
    );
  }

  // ── PRODUCT CARD ──
  Widget _buildProductCard(Product product) {
    final discount = product.originalPrice != null
        ? ((product.originalPrice! - product.price) / product.originalPrice! * 100).toInt()
        : 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).pushNamed('/product-detail', arguments: product.id),
      child: Container(
        decoration: BoxDecoration(
          color: _C.surface, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.divider.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                      child: CachedNetworkImage(
                        imageUrl: product.images.isNotEmpty ? product.images.first : '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
                        errorWidget: (_, __, ___) => const Icon(Icons.image, color: _C.textMuted, size: 40),
                      ),
                    ),
                  ),
                  if (discount > 0)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _C.rose, borderRadius: BorderRadius.circular(8)),
                        child: Text('-$discount%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  if (!product.inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: _C.bg.withOpacity(0.7),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        ),
                        child: Center(child: Text('Hết hàng', style: GoogleFonts.outfit(color: _C.textSecondary, fontWeight: FontWeight.w600))),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: _C.textPrimary, height: 1.3)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star_rounded, size: 14, color: _C.amber),
                    const SizedBox(width: 3),
                    Text(AppFormatters.formatRating(product.rating), style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textSecondary)),
                    Flexible(
                      child: Text(' (${product.reviewCount})',
                        style: GoogleFonts.outfit(fontSize: 11, color: _C.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (product.originalPrice != null)
                              Text(AppFormatters.formatCurrency(product.originalPrice!),
                                style: GoogleFonts.outfit(fontSize: 11, color: _C.textMuted, decoration: TextDecoration.lineThrough)),
                            Text(AppFormatters.formatCurrency(product.price),
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: _C.emerald)),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: product.inStock ? () => _onAddToCart(product) : null,
                        child: Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: product.inStock ? _C.primary : _C.divider,
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

  void _onAddToCart(Product product) async {
    if (!AuthService().isTokenValid) {
      if (widget.onCartTap != null) widget.onCartTap!();
      return;
    }

    // Fetch variants
    final variants = await CartService().getProductVariants(product.id);

    if (variants.isEmpty) {
      // No variants — add directly
      if (!mounted) return;
      context.read<CartBloc>().add(CartAddItem(productId: product.id, quantity: 1));
      AppSnackbars.showSuccess(context, '${product.name} đã thêm vào giỏ');
      return;
    }

    if (!mounted) return;
    // Show variant picker bottom sheet
    final selectedVariantId = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VariantPickerSheet(
        productName: product.name,
        variants: variants,
        productImage: product.images.isNotEmpty ? product.images.first : null,
      ),
    );

    if (selectedVariantId != null && mounted) {
      context.read<CartBloc>().add(CartAddItem(
        productId: product.id,
        variantId: selectedVariantId,
        quantity: 1,
      ));
      final picked = variants.firstWhere((v) => v['id'] == selectedVariantId);
      AppSnackbars.showSuccess(context, '${product.name} (${picked['color_name']}) đã thêm vào giỏ');
    }
  }

  Widget _buildShimmerCard() {
    return Container(
      decoration: BoxDecoration(
        color: _C.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Container(
            decoration: const BoxDecoration(color: _C.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          )),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: double.infinity, height: 12, decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 80, height: 12, decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 8),
                Container(width: 60, height: 16, decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  _PromoBanner(this.title, this.subtitle, this.gradient, this.icon);
}

// ── Variant Picker Bottom Sheet ──
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
          Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Product info row
          Row(children: [
            if (widget.productImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.productImage!, width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(width: 56, height: 56,
                    decoration: BoxDecoration(color: const Color(0xFF273548), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.devices, color: Color(0xFF64748B), size: 24))),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.productName, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFF8FAFC))),
                const SizedBox(height: 4),
                Text(_fmtPrice((v['price'] as num).toDouble()),
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          // Label
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Chọn màu sắc', style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
          ),
          const SizedBox(height: 12),
          // Color options
          Wrap(
            spacing: 10, runSpacing: 10,
            children: List.generate(widget.variants.length, (i) {
              final vr = widget.variants[i];
              final isSel = i == _selectedIndex;
              final inStock = (vr['stock_quantity'] as int? ?? 0) > 0;
              return GestureDetector(
                onTap: inStock ? () => setState(() => _selectedIndex = i) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF6366F1).withOpacity(0.15) : const Color(0xFF273548),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF6366F1) : const Color(0xFF334155),
                      width: isSel ? 1.5 : 1,
                    ),
                  ),
                  child: Opacity(
                    opacity: inStock ? 1.0 : 0.4,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 18, height: 18,
                        decoration: BoxDecoration(
                          color: _hex(vr['color_hex'] as String?),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1.5),
                        )),
                      const SizedBox(width: 8),
                      Text(vr['color_name'] as String,
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600,
                          color: isSel ? const Color(0xFFF8FAFC) : const Color(0xFF94A3B8))),
                      if (!inStock) ...[
                        const SizedBox(width: 6),
                        Text('Hết hàng', style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFFF43F5E))),
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
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, widget.variants[_selectedIndex]['id'] as String),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.shopping_cart_rounded, size: 18),
                const SizedBox(width: 8),
                Text('Thêm vào giỏ hàng', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

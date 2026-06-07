import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../bloc/cart_bloc.dart';
import '../utils/formatters.dart';
import '../utils/snackbars.dart';

// ── Dark theme constants ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const primary = Color(0xFF6366F1);
  static const success = Color(0xFF10B981);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
  static const error = Color(0xFFEF4444);
  static const amber = Color(0xFFFBBF24);
}

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({Key? key, required this.productId}) : super(key: key);

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductDetail? _product;
  bool _isLoading = true;
  String? _error;
  int _selectedVariantIndex = 0;
  int _currentImagePage = 0;
  final Set<String> _expandedSpecGroups = {};
  bool _showFullDesc = false;
  late PageController _pageController;

  static const _specGroupLabels = {
    'design': 'Thiết kế', 'screen': 'Màn hình',
    'performance': 'Hiệu năng', 'camera_rear': 'Camera sau',
    'camera_front': 'Camera trước', 'connectivity': 'Kết nối',
    'battery': 'Pin', 'webcam': 'Webcam',
    'special_features': 'Tính năng đặc biệt',
  };

  static const _specKeyLabels = {
    'material': 'Chất liệu', 'weight_g': 'Trọng lượng (g)',
    'weight_kg': 'Trọng lượng (kg)', 'dimensions_mm': 'Kích thước',
    'dimensions_cm': 'Kích thước', 'size_inch': 'Kích thước màn hình',
    'resolution': 'Độ phân giải', 'refresh_rate_hz': 'Tần số quét (Hz)',
    'technology': 'Công nghệ màn hình', 'chipset': 'Vi xử lý',
    'cpu': 'CPU', 'gpu': 'GPU', 'ram_gb': 'RAM (GB)',
    'storage_gb': 'Bộ nhớ trong (GB)', 'os': 'Hệ điều hành',
    'main_mp': 'Camera chính (MP)', 'resolution_mp': 'Độ phân giải (MP)',
    'wifi': 'Wi-Fi', 'bluetooth': 'Bluetooth',
    'usage_hours': 'Thời gian sử dụng (giờ)', 'raw': 'Chi tiết',
  };

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadProduct();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final product = await CatalogService().getProductDetail(widget.productId);
      if (mounted) setState(() { _product = product; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
      bottomNavigationBar: _product != null && !_isLoading ? _buildBottomBar() : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _C.error, size: 56),
            const SizedBox(height: 16),
            Text('Không thể tải sản phẩm', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: GoogleFonts.outfit(color: _C.textMuted, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _loadProduct, style: ElevatedButton.styleFrom(backgroundColor: _C.primary), child: const Text('Thử lại')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final product = _product!;
    return CustomScrollView(
      slivers: [
        _buildAppBar(product),
        SliverToBoxAdapter(child: _buildBasicInfo(product)),
        SliverToBoxAdapter(child: _buildVariantSelector(product)),
        if (product.highlightFeatures.isNotEmpty)
          SliverToBoxAdapter(child: _buildHighlightFeatures(product)),
        SliverToBoxAdapter(child: _buildQuickSpecs(product)),
        SliverToBoxAdapter(child: _buildFullSpecs(product)),
        if (product.description != null && product.description!.isNotEmpty)
          SliverToBoxAdapter(child: _buildDescription(product)),
        SliverToBoxAdapter(child: _buildInTheBox(product)),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  // ── APP BAR WITH IMAGE CAROUSEL ──
  Widget _buildAppBar(ProductDetail product) {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      backgroundColor: _C.bg,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _C.surface.withOpacity(0.8), shape: BoxShape.circle),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: _C.surface.withOpacity(0.8), shape: BoxShape.circle),
          child: IconButton(icon: const Icon(Icons.share, color: Colors.white, size: 20), onPressed: () => _shareProduct(product)),
        )
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Column(
          children: [
            Expanded(
              child: product.images.isNotEmpty
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: product.images.length,
                      onPageChanged: (i) => setState(() => _currentImagePage = i),
                      itemBuilder: (_, i) => Container(
                        color: _C.bg,
                        padding: const EdgeInsets.all(24),
                        child: CachedNetworkImage(
                          imageUrl: product.images[i].imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _C.primary)),
                          errorWidget: (_, __, ___) => const Icon(Icons.image, color: _C.textMuted, size: 60),
                        ),
                      ),
                    )
                  : const Center(child: Icon(Icons.image, color: _C.textMuted, size: 60)),
            ),
            if (product.images.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(product.images.length, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImagePage == i ? 24 : 8, height: 8,
                    decoration: BoxDecoration(
                      color: _currentImagePage == i ? _C.primary : _C.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── BASIC INFO ──
  Widget _buildBasicInfo(ProductDetail product) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (product.brandName.isNotEmpty)
            Text(product.brandName.toUpperCase(), style: GoogleFonts.outfit(fontSize: 13, color: _C.primary, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Text(product.name, style: GoogleFonts.outfit(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700, height: 1.2), maxLines: 3, overflow: TextOverflow.ellipsis),
          if (product.lineName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(product.lineName, style: GoogleFonts.outfit(fontSize: 12, color: _C.textMuted)),
          ],
          const SizedBox(height: 8),
          // Rating row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 16, color: _C.amber),
                  const SizedBox(width: 4),
                  Text(product.ratingAvg.toStringAsFixed(1), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
              Text('(${product.ratingCount} đánh giá)', style: GoogleFonts.outfit(fontSize: 12, color: _C.textMuted)),
              Text('• Đã bán ${product.soldCount}', style: GoogleFonts.outfit(fontSize: 12, color: _C.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          // Price row
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(AppFormatters.formatCurrency(product.displayPrice), style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w800, color: _C.success)),
              if (product.hasDiscount) ...[
                Text(AppFormatters.formatCurrency(product.basePrice), style: GoogleFonts.outfit(fontSize: 16, color: _C.textMuted, decoration: TextDecoration.lineThrough)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _C.error, borderRadius: BorderRadius.circular(8)),
                  child: Text('-${product.discountPercent}%', style: GoogleFonts.outfit(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── VARIANT SELECTOR ──
  Widget _buildVariantSelector(ProductDetail product) {
    if (product.variants.isEmpty) return const SizedBox.shrink();
    final selectedVariant = product.variants[_selectedVariantIndex];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Màu sắc', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 10,
            children: List.generate(product.variants.length, (i) {
              final v = product.variants[i];
              final isSel = i == _selectedVariantIndex;
              return GestureDetector(
                onTap: () => setState(() => _selectedVariantIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSel ? _C.primary.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSel ? _C.primary : _C.divider, width: isSel ? 2 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (v.colorHex != null && v.colorHex!.isNotEmpty) ...[
                      Container(width: 12, height: 12, decoration: BoxDecoration(color: _hexColor(v.colorHex), shape: BoxShape.circle, border: Border.all(color: Colors.white24))),
                      const SizedBox(width: 8),
                    ],
                    Text(v.colorName, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: isSel ? Colors.white : _C.textSecondary)),
                  ]),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Text(
            selectedVariant.inStock ? 'Còn ${selectedVariant.stockQuantity} sản phẩm' : 'Hết hàng',
            style: GoogleFonts.outfit(fontSize: 12, color: selectedVariant.inStock ? _C.success : _C.error, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // ── HIGHLIGHT FEATURES ──
  Widget _buildHighlightFeatures(ProductDetail product) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tính năng nổi bật', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: product.highlightFeatures.map((f) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: _C.divider, borderRadius: BorderRadius.circular(20)),
              child: Text(f, style: GoogleFonts.outfit(fontSize: 12, color: _C.textSecondary)),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── QUICK SPECS ──
  Widget _buildQuickSpecs(ProductDetail product) {
    final quickItems = <Map<String, String>>[];
    final specs = product.specs;

    // Try common quick spec paths
    final paths = [
      ['screen', 'size_inch', 'Màn hình', Icons.phone_android],
      ['performance', 'chipset', 'Vi xử lý', Icons.memory],
      ['camera_rear', 'main_mp', 'Camera', Icons.camera_alt],
      ['performance', 'storage_gb', 'Bộ nhớ', Icons.storage],
      ['performance', 'ram_gb', 'RAM', Icons.developer_board],
      ['performance', 'cpu', 'CPU', Icons.memory],
    ];

    for (final p in paths) {
      if (quickItems.length >= 4) break;
      final group = specs[p[0] as String];
      if (group is Map) {
        final val = group[p[1] as String];
        if (val != null) {
          String display = val.toString();
          if (p[1] == 'size_inch') display = '${display}"';
          if (p[1] == 'main_mp') display = '${display}MP';
          if (p[1] == 'storage_gb' || p[1] == 'ram_gb') display = '${display}GB';
          quickItems.add({'label': p[2] as String, 'value': display});
        }
      }
    }

    if (quickItems.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông số nổi bật', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
            children: quickItems.map((item) => Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _C.bg, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item['value']!, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(item['label']!, style: GoogleFonts.outfit(fontSize: 11, color: _C.textMuted)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── FULL SPECS ──
  Widget _buildFullSpecs(ProductDetail product) {
    final specs = product.specs;
    if (specs.isEmpty) return const SizedBox.shrink();

    final groups = <Widget>[];
    for (final entry in specs.entries) {
      if (entry.value == null) continue;
      if (entry.value is Map && (entry.value as Map).isEmpty) continue;
      if (entry.value is List && (entry.value as List).isEmpty) continue;

      final groupLabel = _specGroupLabels[entry.key] ?? entry.key;
      final isExpanded = _expandedSpecGroups.contains(entry.key);

      groups.add(
        GestureDetector(
          onTap: () => setState(() {
            if (isExpanded) { _expandedSpecGroups.remove(entry.key); }
            else { _expandedSpecGroups.add(entry.key); }
          }),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: _C.divider.withOpacity(0.5)))),
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: Text(groupLabel, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white))),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _C.textMuted, size: 20),
                ]),
                if (isExpanded) ...[
                  const SizedBox(height: 8),
                  if (entry.value is Map)
                    ...((entry.value as Map).entries.where((s) => s.value != null).map((spec) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        Expanded(child: Text(_specKeyLabels[spec.key] ?? spec.key.toString(), style: GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary))),
                        Expanded(child: Text(
                          spec.value is List ? (spec.value as List).join(', ') : spec.value.toString(),
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.white), textAlign: TextAlign.right,
                        )),
                      ]),
                    ))),
                  if (entry.value is List)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text((entry.value as List).join(', '), style: GoogleFonts.outfit(fontSize: 13, color: Colors.white)),
                    ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Thông số kỹ thuật', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ...groups,
        ],
      ),
    );
  }

  // ── DESCRIPTION ──
  Widget _buildDescription(ProductDetail product) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mô tả sản phẩm', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          Text(product.description!, style: GoogleFonts.outfit(fontSize: 14, color: _C.textSecondary, height: 1.5), maxLines: _showFullDesc ? null : 4, overflow: _showFullDesc ? null : TextOverflow.ellipsis),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _showFullDesc = !_showFullDesc),
            child: Text(_showFullDesc ? 'Thu gọn' : 'Xem thêm', style: GoogleFonts.outfit(fontSize: 13, color: _C.primary, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── IN THE BOX ──
  Widget _buildInTheBox(ProductDetail product) {
    final items = [product.name, 'Cáp sạc', 'Tài liệu hướng dẫn'];
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trong hộp có gì', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 10),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              const Icon(Icons.check_circle, color: _C.success, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(item, style: GoogleFonts.outfit(fontSize: 13, color: _C.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis)),
            ]),
          )),
        ],
      ),
    );
  }

  // ── BOTTOM ACTION BAR ──
  Widget _buildBottomBar() {
    final product = _product!;
    final selectedVariant = product.variants.isNotEmpty ? product.variants[_selectedVariantIndex] : null;
    final isOutOfStock = selectedVariant != null && !selectedVariant.inStock;

    return Container(
      decoration: BoxDecoration(color: _C.bg, border: Border(top: BorderSide(color: _C.divider))),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(children: [
        // Add to cart button
        GestureDetector(
          onTap: isOutOfStock ? null : () => _addToCart(product, selectedVariant),
          child: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: isOutOfStock ? _C.divider : _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.divider),
            ),
            child: Icon(Icons.shopping_cart_outlined, color: isOutOfStock ? _C.textMuted : Colors.white, size: 24),
          ),
        ),
        const SizedBox(width: 12),
        // Buy now button
        Expanded(
          child: GestureDetector(
            onTap: isOutOfStock ? null : () => _buyNow(product, selectedVariant),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: isOutOfStock ? _C.divider : _C.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  isOutOfStock ? 'Hết hàng' : 'Mua ngay',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: isOutOfStock ? _C.textMuted : Colors.white),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _shareProduct(ProductDetail product) {
    // Lấy base host từ API_URL (bỏ /api/v1)
    final apiUrl = ApiService().baseUrl;
    final baseHost = apiUrl.replaceAll('/api/v1', '');
    final shareLink = '$baseHost/share/product/${product.id}';

    final price = AppFormatters.formatCurrency(product.displayPrice);
    final brand = product.brandName.isNotEmpty ? ' - ${product.brandName}' : '';

    final shareText = '🔥 ${product.name}$brand\n'
        '💰 Giá: $price\n'
        '📱 Xem chi tiết trên TechHub:\n'
        '$shareLink';

    SharePlus.instance.share(
      ShareParams(text: shareText),
    );
  }

  void _addToCart(ProductDetail product, ProductVariantDetail? variant) {
    if (!AuthService().isTokenValid) {
      AppSnackbars.showError(context, 'Vui lòng đăng nhập để thêm vào giỏ');
      return;
    }
    context.read<CartBloc>().add(CartAddItem(
      productId: product.id,
      variantId: variant?.id,
      quantity: 1,
    ));
    AppSnackbars.showSuccess(context, '${product.name} đã thêm vào giỏ');
  }

  void _buyNow(ProductDetail product, ProductVariantDetail? variant) {
    _addToCart(product, variant);
    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false, arguments: 2);
  }

  Color _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return Colors.grey;
    String h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

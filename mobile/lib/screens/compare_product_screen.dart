import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';
import '../utils/formatters.dart';

// ── Theme constants ──
class _C {
  static const bg = Color(0xFF0F172A);
  static const surface = Color(0xFF1E293B);
  static const surfaceLight = Color(0xFF273548);
  static const primary = Color(0xFF6366F1);
  static const emerald = Color(0xFF10B981);
  static const amber = Color(0xFFFBBF24);
  static const rose = Color(0xFFF43F5E);
  static const textPrimary = Color(0xFFF8FAFC);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);
  static const divider = Color(0xFF334155);
}

/// Screen to display a side-by-side comparison of products from chatbot.
class CompareProductScreen extends StatefulWidget {
  final List<String> productIds;

  const CompareProductScreen({Key? key, required this.productIds})
      : super(key: key);

  @override
  State<CompareProductScreen> createState() => _CompareProductScreenState();
}

class _CompareProductScreenState extends State<CompareProductScreen> {
  final CatalogService _catalogService = CatalogService();
  List<ProductDetail>? _products;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final futures = widget.productIds
          .map((id) => _catalogService.getProductDetail(id))
          .toList();
      final products = await Future.wait(futures);
      if (mounted) setState(() { _products = products; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: _C.bg,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _C.surface, shape: BoxShape.circle,
              border: Border.all(color: _C.divider),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: _C.textPrimary, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('So sánh sản phẩm',
            style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _C.textPrimary)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.primary, strokeWidth: 2.5),
      );
    }
    if (_error != null || _products == null || _products!.length < 2) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
                color: _C.rose.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.error_outline_rounded,
                color: _C.rose, size: 36),
          ),
          const SizedBox(height: 16),
          Text('Không thể tải dữ liệu so sánh',
              style: GoogleFonts.outfit(
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadProducts,
            child: Text('Thử lại',
                style: GoogleFonts.outfit(color: _C.primary)),
          ),
        ]),
      );
    }
    return _buildCompareTable(_products!);
  }

  Widget _buildCompareTable(List<ProductDetail> products) {
    // Collect all spec keys
    final allSpecKeys = <String>{};
    for (final p in products) {
      if (p.specs.isNotEmpty) {
        for (final entry in p.specs.entries) {
          if (entry.value is Map) {
            allSpecKeys.addAll((entry.value as Map).keys.cast<String>());
          } else {
            allSpecKeys.add(entry.key);
          }
        }
      }
    }
    final specKeys = allSpecKeys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 40),
      child: Column(children: [
        // ── Product Images + Names (horizontal scroll) ──
        _buildProductHeaders(products),
        const SizedBox(height: 16),
        // ── Basic Info Rows ──
        _buildSectionHeader('Thông tin cơ bản'),
        _buildCompareRow('Thương hiệu',
            products.map((p) => p.brandName.isNotEmpty ? p.brandName : 'N/A').toList()),
        _buildCompareRow('Danh mục',
            products.map((p) => p.categoryName.isNotEmpty ? p.categoryName : 'N/A').toList()),
        _buildPriceRow(products),
        _buildCompareRow('Đánh giá',
            products.map((p) => '${p.ratingAvg.toStringAsFixed(1)}/5 (${p.ratingCount})').toList()),
        _buildCompareRow('Đã bán',
            products.map((p) => '${p.soldCount}').toList()),
        _buildCompareRow('Tồn kho',
            products.map((p) => '${p.totalStock}').toList()),
        // ── Specs ──
        if (specKeys.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildSectionHeader('Thông số kỹ thuật'),
          ...specKeys.map((key) {
            final values = products.map((p) => _getSpecValue(p.specs, key)).toList();
            return _buildCompareRow(key, values);
          }),
        ],
        // ── Highlight Features ──
        if (products.any((p) => p.highlightFeatures.isNotEmpty)) ...[
          const SizedBox(height: 8),
          _buildSectionHeader('Điểm nổi bật'),
          _buildFeaturesRow(products),
        ],
        const SizedBox(height: 24),
        // ── Action buttons ──
        _buildActionButtons(products),
      ]),
    );
  }

  Widget _buildProductHeaders(List<ProductDetail> products) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _C.surface,
        border: Border(bottom: BorderSide(color: _C.divider.withOpacity(0.5))),
      ),
      child: Row(
        children: products.map((p) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(children: [
                // Image
                Container(
                  height: 100, width: 100,
                  decoration: BoxDecoration(
                    color: _C.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.divider.withOpacity(0.5)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: p.primaryImage != null
                        ? CachedNetworkImage(
                            imageUrl: p.primaryImage!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: _C.primary),
                            ),
                            errorWidget: (_, __, ___) => const Icon(
                                Icons.image_outlined,
                                color: _C.textMuted,
                                size: 32),
                          )
                        : const Icon(Icons.image_outlined,
                            color: _C.textMuted, size: 32),
                  ),
                ),
                const SizedBox(height: 10),
                // Name
                Text(p.name,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _C.textPrimary,
                        height: 1.3)),
                const SizedBox(height: 4),
                // Price
                if (p.hasDiscount) ...[
                  Text(AppFormatters.formatCurrency(p.basePrice),
                      style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: _C.textMuted,
                          decoration: TextDecoration.lineThrough)),
                ],
                Text(AppFormatters.formatCurrency(p.displayPrice),
                    style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _C.emerald)),
                if (p.hasDiscount)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.rose.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('-${p.discountPercent}%',
                        style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _C.rose)),
                  ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _C.primary.withOpacity(0.08),
        border: Border(
          bottom: BorderSide(color: _C.primary.withOpacity(0.2)),
        ),
      ),
      child: Row(children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(
              color: _C.primary, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _C.primary)),
      ]),
    );
  }

  Widget _buildCompareRow(String label, List<String> values) {
    // Highlight the "best" value if they differ
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.divider.withOpacity(0.3))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Label column
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: _C.surface.withOpacity(0.5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.textSecondary)),
              ),
            ),
            // Value columns
            ...values.map((v) {
              return Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: Text(v,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: _C.textPrimary,
                          height: 1.4)),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(List<ProductDetail> products) {
    // Find the lowest price
    final prices = products.map((p) => p.displayPrice).toList();
    final minPrice = prices.reduce((a, b) => a < b ? a : b);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.divider.withOpacity(0.3))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 110,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: _C.surface.withOpacity(0.5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Giá bán',
                    style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.textSecondary)),
              ),
            ),
            ...products.map((p) {
              final isBest = p.displayPrice == minPrice && prices.toSet().length > 1;
              return Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  color: isBest ? _C.emerald.withOpacity(0.08) : null,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppFormatters.formatCurrency(p.displayPrice),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isBest ? _C.emerald : _C.textPrimary)),
                      if (isBest)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Rẻ hơn',
                              style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _C.emerald)),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesRow(List<ProductDetail> products) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _C.divider.withOpacity(0.3))),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: products.map((p) {
            return Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: p.highlightFeatures.isEmpty
                      ? [Text('N/A',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: _C.textMuted))]
                      : p.highlightFeatures
                          .take(5)
                          .map((f) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(Icons.check_circle_rounded,
                                          color: _C.emerald, size: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(f,
                                          style: GoogleFonts.outfit(
                                              fontSize: 10,
                                              color: _C.textPrimary,
                                              height: 1.3)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildActionButtons(List<ProductDetail> products) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: products.map((p) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .pushNamed('/product-detail', arguments: p.id);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Xem',
                    style: GoogleFonts.outfit(
                        fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _getSpecValue(Map<String, dynamic> specs, String key) {
    if (specs.containsKey(key)) {
      final val = specs[key];
      if (val is Map) return val.values.join(', ');
      return val.toString();
    }
    for (final group in specs.values) {
      if (group is Map && group.containsKey(key)) {
        return group[key].toString();
      }
    }
    return 'N/A';
  }
}

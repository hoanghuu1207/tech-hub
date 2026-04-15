import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/index.dart';
import 'app_button.dart';

class ProductCard extends StatelessWidget {
  final String productId;
  final String name;
  final double price;
  final double? originalPrice;
  final double rating;
  final int reviewCount;
  final String imagePath;
  final bool inStock;
  final VoidCallback onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    Key? key,
    required this.productId,
    required this.name,
    required this.price,
    this.originalPrice,
    required this.rating,
    required this.reviewCount,
    required this.imagePath,
    required this.inStock,
    required this.onTap,
    this.onAddToCart,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final discount = originalPrice != null
        ? ((originalPrice! - price) / originalPrice! * 100).toInt()
        : 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.softCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.xl),
                        topRight: Radius.circular(AppRadius.xl),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.xl),
                        topRight: Radius.circular(AppRadius.xl),
                      ),
                      child: imagePath.endsWith('.svg')
                          ? SvgPicture.asset(imagePath, fit: BoxFit.cover)
                          : Image.network(imagePath, fit: BoxFit.cover),
                    ),
                  ),
                  // Premium Discount Badge
                  if (discount > 0)
                    Positioned(
                      top: AppSpacing.md,
                      right: AppSpacing.md,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          gradient: AppColors.discountGradient,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.discount.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '-$discount%',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // Stock status overlay
                  if (!inStock)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.7),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(AppRadius.xl),
                            topRight: Radius.circular(AppRadius.xl),
                          ),
                        ),
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                                color: AppColors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(AppRadius.full)
                            ),
                            child: const Text(
                              'Hết hàng',
                              style: TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info Section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Rating
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Text(
                        AppFormatters.formatRating(rating),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '($reviewCount)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.gray400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Price Layout
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (originalPrice != null)
                              Text(
                                AppFormatters.formatCurrency(originalPrice!),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.gray400,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            Text(
                              AppFormatters.formatCurrency(price),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.secondaryDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Add to cart button (Floating style)
                      GestureDetector(
                        onTap: inStock ? onAddToCart : null,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            gradient: inStock ? AppColors.neonGradient : null,
                            color: inStock ? null : AppColors.gray300,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: inStock ? AppShadows.neonGlow : [],
                          ),
                          child: const Icon(
                            Icons.add_shopping_cart_rounded,
                            color: AppColors.white,
                            size: 20,
                          ),
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

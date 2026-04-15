import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../bloc/index.dart';
import '../../models/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _carouselIndex = 0;

  @override
  void initState() {
    super.initState();
    // Fetch data on init
    context.read<ProductBloc>().add(const FetchTrendingProductsRequested());
    context.read<ProductBloc>().add(const FetchCategoriesRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHomeAppBar(
        userName: 'Hữu Hoàng',
        onProfileTap: () {
          Navigator.of(context).pushNamed('/profile');
        },
        onNotificationTap: () {
          // TODO: Navigate to notifications
        },
        notificationCount: 3,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Floating Glassmorphic Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/search'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    boxShadow: AppShadows.floating,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded, color: AppColors.primary, size: 24),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Tìm kiếm laptop, điện thoại...',
                          style: TextStyle(
                            color: AppColors.gray400,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: const Icon(Icons.mic_rounded, color: AppColors.secondaryDark, size: 20),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Premium Banner Carousel
            CarouselSlider(
              options: CarouselOptions(
                height: 180,
                autoPlay: true,
                autoPlayInterval: const Duration(seconds: 4),
                enlargeCenterPage: true,
                viewportFraction: 0.9,
                onPageChanged: (index, reason) {
                  setState(() => _carouselIndex = index);
                },
              ),
              items: [
                {'title': 'Màn Hình\nĐỉnh Cao', 'subtitle': 'Giảm tới 30%', 'color1': Color(0xFF0F172A), 'color2': Color(0xFF334155)},
                {'title': 'Gaming Gear', 'subtitle': 'Mới về hàng', 'color1': AppColors.secondary, 'color2': AppColors.accentPurple},
                {'title': 'Flash Sale', 'subtitle': 'Duy nhất hôm nay', 'color1': AppColors.discount, 'color2': AppColors.accentPink},
              ].map((banner) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [banner['color1'] as Color, banner['color2'] as Color],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadows.softCard,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        banner['subtitle'] as String,
                        style: const TextStyle(
                          color: AppColors.surface,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        banner['title'] as String,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.md),
            // Modern Dot Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                3,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _carouselIndex == index ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _carouselIndex == index
                        ? AppColors.secondary
                        : AppColors.gray300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Dynamic Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: const Text(
                'Danh Mục',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state is CategoriesLoadedSuccess) {
                  return SizedBox(
                    height: 100,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      scrollDirection: Axis.horizontal,
                      itemCount: state.categories.length,
                      itemBuilder: (context, index) {
                        final category = state.categories[index];
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/products-by-category',
                              arguments: category.name,
                            );
                          },
                          child: Container(
                            width: 80,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                            child: Column(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(AppRadius.xl),
                                    boxShadow: AppShadows.softCard,
                                  ),
                                  child: Icon(
                                    Icons.devices_other_rounded,
                                    color: AppColors.secondaryDark,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  category.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                } else if (state is ProductLoading) {
                  return SizedBox(
                    height: 100,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      scrollDirection: Axis.horizontal,
                      itemCount: 5,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                          child: LoadingShimmer(
                            width: 64,
                            height: 64,
                            borderRadius: AppRadius.xl,
                          ),
                        );
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Trending section with premium styling
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Sản Phẩm Nổi Bật',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed('/products');
                    },
                    child: const Text(
                      'Tất cả',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            BlocBuilder<ProductBloc, ProductState>(
              builder: (context, state) {
                if (state is ProductsLoadedSuccess) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.lg,
                        crossAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: state.products.length,
                      itemBuilder: (context, index) {
                        final product = state.products[index];
                        return ProductCard(
                          // ... mapping same as before ...
                          productId: product.id,
                          name: product.name,
                          price: product.price,
                          originalPrice: product.originalPrice,
                          rating: product.rating,
                          reviewCount: product.reviewCount,
                          imagePath: product.images.first,
                          inStock: product.inStock,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              '/product-detail',
                              arguments: product.id,
                            );
                          },
                          onAddToCart: () {
                            // ... same logic ...
                            final cartItem = CartItem(
                              id: product.id,
                              product: product,
                              quantity: 1,
                              addedAt: DateTime.now(),
                            );
                            context.read<CartBloc>().add(
                                  CartAddItemRequested(
                                    product,
                                    quantity: 1,
                                  ),
                                );
                            AppSnackbars.showSuccess(
                              context,
                              '${product.name} đã thêm vào giỏ',
                            );
                          },
                        );
                      },
                    ),
                  );
                } else if (state is ProductLoading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: AppSpacing.lg,
                        crossAxisSpacing: AppSpacing.lg,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: 4,
                      itemBuilder: (context, index) {
                        return const ProductCardShimmer();
                      },
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 100), // padding for FAB
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: AppShadows.neonGlow,
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.of(context).pushNamed('/chat');
          },
          label: const Text(
            'Trợ lý AI',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          icon: const Icon(Icons.auto_awesome),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.secondaryLight,
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Tìm kiếm'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Giỏ hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt), label: 'Đơn hàng'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Tài khoản'),
        ],
        onTap: (index) {
          // TODO: Navigate based on index
        },
      ),
    );
  }
}

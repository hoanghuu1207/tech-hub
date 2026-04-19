import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../bloc/index.dart';
import '../../models/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _carouselIndex = 0;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    // Fetch data on init
    context.read<ProductBloc>().add(const FetchTrendingProductsRequested());
    context.read<ProductBloc>().add(const FetchCategoriesRequested());
  }

  Widget _buildTimeBox(String time, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            time,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF8690ee), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: isActive
          ? Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFF1a237e),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            )
          : Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: const Color(0xFF9CA3AF), size: 28),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildHomeTab(context),
          const Scaffold(body: Center(child: Text('Search', style: TextStyle(color: Colors.black)))),
          const CartScreen(),
          const Scaffold(body: Center(child: Text('Orders', style: TextStyle(color: Colors.black)))),
          const ProfileScreen(),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1a237e).withOpacity(0.4),
              blurRadius: 30,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/chat');
          },
          backgroundColor: const Color(0xFF1a237e),
          foregroundColor: const Color(0xFF58e6ff),
          elevation: 0,
          child: const Icon(Icons.psychology, size: 32),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(30),
            topRight: Radius.circular(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildNavItem(Icons.home, 'HOME', _selectedTab == 0, () => setState(() => _selectedTab = 0)),
                _buildNavItem(Icons.search, 'SEARCH', _selectedTab == 1, () => setState(() => _selectedTab = 1)),
                _buildNavItem(Icons.shopping_cart, 'CART', _selectedTab == 2, () => setState(() => _selectedTab = 2)),
                _buildNavItem(Icons.inventory_2, 'ORDERS', _selectedTab == 3, () => setState(() => _selectedTab = 3)),
                _buildNavItem(Icons.person, 'ACCOUNT', _selectedTab == 4, () => setState(() => _selectedTab = 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppHomeAppBar(
        userName: 'Hữu Hoàng',
        onProfileTap: () {
          setState(() {
            _selectedTab = 4;
          });
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
            // Premium Bento Cards
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                children: [
                  // Card 1: Quantum Efficiency
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xxl),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF000666), Color(0xFF1a237e)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.softCard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2c1600),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt, color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'FLASH SALE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text(
                          'Quantum\nEfficiency.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const Text(
                          'Elevate your workspace with the next generation of neural-engine processing.',
                          style: TextStyle(
                            color: Color(0xFF8690ee),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            _buildTimeBox('08', 'HRS'),
                            const SizedBox(width: AppSpacing.sm),
                            _buildTimeBox('42', 'MIN'),
                            const SizedBox(width: AppSpacing.sm),
                            _buildTimeBox('19', 'SEC'),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006876),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                          ),
                          child: const Text('Explore Drops', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Card 2: Retro Futures
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: const Color(0xFF58e6ff),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      boxShadow: AppShadows.softCard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Retro Futures.',
                          style: TextStyle(
                            color: Color(0xFF006573),
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const Text(
                          'Curated collection of analog-inspired digital gear.',
                          style: TextStyle(
                            color: Color(0xFF004e59),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: const [
                            Text(
                              'View Collection',
                              style: TextStyle(
                                color: Color(0xFF006573),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward, color: Color(0xFF006573), size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            // Dynamic Categories
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Browse Labs',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF000666),
                        ),
                      ),
                      Text(
                        'Specialized hardware sectors',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF767683),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: const Row(
                      children: [
                        Text(
                          'View All Labs',
                          style: TextStyle(
                            color: Color(0xFF006876),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(Icons.open_in_new, color: Color(0xFF006876), size: 16),
                      ],
                    ),
                  ),
                ],
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
                                  width: 72,
                                  height: 72,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFf5f2fb),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.computer_rounded,
                                    color: Color(0xFF000666),
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  category.name.toUpperCase(),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    color: Color(0xFF454652),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Featured Apparatus',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF000666),
                    ),
                  ),
                  Text(
                    'Engineered for peak performance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF767683),
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
    );
  }
}

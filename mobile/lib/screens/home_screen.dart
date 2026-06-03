import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../bloc/chat_bloc.dart';
import '../../bloc/cart_bloc.dart';
import '../../bloc/catalog_bloc.dart';
import '../../widgets/premium_home_tab.dart';
import '../../widgets/products_tab.dart';
import '../../widgets/chat_bottom_sheet.dart';
import 'cart_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartBloc>().add(const CartFetch());
    });
  }

  // ── Dark theme colors ──
  static const _bgDark = Color(0xFF0F172A);
  static const _surfaceDark = Color(0xFF1E293B);
  static const _primaryColor = Color(0xFF6366F1);
  static const _textMuted = Color(0xFF64748B);
  static const _dividerColor = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          PremiumHomeTab(
            onProfileTap: () => setState(() => _selectedTab = 4),
            onCartTap: () => setState(() => _selectedTab = 2),
            onSearchTap: () => Navigator.of(context).pushNamed('/search'),
            onProductsTap: () => setState(() => _selectedTab = 1),
          ),
          BlocProvider(
            create: (_) => CatalogBloc()..add(const CatalogStarted()),
            child: const ProductsTab(),
          ),
          CartScreen(
            onContinueShopping: () => setState(() => _selectedTab = 0),
          ),
          const Scaffold(
            backgroundColor: _bgDark,
            body: Center(child: Text('Orders', style: TextStyle(color: Colors.white))),
          ),
          const ProfileScreen(),
        ],
      ),
      // ── AI Chatbot FAB with glow ──
      floatingActionButton: _buildChatbotFAB(),
      // ── Premium Dark Bottom Nav ──
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildChatbotFAB() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.5),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => BlocProvider.value(
              value: context.read<ChatBloc>(),
              child: ChatBottomSheet(
                onViewCart: () => setState(() => _selectedTab = 2),
              ),
            ),
          );
        },
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.psychology, size: 28),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceDark,
        border: Border(top: BorderSide(color: _dividerColor.withOpacity(0.5))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          child: BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(Icons.home_rounded, 'Trang chủ', 0),
                  _buildNavItem(Icons.grid_view_rounded, 'Sản phẩm', 1),
                  _buildNavItem(Icons.shopping_bag_rounded, 'Giỏ hàng', 2, badgeCount: cartState.cart.itemCount),
                  _buildNavItem(Icons.receipt_long_rounded, 'Đơn hàng', 3),
                  _buildNavItem(Icons.person_rounded, 'Tài khoản', 4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, {int badgeCount = 0}) {
    final isActive = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? _primaryColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? _primaryColor : _textMuted,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF43F5E), // Rose red color
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Center(
                        child: Text(
                          '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? _primaryColor : _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

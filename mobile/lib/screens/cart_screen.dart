import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/index.dart';
import '../../utils/index.dart';
import '../../widgets/index.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppAppBar(
        title: 'Giỏ Hàng',
        showBackButton: false,
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.cart.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 80,
                    color: AppColors.gray300,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text(
                    'Giỏ hàng của bạn trống',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    label: 'Tiếp tục mua sắm',
                    onPressed: () {
                      Navigator.of(context).pushNamed('/home');
                    },
                    width: 200,
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: state.cart.items.length,
                  itemBuilder: (context, index) {
                    final cartItem = state.cart.items[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withOpacity(0.08),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Product image
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.gray100,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Image.network(
                              cartItem.product.images.first,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          // Product info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cartItem.product.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.black,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  AppFormatters.formatCurrency(
                                      cartItem.product.price),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Quantity controls
                          Column(
                            children: [
                              Row(
                                children: [
                                  IconButton(
                                    iconSize: 20,
                                    onPressed: cartItem.quantity > 1
                                        ? () {
                                            context.read<CartBloc>().add(
                                                  CartUpdateQuantityRequested(
                                                    cartItem.id,
                                                    cartItem.quantity - 1,
                                                  ),
                                                );
                                          }
                                        : null,
                                    icon: const Icon(Icons.remove),
                                  ),
                                  Text(
                                    '${cartItem.quantity}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  IconButton(
                                    iconSize: 20,
                                    onPressed: () {
                                      context.read<CartBloc>().add(
                                            CartUpdateQuantityRequested(
                                              cartItem.id,
                                              cartItem.quantity + 1,
                                            ),
                                          );
                                    },
                                    icon: const Icon(Icons.add),
                                  ),
                                ],
                              ),
                              AppTextButton(
                                label: 'Xóa',
                                onPressed: () {
                                  context.read<CartBloc>().add(
                                        CartRemoveItemRequested(cartItem.id),
                                      );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Summary
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.gray200),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tổng tiền:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppFormatters.formatCurrency(state.cart.total),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Tiến hành thanh toán',
                      onPressed: () {
                        Navigator.of(context).pushNamed('/checkout');
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

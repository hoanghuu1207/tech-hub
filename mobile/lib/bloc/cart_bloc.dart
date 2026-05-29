import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/cart_model.dart';
import '../../services/cart_service.dart';

// ── Events ──
abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

class CartFetch extends CartEvent {
  const CartFetch();
}

class CartAddItem extends CartEvent {
  final String productId;
  final String? variantId;
  final int quantity;

  const CartAddItem({
    required this.productId,
    this.variantId,
    this.quantity = 1,
  });

  @override
  List<Object?> get props => [productId, variantId, quantity];
}

class CartRemoveItem extends CartEvent {
  final String itemId;
  const CartRemoveItem(this.itemId);
  @override
  List<Object?> get props => [itemId];
}

class CartUpdateQuantity extends CartEvent {
  final String itemId;
  final int quantity;
  const CartUpdateQuantity(this.itemId, this.quantity);
  @override
  List<Object?> get props => [itemId, quantity];
}

class CartClear extends CartEvent {
  const CartClear();
}

class CartDeleteSelected extends CartEvent {
  final List<String> itemIds;
  const CartDeleteSelected(this.itemIds);
  @override
  List<Object?> get props => [itemIds];
}

class CartCheckoutRequested extends CartEvent {
  final List<CartItem>? items; // if null, checkout all items
  final String? addressId;
  final ShippingAddress? shippingAddress;
  final String? note;
  final String paymentMethod;

  const CartCheckoutRequested({
    this.items,
    this.addressId,
    this.shippingAddress,
    this.note,
    this.paymentMethod = 'payos',
  });

  @override
  List<Object?> get props => [items, addressId, shippingAddress, note, paymentMethod];
}

// ── State ──
class CartState extends Equatable {
  final Cart cart;
  final bool isCheckingOut;
  final String? checkoutUrl;
  final String? checkoutError;
  final String? lastOrderId;
  final bool isLoading;

  const CartState({
    required this.cart,
    this.isCheckingOut = false,
    this.checkoutUrl,
    this.checkoutError,
    this.lastOrderId,
    this.isLoading = false,
  });

  CartState copyWith({
    Cart? cart,
    bool? isCheckingOut,
    String? checkoutUrl,
    String? checkoutError,
    String? lastOrderId,
    bool? isLoading,
  }) {
    return CartState(
      cart: cart ?? this.cart,
      isCheckingOut: isCheckingOut ?? this.isCheckingOut,
      checkoutUrl: checkoutUrl,
      checkoutError: checkoutError,
      lastOrderId: lastOrderId,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  @override
  List<Object?> get props => [cart, isCheckingOut, checkoutUrl, checkoutError, lastOrderId, isLoading];
}

// ── BLoC ──
class CartBloc extends Bloc<CartEvent, CartState> {
  final CartService _cartService = CartService();

  CartBloc() : super(CartState(cart: Cart(items: []))) {
    on<CartFetch>(_onFetch);
    on<CartAddItem>(_onAdd);
    on<CartRemoveItem>(_onRemove);
    on<CartUpdateQuantity>(_onUpdateQty);
    on<CartClear>(_onClear);
    on<CartDeleteSelected>(_onDeleteSelected);
    on<CartCheckoutRequested>(_onCheckout);
  }

  Future<void> _onFetch(CartFetch event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final cart = await _cartService.getCart();
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onAdd(CartAddItem event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final cart = await _cartService.addToCart(
        productId: event.productId,
        variantId: event.variantId,
        quantity: event.quantity,
      );
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onRemove(CartRemoveItem event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final cart = await _cartService.removeCartItem(event.itemId);
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onUpdateQty(CartUpdateQuantity event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final cart = await _cartService.updateQuantity(event.itemId, event.quantity);
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onClear(CartClear event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final cart = await _cartService.clearCart();
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onDeleteSelected(CartDeleteSelected event, Emitter<CartState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      Cart cart = state.cart;
      for (final id in event.itemIds) {
        cart = await _cartService.removeCartItem(id);
      }
      emit(state.copyWith(cart: cart, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onCheckout(CartCheckoutRequested event, Emitter<CartState> emit) async {
    emit(state.copyWith(isCheckingOut: true, checkoutError: null, checkoutUrl: null));
    try {
      final checkoutItems = event.items ?? state.cart.items;
      final result = await _cartService.createOrder(
        items: checkoutItems,
        addressId: event.addressId,
        shippingAddress: event.shippingAddress,
        note: event.note,
        paymentMethod: event.paymentMethod,
      );

      final checkoutUrl = result['checkout_url'] as String?;
      final orderId = result['order_id']?.toString();

      // After checkout, re-fetch to get remaining items
      final updatedCart = await _cartService.getCart();

      emit(CartState(
        cart: updatedCart,
        isCheckingOut: false,
        checkoutUrl: checkoutUrl,
        lastOrderId: orderId,
      ));
    } catch (e) {
      emit(state.copyWith(
        isCheckingOut: false,
        checkoutError: e.toString(),
      ));
    }
  }
}

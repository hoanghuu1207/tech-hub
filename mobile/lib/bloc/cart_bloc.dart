import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/index.dart';
import 'package:uuid/uuid.dart';

// Events
abstract class CartEvent extends Equatable {
  const CartEvent();
  @override
  List<Object?> get props => [];
}

class CartAddItemRequested extends CartEvent {
  final Product product;
  final int quantity;

  const CartAddItemRequested(this.product, {this.quantity = 1});

  @override
  List<Object?> get props => [product, quantity];
}

class CartRemoveItemRequested extends CartEvent {
  final String itemId;

  const CartRemoveItemRequested(this.itemId);

  @override
  List<Object?> get props => [itemId];
}

class CartUpdateQuantityRequested extends CartEvent {
  final String itemId;
  final int quantity;

  const CartUpdateQuantityRequested(this.itemId, this.quantity);

  @override
  List<Object?> get props => [itemId, quantity];
}

class CartClearRequested extends CartEvent {
  const CartClearRequested();
}

// States
abstract class CartState extends Equatable {
  final Cart cart;

  const CartState(this.cart);

  @override
  List<Object?> get props => [cart];
}

class CartInitial extends CartState {
  CartInitial() : super(Cart(items: [], updatedAt: DateTime.now()));
}

class CartUpdated extends CartState {
  const CartUpdated(Cart cart) : super(cart);
}

// BLoC
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(CartInitial()) {
    on<CartAddItemRequested>(_onCartAddItemRequested);
    on<CartRemoveItemRequested>(_onCartRemoveItemRequested);
    on<CartUpdateQuantityRequested>(_onCartUpdateQuantityRequested);
    on<CartClearRequested>(_onCartClearRequested);
  }

  Future<void> _onCartAddItemRequested(
    CartAddItemRequested event,
    Emitter<CartState> emit,
  ) async {
    final item = CartItem(
      id: const Uuid().v4(),
      product: event.product,
      quantity: event.quantity,
      addedAt: DateTime.now(),
    );

    final updatedCart = state.cart.addItem(item);
    emit(CartUpdated(updatedCart));
  }

  Future<void> _onCartRemoveItemRequested(
    CartRemoveItemRequested event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = state.cart.removeItem(event.itemId);
    emit(CartUpdated(updatedCart));
  }

  Future<void> _onCartUpdateQuantityRequested(
    CartUpdateQuantityRequested event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = state.cart.updateQuantity(event.itemId, event.quantity);
    emit(CartUpdated(updatedCart));
  }

  Future<void> _onCartClearRequested(
    CartClearRequested event,
    Emitter<CartState> emit,
  ) async {
    final updatedCart = state.cart.clear();
    emit(CartUpdated(updatedCart));
  }
}

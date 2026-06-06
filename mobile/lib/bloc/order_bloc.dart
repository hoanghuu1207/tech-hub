import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/order_model.dart';
import '../services/order_service.dart';

// ═══════════════════════════════════════════
//  EVENTS
// ═══════════════════════════════════════════

abstract class OrderEvent extends Equatable {
  const OrderEvent();
  @override
  List<Object?> get props => [];
}

class OrdersFetchRequested extends OrderEvent {
  const OrdersFetchRequested();
}

class OrdersFilterChanged extends OrderEvent {
  final String? statusFilter;
  const OrdersFilterChanged(this.statusFilter);
  @override
  List<Object?> get props => [statusFilter];
}

class OrdersRefreshRequested extends OrderEvent {
  const OrdersRefreshRequested();
}

// ═══════════════════════════════════════════
//  STATE
// ═══════════════════════════════════════════

enum OrdersStatus { initial, loading, loaded, error }

class OrdersState extends Equatable {
  final OrdersStatus status;
  final List<Order> orders;
  final List<Order> filteredOrders;
  final String? selectedStatus;
  final String? errorMessage;

  const OrdersState({
    this.status = OrdersStatus.initial,
    this.orders = const [],
    this.filteredOrders = const [],
    this.selectedStatus,
    this.errorMessage,
  });

  OrdersState copyWith({
    OrdersStatus? status,
    List<Order>? orders,
    List<Order>? filteredOrders,
    String? Function()? selectedStatus,
    String? Function()? errorMessage,
  }) {
    return OrdersState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      selectedStatus:
          selectedStatus != null ? selectedStatus() : this.selectedStatus,
      errorMessage:
          errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, orders, filteredOrders, selectedStatus, errorMessage];
}

// ═══════════════════════════════════════════
//  BLOC
// ═══════════════════════════════════════════

class OrderBloc extends Bloc<OrderEvent, OrdersState> {
  final OrderService _orderService = OrderService();

  OrderBloc() : super(const OrdersState()) {
    on<OrdersFetchRequested>(_onFetch);
    on<OrdersFilterChanged>(_onFilter);
    on<OrdersRefreshRequested>(_onRefresh);
  }

  Future<void> _onFetch(
    OrdersFetchRequested event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(status: OrdersStatus.loading));
    try {
      final orders = await _orderService.getUserOrders(limit: 50);
      final filtered = _applyFilter(orders, state.selectedStatus);
      emit(state.copyWith(
        status: OrdersStatus.loaded,
        orders: orders,
        filteredOrders: filtered,
        errorMessage: () => null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: OrdersStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  Future<void> _onRefresh(
    OrdersRefreshRequested event,
    Emitter<OrdersState> emit,
  ) async {
    try {
      final orders = await _orderService.getUserOrders(limit: 50);
      final filtered = _applyFilter(orders, state.selectedStatus);
      emit(state.copyWith(
        status: OrdersStatus.loaded,
        orders: orders,
        filteredOrders: filtered,
        errorMessage: () => null,
      ));
    } catch (e) {
      // Keep existing data on refresh failure
    }
  }

  void _onFilter(
    OrdersFilterChanged event,
    Emitter<OrdersState> emit,
  ) {
    final filtered = _applyFilter(state.orders, event.statusFilter);
    emit(state.copyWith(
      filteredOrders: filtered,
      selectedStatus: () => event.statusFilter,
    ));
  }

  List<Order> _applyFilter(List<Order> orders, String? status) {
    if (status == null || status.isEmpty) return orders;
    return orders.where((o) => o.status == status).toList();
  }
}

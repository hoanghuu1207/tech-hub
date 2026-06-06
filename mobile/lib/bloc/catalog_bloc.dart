import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/catalog_models.dart';
import '../services/catalog_service.dart';

// ═══════════════════════════════════════════════════════════════
// ── Events ──
// ═══════════════════════════════════════════════════════════════

abstract class CatalogEvent extends Equatable {
  const CatalogEvent();
  @override
  List<Object?> get props => [];
}

/// Initial load — fetch categories + all products.
class CatalogStarted extends CatalogEvent {
  const CatalogStarted();
}

/// User taps a category chip. null = "Tất cả".
class CatalogCategorySelected extends CatalogEvent {
  final String? categoryId;
  const CatalogCategorySelected(this.categoryId);
  @override
  List<Object?> get props => [categoryId];
}

/// User taps a brand chip. null = "Tất cả [Cat]".
class CatalogBrandSelected extends CatalogEvent {
  final String categoryId;
  final String? brandId;
  const CatalogBrandSelected(this.categoryId, this.brandId);
  @override
  List<Object?> get props => [categoryId, brandId];
}

/// User taps a product-line chip.
class CatalogLineSelected extends CatalogEvent {
  final String lineId;
  const CatalogLineSelected(this.lineId);
  @override
  List<Object?> get props => [lineId];
}

/// Infinite scroll — load next page.
class CatalogLoadMore extends CatalogEvent {
  const CatalogLoadMore();
}

// ═══════════════════════════════════════════════════════════════
// ── State ──
// ═══════════════════════════════════════════════════════════════

enum CatalogStatus { initial, loading, loaded, error }

class CatalogState extends Equatable {
  final CatalogStatus status;
  final List<CatalogCategory> categories;
  final List<ProductCompact> products;
  final int total;

  // Current filter selections
  final String? selectedCategoryId;
  final String? selectedBrandId;
  final String? selectedLineId;

  // Sub-filter lists
  final List<CatalogBrand> brands;
  final List<CatalogProductLine> productLines;

  // Display names for breadcrumb
  final String? selectedCategoryName;
  final String? selectedBrandName;
  final String? selectedLineName;

  // Pagination
  final int offset;
  final bool hasMore;

  // Error
  final String? errorMessage;

  const CatalogState({
    this.status = CatalogStatus.initial,
    this.categories = const [],
    this.products = const [],
    this.total = 0,
    this.selectedCategoryId,
    this.selectedBrandId,
    this.selectedLineId,
    this.brands = const [],
    this.productLines = const [],
    this.selectedCategoryName,
    this.selectedBrandName,
    this.selectedLineName,
    this.offset = 0,
    this.hasMore = true,
    this.errorMessage,
  });

  CatalogState copyWith({
    CatalogStatus? status,
    List<CatalogCategory>? categories,
    List<ProductCompact>? products,
    int? total,
    String? Function()? selectedCategoryId,
    String? Function()? selectedBrandId,
    String? Function()? selectedLineId,
    List<CatalogBrand>? brands,
    List<CatalogProductLine>? productLines,
    String? Function()? selectedCategoryName,
    String? Function()? selectedBrandName,
    String? Function()? selectedLineName,
    int? offset,
    bool? hasMore,
    String? Function()? errorMessage,
  }) {
    return CatalogState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      products: products ?? this.products,
      total: total ?? this.total,
      selectedCategoryId:
          selectedCategoryId != null ? selectedCategoryId() : this.selectedCategoryId,
      selectedBrandId:
          selectedBrandId != null ? selectedBrandId() : this.selectedBrandId,
      selectedLineId:
          selectedLineId != null ? selectedLineId() : this.selectedLineId,
      brands: brands ?? this.brands,
      productLines: productLines ?? this.productLines,
      selectedCategoryName:
          selectedCategoryName != null ? selectedCategoryName() : this.selectedCategoryName,
      selectedBrandName:
          selectedBrandName != null ? selectedBrandName() : this.selectedBrandName,
      selectedLineName:
          selectedLineName != null ? selectedLineName() : this.selectedLineName,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        products,
        total,
        selectedCategoryId,
        selectedBrandId,
        selectedLineId,
        brands,
        productLines,
        selectedCategoryName,
        selectedBrandName,
        selectedLineName,
        offset,
        hasMore,
        errorMessage,
      ];
}

// ═══════════════════════════════════════════════════════════════
// ── BLoC ──
// ═══════════════════════════════════════════════════════════════

class CatalogBloc extends Bloc<CatalogEvent, CatalogState> {
  final CatalogService _service = CatalogService();
  static const int _pageSize = 50;

  CatalogBloc() : super(const CatalogState()) {
    on<CatalogStarted>(_onStarted);
    on<CatalogCategorySelected>(_onCategorySelected);
    on<CatalogBrandSelected>(_onBrandSelected);
    on<CatalogLineSelected>(_onLineSelected);
    on<CatalogLoadMore>(_onLoadMore);
  }

  // ── Initial load ──
  Future<void> _onStarted(CatalogStarted event, Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      final categories = await _service.getCategories();
      final products = await _service.getAllProducts(limit: _pageSize, offset: 0);
      final total = await _service.getAllProductsTotal();
      emit(state.copyWith(
        status: CatalogStatus.loaded,
        categories: categories,
        products: products,
        total: total,
        offset: products.length,
        hasMore: products.length < total,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CatalogStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  // ── Category selected ──
  Future<void> _onCategorySelected(
      CatalogCategorySelected event, Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      if (event.categoryId == null) {
        // "Tất cả" — clear all filters
        final products = await _service.getAllProducts(limit: _pageSize, offset: 0);
        final total = await _service.getAllProductsTotal();
        emit(state.copyWith(
          status: CatalogStatus.loaded,
          products: products,
          total: total,
          selectedCategoryId: () => null,
          selectedBrandId: () => null,
          selectedLineId: () => null,
          brands: [],
          productLines: [],
          selectedCategoryName: () => null,
          selectedBrandName: () => null,
          selectedLineName: () => null,
          offset: products.length,
          hasMore: products.length < total,
        ));
      } else {
        final result =
            await _service.getCategoryProducts(event.categoryId!, limit: _pageSize, offset: 0);
        final catName = state.categories
            .where((c) => c.id == event.categoryId)
            .map((c) => c.name)
            .firstOrNull;
        emit(state.copyWith(
          status: CatalogStatus.loaded,
          products: result.products,
          total: result.total,
          brands: result.brands,
          productLines: [],
          selectedCategoryId: () => event.categoryId,
          selectedBrandId: () => null,
          selectedLineId: () => null,
          selectedCategoryName: () => catName,
          selectedBrandName: () => null,
          selectedLineName: () => null,
          offset: result.products.length,
          hasMore: result.products.length < result.total,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CatalogStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  // ── Brand selected ──
  Future<void> _onBrandSelected(
      CatalogBrandSelected event, Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      if (event.brandId == null) {
        // "Tất cả [Category]" — go back to category view
        final result = await _service.getCategoryProducts(
            event.categoryId,
            limit: _pageSize,
            offset: 0);
        emit(state.copyWith(
          status: CatalogStatus.loaded,
          products: result.products,
          total: result.total,
          brands: result.brands,
          productLines: [],
          selectedBrandId: () => null,
          selectedLineId: () => null,
          selectedBrandName: () => null,
          selectedLineName: () => null,
          offset: result.products.length,
          hasMore: result.products.length < result.total,
        ));
      } else {
        final result = await _service.getBrandProducts(
            event.categoryId, event.brandId!,
            limit: _pageSize, offset: 0);
        final brandName = state.brands
            .where((b) => b.id == event.brandId)
            .map((b) => b.name)
            .firstOrNull;
        emit(state.copyWith(
          status: CatalogStatus.loaded,
          products: result.products,
          total: result.total,
          productLines: result.lines,
          selectedBrandId: () => event.brandId,
          selectedLineId: () => null,
          selectedBrandName: () => brandName,
          selectedLineName: () => null,
          offset: result.products.length,
          hasMore: result.products.length < result.total,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: CatalogStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  // ── Product-line selected ──
  Future<void> _onLineSelected(
      CatalogLineSelected event, Emitter<CatalogState> emit) async {
    emit(state.copyWith(status: CatalogStatus.loading));
    try {
      final result =
          await _service.getLineProducts(event.lineId, limit: _pageSize, offset: 0);
      final lineName = state.productLines
          .where((l) => l.id == event.lineId)
          .map((l) => l.name)
          .firstOrNull;
      emit(state.copyWith(
        status: CatalogStatus.loaded,
        products: result.products,
        total: result.total,
        selectedLineId: () => event.lineId,
        selectedLineName: () => lineName,
        offset: result.products.length,
        hasMore: result.products.length < result.total,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: CatalogStatus.error,
        errorMessage: () => e.toString(),
      ));
    }
  }

  // ── Load more (pagination) ──
  Future<void> _onLoadMore(CatalogLoadMore event, Emitter<CatalogState> emit) async {
    if (!state.hasMore || state.status == CatalogStatus.loading) return;

    try {
      List<ProductCompact> moreProducts;

      if (state.selectedLineId != null) {
        final result = await _service.getLineProducts(
          state.selectedLineId!,
          limit: _pageSize,
          offset: state.offset,
        );
        moreProducts = result.products;
      } else if (state.selectedBrandId != null && state.selectedCategoryId != null) {
        final result = await _service.getBrandProducts(
          state.selectedCategoryId!,
          state.selectedBrandId!,
          limit: _pageSize,
          offset: state.offset,
        );
        moreProducts = result.products;
      } else if (state.selectedCategoryId != null) {
        final result = await _service.getCategoryProducts(
          state.selectedCategoryId!,
          limit: _pageSize,
          offset: state.offset,
        );
        moreProducts = result.products;
      } else {
        moreProducts = await _service.getAllProducts(
          limit: _pageSize,
          offset: state.offset,
        );
      }

      final allProducts = [...state.products, ...moreProducts];
      emit(state.copyWith(
        products: allProducts,
        offset: allProducts.length,
        hasMore: allProducts.length < state.total,
      ));
    } catch (_) {
      // Silently fail pagination — keep existing products
    }
  }
}

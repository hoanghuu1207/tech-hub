import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../../models/index.dart';
import '../../services/index.dart';

// Events
abstract class ProductEvent extends Equatable {
  const ProductEvent();
  @override
  List<Object?> get props => [];
}

class FetchTrendingProductsRequested extends ProductEvent {
  const FetchTrendingProductsRequested();
}

class FetchProductsByCategoryRequested extends ProductEvent {
  final String categoryName;
  final int page;
  final String? sortBy;

  const FetchProductsByCategoryRequested(
    this.categoryName, {
    this.page = 1,
    this.sortBy,
  });

  @override
  List<Object?> get props => [categoryName, page, sortBy];
}

class SearchProductsRequested extends ProductEvent {
  final String query;
  final int page;

  const SearchProductsRequested(this.query, {this.page = 1});

  @override
  List<Object?> get props => [query, page];
}

class FetchProductDetailRequested extends ProductEvent {
  final String productId;

  const FetchProductDetailRequested(this.productId);

  @override
  List<Object?> get props => [productId];
}

class FetchCategoriesRequested extends ProductEvent {
  const FetchCategoriesRequested();
}

// States
abstract class ProductState extends Equatable {
  const ProductState();
  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {
  const ProductInitial();
}

class ProductLoading extends ProductState {
  const ProductLoading();
}

class ProductsLoadedSuccess extends ProductState {
  final List<Product> products;
  final int page;
  final bool hasMoreData;

  const ProductsLoadedSuccess(
    this.products, {
    this.page = 1,
    this.hasMoreData = false,
  });

  @override
  List<Object?> get props => [products, page, hasMoreData];
}

class ProductDetailLoadedSuccess extends ProductState {
  final Product product;
  final List<Review> reviews;

  const ProductDetailLoadedSuccess(this.product, this.reviews);

  @override
  List<Object?> get props => [product, reviews];
}

class CategoriesLoadedSuccess extends ProductState {
  final List<Category> categories;

  const CategoriesLoadedSuccess(this.categories);

  @override
  List<Object?> get props => [categories];
}

class ProductFailure extends ProductState {
  final String message;

  const ProductFailure(this.message);

  @override
  List<Object?> get props => [message];
}

// BLoC
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  final ProductService _productService = ProductService();

  ProductBloc() : super(const ProductInitial()) {
    on<FetchTrendingProductsRequested>(_onFetchTrendingProductsRequested);
    on<FetchProductsByCategoryRequested>(_onFetchProductsByCategoryRequested);
    on<SearchProductsRequested>(_onSearchProductsRequested);
    on<FetchProductDetailRequested>(_onFetchProductDetailRequested);
    on<FetchCategoriesRequested>(_onFetchCategoriesRequested);
  }

  Future<void> _onFetchTrendingProductsRequested(
    FetchTrendingProductsRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _productService.getTrendingProducts();
      emit(ProductsLoadedSuccess(products));
    } catch (e) {
      emit(ProductFailure(e.toString()));
    }
  }

  Future<void> _onFetchProductsByCategoryRequested(
    FetchProductsByCategoryRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _productService.getProductsByCategory(
        event.categoryName,
        page: event.page,
        sortBy: event.sortBy,
      );
      emit(ProductsLoadedSuccess(products, page: event.page));
    } catch (e) {
      emit(ProductFailure(e.toString()));
    }
  }

  Future<void> _onSearchProductsRequested(
    SearchProductsRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final products = await _productService.searchProducts(
        event.query,
        page: event.page,
      );
      emit(ProductsLoadedSuccess(products, page: event.page));
    } catch (e) {
      emit(ProductFailure(e.toString()));
    }
  }

  Future<void> _onFetchProductDetailRequested(
    FetchProductDetailRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final product = await _productService.getProductById(event.productId);
      final reviews = await _productService.getProductReviews(event.productId);
      emit(ProductDetailLoadedSuccess(product, reviews));
    } catch (e) {
      emit(ProductFailure(e.toString()));
    }
  }

  Future<void> _onFetchCategoriesRequested(
    FetchCategoriesRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(const ProductLoading());
    try {
      final categories = await _productService.getCategories();
      emit(CategoriesLoadedSuccess(categories));
    } catch (e) {
      emit(ProductFailure(e.toString()));
    }
  }
}

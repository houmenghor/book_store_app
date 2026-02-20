import 'package:flutter/foundation.dart';

import '../data/product_models.dart';
import '../data/product_repository.dart';

class ProductProvider extends ChangeNotifier {
  ProductProvider(this._repository);

  final IProductRepository _repository;

  final List<ProductModel> _products = <ProductModel>[];
  ProductModel? _selected;

  bool _isLoading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  String _search = '';

  List<ProductModel> get products => List<ProductModel>.unmodifiable(_products);
  ProductModel? get selected => _selected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadInitial({String search = ''}) async {
    _setLoading(true);
    _error = null;
    _page = 1;
    _hasMore = true;
    _search = search;

    try {
      final response = await _repository.getProducts(search: search, page: _page);
      _products
        ..clear()
        ..addAll(response.products);
      _hasMore = response.pagination?.hasMorePages ?? (response.nextLink != null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMore() async {
    if (_isLoading || !_hasMore) {
      return;
    }

    _setLoading(true);
    _error = null;

    try {
      final nextPage = _page + 1;
      final response = await _repository.getProducts(search: _search, page: nextPage);
      _products.addAll(response.products);
      _page = nextPage;
      _hasMore = response.pagination?.hasMorePages ?? (response.nextLink != null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadDetail(String uuid) async {
    _setLoading(true);
    _error = null;

    try {
      _selected = await _repository.getProduct(uuid);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

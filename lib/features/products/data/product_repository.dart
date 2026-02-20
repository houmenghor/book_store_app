import 'product_api.dart';
import 'product_models.dart';

abstract class IProductRepository {
  Future<ProductListResponse> getProducts({
    String? search,
    String? column,
    String? sort,
    int? status,
    int? perPage,
    int? categoryId,
    int? page,
  });

  Future<ProductModel> getProduct(String uuid);
}

class ProductRepository implements IProductRepository {
  const ProductRepository({required ProductApi api}) : _api = api;

  final ProductApi _api;

  @override
  Future<ProductListResponse> getProducts({
    String? search,
    String? column,
    String? sort,
    int? status,
    int? perPage,
    int? categoryId,
    int? page,
  }) {
    return _api.getProducts(
      search: search,
      column: column,
      sort: sort,
      status: status,
      perPage: perPage,
      categoryId: categoryId,
      page: page,
    );
  }

  @override
  Future<ProductModel> getProduct(String uuid) {
    return _api.getProduct(uuid);
  }
}

import '../../../core/network/api_client.dart';
import '../../../core/network/endpoints.dart';
import 'product_models.dart';

class ProductApi {
  const ProductApi(this._client);

  final ApiClient _client;

  Future<ProductListResponse> getProducts({
    String? search,
    String? column,
    String? sort,
    int? status,
    int? perPage,
    int? categoryId,
    int? page,
  }) async {
    final response = await _client.get(
      Endpoints.products,
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (column != null && column.isNotEmpty) 'column': column,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (status != null) 'status': status,
        if (perPage != null) 'per_page': perPage,
        if (categoryId != null) 'category_id': categoryId,
        if (page != null) 'page': page,
      },
    );

    return ProductListResponse.fromApi(response);
  }

  Future<ProductModel> getProduct(String uuid) async {
    final response = await _client.get(Endpoints.productByUuid(uuid));
    final data = (response['data'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return ProductModel.fromJson(data);
  }

  Future<CategoryListResponse> getCategories({
    String? search,
    String? column,
    String? sort,
    int? status,
    int? perPage,
    int? page,
  }) async {
    final response = await _client.get(
      Endpoints.categories,
      query: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (column != null && column.isNotEmpty) 'column': column,
        if (sort != null && sort.isNotEmpty) 'sort': sort,
        if (status != null) 'status': status,
        if (perPage != null) 'per_page': perPage,
        if (page != null) 'page': page,
      },
    );

    return CategoryListResponse.fromApi(response);
  }
}

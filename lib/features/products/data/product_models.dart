class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.description,
  });

  final int id;
  final String name;
  final String? description;

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: _asInt(json['id']),
      name: _asString(json['name']).isNotEmpty
          ? _asString(json['name'])
          : _asString(json['title']),
      description: _asNullableString(json['description']),
    );
  }
}

class ProductModel {
  const ProductModel({
    required this.id,
    required this.uuid,
    required this.title,
    required this.description,
    required this.price,
    required this.stock,
    required this.status,
    this.image,
    this.category,
  });

  final int id;
  final String uuid;
  final String title;
  final String description;
  final double price;
  final int stock;
  final String status;
  final String? image;
  final ProductCategory? category;

  bool get isActive => status == 'active' || status == '1';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category_id'] ?? json['category'];

    return ProductModel(
      id: _asInt(json['id']),
      uuid: _asString(json['uuid']),
      title: _asString(json['title']),
      description: _asString(json['description']),
      price: _asDouble(json['price']),
      stock: _asInt(json['stock']),
      status: _asString(json['status']).isNotEmpty
          ? _asString(json['status'])
          : 'inactive',
      image: _asNullableString(json['image']),
      category: categoryRaw is Map<String, dynamic>
          ? ProductCategory.fromJson(categoryRaw)
          : null,
    );
  }
}

class ProductPagination {
  const ProductPagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.hasMorePages,
  });

  final int total;
  final int perPage;
  final int currentPage;
  final bool hasMorePages;

  factory ProductPagination.fromJson(Map<String, dynamic> json) {
    return ProductPagination(
      total: _asInt(json['total']),
      perPage: _asInt(json['per_page']),
      currentPage: _asInt(json['current_page'], fallback: 1),
      hasMorePages: _asBool(json['has_more_pages']),
    );
  }
}

class ProductListResponse {
  const ProductListResponse({
    required this.products,
    this.pagination,
    this.nextLink,
  });

  final List<ProductModel> products;
  final ProductPagination? pagination;
  final String? nextLink;

  factory ProductListResponse.fromApi(Map<String, dynamic> json) {
    final rows = _extractRows(json);
    final products = rows
        .whereType<Map<String, dynamic>>()
        .map(ProductModel.fromJson)
        .toList(growable: false);

    final paginateRaw = json['paginate'];
    final linksRaw = json['links'];

    return ProductListResponse(
      products: products,
      pagination: paginateRaw is Map<String, dynamic>
          ? ProductPagination.fromJson(paginateRaw)
          : null,
      nextLink: linksRaw is Map<String, dynamic> ? linksRaw['next'] as String? : null,
    );
  }
}

class CategoryListResponse {
  const CategoryListResponse({
    required this.categories,
    this.pagination,
    this.nextLink,
  });

  final List<ProductCategory> categories;
  final ProductPagination? pagination;
  final String? nextLink;

  factory CategoryListResponse.fromApi(Map<String, dynamic> json) {
    final rows = _extractRows(json);
    final categories = rows
        .whereType<Map<String, dynamic>>()
        .map(ProductCategory.fromJson)
        .toList(growable: false);

    final paginateRaw = json['paginate'];
    final linksRaw = json['links'];

    return CategoryListResponse(
      categories: categories,
      pagination: paginateRaw is Map<String, dynamic>
          ? ProductPagination.fromJson(paginateRaw)
          : null,
      nextLink: linksRaw is Map<String, dynamic> ? linksRaw['next'] as String? : null,
    );
  }
}

List<dynamic> _extractRows(Map<String, dynamic> json) {
  final data = json['data'];

  if (data is List) {
    return data;
  }

  if (data is Map<String, dynamic> && data['data'] is List) {
    return data['data'] as List<dynamic>;
  }

  return <dynamic>[];
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

bool _asBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == '0') {
      return false;
    }
  }
  return fallback;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) {
    return fallback;
  }
  if (value is String) {
    return value;
  }
  return value.toString();
}

String? _asNullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final result = _asString(value).trim();
  return result.isEmpty ? null : result;
}

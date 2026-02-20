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
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      description: json['description'] as String?,
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

  bool get isActive => status == 'active';

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final categoryRaw = json['category_id'];

    return ProductModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: (json['uuid'] as String?) ?? '',
      title: (json['title'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'inactive',
      image: json['image'] as String?,
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
      total: (json['total'] as num?)?.toInt() ?? 0,
      perPage: (json['per_page'] as num?)?.toInt() ?? 0,
      currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
      hasMorePages: (json['has_more_pages'] as bool?) ?? false,
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
    final data = json['data'];

    List<dynamic> rows;
    if (data is List) {
      rows = data;
    } else if (data is Map<String, dynamic> && data['data'] is List) {
      rows = data['data'] as List<dynamic>;
    } else {
      rows = <dynamic>[];
    }

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

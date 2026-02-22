import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/wishlist_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/product_api.dart';
import '../../data/product_models.dart';
import '../../data/product_repository.dart';
import '../../state/product_provider.dart';
import 'product_detail_page.dart';

class AllBooksPage extends StatefulWidget {
  const AllBooksPage({
    super.key,
    this.initialCategory,
  });

  final ProductCategory? initialCategory;

  @override
  State<AllBooksPage> createState() => _AllBooksPageState();
}

class _AllBooksPageState extends State<AllBooksPage> {
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();

  late final TokenStorage _tokenStorage = TokenStorage();
  late final ProductApi _productApi = ProductApi(
    ApiClient(tokenStorage: _tokenStorage),
  );

  bool _isLoading = true;
  bool _isListView = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMorePages = false;
  int _totalBooks = 0;
  String _stockFilter = 'all';
  String _sortFilter = 'default';
  Set<String> _wishlistUuids = <String>{};
  List<ProductModel> _allProducts = const <ProductModel>[];
  List<ProductModel> _visibleProducts = const <ProductModel>[];
  late final WishlistStorage _wishlistStorage = WishlistStorage(
    tokenStorage: _tokenStorage,
  );

  @override
  void initState() {
    super.initState();
    _loadWishlistState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _fetchProductsPage();
      final products = response.products;
      final scoped = products.where((product) {
        if (!product.isActive) {
          return false;
        }
        final category = widget.initialCategory;
        if (category == null) {
          return true;
        }
        if (product.category?.id == category.id) {
          return true;
        }
        final productCategoryName = (product.category?.name ?? '').trim().toLowerCase();
        final selectedName = category.name.trim().toLowerCase();
        return selectedName.isNotEmpty && productCategoryName == selectedName;
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _allProducts = scoped;
        _totalBooks = scoped.length;
        _currentPage = 1;
        _applyFiltersAndSearch();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      final message = e is ApiException ? e.message : e.toString();
      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<List<ProductModel>> _loadAllProductPages() async {
    final all = <ProductModel>[];
    var page = 1;
    var hasMorePages = true;
    var safety = 0;

    while (hasMorePages && safety < 20) {
      ProductListResponse response;
      try {
        response = await _fetchProductsPage();
      } catch (e) {
        // If a later page fails validation (common with strict backends),
        // keep the already loaded pages instead of failing the whole screen.
        if (all.isNotEmpty && page > 1) {
          break;
        }
        rethrow;
      }
      all.addAll(response.products);

      hasMorePages = response.pagination?.hasMorePages ?? false;
      page += 1;
      safety += 1;

      if (response.products.isEmpty) {
        break;
      }

      // If backend omits pagination metadata, stop after first page.
      if (response.pagination == null) {
        break;
      }
    }

    final deduped = <String, ProductModel>{};
    for (final product in all) {
      final key = product.uuid.trim().isNotEmpty ? product.uuid.trim() : 'id_${product.id}';
      deduped[key] = product;
    }

    return deduped.values.toList(growable: false);
  }

  Future<ProductListResponse> _fetchProductsPage() async {
    final categoryId = widget.initialCategory?.id;

    try {
      return await _productApi.getProducts(
        status: 1,
        perPage: 50,
        categoryId: categoryId,
      );
    } catch (_) {
      try {
        return await _productApi.getProducts(
          status: 1,
          perPage: 10,
          categoryId: categoryId,
        );
      } catch (_) {
        if (categoryId != null) {
          try {
            return await _productApi.getProducts(
              status: 1,
              categoryId: categoryId,
            );
          } catch (_) {
            // continue to broader fallbacks
          }
        }

        try {
          return await _productApi.getProducts(
            status: 1,
            perPage: 10,
          );
        } catch (_) {
          return await _productApi.getProducts();
        }
      }
    }
  }

  Future<void> _loadWishlistState() async {
    final items = await _wishlistStorage.readItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _wishlistUuids = items.map((item) => item.uuid).toSet();
    });
  }

  void _onSearchChanged(String value) {
    setState(_applyFiltersAndSearch);
  }

  void _toggleViewMode() {
    setState(() {
      _isListView = !_isListView;
    });
  }

  void _applyFiltersAndSearch() {
    final query = _searchController.text.trim().toLowerCase();

    var items = _allProducts.where((product) {
      if (_stockFilter == 'in_stock' && product.stock <= 0) return false;
      if (_stockFilter == 'sold' && product.stock > 0) return false;

      if (query.isEmpty) return true;

      final title = product.title.toLowerCase();
      final description = product.description.toLowerCase();
      final category = (product.category?.name ?? '').toLowerCase();
      return title.contains(query) || description.contains(query) || category.contains(query);
    }).toList(growable: false);

    if (_sortFilter == 'price_asc') {
      items.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sortFilter == 'price_desc') {
      items.sort((a, b) => b.price.compareTo(a.price));
    }

    _visibleProducts = items;
    _syncLocalPaginationMeta();
  }

  Future<void> _goToPage(int page) async {
    if (page < 1 || page == _currentPage) {
      return;
    }
    if (page > _totalPages) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _currentPage = page;
      _syncLocalPaginationMeta();
    });
  }

  int get _totalPages {
    if (_visibleProducts.isEmpty) {
      return 1;
    }
    return (_visibleProducts.length / _pageSize).ceil();
  }

  void _syncLocalPaginationMeta() {
    final totalPages = _totalPages;
    if (_currentPage < 1) {
      _currentPage = 1;
    } else if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    _hasMorePages = _currentPage < totalPages;
  }

  List<ProductModel> get _pagedVisibleProducts {
    if (_visibleProducts.isEmpty) {
      return const <ProductModel>[];
    }
    final start = (_currentPage - 1) * _pageSize;
    if (start >= _visibleProducts.length) {
      return const <ProductModel>[];
    }
    final end = start + _pageSize > _visibleProducts.length
        ? _visibleProducts.length
        : start + _pageSize;
    return _visibleProducts.sublist(start, end);
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        String tempStock = _stockFilter;
        String tempSort = _sortFilter;

        Widget chip({
          required String label,
          required bool selected,
          required VoidCallback onTap,
        }) {
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withOpacity(0.08) : const Color(0xFFF4F5FA),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? AppColors.primary : const Color(0xFFE4E7F0),
                ),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }

        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Books',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 14),
                  const Text('Stock', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(
                        label: 'All',
                        selected: tempStock == 'all',
                        onTap: () => setLocalState(() => tempStock = 'all'),
                      ),
                      chip(
                        label: 'In Stock',
                        selected: tempStock == 'in_stock',
                        onTap: () => setLocalState(() => tempStock = 'in_stock'),
                      ),
                      chip(
                        label: 'Sold',
                        selected: tempStock == 'sold',
                        onTap: () => setLocalState(() => tempStock = 'sold'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text('Sort', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      chip(
                        label: 'Default',
                        selected: tempSort == 'default',
                        onTap: () => setLocalState(() => tempSort = 'default'),
                      ),
                      chip(
                        label: 'Price Low-High',
                        selected: tempSort == 'price_asc',
                        onTap: () => setLocalState(() => tempSort = 'price_asc'),
                      ),
                      chip(
                        label: 'Price High-Low',
                        selected: tempSort == 'price_desc',
                        onTap: () => setLocalState(() => tempSort = 'price_desc'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context, <String, String>{
                            'stock': 'all',
                            'sort': 'default',
                          }),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context, <String, String>{
                            'stock': tempStock,
                            'sort': tempSort,
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _stockFilter = result['stock'] ?? _stockFilter;
      _sortFilter = result['sort'] ?? _sortFilter;
      _applyFiltersAndSearch();
    });
  }

  String _wishlistKeyForProduct(ProductModel product) {
    final uuid = product.uuid.trim();
    if (uuid.isNotEmpty) {
      return uuid;
    }
    return 'product_${product.id}';
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    final token = await _tokenStorage.readToken();
    final isLoggedIn = token != null && token.trim().isNotEmpty;
    if (!isLoggedIn) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to wishlist.')),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      if (!mounted) {
        return;
      }
      await _loadWishlistState();
      final nextToken = await _tokenStorage.readToken();
      if (nextToken == null || nextToken.trim().isEmpty) {
        return;
      }
    }

    final item = WishlistItem(
      uuid: _wishlistKeyForProduct(product),
      title: product.title,
      description: product.description,
      price: product.price,
      imageUrl: product.image,
      categoryName: product.category?.name,
    );

    try {
      final added = await _wishlistStorage.toggleItem(item);
      if (!mounted) {
        return;
      }

      setState(() {
        if (added) {
          _wishlistUuids.add(item.uuid);
        } else {
          _wishlistUuids.remove(item.uuid);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Added to wishlist' : 'Removed from wishlist',
          ),
          duration: const Duration(milliseconds: 900),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  Future<void> _openProductDetail(ProductModel product) async {
    final uuid = product.uuid.trim();
    if (uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product detail is unavailable for this item.')),
      );
      return;
    }

    final provider = ProductProvider(
      ProductRepository(api: _productApi),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productProvider: provider,
          uuid: uuid,
          initialProduct: product,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 56,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE8E9EF)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
                  ),
                  Expanded(
                    child: Text(
                      (widget.initialCategory?.name ?? 'All Books').trim().isEmpty
                          ? 'All Books'
                          : (widget.initialCategory?.name ?? 'All Books').trim(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMain,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleViewMode,
                    icon: Icon(
                      _isListView ? LucideIcons.layoutGrid : LucideIcons.list,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search books...',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        prefixIcon: const Icon(LucideIcons.search, color: AppColors.textSecondary),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E3EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE0E3EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Page $_currentPage / $_totalPages • ${_visibleProducts.length} found'
                            '${_totalBooks > 0 ? ' / $_totalBooks total' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _openFilterSheet,
                          tooltip: 'Filter',
                          icon: const Icon(
                            LucideIcons.slidersHorizontal,
                            size: 18,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildBody(),
                  ),
                  if (!_isLoading && _error == null) _buildPaginationBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadProducts,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_visibleProducts.isEmpty) {
      return const Center(
        child: Text(
          'No books found.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    if (_isListView) {
      final pageItems = _pagedVisibleProducts;
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: pageItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final product = pageItems[index];
          return _BookListCard(
            product: product,
            index: index,
            isFavorite: _wishlistUuids.contains(_wishlistKeyForProduct(product)),
            onToggleFavorite: () => _toggleWishlist(product),
            onTap: () => _openProductDetail(product),
          );
        },
      );
    }

    final pageItems = _pagedVisibleProducts;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: pageItems.length,
      itemBuilder: (_, index) {
        final product = pageItems[index];
        return _BookGridCard(
          product: product,
          index: index,
          isFavorite: _wishlistUuids.contains(_wishlistKeyForProduct(product)),
          onToggleFavorite: () => _toggleWishlist(product),
          onTap: () => _openProductDetail(product),
        );
      },
    );
  }

  Widget _buildPaginationBar() {
    if (_visibleProducts.length <= _pageSize) {
      return const SizedBox.shrink();
    }
    final canPrev = _currentPage > 1;
    final canNext = _hasMorePages;
    final totalPages = _totalPages;
    final pageNumbers = _buildPageNumbers(totalPages);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _PaginationIconButton(
            icon: LucideIcons.chevronLeft,
            enabled: canPrev,
            onTap: canPrev ? () => _goToPage(_currentPage - 1) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: pageNumbers.map((page) {
                  final isActive = page == _currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: isActive ? null : () => _goToPage(page),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isActive ? AppColors.primary : Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : const Color(0xFFE0E3EC),
                          ),
                        ),
                        child: Text(
                          '$page',
                          style: TextStyle(
                            color: isActive ? Colors.white : AppColors.textMain,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _PaginationIconButton(
            icon: LucideIcons.chevronRight,
            enabled: canNext,
            onTap: canNext ? () => _goToPage(_currentPage + 1) : null,
          ),
        ],
      ),
    );
  }

  List<int> _buildPageNumbers(int totalPages) {
    if (totalPages <= 3) {
      return List<int>.generate(totalPages, (index) => index + 1);
    }

    if (_currentPage <= 2) {
      return const <int>[1, 2, 3];
    }

    if (_currentPage >= totalPages - 1) {
      return <int>[totalPages - 2, totalPages - 1, totalPages];
    }

    return <int>[_currentPage - 1, _currentPage, _currentPage + 1];
  }
}

class _PaginationIconButton extends StatelessWidget {
  const _PaginationIconButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E3EC)),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: enabled ? AppColors.textMain : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _BookGridCard extends StatelessWidget {
  const _BookGridCard({
    required this.product,
    required this.index,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final ProductModel product;
  final int index;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = 4.0 + ((product.id % 10) / 20);
    final subtitle = (product.category?.name ?? '').trim().isEmpty
        ? 'Unknown Author'
        : product.category!.name.trim();
    final stockText = product.stock <= 0 ? 'Sold' : 'Stock: ${product.stock}';
    final stockColor = product.stock <= 0 ? Colors.redAccent : const Color(0xFF138A36);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Stack(
              children: [
                Positioned.fill(
                  child: _BookImage(imageUrl: product.image),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: _FavoriteButton(
                    isFavorite: isFavorite,
                    onTap: onToggleFavorite,
                    size: 24,
                    iconSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title.trim().isEmpty ? 'Untitled Book' : product.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stockText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(LucideIcons.star, size: 12, color: Color(0xFFFFB800)),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _BookListCard extends StatelessWidget {
  const _BookListCard({
    required this.product,
    required this.index,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final ProductModel product;
  final int index;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rating = 4.0 + ((product.id % 10) / 20);
    final subtitle = (product.category?.name ?? '').trim().isEmpty
        ? 'Unknown Author'
        : product.category!.name.trim();
    final stockText = product.stock <= 0 ? 'Sold' : 'Stock: ${product.stock}';
    final stockColor = product.stock <= 0 ? Colors.redAccent : const Color(0xFF138A36);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      height: 122,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 94,
            height: double.infinity,
            child: Stack(
              children: [
                Positioned.fill(child: _BookImage(imageUrl: product.image)),
                Positioned(
                  left: 7,
                  top: 7,
                  child: _FavoriteButton(
                    isFavorite: isFavorite,
                    onTap: onToggleFavorite,
                    size: 22,
                    iconSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title.trim().isEmpty ? 'Untitled Book' : product.title.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                      fontSize: 14,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stockText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(LucideIcons.star, size: 13, color: Color(0xFFFFB800)),
                      const SizedBox(width: 3),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _BookImage extends StatelessWidget {
  const _BookImage({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    if (url.isEmpty) {
      return _placeholder();
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _placeholder(),
      loadingBuilder: (_, child, progress) {
        if (progress == null) {
          return child;
        }
        return Container(
          color: const Color(0xFFF2F3F8),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF2F3F8),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.bookOpen,
        color: AppColors.textSecondary,
        size: 32,
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({
    required this.isFavorite,
    required this.onTap,
    required this.size,
    required this.iconSize,
  });

  final bool isFavorite;
  final VoidCallback onTap;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: isFavorite ? const Color(0xFFFFEEF0) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: isFavorite ? const Color(0xFFFFC5CC) : const Color(0xFFE1E4ED),
            ),
          ),
          child: Icon(
            LucideIcons.heart,
            size: iconSize,
            color: isFavorite ? const Color(0xFFFF3B30) : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}


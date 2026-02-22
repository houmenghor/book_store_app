import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/cart_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../../core/storage/wishlist_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../orders/presentation/pages/orders_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../data/product_api.dart';
import '../../data/product_models.dart';
import '../../data/product_repository.dart';
import '../../state/product_provider.dart';
import 'all_books_page.dart';
import 'categories_page.dart';
import 'product_detail_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // Backend status mapping: 1 = active, 2 = inactive.
  static const int _activeStatus = 1;

  final TokenStorage _tokenStorage = TokenStorage();
  late final CartStorage _cartStorage = CartStorage(
    tokenStorage: _tokenStorage,
  );
  late final WishlistStorage _wishlistStorage = WishlistStorage(
    tokenStorage: _tokenStorage,
  );
  final TextEditingController _searchController = TextEditingController();

  late final IProductRepository _productRepository = ProductRepository(
    api: ProductApi(ApiClient()),
  );

  int _selectedIndex = 0;
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';
  String _userProfileImage = '';

  bool _isCatalogLoading = false;
  String? _catalogError;
  bool _isSearching = false;
  int _latestSearchToken = 0;
  Set<String> _wishlistUuids = <String>{};
  int _cartCount = 0;

  List<ProductModel> _allProducts = <ProductModel>[];
  List<ProductModel> _filteredProducts = <ProductModel>[];
  List<ProductModel> _bestSellerProducts = <ProductModel>[];
  List<ProductModel> _popularProducts = <ProductModel>[];

  List<ProductCategory> _allCategories = <ProductCategory>[];
  List<ProductCategory> _filteredCategories = <ProductCategory>[];

  @override
  void initState() {
    super.initState();
    _loadAuthState();
    _loadWishlistState();
    _loadCartCount();
    _loadCatalogData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAuthState() async {
    final token = await _tokenStorage.readToken();
    final userName = await _tokenStorage.readUserName();
    final userEmail = await _tokenStorage.readUserEmail();
    final userPhone = await _tokenStorage.readUserPhone();
    final userProfileImage = await _tokenStorage.readUserProfileImage();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = token != null && token.trim().isNotEmpty;
      _userName = (userName ?? '').trim();
      _userEmail = (userEmail ?? '').trim();
      _userPhone = (userPhone ?? '').trim();
      _userProfileImage = (userProfileImage ?? '').trim();
    });

    await _loadWishlistState();
    await _loadCartCount();
  }

  Future<void> _goToLogin() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    if (!mounted) {
      return;
    }

    await _loadAuthState();
  }

  Future<void> _logout() async {
    await _tokenStorage.clearToken();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = false;
      _userName = '';
      _userEmail = '';
      _userPhone = '';
      _userProfileImage = '';
    });
    await _loadWishlistState();
    await _loadCartCount();
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

  Future<void> _loadCartCount() async {
    final count = await _cartStorage.totalCount();
    if (!mounted) {
      return;
    }
    setState(() {
      _cartCount = count;
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
    if (!_isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login to add items to wishlist.')),
      );
      await _goToLogin();
      if (!_isLoggedIn) {
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
        content: Text(added ? 'Added to wishlist' : 'Removed from wishlist'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _openProductDetail(ProductModel product) async {
    final uuid = product.uuid.trim();
    if (uuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product detail is unavailable for this item.')),
      );
      return;
    }

    final provider = ProductProvider(_productRepository);
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
    await _loadCartCount();
  }

  Future<void> _openCartPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CartPage(),
      ),
    );
    await _loadCartCount();
  }

  Future<void> _openOrdersPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OrdersPage(),
      ),
    );
  }

  Future<void> _openCategoriesPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoriesPage(
          categories: _allCategories,
          products: _allProducts,
        ),
      ),
    );
  }

  Future<void> _openAllBooksPage({ProductCategory? initialCategory}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllBooksPage(initialCategory: initialCategory),
      ),
    );
    await _loadCartCount();
    await _loadWishlistState();
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'profile':
        _openProfilePage();
        break;
      case 'my_books':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('My books page is coming soon.')),
        );
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  Future<void> _openProfilePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          userName: _userName,
          userEmail: _userEmail,
          userPhone: _userPhone,
          userProfileImage: _userProfileImage,
          isLoggedIn: _isLoggedIn,
          onLogout: _logout,
          onLogin: _goToLogin,
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    await _loadAuthState();
  }

  Future<void> _loadCatalogData() async {
    setState(() {
      _isCatalogLoading = true;
      _catalogError = null;
    });

    try {
      ProductListResponse productResponse;
      try {
        productResponse = await _productRepository.getProducts(
          status: _activeStatus,
          perPage: 50,
          page: 1,
        );
      } catch (_) {
        productResponse = await _productRepository.getProducts();
      }

      List<ProductCategory> categories;
      final activeProducts = productResponse.products.where((p) => p.isActive).toList(growable: false);
      try {
        CategoryListResponse categoryResponse;
        try {
          categoryResponse = await _productRepository.getCategories(
            status: _activeStatus,
            perPage: 50,
            page: 1,
          );
        } catch (_) {
          categoryResponse = await _productRepository.getCategories();
        }
        categories = categoryResponse.categories.where((c) => c.isActive).toList(growable: false);
      } catch (_) {
        categories = _deriveCategoriesFromProducts(activeProducts);
      }

      List<ProductModel> bestSellers = <ProductModel>[];
      try {
        final bestSellerResponse = await _productRepository.getBestSellerProducts(
          timeRange: 'last_30_days',
          limit: 50,
        );
        bestSellers = bestSellerResponse.products.where((p) => p.isActive).toList(growable: false);
      } catch (_) {
        bestSellers = activeProducts.take(10).toList(growable: false);
      }

        List<ProductModel> popularProducts = <ProductModel>[];
        try {
          final popularResponse = await _productRepository.getPopularProducts(
            timeRange: 'last_30_days',
            limit: 50,
          );
          popularProducts = popularResponse.products.where((p) => p.isActive).toList(growable: false);
          if (popularProducts.isEmpty) {
            // Popular endpoint can legitimately return empty when there is not
            // enough paid-order history yet. Keep the UI populated.
            popularProducts = bestSellers.isNotEmpty
                ? bestSellers.take(10).toList(growable: false)
                : activeProducts.take(10).toList(growable: false);
          }
        } catch (_) {
          popularProducts = activeProducts.take(10).toList(growable: false);
        }

      if (!mounted) {
        return;
      }

      setState(() {
        _allProducts = activeProducts;
        _allCategories = categories;
        _bestSellerProducts = bestSellers;
        _popularProducts = popularProducts;
        _updateSearchResults(_searchController.text);
        _isCatalogLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _catalogError = e.toString();
        _allProducts = <ProductModel>[];
        _filteredProducts = <ProductModel>[];
        _bestSellerProducts = <ProductModel>[];
        _popularProducts = <ProductModel>[];
        _allCategories = <ProductCategory>[];
        _filteredCategories = <ProductCategory>[];
        _isCatalogLoading = false;
      });
    }
  }

  void _onSearchChanged(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
        _updateSearchResults('');
      });
      return;
    }

    _searchCatalogByFields(query);
  }

  void _updateSearchResults(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredProducts = List<ProductModel>.from(_allProducts);
      _filteredCategories = List<ProductCategory>.from(_allCategories);
      return;
    }

    _filteredProducts = _allProducts.where((product) {
      final title = product.title.toLowerCase();
      final description = product.description.toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList(growable: false);

    _filteredCategories = _allCategories.where((category) {
      final name = category.name.toLowerCase();
      final description = (category.description ?? '').toLowerCase();
      return name.contains(query) || description.contains(query);
    }).toList(growable: false);
  }

  List<ProductCategory> _deriveCategoriesFromProducts(List<ProductModel> products) {
    final seen = <String>{};
    final categories = <ProductCategory>[];

    for (final product in products) {
      final category = product.category;
      if (category == null) {
        continue;
      }

      final key = '${category.id}:${category.name.toLowerCase()}';
      if (seen.add(key)) {
        categories.add(category);
      }
    }

    categories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return categories;
  }

  Future<void> _searchCatalogByFields(String query) async {
    final searchToken = ++_latestSearchToken;
    setState(() {
      _isSearching = true;
    });

    try {
      final results = await Future.wait<dynamic>([
        _productRepository.getProducts(
          search: query,
          column: 'title',
          status: _activeStatus,
          perPage: 50,
          page: 1,
        ),
        _productRepository.getCategories(
          search: query,
          status: _activeStatus,
          perPage: 50,
          page: 1,
        ),
      ]);

      if (!mounted || searchToken != _latestSearchToken) {
        return;
      }

      final productsByTitle = results[0] as ProductListResponse;
      final categoriesBySearch = results[1] as CategoryListResponse;

      setState(() {
        _filteredProducts = _mergeProducts(
          productsByTitle.products,
          _allProducts.where((product) {
            final title = product.title.toLowerCase();
            final description = product.description.toLowerCase();
            final q = query.toLowerCase();
            return title.contains(q) || description.contains(q);
          }).toList(growable: false),
        ).where((p) => p.isActive).toList(growable: false);
        _filteredCategories = _mergeCategories(
          categoriesBySearch.categories,
          _allCategories.where((category) {
            final name = category.name.toLowerCase();
            final description = (category.description ?? '').toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || description.contains(q);
          }).toList(growable: false),
        ).where((c) => c.isActive).toList(growable: false);
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted || searchToken != _latestSearchToken) {
        return;
      }

      setState(() {
        _updateSearchResults(query);
        _isSearching = false;
      });
    }
  }

  List<ProductModel> _mergeProducts(
    List<ProductModel> first,
    List<ProductModel> second,
  ) {
    final byUuid = <String, ProductModel>{};
    for (final product in [...first, ...second]) {
      byUuid[product.uuid] = product;
    }
    return byUuid.values.toList(growable: false);
  }

  List<ProductCategory> _mergeCategories(
    List<ProductCategory> first,
    List<ProductCategory> second,
  ) {
    final byKey = <String, ProductCategory>{};
    for (final category in [...first, ...second]) {
      final key = '${category.id}:${category.name.toLowerCase()}';
      byKey[key] = category;
    }
    return byKey.values.toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(),
              const SizedBox(height: 16),
              _buildSearchField(),
              if (_isSearching) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(minHeight: 2),
              ],
              const SizedBox(height: 16),
              _buildOfferBanner(),
              const SizedBox(height: 20),
              _buildSectionHeader('Categories', onSeeAll: _openCategoriesPage),
              const SizedBox(height: 12),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildSectionHeader('Bestsellers', onSeeAll: _openAllBooksPage),
              const SizedBox(height: 12),
              _buildBestSellerSection(),
              if (_searchController.text.trim().isEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionHeader('Popular', onSeeAll: _openAllBooksPage),
                const SizedBox(height: 12),
                _buildPopularSection(),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        currentIndex: _selectedIndex,
        backgroundColor: Colors.white,
        onTap: (index) async {
          if (index == 1) {
            setState(() => _selectedIndex = index);
            await _openCategoriesPage();
            if (!mounted) {
              return;
            }
            setState(() => _selectedIndex = 0);
            return;
          }

          if (index == 2) {
            setState(() => _selectedIndex = index);
            await _openOrdersPage();
            if (!mounted) {
              return;
            }
            setState(() => _selectedIndex = 0);
            return;
          }

          if (index == 3) {
            if (!_isLoggedIn) {
              await _goToLogin();
              if (!mounted) {
                return;
              }
              setState(() => _selectedIndex = 0);
              if (!_isLoggedIn) {
                return;
              }
            } else {
              setState(() => _selectedIndex = index);
            }

            await _openProfilePage();
            if (!mounted) {
              return;
            }
            setState(() => _selectedIndex = 0);
            return;
          }
          setState(() => _selectedIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view_rounded),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping_outlined),
            activeIcon: Icon(Icons.local_shipping),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BookStore',
                style: TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Welcome back',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _openCartPage,
          color: AppColors.textMain,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (_cartCount > 0)
                Positioned(
                  right: -6,
                  top: -4,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 1.4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _cartCount > 99 ? '99+' : '$_cartCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildProfileAction(),
      ],
    );
  }

  Widget _buildProfileAction() {
    if (!_isLoggedIn) {
      return IconButton(
        onPressed: _goToLogin,
        icon: const Icon(Icons.person_outline),
        color: AppColors.textMain,
      );
    }

    return PopupMenuButton<String>(
      onSelected: _onMenuSelected,
      offset: const Offset(0, 46),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'name',
          enabled: false,
          child: Text(_userName.isEmpty ? 'User' : _userName),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline, size: 18),
              SizedBox(width: 8),
              Text('Profile'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'my_books',
          child: Row(
            children: [
              Icon(Icons.menu_book_outlined, size: 18),
              SizedBox(width: 8),
              Text('My books'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.power_settings_new, size: 18, color: Colors.red),
              SizedBox(width: 8),
              Text('Log out', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      child: CircleAvatar(
        radius: 16,
        backgroundColor: AppColors.primary.withOpacity(0.08),
        child: _userProfileImage.trim().isNotEmpty
            ? ClipOval(
                child: Image.network(
                  _userProfileImage.trim(),
                  width: 32,
                  height: 32,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(
                    (_userName.isEmpty ? 'U' : _userName[0]).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : Text(
                (_userName.isEmpty ? 'U' : _userName[0]).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: _onSearchChanged,
      decoration: InputDecoration(
        hintText: 'Search books, authors...',
        hintStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildOfferBanner() {
    return Container(
      height: 168,
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.secondary],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -34,
            right: -28,
            child: Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -46,
            right: 12,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.trending_up, color: Colors.white, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Special Offer',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Get 20% Off',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'On your first purchase',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 0,
                  minimumSize: const Size(72, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
                child: const Text('Shop Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onSeeAll}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textMain,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(8),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              'See All',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    if (_catalogError != null && _allCategories.isEmpty) {
      return _buildErrorCard();
    }

    if (_isCatalogLoading && _allCategories.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_filteredCategories.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No categories found for this search.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final itemCount = math.min(8, _filteredCategories.length);

    return GridView.builder(
      itemCount: itemCount,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final item = _filteredCategories[index];
        return _buildCategoryCard(item);
      },
    );
  }

  Widget _buildBestSellerSection() {
    if (_catalogError != null && _allProducts.isEmpty) {
      return _buildErrorCard();
    }

    if (_isCatalogLoading && _allProducts.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final isSearchMode = _searchController.text.trim().isNotEmpty;
    final source = isSearchMode
        ? _filteredProducts
        : (_bestSellerProducts.isNotEmpty ? _bestSellerProducts : _filteredProducts);

    if (source.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No books found for this search.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final itemCount = math.min(10, source.length);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ApiBestSellerCard(
              product: source[index],
              isFavorite: _wishlistUuids.contains(
                _wishlistKeyForProduct(source[index]),
              ),
              onToggleFavorite: () => _toggleWishlist(source[index]),
              onTap: () => _openProductDetail(source[index]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    if (_catalogError != null && _allProducts.isEmpty) {
      return _buildErrorCard();
    }

    if (_isCatalogLoading && _popularProducts.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_popularProducts.isEmpty) {
      return const SizedBox(
        height: 90,
        child: Center(
          child: Text(
            'No popular books yet.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final itemCount = math.min(4, _popularProducts.length);

    return Column(
      children: List<Widget>.generate(
        itemCount,
        (index) {
          final product = _popularProducts[index];
          return Padding(
            padding: EdgeInsets.only(bottom: index == itemCount - 1 ? 0 : 12),
            child: _PopularBookCard(
              product: product,
              isFavorite: _wishlistUuids.contains(_wishlistKeyForProduct(product)),
              onToggleFavorite: () => _toggleWishlist(product),
              onTap: () => _openProductDetail(product),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EAF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _catalogError ?? 'Unable to load catalog data.',
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _loadCatalogData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(ProductCategory category) {
    return InkWell(
      onTap: () => _openAllBooksPage(initialCategory: category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE9EAF1)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_resolveCategoryIcon(category.name), color: AppColors.textMain),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _resolveCategoryIcon(String name) {
    final normalized = name.toLowerCase();

    if (normalized.contains('fiction')) {
      return Icons.auto_stories_outlined;
    }
    if (normalized.contains('mystery')) {
      return Icons.travel_explore_outlined;
    }
    if (normalized.contains('romance')) {
      return Icons.favorite_border;
    }
    if (normalized.contains('sci')) {
      return Icons.rocket_launch_outlined;
    }
    if (normalized.contains('biography')) {
      return Icons.person_outline;
    }
    if (normalized.contains('self')) {
      return Icons.lightbulb_outline;
    }
    if (normalized.contains('cook')) {
      return Icons.ramen_dining_outlined;
    }

    return Icons.menu_book_outlined;
  }
}

class _ApiBestSellerCard extends StatelessWidget {
  const _ApiBestSellerCard({
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (product.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if ((product.category?.name ?? '').isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    product.category!.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              const Spacer(),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onToggleFavorite,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isFavorite ? const Color(0xFFFFEEF0) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isFavorite
                            ? const Color(0xFFFFC5CC)
                            : const Color(0xFFE8E9EF),
                      ),
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: isFavorite ? Colors.redAccent : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: const Color(0xFFF3F4F8),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _BookPlaceholder(product: product),
                  )
                : _BookPlaceholder(product: product),
          ),
          const SizedBox(height: 8),
          Text(
            product.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.textMain,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            product.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PopularBookCard extends StatelessWidget {
  const _PopularBookCard({
    required this.product,
    required this.isFavorite,
    required this.onToggleFavorite,
    required this.onTap,
  });

  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (product.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;
    final stock = product.stock;
    final stockText = stock <= 0 ? 'Sold' : 'Stock: $stock';
    final stockColor = stock <= 0 ? Colors.redAccent : const Color(0xFF138A36);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7E9F1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 86,
                color: const Color(0xFFF3F4F8),
                child: hasImage
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _BookPlaceholder(product: product),
                      )
                    : _BookPlaceholder(product: product),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (product.category?.name ?? '').trim().isEmpty
                        ? 'Book'
                        : product.category!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stockText,
                    style: TextStyle(
                      color: stockColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleFavorite,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isFavorite ? const Color(0xFFFFEEF0) : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isFavorite
                                    ? const Color(0xFFFFC5CC)
                                    : const Color(0xFFE8E9EF),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.favorite_border,
                              size: 16,
                              color: isFavorite ? Colors.redAccent : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookPlaceholder extends StatelessWidget {
  const _BookPlaceholder({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEE7FF), Color(0xFFF7F4FF)],
        ),
      ),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Text(
          product.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}

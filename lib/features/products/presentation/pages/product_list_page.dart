import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import '../../data/product_api.dart';
import '../../data/product_models.dart';
import '../../data/product_repository.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  // Backend status mapping: 1 = active, 2 = inactive.
  static const int _activeStatus = 1;

  final TokenStorage _tokenStorage = TokenStorage();
  final TextEditingController _searchController = TextEditingController();

  late final IProductRepository _productRepository = ProductRepository(
    api: ProductApi(ApiClient()),
  );

  int _selectedIndex = 0;
  bool _isLoggedIn = false;
  String _userName = '';
  String _userEmail = '';
  String _userPhone = '';

  bool _isCatalogLoading = false;
  String? _catalogError;
  bool _isSearching = false;
  int _latestSearchToken = 0;

  List<ProductModel> _allProducts = <ProductModel>[];
  List<ProductModel> _filteredProducts = <ProductModel>[];

  List<ProductCategory> _allCategories = <ProductCategory>[];
  List<ProductCategory> _filteredCategories = <ProductCategory>[];

  @override
  void initState() {
    super.initState();
    _loadAuthState();
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

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = token != null && token.trim().isNotEmpty;
      _userName = (userName ?? '').trim();
      _userEmail = (userEmail ?? '').trim();
      _userPhone = (userPhone ?? '').trim();
    });
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
    });
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
          perPage: 100,
          page: 1,
        );
      } catch (_) {
        productResponse = await _productRepository.getProducts();
      }

      List<ProductCategory> categories;
      try {
        CategoryListResponse categoryResponse;
        try {
          categoryResponse = await _productRepository.getCategories(
            perPage: 100,
            page: 1,
          );
        } catch (_) {
          categoryResponse = await _productRepository.getCategories();
        }
        categories = categoryResponse.categories;
      } catch (_) {
        categories = _deriveCategoriesFromProducts(productResponse.products);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _allProducts = productResponse.products;
        _allCategories = categories;
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
          perPage: 100,
          page: 1,
        ),
        _productRepository.getCategories(
          search: query,
          perPage: 100,
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
        );
        _filteredCategories = _mergeCategories(
          categoriesBySearch.categories,
          _allCategories.where((category) {
            final name = category.name.toLowerCase();
            final description = (category.description ?? '').toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || description.contains(q);
          }).toList(growable: false),
        );
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
              _buildSectionHeader('Categories'),
              const SizedBox(height: 12),
              _buildCategorySection(),
              const SizedBox(height: 20),
              _buildSectionHeader('Bestsellers'),
              const SizedBox(height: 12),
              _buildBestSellerSection(),
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
          onPressed: () {},
          icon: const Icon(Icons.shopping_cart_outlined),
          color: AppColors.textMain,
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
        child: Text(
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

  Widget _buildSectionHeader(String title) {
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
        const Text(
          'See All',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
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

    if (_filteredProducts.isEmpty) {
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

    final itemCount = math.min(10, _filteredProducts.length);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List<Widget>.generate(
          itemCount,
          (index) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _ApiBestSellerCard(product: _filteredProducts[index]),
          ),
        ),
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
    return Container(
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
  const _ApiBestSellerCard({required this.product});

  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (product.image ?? '').trim();
    final hasImage = imageUrl.isNotEmpty;

    return Container(
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8E9EF)),
                ),
                child: const Icon(Icons.favorite_border, size: 16, color: Colors.black54),
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

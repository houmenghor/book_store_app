import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../data/product_models.dart';
import '../../data/product_api.dart';
import 'all_books_page.dart';

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({
    super.key,
    required this.categories,
    required this.products,
  });

  final List<ProductCategory> categories;
  final List<ProductModel> products;

  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final TextEditingController _searchController = TextEditingController();
  late final ProductApi _productApi = ProductApi(ApiClient());
  bool _isListView = true;
  late List<ProductCategory> _visibleCategories;
  Map<int, int> _categoryCounts = const <int, int>{};

  @override
  void initState() {
    super.initState();
    _visibleCategories = _activeCategories(widget.categories);
    _loadCategoryCounts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProductCategory> _activeCategories(List<ProductCategory> items) {
    return items.where((c) => c.isActive).toList(growable: false);
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    final source = _activeCategories(widget.categories);
    setState(() {
      if (query.isEmpty) {
        _visibleCategories = source;
        return;
      }

      _visibleCategories = source.where((category) {
        final name = category.name.toLowerCase();
        final desc = (category.description ?? '').toLowerCase();
        return name.contains(query) || desc.contains(query);
      }).toList(growable: false);
    });
  }

  int _countForCategory(ProductCategory category) {
    final apiCount = _categoryCounts[category.id];
    if (apiCount != null) {
      return apiCount;
    }

    final byId = widget.products.where((p) => p.isActive && p.category?.id == category.id).length;
    if (byId > 0) {
      return byId;
    }

    final selectedName = category.name.trim().toLowerCase();
    if (selectedName.isEmpty) {
      return 0;
    }

    return widget.products.where((p) {
      if (!p.isActive) {
        return false;
      }
      return (p.category?.name ?? '').trim().toLowerCase() == selectedName;
    }).length;
  }

  Future<void> _loadCategoryCounts() async {
    final activeCategories = _activeCategories(widget.categories);
    final next = <int, int>{};

    for (final category in activeCategories) {
      if (category.id <= 0) {
        continue;
      }
      try {
        final response = await _productApi.getProducts(
          status: 1,
          perPage: 1,
          categoryId: category.id,
        );
        next[category.id] = response.pagination?.total ?? response.products.length;
      } catch (_) {
        // Keep local fallback count if this request fails.
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _categoryCounts = next;
    });
  }

  IconData _iconForCategory(String name) {
    final n = name.toLowerCase();
    if (n.contains('fiction')) return LucideIcons.bookOpen;
    if (n.contains('non')) return LucideIcons.book;
    if (n.contains('mystery')) return LucideIcons.search;
    if (n.contains('romance')) return LucideIcons.heart;
    if (n.contains('sci')) return LucideIcons.bookOpen;
    if (n.contains('bio')) return LucideIcons.user;
    if (n.contains('self')) return LucideIcons.lightbulb;
    if (n.contains('cook')) return LucideIcons.book;
    return LucideIcons.bookOpen;
  }

  Future<void> _openCategory(ProductCategory category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AllBooksPage(initialCategory: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalActive = _activeCategories(widget.categories).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6),
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
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                          ),
                          Text(
                            '$totalActive categories',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3F8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _ViewToggleIcon(
                          active: !_isListView,
                          icon: LucideIcons.layoutGrid,
                          onTap: () => setState(() => _isListView = false),
                        ),
                        const SizedBox(width: 4),
                        _ViewToggleIcon(
                          active: _isListView,
                          icon: LucideIcons.list,
                          onTap: () => setState(() => _isListView = true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search categories...',
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
            Expanded(
              child: _visibleCategories.isEmpty
                  ? const Center(
                      child: Text(
                        'No categories found.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : (_isListView ? _buildList() : _buildGrid()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemCount: _visibleCategories.length,
      itemBuilder: (_, index) {
        final category = _visibleCategories[index];
        final count = _countForCategory(category);
        return _CategoryGridCard(
          icon: _iconForCategory(category.name),
          title: category.name.trim().isEmpty ? 'Category' : category.name.trim(),
          subtitle: '$count ${count == 1 ? 'book' : 'books'}',
          onTap: () => _openCategory(category),
        );
      },
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _visibleCategories.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, index) {
        final category = _visibleCategories[index];
        final count = _countForCategory(category);
        return _CategoryListTile(
          icon: _iconForCategory(category.name),
          title: category.name.trim().isEmpty ? 'Category' : category.name.trim(),
          subtitle: '$count ${count == 1 ? 'book' : 'books'} available',
          onTap: () => _openCategory(category),
        );
      },
    );
  }
}

class _ViewToggleIcon extends StatelessWidget {
  const _ViewToggleIcon({
    required this.active,
    required this.icon,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: active ? Border.all(color: const Color(0xFFE3E6F0)) : null,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 15,
          color: active ? AppColors.primary : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CategoryGridCard extends StatelessWidget {
  const _CategoryGridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE6E9F2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 22, color: AppColors.primary),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryListTile extends StatelessWidget {
  const _CategoryListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE6E9F2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

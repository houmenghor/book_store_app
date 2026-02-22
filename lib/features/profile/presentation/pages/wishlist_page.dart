import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/wishlist_storage.dart';
import '../../../products/presentation/pages/all_books_page.dart';
import '../../../products/presentation/pages/product_detail_page.dart';
import '../../../products/data/product_api.dart';
import '../../../products/data/product_repository.dart';
import '../../../products/state/product_provider.dart';

class WishlistPage extends StatefulWidget {
  const WishlistPage({super.key});

  @override
  State<WishlistPage> createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  late final WishlistStorage _wishlistStorage = WishlistStorage();
  final TokenStorage _tokenStorage = TokenStorage();

  bool _isLoading = true;
  List<WishlistItem> _items = const <WishlistItem>[];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  Future<void> _loadWishlist() async {
    final items = await _wishlistStorage.readItems();
    if (!mounted) {
      return;
    }
    setState(() {
      _items = items;
      _isLoading = false;
    });
  }

  Future<void> _openBrowseBooks() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AllBooksPage(),
      ),
    );
    await _loadWishlist();
  }

  Future<void> _removeItem(WishlistItem item) async {
    await _wishlistStorage.removeItem(item.uuid);
    if (!mounted) {
      return;
    }
    setState(() {
      _items = _items.where((e) => e.uuid != item.uuid).toList(growable: false);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Removed from wishlist'),
        duration: Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _openDetail(WishlistItem item) async {
    final uuid = item.uuid.trim();
    if (uuid.isEmpty || uuid.startsWith('product_')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product detail is unavailable for this item.')),
      );
      return;
    }

    final api = ProductApi(ApiClient(tokenStorage: _tokenStorage));
    final provider = ProductProvider(
      ProductRepository(api: api),
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(
          productProvider: provider,
          uuid: uuid,
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
                  const Text(
                    'My Wishlist',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _buildEmptyState()
                      : _buildWishlistList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.heart,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your wishlist is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Save your favorite books here!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _openBrowseBooks,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Browse Books'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWishlistList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Text(
                '${_items.length} saved',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openBrowseBooks,
                child: const Text('Browse Books'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, index) {
              final item = _items[index];
              return _WishlistItemCard(
                item: item,
                onRemove: () => _removeItem(item),
                onTap: () => _openDetail(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _WishlistItemCard extends StatelessWidget {
  const _WishlistItemCard({
    required this.item,
    required this.onRemove,
    required this.onTap,
  });

  final WishlistItem item;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled Book' : item.title.trim();
    final subtitle = (item.categoryName ?? '').trim().isNotEmpty
        ? item.categoryName!.trim()
        : 'Book';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 92,
            height: 118,
            child: _WishlistImage(imageUrl: item.imageUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain,
                      fontSize: 14,
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
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      fontSize: 14,
                    ),
                  ),
                  if (item.description.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.description.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              onPressed: onRemove,
              icon: const Icon(
                LucideIcons.x,
                size: 18,
                color: AppColors.textSecondary,
              ),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFFF2F3F8),
                foregroundColor: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _WishlistImage extends StatelessWidget {
  const _WishlistImage({required this.imageUrl});

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
        size: 28,
        color: AppColors.textSecondary,
      ),
    );
  }
}

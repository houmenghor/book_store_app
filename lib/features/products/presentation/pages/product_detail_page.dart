import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/storage/cart_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/storage/wishlist_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../../cart/presentation/pages/cart_page.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../data/product_models.dart';
import '../../state/product_provider.dart';

class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productProvider,
    required this.uuid,
    this.initialProduct,
  });

  final ProductProvider productProvider;
  final String uuid;
  final ProductModel? initialProduct;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  late final TokenStorage _tokenStorage = TokenStorage();
  late final CartStorage _cartStorage = CartStorage();
  late final WishlistStorage _wishlistStorage = WishlistStorage();
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _loadWishlistState();
    widget.productProvider.loadDetail(widget.uuid);
  }

  Future<void> _loadWishlistState() async {
    final key = _wishlistKey(widget.initialProduct, widget.uuid);
    final isFavorite = await _wishlistStorage.contains(key);
    if (!mounted) {
      return;
    }
    setState(() {
      _isFavorite = isFavorite;
    });
  }

  String _wishlistKey(ProductModel? product, String uuid) {
    final normalizedUuid = uuid.trim();
    if (normalizedUuid.isNotEmpty) {
      return normalizedUuid;
    }
    return 'product_${product?.id ?? 0}';
  }

  Future<bool> _ensureAuthenticated(String message) async {
    final token = await _tokenStorage.readToken();
    final isLoggedIn = token != null && token.trim().isNotEmpty;
    if (isLoggedIn) {
      return true;
    }

    if (!mounted) {
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    final nextToken = await _tokenStorage.readToken();
    final authenticated = nextToken != null && nextToken.trim().isNotEmpty;
    if (authenticated) {
      await _loadWishlistState();
    }
    return authenticated;
  }

  Future<void> _toggleWishlist(ProductModel product) async {
    final ok = await _ensureAuthenticated('Please login to add items to wishlist.');
    if (!ok) {
      return;
    }

    final item = WishlistItem(
      uuid: _wishlistKey(product, widget.uuid),
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
      _isFavorite = added;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(added ? 'Added to wishlist' : 'Removed from wishlist'),
        duration: const Duration(milliseconds: 900),
      ),
    );
  }

  Future<void> _openCartPage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CartPage(),
      ),
    );
  }

  Future<void> _addToCart(ProductModel product) async {
    if (product.stock <= 0) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This product is sold out.')),
      );
      return;
    }

    final ok = await _ensureAuthenticated('Please login to add items to cart.');
    if (!ok) {
      return;
    }

    final uuid = _wishlistKey(product, widget.uuid);
    await _cartStorage.addItem(
      CartItem(
        uuid: uuid,
        productId: product.id,
        title: product.title,
        price: product.price,
        quantity: 1,
        imageUrl: product.image,
        categoryName: product.category?.name,
      ),
    );

    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Added to cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.productProvider,
      builder: (_, __) {
        final provider = widget.productProvider;
        final product = provider.selected ?? widget.initialProduct;

        return Scaffold(
          backgroundColor: AppColors.background,
          body: provider.isLoading && product == null
              ? const LoadingView(label: 'Loading detail...')
              : product == null
                  ? Center(child: Text(provider.error ?? 'Product not found.'))
                  : _DetailBody(
                      product: product,
                      isFavorite: _isFavorite,
                      onBack: () => Navigator.pop(context),
                      onShare: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Share is coming soon.')),
                        );
                      },
                      onToggleFavorite: () => _toggleWishlist(product),
                    ),
          bottomNavigationBar: product == null
              ? null
              : _BottomActions(
                  onViewCart: _openCartPage,
                  onAddToCart: () => _addToCart(product),
                  canAddToCart: product.stock > 0,
                ),
        );
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.product,
    required this.isFavorite,
    required this.onBack,
    required this.onShare,
    required this.onToggleFavorite,
  });

  final ProductModel product;
  final bool isFavorite;
  final VoidCallback onBack;
  final VoidCallback onShare;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final imageUrl = (product.image ?? '').trim();
    final rating = 4.0 + ((product.id % 10) / 20);
    final reviewCount = (product.stock * 7).clamp(12, 987);
    final category = (product.category?.name ?? 'Book').trim();
    final author = category.isEmpty ? 'Unknown Author' : category;
    final stockLabel = product.stock <= 0 ? 'Sold' : 'Stock: ${product.stock}';
    final stockColor = product.stock <= 0 ? Colors.redAccent : const Color(0xFF138A36);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                IconButton(
                  onPressed: onBack,
                  icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textMain),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onShare,
                  icon: const Icon(LucideIcons.share2, color: AppColors.textMain, size: 20),
                ),
                IconButton(
                  onPressed: onToggleFavorite,
                  icon: Icon(
                    LucideIcons.heart,
                    color: isFavorite ? Colors.redAccent : AppColors.textMain,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 290,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl.isEmpty
                        ? _DetailImagePlaceholder(title: product.title)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _DetailImagePlaceholder(title: product.title),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F2F7),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      category.isEmpty ? 'Book' : category,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMain,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.title.trim().isEmpty ? 'Untitled Book' : product.title.trim(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by $author',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(LucideIcons.star, size: 16, color: Color(0xFFFFB800)),
                      const SizedBox(width: 4),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '($reviewCount reviews)',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: Color(0xFFE8E9EF)),
                  const SizedBox(height: 12),
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.package,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stockLabel,
                        style: TextStyle(
                          color: stockColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.trim().isEmpty
                        ? 'No description available for this book yet.'
                        : product.description.trim(),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.onViewCart,
    required this.onAddToCart,
    required this.canAddToCart,
  });

  final VoidCallback onViewCart;
  final VoidCallback onAddToCart;
  final bool canAddToCart;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        color: AppColors.background,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onViewCart,
                icon: const Icon(LucideIcons.shoppingCart, size: 16),
                label: const Text('View Cart'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textMain,
                  side: const BorderSide(color: Color(0xFFD8DCE7)),
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: canAddToCart ? onAddToCart : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.45),
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                  ),
                ),
                child: Text(canAddToCart ? 'Add to Cart' : 'Sold Out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailImagePlaceholder extends StatelessWidget {
  const _DetailImagePlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEEE7FF), Color(0xFFF7F4FF)],
        ),
      ),
      padding: const EdgeInsets.all(18),
      alignment: Alignment.bottomLeft,
      child: Text(
        title.trim().isEmpty ? 'Book' : title.trim(),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          height: 1.05,
        ),
      ),
    );
  }
}

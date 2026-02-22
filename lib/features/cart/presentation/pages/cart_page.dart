import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/storage/cart_storage.dart';
import '../../../payments/presentation/pages/payment_page.dart';
import '../../../products/presentation/pages/all_books_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  late final CartStorage _cartStorage = CartStorage();

  bool _isLoading = true;
  List<CartItem> _items = const <CartItem>[];

  @override
  void initState() {
    super.initState();
    _loadCart();
  }

  Future<void> _loadCart() async {
    final items = await _cartStorage.readItems();
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
    await _loadCart();
  }

  Future<void> _changeQty(CartItem item, int nextQty) async {
    await _cartStorage.updateQuantity(item.uuid, nextQty);
    await _loadCart();
  }

  Future<void> _removeItem(CartItem item) async {
    await _cartStorage.removeItem(item.uuid);
    await _loadCart();
  }

  Future<void> _openPaymentPage() async {
    if (_items.isEmpty) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentPage(
          items: List<CartItem>.from(_items),
          currency: 'USD',
          onPaymentVerified: () async {
            await _cartStorage.saveItems(const <CartItem>[]);
            await _loadCart();
          },
        ),
      ),
    );

    await _loadCart();
  }

  double get _totalAmount =>
      _items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));

  int get _totalQty => _items.fold<int>(0, (sum, item) => sum + item.quantity);
  int get _itemLines => _items.length;
  double get _shippingFee => 0.0;
  double get _deliveryFee => 0.0;
  double get _grandTotal => _totalAmount + _shippingFee + _deliveryFee;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 68,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shopping Cart',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                        ),
                        if (!_isLoading && _items.isNotEmpty)
                          Text(
                            '$_itemLines item${_itemLines == 1 ? '' : 's'} selected',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
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
                      : _buildCartContent(),
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
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.shoppingBag,
                size: 42,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Discover amazing books and add them to your cart',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _openBrowseBooks,
              icon: const Icon(LucideIcons.bookOpen, size: 15),
              label: const Text('Browse Books'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.3),
                minimumSize: const Size(140, 42),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              children: [
                for (var i = 0; i < _items.length; i++) ...[
                  _CartItemCard(
                    item: _items[i],
                    onDecrement: () => _changeQty(_items[i], _items[i].quantity - 1),
                    onIncrement: () => _changeQty(_items[i], _items[i].quantity + 1),
                    onRemove: () => _removeItem(_items[i]),
                  ),
                  if (i != _items.length - 1) const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
                _buildOrderSummaryCard(),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(
              top: BorderSide(color: Color(0xFFE8E9EF)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total ($_itemLines item${_itemLines == 1 ? '' : 's'})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${_grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMain,
                        fontSize: 26,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openPaymentPage,
                  icon: const Icon(LucideIcons.shoppingCart, size: 16),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE6E9F2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            color: const Color(0xFFF1F4FB),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 10,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    LucideIcons.shoppingBag,
                    size: 11,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'Order Summary',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              children: [
                _SummaryRow(
                  label: 'Subtotal ($_itemLines item${_itemLines == 1 ? '' : 's'})',
                  value: '\$${_totalAmount.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Shipping Fee',
                  value: '\$${_shippingFee.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 8),
                _SummaryRow(
                  label: 'Delivery Fee',
                  value: '\$${_deliveryFee.toStringAsFixed(2)}',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE8E9EF)),
                ),
                _SummaryRow(
                  label: 'Total',
                  value: '\$${_grandTotal.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({
    required this.item,
    required this.onDecrement,
    required this.onIncrement,
    required this.onRemove,
  });

  final CartItem item;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled Book' : item.title.trim();
    final subtitle = (item.categoryName ?? '').trim().isNotEmpty ? item.categoryName!.trim() : 'Book';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 86,
            height: 110,
            child: _CartImage(imageUrl: item.imageUrl),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        child: Row(
                          children: [
                            _QtyButton(icon: LucideIcons.minus, onTap: onDecrement),
                            SizedBox(
                              width: 30,
                              child: Center(
                                child: Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            _QtyButton(icon: LucideIcons.plus, onTap: onIncrement),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${item.price.toStringAsFixed(2)} each',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMain,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(LucideIcons.trash2, size: 18),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 14, color: AppColors.textMain),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      color: isTotal ? AppColors.textMain : AppColors.textSecondary,
      fontSize: isTotal ? 14 : 13,
      fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
    );
    final valueStyle = TextStyle(
      color: isTotal ? AppColors.primary : AppColors.textMain,
      fontSize: isTotal ? 16 : 13,
      fontWeight: FontWeight.w800,
    );

    return Row(
      children: [
        Text(label, style: labelStyle),
        const Spacer(),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _CartImage extends StatelessWidget {
  const _CartImage({required this.imageUrl});

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

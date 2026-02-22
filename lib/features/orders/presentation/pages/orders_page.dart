import 'package:flutter/material.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../auth/presentation/pages/login_page.dart';
import '../../data/order_api.dart';
import '../../data/order_models.dart';
import '../../../products/presentation/pages/all_books_page.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final TokenStorage _tokenStorage = TokenStorage();
  late final OrderApi _orderApi = OrderApi(
    ApiClient(tokenStorage: _tokenStorage),
  );

  bool _isLoading = true;
  bool _requiresLogin = false;
  String? _error;
  List<OrderModel> _orders = const <OrderModel>[];

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _openBrowseBooks(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AllBooksPage(),
      ),
    );
  }

  Future<void> _openLogin(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
    if (!mounted) {
      return;
    }
    await _loadOrders();
  }

  Future<void> _loadOrders() async {
    final token = await _tokenStorage.readToken();
    final isLoggedIn = token != null && token.trim().isNotEmpty;
    if (!isLoggedIn) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _requiresLogin = true;
        _error = null;
        _orders = const <OrderModel>[];
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _requiresLogin = false;
      _error = null;
    });

    try {
      OrdersListResponse response;
      try {
        response = await _orderApi.getOrders(perPage: 50, page: 1);
      } catch (_) {
        response = await _orderApi.getOrders();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _orders = response.orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        final message = e is ApiException ? e.message : e.toString();
        final normalized = message.toLowerCase();
        if (normalized.contains('authentication token') ||
            normalized.contains('unauthenticated') ||
            normalized.contains('please login')) {
          _requiresLogin = true;
          _error = null;
          _orders = const <OrderModel>[];
        } else {
          _error = message;
        }
        _isLoading = false;
      });
    }
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
                    icon: const Icon(Icons.arrow_back, color: AppColors.textMain),
                  ),
                  const Text(
                    'My Orders',
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
                  : _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_requiresLogin) {
      return _buildLoginRequiredState();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
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
                onPressed: _loadOrders,
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

    if (_orders.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, index) {
          final order = _orders[index];
          return _OrderCard(order: order);
        },
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
              Icons.inventory_2_outlined,
              size: 76,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'No orders yet',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _openBrowseBooks(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(118, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Start Shopping'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginRequiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 76,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            const Text(
              'Login to view orders',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Your order history is available after you sign in.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => _openLogin(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(140, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: const Text('Login'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => _openBrowseBooks(context),
              child: const Text('Browse Books'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final status = order.primaryBadgeStatus;
    final badge = _statusBadge(status);
    final dateText = _formatDate(order.createdAt);
    final items = order.items.take(3).toList(growable: false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E7EF)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.displayNo,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateText,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: status.isEmpty ? 'Unknown' : _toTitle(status),
                  backgroundColor: badge.bg,
                  textColor: badge.fg,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E9EF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                if (items.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '- No items',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${item.productTitle}  x${item.quantity}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (order.items.length > 3)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+${order.items.length - 3} more items',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8E9EF)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${order.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors(this.bg, this.fg);

  final Color bg;
  final Color fg;
}

_BadgeColors _statusBadge(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();
  switch (status) {
    case PaymentStatus.pending:
    case OrderStatus.pending:
      return const _BadgeColors(Color(0xFFFFF3BF), Color(0xFFB07A00));
    case OrderStatus.confirmed:
    case OrderStatus.processing:
      return const _BadgeColors(Color(0xFFE8F0FF), Color(0xFF2F5BDB));
    case OrderStatus.completed:
    case PaymentStatus.paid:
      return const _BadgeColors(Color(0xFFE6FAEC), Color(0xFF138A36));
    case PaymentStatus.expired:
      return const _BadgeColors(Color(0xFFFFEEE0), Color(0xFFCC6A00));
    case OrderStatus.cancelled:
    case OrderStatus.failed:
    case PaymentStatus.failed:
      return const _BadgeColors(Color(0xFFFFE9EA), Color(0xFFD93025));
    case PaymentStatus.refunded:
      return const _BadgeColors(Color(0xFFF0E8FF), Color(0xFF6B35D7));
    default:
      return const _BadgeColors(Color(0xFFF1F3F7), Color(0xFF677086));
  }
}

String _toTitle(String value) {
  final text = value.trim();
  if (text.isEmpty) return '';
  return text[0].toUpperCase() + text.substring(1).toLowerCase();
}

String _formatDate(DateTime? date) {
  if (date == null) {
    return '-';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[date.month - 1];
  return '$month ${date.day}, ${date.year}';
}


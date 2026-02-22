import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/config/theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/storage/cart_storage.dart';
import '../../../../core/storage/token_storage.dart';
import '../../data/payment_api.dart';
import '../../data/payment_models.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({
    super.key,
    required this.items,
    required this.currency,
    this.onPaymentVerified,
  });

  final List<CartItem> items;
  final String currency;
  final Future<void> Function()? onPaymentVerified;

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  static const int _qrExpirySeconds = 111;
  static const int _warningThresholdSeconds = 15;
  static const Duration _verifyPollInterval = Duration(seconds: 3);

  late final TokenStorage _tokenStorage = TokenStorage();
  late final PaymentApi _paymentApi = PaymentApi(
    ApiClient(tokenStorage: _tokenStorage),
  );

  bool _isLoading = true;
  bool _isVerifying = false;
  bool _isPaymentSuccess = false;
  String? _error;
  CheckoutPaymentSession? _session;
  Timer? _timer;
  Timer? _verifyTimer;
  int _remainingSeconds = _qrExpirySeconds; // starts near 1:51 like design screenshot
  bool _hasShownExpiryWarning = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _checkout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _verifyTimer?.cancel();
    super.dispose();
  }

  double get _subtotal =>
      widget.items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
  double get _shippingFee => 0.0;
  double get _deliveryFee => 0.0;
  double get _total => _subtotal + _shippingFee + _deliveryFee;
  int get _totalQty => widget.items.fold<int>(0, (sum, item) => sum + item.quantity);
  bool get _isExpired => _remainingSeconds <= 0;
  bool get _isExpiringSoon => !_isExpired && _remainingSeconds <= _warningThresholdSeconds;

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _stopAutoVerifyPolling();
        return;
      }
      setState(() {
        _remainingSeconds -= 1;
      });
      if (_remainingSeconds == _warningThresholdSeconds && !_hasShownExpiryWarning) {
        _hasShownExpiryWarning = true;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR code will expire in 15 seconds.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
  }

  void _resetCountdown() {
    _remainingSeconds = _qrExpirySeconds;
    _hasShownExpiryWarning = false;
    _startTimer();
  }

  void _stopAutoVerifyPolling() {
    _verifyTimer?.cancel();
    _verifyTimer = null;
  }

  void _startAutoVerifyPolling() {
    final session = _session;
    if (session == null) return;
    if (session.orderUuid.trim().isEmpty || session.md5.trim().isEmpty) return;
    if (_isPaymentSuccess || _isExpired) return;

    _stopAutoVerifyPolling();

    _verifyTimer = Timer.periodic(_verifyPollInterval, (timer) async {
      if (!mounted || _isPaymentSuccess || _isExpired) {
        timer.cancel();
        return;
      }
      await _verifyPaymentInternal(silent: true);
    });
  }

  String get _countdownLabel {
    final min = (_remainingSeconds ~/ 60).toString().padLeft(1, '0');
    final sec = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$min:$sec';
  }

  Future<void> _checkout() async {
    setState(() {
      _isLoading = true;
      _isPaymentSuccess = false;
      _error = null;
    });
    _stopAutoVerifyPolling();
    _resetCountdown();

    final checkoutItems = <CheckoutOrderItem>[];
    for (final item in widget.items) {
      final productId = item.productId;
      if (productId == null || productId <= 0) {
        setState(() {
          _isLoading = false;
          _error = 'Some cart items are missing product id. Please remove and add them again.';
        });
        return;
      }
      checkoutItems.add(
        CheckoutOrderItem(
          productId: productId,
          quantity: item.quantity,
        ),
      );
    }

    if (checkoutItems.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = 'Cart is empty.';
      });
      return;
    }

    try {
      final session = await _paymentApi.checkoutOrder(
        currency: widget.currency,
        items: checkoutItems,
      );

      if (!mounted) {
        return;
      }

      if (session.qrData.trim().isEmpty) {
        setState(() {
          _session = session;
          _isLoading = false;
          _error = 'Checkout succeeded but QR data was not found in response.';
        });
        return;
      }

      setState(() {
        _session = session;
        _isLoading = false;
      });
      _startAutoVerifyPolling();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = _resolvePaymentError(e, fallback: 'Checkout failed. Please try again.');
      });
    }
  }

  Future<void> _verifyPayment() async {
    return _verifyPaymentInternal(silent: false);
  }

  Future<void> _verifyPaymentInternal({required bool silent}) async {
    final session = _session;
    if (session == null) {
      return;
    }
    if (session.orderUuid.trim().isEmpty || session.md5.trim().isEmpty) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Missing order verification info (order_uuid/md5).'),
          ),
        );
      }
      return;
    }

    if (_isVerifying || _isPaymentSuccess || _isExpired) {
      return;
    }

    setState(() {
      _isVerifying = true;
    });
    try {
      await _paymentApi.verifyPayment(
        orderUuid: session.orderUuid.trim(),
        md5: session.md5.trim(),
      );
      if (!mounted) {
        return;
      }
      _stopAutoVerifyPolling();
      _timer?.cancel();
      setState(() {
        _isPaymentSuccess = true;
        _error = null;
      });
      if (widget.onPaymentVerified != null) {
        await widget.onPaymentVerified!.call();
      }
      if (!mounted) {
        return;
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment verified successfully.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _resolvePaymentError(
                e,
                fallback: 'Payment is not verified yet. Please complete payment and try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _regenerateQr() async {
    await _checkout();
  }

  String _resolvePaymentError(
    Object error, {
    required String fallback,
  }) {
    if (error is ApiException) {
      final details = error.details;
      if (details != null) {
        for (final entry in details.entries) {
          final value = entry.value;
          if (value is List && value.isNotEmpty) {
            final msg = value.first.toString().trim();
            if (msg.isNotEmpty) {
              return msg;
            }
          }
          if (value is String && value.trim().isNotEmpty) {
            return value.trim();
          }
        }
      }

      final message = error.message.trim();
      if (message.isEmpty || message.toLowerCase() == 'validation failed.') {
        return fallback;
      }
      return message;
    }

    final text = error.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    if (_isPaymentSuccess) {
      return _buildSuccessScaffold();
    }

    final qrData = _session?.qrData.trim() ?? '';
    final qrUrl = qrData.isEmpty
        ? ''
        : 'https://api.qrserver.com/v1/create-qr-code/?size=320x320&data=${Uri.encodeComponent(qrData)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 60,
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
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Scan QR code to pay',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        children: [
                          _buildPaymentCard(qrUrl),
                          const SizedBox(height: 14),
                          _buildOrderSummaryCard(),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            _buildErrorCard(),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessScaffold() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8EF),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFAFE3C1)),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF159B53),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Payment received!',
                  style: TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Thanks for your order.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: 180,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Done'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(String qrUrl) {
    final canVerify = _session != null &&
        (_session!.orderUuid.trim().isNotEmpty) &&
        (_session!.md5.trim().isNotEmpty) &&
        !_isExpired;
    final timerBg = _isExpired
        ? const Color(0xFFFFE8E8)
        : (_isExpiringSoon ? const Color(0xFFFFEAEA) : const Color(0xFFF1EAFF));
    final timerFg = _isExpired
        ? const Color(0xFFE53935)
        : (_isExpiringSoon ? const Color(0xFFE53935) : AppColors.primary);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E9F2)),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.secondary],
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'BookStore',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Scan QR code with your banking app',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: timerBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isExpired ? Icons.timer_off_outlined : Icons.timer_outlined,
                        size: 14,
                        color: timerFg,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isExpired ? 'Expired' : _countdownLabel,
                        style: TextStyle(
                          color: timerFg,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Total Payment',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${_total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textMain,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                  ),
                ),
                Text(
                  '$_totalQty items',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                if (_isExpired) ...[
                  _buildExpiredSection(),
                ] else ...[
                  _buildActiveQrSection(qrUrl, canVerify),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveQrSection(String qrUrl, bool canVerify) {
    final isProcessing = canVerify && !_isExpired && !_isPaymentSuccess;
    return Column(
      children: [
        Container(
          width: 240,
          height: 240,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8EAF3)),
          ),
          child: qrUrl.isEmpty
              ? const Center(
                  child: Text(
                    'QR not available',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          qrUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Text(
                              'Failed to load QR',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.qr_code, color: Colors.white, size: 20),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Supported Payment Methods',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _BankChip(label: 'ABA Bank', color: Color(0xFF2E6CF6)),
            _BankChip(label: 'KHQR', color: Color(0xFFFF2F2F)),
            _BankChip(label: 'All Banks', color: Color(0xFF10A53C)),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4FB),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to Pay:',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMain,
                ),
              ),
              SizedBox(height: 8),
              _HowToRow(step: '1', text: 'Open your banking app'),
              SizedBox(height: 6),
              _HowToRow(step: '2', text: 'Select "Scan QR" or "Pay by QR"'),
              SizedBox(height: 6),
              _HowToRow(step: '3', text: 'Scan the QR code above'),
              SizedBox(height: 6),
              _HowToRow(step: '4', text: 'Payment will verify automatically after you pay'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: null,
            icon: isProcessing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.hourglass_empty, size: 16),
            label: Text(
              isProcessing
                  ? 'Processing Payment...'
                  : 'Waiting for Payment',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
              disabledForegroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 12, color: AppColors.textSecondary),
            SizedBox(width: 4),
            Text(
              'Secure payment powered by QR technology',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpiredSection() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xFFFFE8E8),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.timer_off_outlined,
            color: Color(0xFFE53935),
            size: 30,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'QR Code Expired',
          style: TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Please generate a new code to continue payment',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _regenerateQr,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Generate New QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
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
                  radius: 11,
                  backgroundColor: Color(0xFFE6EEFF),
                  child: Icon(Icons.receipt_long, size: 14, color: Color(0xFF3A6CFF)),
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
                for (var i = 0; i < widget.items.length; i++) ...[
                  _PaymentOrderItemTile(item: widget.items[i]),
                  if (i != widget.items.length - 1)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE8E9EF)),
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFE8E9EF)),
                ),
                _SummaryLine(
                  label: 'Subtotal (${widget.items.length} item${widget.items.length == 1 ? '' : 's'})',
                  value: '\$${_subtotal.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _SummaryLine(
                  label: 'Shipping Fee',
                  value: '\$${_shippingFee.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 6),
                _SummaryLine(
                  label: 'Delivery Fee',
                  value: '\$${_deliveryFee.toStringAsFixed(2)}',
                ),
                const SizedBox(height: 10),
                _SummaryLine(
                  label: 'Total Amount',
                  value: '\$${_total.toStringAsFixed(2)}',
                  isTotal: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF7C8C8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _error ?? 'Unknown error',
            style: const TextStyle(color: Colors.redAccent),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: _checkout,
              child: const Text('Retry Checkout'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BankChip extends StatelessWidget {
  const _BankChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  const _HowToRow({
    required this.step,
    required this.text,
  });

  final String step;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentOrderItemTile extends StatelessWidget {
  const _PaymentOrderItemTile({
    required this.item,
  });

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled Book' : item.title.trim();
    final qty = item.quantity;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 34,
            height: 42,
            color: const Color(0xFFF2F3F8),
            child: (item.imageUrl ?? '').trim().isEmpty
                ? const Icon(Icons.book_outlined, size: 18, color: AppColors.textSecondary)
                : Image.network(
                    item.imageUrl!.trim(),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.book_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMain,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                'Qty: $qty x \$${item.price.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Text(
          '\$${(item.price * qty).toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppColors.textMain,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? AppColors.textMain : AppColors.textSecondary,
            fontSize: isTotal ? 14 : 13,
            fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: isTotal ? AppColors.primary : AppColors.textMain,
            fontSize: isTotal ? 16 : 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

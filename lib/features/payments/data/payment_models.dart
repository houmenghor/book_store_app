class PaymentStatusModel {
  const PaymentStatusModel._();

  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String expired = 'expired';
  static const String failed = 'failed';
  static const String refunded = 'refunded';
}

class CheckoutOrderItem {
  const CheckoutOrderItem({
    required this.productId,
    required this.quantity,
  });

  final int productId;
  final int quantity;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'product_id': productId,
        'quantity': quantity,
      };
}

class CheckoutPaymentSession {
  const CheckoutPaymentSession({
    required this.orderUuid,
    required this.md5,
    required this.qrData,
    this.message,
    this.raw = const <String, dynamic>{},
  });

  final String orderUuid;
  final String md5;
  final String qrData;
  final String? message;
  final Map<String, dynamic> raw;

  factory CheckoutPaymentSession.fromApi(Map<String, dynamic> json) {
    final orderUuid = _findString(json, const [
      'order_uuid',
      'uuid',
      'orderUuid',
    ]);
    final md5 = _findString(json, const [
      'md5',
      'hash',
    ]);
    final qrData = _findString(json, const [
      'qr',
      'qr_data',
      'qrData',
      'khqr',
      'kh_qr',
      'payload',
      'data',
    ]);

    return CheckoutPaymentSession(
      orderUuid: orderUuid,
      md5: md5,
      qrData: qrData,
      message: _findString(json, const ['message']),
      raw: json,
    );
  }
}

String _findString(Map<String, dynamic> root, List<String> keys) {
  for (final key in keys) {
    final direct = root[key];
    final text = _asString(direct);
    if (text.isNotEmpty) {
      return text;
    }
  }

  final nested = _findStringRecursive(root, keys);
  return nested ?? '';
}

String? _findStringRecursive(dynamic value, List<String> keys) {
  if (value is Map) {
    for (final key in keys) {
      if (value.containsKey(key)) {
        final text = _asString(value[key]);
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    for (final child in value.values) {
      final result = _findStringRecursive(child, keys);
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }
  } else if (value is List) {
    for (final child in value) {
      final result = _findStringRecursive(child, keys);
      if (result != null && result.isNotEmpty) {
        return result;
      }
    }
  }

  return null;
}

String _asString(dynamic value) {
  if (value == null) {
    return '';
  }
  if (value is String) {
    return value.trim();
  }
  if (value is num || value is bool) {
    return value.toString().trim();
  }
  return '';
}

class OrderStatus {
  const OrderStatus._();

  static const String pending = 'pending';
  static const String confirmed = 'confirmed';
  static const String processing = 'processing';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
  static const String failed = 'failed';
}

class PaymentStatus {
  const PaymentStatus._();

  static const String pending = 'pending';
  static const String paid = 'paid';
  static const String expired = 'expired';
  static const String failed = 'failed';
  static const String refunded = 'refunded';
}

class OrderItemSummary {
  const OrderItemSummary({
    required this.productTitle,
    required this.quantity,
    required this.unitPrice,
    this.productImage,
  });

  final String productTitle;
  final int quantity;
  final double unitPrice;
  final String? productImage;

  factory OrderItemSummary.fromJson(Map<String, dynamic> json) {
    final productRaw = json['product'];
    String productTitle = _pickString(json, const ['product_title', 'title', 'name']);
    if (productTitle.isEmpty && productRaw is Map<String, dynamic>) {
      productTitle = _pickString(productRaw, const ['title', 'name']);
    }

    return OrderItemSummary(
      productTitle: productTitle.isEmpty ? 'Item' : productTitle,
      quantity: _asInt(json['quantity'], fallback: 1),
      unitPrice: _asDouble(
        json['price'] ?? json['unit_price'] ?? json['amount'] ?? json['line_total'] ?? json['subtotal'],
      ),
      productImage: productRaw is Map<String, dynamic>
          ? _pickNullableString(productRaw, const ['image', 'thumbnail', 'cover_image'])
          : null,
    );
  }
}

class OrderModel {
  const OrderModel({
    required this.id,
    required this.uuid,
    required this.orderNo,
    required this.status,
    required this.paymentStatus,
    required this.totalAmount,
    required this.createdAt,
    required this.items,
  });

  final int id;
  final String uuid;
  final String orderNo;
  final String status;
  final String paymentStatus;
  final double totalAmount;
  final DateTime? createdAt;
  final List<OrderItemSummary> items;

  String get displayNo {
    if (orderNo.trim().isNotEmpty) return orderNo.trim();
    if (uuid.trim().isNotEmpty) return 'ORD-${uuid.trim()}';
    if (id > 0) return 'ORD-$id';
    return 'Order';
  }

  String get primaryBadgeStatus {
    final payment = paymentStatus.trim().toLowerCase();
    if (payment.isNotEmpty) {
      return payment;
    }
    return status.trim().toLowerCase();
  }

  bool get isPendingLike {
    final s = primaryBadgeStatus;
    return s == OrderStatus.pending || s == PaymentStatus.pending;
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final itemsRaw = json['items'] ?? json['order_items'] ?? json['orderItems'];
    final items = <OrderItemSummary>[];
    if (itemsRaw is List) {
      for (final row in itemsRaw) {
        if (row is Map<String, dynamic>) {
          items.add(OrderItemSummary.fromJson(row));
        } else if (row is Map) {
          items.add(OrderItemSummary.fromJson(Map<String, dynamic>.from(row)));
        }
      }
    }

    final orderNo = _pickString(json, const [
      'order_no',
      'order_number',
      'orderNo',
      'invoice_no',
      'invoice_number',
    ]);
    final latestPaymentRaw = json['latest_payment'];
    final latestPaymentStatus = latestPaymentRaw is Map<String, dynamic>
        ? _pickString(latestPaymentRaw, const ['status', 'payment_status'])
        : '';

    return OrderModel(
      id: _asInt(json['id']),
      uuid: _pickString(json, const ['uuid']),
      orderNo: orderNo,
      status: _pickString(json, const ['status']),
      paymentStatus: _pickString(json, const ['payment_status', 'paymentStatus']).isNotEmpty
          ? _pickString(json, const ['payment_status', 'paymentStatus'])
          : latestPaymentStatus,
      totalAmount: _asDouble(
        json['grand_total'] ?? json['total_amount'] ?? json['total'] ?? json['amount'],
      ),
      createdAt: _asDateTime(json['created_at'] ?? json['createdAt'] ?? json['date']),
      items: items,
    );
  }
}

class OrdersListResponse {
  const OrdersListResponse({
    required this.orders,
    this.totalCount,
  });

  final List<OrderModel> orders;
  final int? totalCount;

  factory OrdersListResponse.fromApi(Map<String, dynamic> json) {
    final rows = _extractRows(json);
    final totalCount = _extractTotalCount(json);
    return OrdersListResponse(
      orders: rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .map(OrderModel.fromJson)
          .toList(growable: false),
      totalCount: totalCount,
    );
  }
}

List<dynamic> _extractRows(Map<String, dynamic> json) {
  final data = json['data'];
  if (data is List) {
    return data;
  }
  if (data is Map<String, dynamic> && data['data'] is List) {
    return data['data'] as List<dynamic>;
  }
  return <dynamic>[];
}

int? _extractTotalCount(Map<String, dynamic> json) {
  final directPaginate = json['paginate'];
  if (directPaginate is Map) {
    final total = _asNullableInt(directPaginate['total']);
    if (total != null) return total;
  }

  final data = json['data'];
  if (data is Map) {
    final nestedTotal = _asNullableInt(data['total']);
    if (nestedTotal != null) return nestedTotal;

    final nestedPaginate = data['paginate'];
    if (nestedPaginate is Map) {
      final total = _asNullableInt(nestedPaginate['total']);
      if (total != null) return total;
    }
  }

  final meta = json['meta'];
  if (meta is Map) {
    final total = _asNullableInt(meta['total']);
    if (total != null) return total;
  }

  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

String _pickString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return '';
}

String? _pickNullableString(Map<String, dynamic> json, List<String> keys) {
  final value = _pickString(json, keys).trim();
  return value.isEmpty ? null : value;
}

DateTime? _asDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}

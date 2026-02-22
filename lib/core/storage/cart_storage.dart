import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

class CartItem {
  const CartItem({
    required this.uuid,
    required this.title,
    required this.price,
    required this.quantity,
    this.productId,
    this.imageUrl,
    this.categoryName,
  });

  final String uuid;
  final String title;
  final double price;
  final int quantity;
  final int? productId;
  final String? imageUrl;
  final String? categoryName;

  CartItem copyWith({
    String? uuid,
    String? title,
    double? price,
    int? quantity,
    int? productId,
    String? imageUrl,
    String? categoryName,
  }) {
    return CartItem(
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      productId: productId ?? this.productId,
      imageUrl: imageUrl ?? this.imageUrl,
      categoryName: categoryName ?? this.categoryName,
    );
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      uuid: (json['uuid'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      price: _asDouble(json['price']),
      quantity: _asInt(json['quantity'], fallback: 1).clamp(1, 999),
      productId: _asNullableInt(json['product_id']),
      imageUrl: _nullableString(json['image_url']),
      categoryName: _nullableString(json['category_name']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uuid': uuid,
      'title': title,
      'price': price,
      'quantity': quantity,
      'product_id': productId,
      'image_url': imageUrl,
      'category_name': categoryName,
    };
  }
}

class CartStorage {
  CartStorage({
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

  static const String _cartKeyPrefix = 'user_cart_items';

  final TokenStorage _tokenStorage;

  Future<List<CartItem>> readItems() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _scopedKey());
    if (raw == null || raw.trim().isEmpty) {
      return <CartItem>[];
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return <CartItem>[];
      }
      return parsed
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(CartItem.fromJson)
          .where((item) => item.uuid.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return <CartItem>[];
    }
  }

  Future<void> saveItems(List<CartItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList(growable: false));
    await prefs.setString(key, encoded);
  }

  Future<void> addItem(CartItem item) async {
    final items = (await readItems()).toList(growable: true);
    final index = items.indexWhere((e) => e.uuid == item.uuid);
    if (index >= 0) {
      final current = items[index];
      items[index] = current.copyWith(
        quantity: (current.quantity + item.quantity).clamp(1, 999),
        price: item.price,
        title: item.title,
        productId: item.productId ?? current.productId,
        imageUrl: item.imageUrl,
        categoryName: item.categoryName,
      );
    } else {
      items.insert(0, item.copyWith(quantity: item.quantity.clamp(1, 999)));
    }
    await saveItems(items);
  }

  Future<void> removeItem(String uuid) async {
    final items = (await readItems()).where((e) => e.uuid != uuid.trim()).toList();
    await saveItems(items);
  }

  Future<void> updateQuantity(String uuid, int quantity) async {
    final normalized = uuid.trim();
    if (normalized.isEmpty) {
      return;
    }
    final items = (await readItems()).toList(growable: true);
    final index = items.indexWhere((e) => e.uuid == normalized);
    if (index < 0) {
      return;
    }
    if (quantity <= 0) {
      items.removeAt(index);
    } else {
      items[index] = items[index].copyWith(quantity: quantity.clamp(1, 999));
    }
    await saveItems(items);
  }

  Future<int> totalCount() async {
    final items = await readItems();
    return items.fold<int>(0, (sum, item) => sum + item.quantity);
  }

  Future<double> totalAmount() async {
    final items = await readItems();
    return items.fold<double>(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Future<String> _scopedKey() async {
    final account = ((await _tokenStorage.readUserEmail()) ?? '').trim().toLowerCase();
    if (account.isEmpty) {
      return '${_cartKeyPrefix}_guest';
    }
    final safe = account.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '${_cartKeyPrefix}_$safe';
  }
}

int? _asNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? fallback;
  }
  return fallback;
}

double _asDouble(dynamic value) {
  if (value is double) {
    return value;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value.trim()) ?? 0;
  }
  return 0;
}

String? _nullableString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

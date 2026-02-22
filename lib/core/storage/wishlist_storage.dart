import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'token_storage.dart';

class WishlistItem {
  const WishlistItem({
    required this.uuid,
    required this.title,
    required this.description,
    required this.price,
    this.imageUrl,
    this.categoryName,
  });

  final String uuid;
  final String title;
  final String description;
  final double price;
  final String? imageUrl;
  final String? categoryName;

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      uuid: (json['uuid'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: _asDouble(json['price']),
      imageUrl: _nullableString(json['image_url']),
      categoryName: _nullableString(json['category_name']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'uuid': uuid,
      'title': title,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category_name': categoryName,
    };
  }
}

class WishlistStorage {
  WishlistStorage({
    TokenStorage? tokenStorage,
  }) : _tokenStorage = tokenStorage ?? TokenStorage();

  static const String _wishlistKeyPrefix = 'user_wishlist_items';

  final TokenStorage _tokenStorage;

  Future<List<WishlistItem>> readItems() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    final raw = prefs.getString(key);
    if (raw == null || raw.trim().isEmpty) {
      return <WishlistItem>[];
    }

    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) {
        return <WishlistItem>[];
      }
      return parsed
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .map(WishlistItem.fromJson)
          .where((item) => item.uuid.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return <WishlistItem>[];
    }
  }

  Future<void> saveItems(List<WishlistItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _scopedKey();
    final encoded = jsonEncode(items.map((item) => item.toJson()).toList(growable: false));
    await prefs.setString(key, encoded);
  }

  Future<bool> contains(String uuid) async {
    final normalized = uuid.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final items = await readItems();
    return items.any((item) => item.uuid == normalized);
  }

  Future<bool> toggleItem(WishlistItem item) async {
    final normalizedUuid = item.uuid.trim();
    if (normalizedUuid.isEmpty) {
      return false;
    }

    final items = (await readItems()).toList(growable: true);
    final index = items.indexWhere((e) => e.uuid == normalizedUuid);
    if (index >= 0) {
      items.removeAt(index);
      await saveItems(items);
      return false;
    }

    items.insert(0, item);
    await saveItems(items);
    return true;
  }

  Future<void> removeItem(String uuid) async {
    final normalized = uuid.trim();
    if (normalized.isEmpty) {
      return;
    }
    final items = (await readItems()).where((item) => item.uuid != normalized).toList();
    await saveItems(items);
  }

  Future<String> _scopedKey() async {
    final account = ((await _tokenStorage.readUserEmail()) ?? '').trim().toLowerCase();
    if (account.isEmpty) {
      return '${_wishlistKeyPrefix}_guest';
    }
    final safe = account.replaceAll(RegExp(r'[^a-z0-9]'), '_');
    return '${_wishlistKeyPrefix}_$safe';
  }
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

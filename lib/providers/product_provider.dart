import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/catalog_categories.dart';
import '../core/services/supabase_service.dart';
import '../models/category.dart';
import '../models/product.dart';

final categoriesProvider = Provider<List<Category>>((ref) {
  return const [
    Category(name: 'Engine', icon: Icons.settings, count: 162),
    Category(name: 'Electrical', icon: Icons.bolt, count: 84),
    Category(name: 'Body', icon: Icons.directions_car, count: 121),
    Category(name: 'Filters', icon: Icons.filter_alt, count: 53),
    Category(name: 'Brake', icon: Icons.disc_full, count: 76),
    Category(name: 'Cooling', icon: Icons.ac_unit, count: 44),
  ];
});

// Async provider that fetches products from Supabase
final productsStreamProvider =
    FutureProvider.autoDispose<List<Product>>((ref) async {
  final data = await SupabaseService.fetchProducts();
  final existingCategories = data
      .map((row) => row['category'] as String? ?? '')
      .where((category) => category.trim().isNotEmpty)
      .toList();
  // Only normalize/merge category labels. Every database product remains in
  // the customer catalog, even when two records have the same name.
  return data
      .map((row) => _productFromRow({
            ...row,
            'category': resolveProductCategory(
                row['category'] as String? ?? '', existingCategories),
          }))
      .toList();
});

// Kept for API compatibility, but deliberately empty: demo products must never
// appear in a customer catalog.
final productsProvider = Provider<List<Product>>((ref) {
  return const [];
});

// Helper to map a raw DB row into a Product
Product _productFromRow(Map<String, dynamic> row) => Product(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      category: canonicalProductCategory(row['category'] as String? ?? ''),
      price: (row['price'] as num?)?.toDouble() ?? 0,
      mrp: (row['mrp'] as num?)?.toDouble() ?? 0,
      rating: 4.5,
      stock: (row['stock'] as num?)?.toInt() ?? 0,
      imageIcon: row['image_url'] as String? ?? '',
      badge: row['badge'] as String? ?? '',
      description: (row['description'] as String?)?.trim().isNotEmpty == true
          ? (row['description'] as String).trim()
          : 'Precision spare part with catalog-ready fitment and quality details.',
      compatibility: (row['compatibility'] is List)
          ? List<String>.from(row['compatibility'])
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty)
              .toList()
          : const [],
      specs: Map<String, String>.from(
        (row['specs'] as Map?)
                ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
            {},
      ),
      imageUrls: (row['image_urls'] is List)
          ? List<String>.from(row['image_urls'])
              .where((u) => u.isNotEmpty)
              .toList()
          : (row['image_url'] as String? ?? '').isNotEmpty
              ? [row['image_url'] as String]
              : [],
    );

// Live DB-backed single product lookup.
final productByIdProvider =
    FutureProvider.family<Product, String>((ref, id) async {
  final row = await SupabaseService.fetchProductById(id);
  if (row != null) return _productFromRow(row);
  throw StateError('Product not found');
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'product_provider.dart';
import '../models/product.dart';

/// Live catalog: reflects the real Supabase `products` table.
/// Never substitutes demo products: customers only see records that exist in
/// the real catalog.
final catalogProvider = Provider<List<Product>>((ref) {
  final asyncProducts = ref.watch(productsStreamProvider);
  return asyncProducts.when(
    data: (products) => products,
    loading: () => const [],
    error: (_, __) => const [],
  );
});

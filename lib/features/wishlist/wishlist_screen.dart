import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/wishlist_provider.dart';
import '../../widgets/product_card.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishlistIds = ref.watch(wishlistProvider);
    final allProducts = ref.watch(catalogProvider);
    final wishlisted =
        allProducts.where((p) => wishlistIds.contains(p.id)).toList();

    return WebShell(
      selectedIndex: -1,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => context.go('/profile'),
                    ),
                    const Expanded(
                      child: Text('Wishlist',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w900)),
                    ),
                    if (wishlisted.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Clear Wishlist',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w900)),
                              content: const Text('Remove all saved items?'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(
                                      backgroundColor: AppPalette.danger),
                                  child: const Text('Clear all',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            for (final p in wishlisted) {
                              ref.read(wishlistProvider.notifier).toggle(p.id);
                            }
                          }
                        },
                        child: const Text('Clear all',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppPalette.danger)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: wishlisted.isEmpty
                    ? _EmptyWishlist()
                    : Column(
                        children: [
                          Container(
                            color: AppPalette.navy.withOpacity(.04),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            width: double.infinity,
                            child: Row(
                              children: [
                                const Icon(Icons.favorite,
                                    size: 14, color: AppPalette.danger),
                                const SizedBox(width: 6),
                                Text(
                                  '${wishlisted.length} saved part${wishlisted.length > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppPalette.muted),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: Responsive.gridColumns(context),
                                childAspectRatio: .68,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: wishlisted.length,
                              itemBuilder: (_, i) =>
                                  ProductCard(product: wishlisted[i]),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyWishlist extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('Nothing saved yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            const Text(
              'Tap the ♡ on any part to save it here',
              style: TextStyle(color: AppPalette.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/catalog'),
              icon: const Icon(Icons.grid_view, size: 17),
              label: const Text('Browse Catalog',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

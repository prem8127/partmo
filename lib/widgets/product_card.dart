import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/responsive.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'hover_lift.dart';
import 'product_wishlist_icon.dart';

class ProductCard extends ConsumerWidget {
  const ProductCard({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desktop = !Responsive.isMobile(context);
    final image = _ProductImageStack(product: product);

    return HoverLift(
      borderRadius: BorderRadius.circular(8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => context.push('/product/${product.id}'),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (desktop)
                  SizedBox(height: 205, child: image)
                else
                  Expanded(child: image),
                const SizedBox(height: 10),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: AppPalette.warning),
                    Text(' ${product.rating}',
                        style: Theme.of(context).textTheme.labelSmall),
                    const Spacer(),
                    Text(
                      '${product.stock} left',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppPalette.success),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${AppConstants.currency}${product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppPalette.navy,
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _addToCart(context, ref),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppPalette.navy.withOpacity(.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          product.stock > 0
                              ? Icons.add_shopping_cart
                              : Icons.remove_shopping_cart_outlined,
                          size: 17,
                          color: product.stock > 0
                              ? AppPalette.navy
                              : AppPalette.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addToCart(BuildContext context, WidgetRef ref) {
    final added = ref.read(cartProvider.notifier).add(product);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        backgroundColor: AppPalette.navy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(
              added ? Icons.check_circle : Icons.info_outline,
              color: added ? const Color(0xFF1DBD79) : AppPalette.warning,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                added
                    ? '${product.name} added!'
                    : product.stock <= 0
                        ? '${product.name} is out of stock.'
                        : 'Only ${product.stock} available.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        action: added
            ? SnackBarAction(
                label: 'VIEW CART',
                textColor: AppPalette.cyan,
                onPressed: () {
                  ScaffoldMessenger.of(context).clearSnackBars();
                  context.push('/cart');
                },
              )
            : null,
      ),
    );
  }
}

class _ProductImageStack extends StatelessWidget {
  const _ProductImageStack({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppPalette.surface,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _hasRealImage(product.imageIcon)
                  ? Image.network(
                      product.imageIcon,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) => Icon(
                        _iconFor(product.imageIcon),
                        size: 52,
                        color: AppPalette.navy,
                      ),
                    )
                  : Icon(
                      _iconFor(product.imageIcon),
                      size: 52,
                      color: AppPalette.navy,
                    ),
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: ProductWishlistIcon(
            productId: product.id,
            iconSize: 18,
          ),
        ),
      ],
    );
  }
}

bool _hasRealImage(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

IconData _iconFor(String key) {
  return switch (key) {
    'lamp' => Icons.lightbulb,
    'filter' => Icons.filter_alt,
    'clutch' => Icons.settings,
    _ => Icons.disc_full,
  };
}

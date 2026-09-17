import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../models/cart_item.dart';
import '../providers/cart_provider.dart';
import 'quantity_selector.dart';

class CartItemCard extends ConsumerWidget {
  const CartItemCard({super.key, required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                  color: AppPalette.surface,
                  borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.precision_manufacturing,
                  color: AppPalette.navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  Text(item.product.category,
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: AppPalette.muted)),
                  const SizedBox(height: 8),
                  Text(
                      '${AppConstants.currency}${item.product.price.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            QuantitySelector(
              value: item.quantity,
              onChanged: (value) => ref
                  .read(cartProvider.notifier)
                  .changeQuantity(item.product.id, value),
            ),
          ],
        ),
      ),
    );
  }
}

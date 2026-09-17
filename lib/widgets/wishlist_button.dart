import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../providers/wishlist_provider.dart';

/// A visible entry point to the customer's saved parts.
class WishlistButton extends ConsumerWidget {
  const WishlistButton({super.key, this.useGo = false});

  final bool useGo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(wishlistProvider).length;

    return IconButton(
      onPressed: () =>
          useGo ? context.go('/wishlist') : context.push('/wishlist'),
      tooltip: 'Wishlist',
      visualDensity: VisualDensity.compact,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(
          count > 99 ? '99+' : '$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: AppPalette.danger,
        child: Icon(
          count > 0 ? Icons.favorite : Icons.favorite_border,
          color: count > 0 ? AppPalette.danger : AppPalette.navy,
          size: 22,
        ),
      ),
    );
  }
}

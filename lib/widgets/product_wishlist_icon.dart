import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/app_constants.dart';
import '../core/services/supabase_service.dart';
import '../providers/wishlist_provider.dart';

class ProductWishlistIcon extends ConsumerWidget {
  const ProductWishlistIcon({
    super.key,
    required this.productId,
    this.iconSize = 20,
  });

  final String productId;
  final double iconSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(wishlistProvider).contains(productId);
    return Material(
      color: Colors.white.withValues(alpha: .94),
      elevation: 1,
      shape: const CircleBorder(),
      child: IconButton(
        visualDensity: VisualDensity.compact,
        tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
        icon: Icon(
          saved ? Icons.favorite : Icons.favorite_border,
          color: saved ? AppPalette.danger : AppPalette.navy,
          size: iconSize,
        ),
        onPressed: () async {
          if (!SupabaseService.isLoggedIn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Sign in to save items.'),
                action: SnackBarAction(
                  label: 'SIGN IN',
                  onPressed: () => context.go('/login?return=/wishlist'),
                ),
              ),
            );
            return;
          }
          await ref.read(wishlistProvider.notifier).toggle(productId);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                saved ? 'Removed from wishlist.' : 'Saved to wishlist.',
              ),
            ),
          );
        },
      ),
    );
  }
}

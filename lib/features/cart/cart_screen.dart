import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(cartProvider);
    final subtotal = ref.watch(cartSubtotalProvider);
    const delivery = 0.0;
    final tax = subtotal * .18;
    final total = subtotal + delivery + tax;

    return WebShell(
      selectedIndex: -1,
      backgroundColor: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _CartHeader(onBack: () => context.go('/home'), onCart: () {}),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('ITEMS IN CART (${items.length})',
                            style: const TextStyle(
                                color: Color(0xFF5D6D7A),
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                        const Spacer(),
                        const Icon(Icons.check_circle,
                            color: AppPalette.cyan, size: 13),
                        const SizedBox(width: 5),
                        const Text('Express Delivery Enabled',
                            style: TextStyle(
                                color: Color(0xFF5D6D7A),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      const _EmptyCart()
                    else ...[
                      for (var i = 0; i < items.length; i++)
                        _StaggeredEntry(
                          index: i,
                          child: _CartLine(
                            item: items[i],
                            onChanged: (value) => ref
                                .read(cartProvider.notifier)
                                .changeQuantity(items[i].product.id, value),
                            onRemove: () =>
                                _confirmRemove(context, ref, items[i]),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _StaggeredEntry(
                          index: items.length,
                          child: _CartSummary(
                              subtotal: subtotal, tax: tax, total: total)),
                      const SizedBox(height: 16),
                      _StaggeredEntry(
                          index: items.length + 1,
                          child: const _DeliveringToCard()),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: FilledButton(
                          onPressed: () async {
                            if (!SupabaseService.isLoggedIn) {
                              context.go('/login?return=/checkout');
                              return;
                            }
                            if (ref.read(addressesProvider).isEmpty) {
                              await context.push('/addresses');
                              if (!context.mounted ||
                                  ref.read(addressesProvider).isEmpty) return;
                            }
                            if (context.mounted) context.go('/checkout');
                          },
                          style: FilledButton.styleFrom(
                              backgroundColor: AppPalette.navy,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4))),
                          child: const Text('PROCEED TO PAYMENT  ›',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8)),
                        ),
                      ),
                    ],
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

Future<void> _confirmRemove(
    BuildContext context, WidgetRef ref, dynamic item) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove item?'),
      content: Text('Remove "${item.product.name}" from your cart?'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child:
              const Text('REMOVE', style: TextStyle(color: Color(0xFFC0392B))),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    ref
        .read(cartProvider.notifier)
        .changeQuantity(item.product.id as String, 0);
  }
}

class _CartHeader extends StatelessWidget {
  const _CartHeader({required this.onBack, required this.onCart});

  final VoidCallback onBack;
  final VoidCallback onCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          10, MediaQuery.paddingOf(context).top + 10, 10, 10),
      child: Row(
        children: [
          IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back,
                  color: AppPalette.navy, size: 19),
              visualDensity: VisualDensity.compact),
          const Text('Checkout',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
              onPressed: onCart,
              icon: const Icon(Icons.shopping_cart_outlined,
                  color: AppPalette.navy, size: 20),
              visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

/// Fades + slides a child in on first build, with a small per-index delay
/// so cart lines cascade in one after another instead of popping in at once.
class _StaggeredEntry extends StatelessWidget {
  const _StaggeredEntry({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + (index * 70).clamp(0, 420)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
              offset: Offset(0, (1 - value) * 18), child: child),
        );
      },
      child: child,
    );
  }
}

class _CartLine extends StatelessWidget {
  const _CartLine(
      {required this.item, required this.onChanged, required this.onRemove});

  final dynamic item;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: .85, end: 1),
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 78,
                    height: 72,
                    color: const Color(0xFFE7ECF2),
                    child: _hasRealImage(item.product.imageIcon)
                        ? Image.network(
                            item.product.imageIcon,
                            width: 78,
                            height: 72,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2)),
                              );
                            },
                            errorBuilder: (_, __, ___) => Icon(
                                _partIcon(item.product.imageIcon),
                                color: const Color(0xFF536877),
                                size: 43),
                          )
                        : Icon(_partIcon(item.product.imageIcon),
                            color: const Color(0xFF536877), size: 43),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Color(0xFF172635),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.15)),
                    const SizedBox(height: 4),
                    const Text('4.8 ★ with Delivery',
                        style: TextStyle(
                            color: AppPalette.cyan,
                            fontSize: 9,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Text('₹${item.product.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: AppPalette.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              _QtyStepper(value: item.quantity, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline,
                        size: 15, color: Color(0xFFC0392B)),
                    SizedBox(width: 4),
                    Text('REMOVE',
                        style: TextStyle(
                            color: Color(0xFFC0392B),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .4)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 84,
      decoration: BoxDecoration(
          color: const Color(0xFFF0F3F7),
          borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          InkWell(
              onTap: () => onChanged((value - 1).clamp(1, 99).toInt()),
              child:
                  const Icon(Icons.remove, size: 14, color: Color(0xFF415262))),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) => ScaleTransition(
                scale: animation,
                child: FadeTransition(opacity: animation, child: child)),
            child: Text('$value',
                key: ValueKey<int>(value),
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          InkWell(
              onTap: () => onChanged(value + 1),
              child: const Icon(Icons.add, size: 14, color: Color(0xFF415262))),
        ],
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  const _CartSummary(
      {required this.subtotal, required this.tax, required this.total});

  final double subtotal;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(5),
        border:
            const Border(left: BorderSide(color: AppPalette.navy, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Order Summary',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          _SummaryRow(label: 'Subtotal', value: subtotal),
          const _SummaryRow(label: 'Delivery Fee', value: 0, free: true),
          _SummaryRow(label: 'GST (18%)', value: tax),
          const Divider(height: 24, color: Color(0xFFE5ECF2)),
          _SummaryRow(label: 'Total Amount', value: total, strong: true),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label,
      required this.value,
      this.strong = false,
      this.free = false});

  final String label;
  final double value;
  final bool strong;
  final bool free;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: const Color(0xFF5E6E7C),
                      fontSize: strong ? 12 : 10.5,
                      fontWeight: FontWeight.w700))),
          Text(
            free ? 'FREE' : '₹${value.toStringAsFixed(0)}',
            style: TextStyle(
                color: strong ? AppPalette.navy : const Color(0xFF172635),
                fontSize: strong ? 17 : 11,
                fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _DeliveringToCard extends ConsumerWidget {
  const _DeliveringToCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final selectedId = ref.watch(selectedAddressProvider);
    final selected = addresses.isEmpty
        ? null
        : addresses.firstWhere((a) => a.id == selectedId,
            orElse: () => addresses.first);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(5)),
      child: Row(
        children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppPalette.navy,
                  borderRadius: BorderRadius.circular(4)),
              child:
                  const Icon(Icons.location_on, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DELIVERING TO',
                    style: TextStyle(
                        color: Color(0xFF7A8995),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8)),
                const SizedBox(height: 4),
                Text(
                    selected == null
                        ? 'No delivery address added'
                        : '${selected.label} • ${selected.line}, ${selected.city}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        height: 1.2)),
              ],
            ),
          ),
          TextButton(
              onPressed: () => context.push('/addresses'),
              child: Text(selected == null ? 'ADD' : 'CHANGE',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

IconData _partIcon(String key) {
  return switch (key) {
    'engine' => Icons.precision_manufacturing,
    'brake' => Icons.disc_full,
    'air' => Icons.blur_on,
    'oil' => Icons.filter_alt,
    'link' => Icons.timeline,
    _ => Icons.filter_alt,
  };
}

bool _hasRealImage(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 18),
          const Text('Your cart is empty',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF172635))),
          const SizedBox(height: 8),
          const Text('Add some parts to get started.',
              style: TextStyle(color: Color(0xFF7D8B97), fontSize: 12.5)),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () => context.go('/catalog'),
            icon: const Icon(Icons.shopping_bag_outlined, size: 17),
            label: const Text('Browse Catalog',
                style: TextStyle(fontWeight: FontWeight.w900)),
            style: FilledButton.styleFrom(
                backgroundColor: AppPalette.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5))),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../models/product.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_wishlist_icon.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));

    return WebShell(
      selectedIndex: -1,
      backgroundColor: const Color(0xFFF4F7FB),
      child: productAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child:
              Text('Could not load product.\n$e', textAlign: TextAlign.center),
        ),
        data: (product) => _ProductDetailBody(product: product, ref: ref),
      ),
    );
  }
}

// ── Stateful body so we can track selected thumbnail ───────────────────────────
class _ProductDetailBody extends StatefulWidget {
  const _ProductDetailBody({required this.product, required this.ref});
  final Product product;
  final WidgetRef ref;

  @override
  State<_ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends State<_ProductDetailBody> {
  int _selectedIdx = 0;

  Product get product => widget.product;
  WidgetRef get ref => widget.ref;

  @override
  Widget build(BuildContext context) {
    final images = product.allImages;
    final activeUrl = images.isNotEmpty
        ? images[_selectedIdx.clamp(0, images.length - 1)]
        : null;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DetailHeader(onMenu: () => context.go('/home')),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catalog  ›  Spares',
                    style: TextStyle(
                        color: Color(0xFF617180),
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 28),
                  if (product.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                          color: AppPalette.cyan,
                          borderRadius: BorderRadius.circular(14)),
                      child: Text(
                        product.badge.toUpperCase(),
                        style: const TextStyle(
                            color: AppPalette.navy,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .7),
                      ),
                    ),
                  const SizedBox(height: 22),

                  // ── Main image ──
                  SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _MainProductImage(
                              product: product, activeUrl: activeUrl),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: ProductWishlistIcon(productId: product.id),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Thumbnail row ──
                  _ImageThumbnailRow(
                    images: images,
                    product: product,
                    selectedIndex: _selectedIdx,
                    onSelect: (i) => setState(() => _selectedIdx = i),
                  ),

                  const SizedBox(height: 28),
                  _TechnicalSpecs(product: product),
                  const SizedBox(height: 24),
                  const Text(
                    'SPARE PART',
                    style: TextStyle(
                        color: Color(0xFF758596),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 32,
                        height: .9,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 22),
                  _PricePanel(
                    product: product,
                    onAdd: () => ref.read(cartProvider.notifier).add(product),
                    onBuy: () {
                      ref.read(cartProvider.notifier).add(product);
                      context.go('/checkout');
                    },
                  ),
                  const SizedBox(height: 18),
                  const _FitmentNote(),
                  const SizedBox(height: 44),
                  const Text('Engineering Insights',
                      style: TextStyle(
                          color: AppPalette.navy,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 22),
                  const _InsightCard(
                    icon: Icons.filter_alt,
                    title: 'Advanced Filtration',
                    body:
                        'Multi-layered synthetic fibers capture particles down to 20 microns, protecting engine longevity.',
                  ),
                  const _InsightCard(
                    icon: Icons.device_thermostat,
                    title: 'High Temp Gasket',
                    body:
                        'Nitrile rubber seal maintains elasticity in extreme temperatures preventing oil leaks under pressure.',
                  ),
                  const _InsightCard(
                    icon: Icons.shield_outlined,
                    title: 'Anti-Drain Back',
                    body:
                        'Integrated silicone valve prevents dry starts by keeping oil in the filter after engine shutdown.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Main image display ─────────────────────────────────────────────────────────
class _MainProductImage extends StatelessWidget {
  const _MainProductImage({required this.product, required this.activeUrl});

  final Product product;
  final String? activeUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: Container(
          key: ValueKey(activeUrl),
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
          ),
          child: activeUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    activeUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _iconFallback(product),
                  ),
                )
              : _iconFallback(product),
        ),
      ),
    );
  }

  Widget _iconFallback(Product p) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            color: const Color(0xFFE7ECF2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFB6C5D1), width: 8),
          ),
        ),
        Icon(_partIcon(p.imageIcon), color: const Color(0xFF2E4B58), size: 78),
      ],
    );
  }
}

// ── Thumbnail row ──────────────────────────────────────────────────────────────
class _ImageThumbnailRow extends StatelessWidget {
  const _ImageThumbnailRow({
    required this.images,
    required this.product,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> images;
  final Product product;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // Always show at least 3 slots
    const slotCount = 3;
    return Row(
      children: List.generate(slotCount, (i) {
        final hasImage = i < images.length;
        final isSelected = i == selectedIndex;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < slotCount - 1 ? 12 : 0),
            child: GestureDetector(
              onTap: hasImage ? () => onSelect(i) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 80,
                decoration: BoxDecoration(
                  color: hasImage ? Colors.white : const Color(0xFFF0F4F8),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected && hasImage
                        ? AppPalette.cyan
                        : const Color(0xFFDDE5EE),
                    width: isSelected && hasImage ? 2 : 1,
                  ),
                ),
                child: hasImage
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              images[i],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFFB0BBC6),
                                size: 28,
                              ),
                            ),
                            if (isSelected)
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: AppPalette.cyan, width: 2),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                          ],
                        ),
                      )
                    : Center(
                        child: Icon(
                          i == 1
                              ? Icons.view_in_ar
                              : Icons.add_photo_alternate_outlined,
                          color: const Color(0xFFB0BBC6),
                          size: 28,
                        ),
                      ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    if (!Responsive.isMobile(context)) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.paddingOf(context).top + 12, 14, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu, color: AppPalette.navy, size: 22),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 4),
          const Text('PARTMO',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 14)),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: const Color(0xFFFFC7A5),
                borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.person, color: AppPalette.navy, size: 19),
          ),
        ],
      ),
    );
  }
}

// ── Technical specs ────────────────────────────────────────────────────────────
class _TechnicalSpecs extends StatelessWidget {
  const _TechnicalSpecs({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final compatibility = product.compatibility.isNotEmpty
        ? product.compatibility.first
        : product.category.isNotEmpty
            ? product.category
            : 'Universal fitment — verify before ordering';

    // Show all non-empty specs from the product, plus compatibility
    final specEntries = <(String, String)>[
      if ((product.specs['OEM Number'] ?? '').isNotEmpty)
        ('OEM NUMBER', product.specs['OEM Number']!),
      ('COMPATIBILITY', compatibility),
      if ((product.specs['Material'] ?? '').isNotEmpty)
        ('MATERIAL', product.specs['Material']!),
      if ((product.specs['Thread Size'] ?? '').isNotEmpty)
        ('THREAD SIZE', product.specs['Thread Size']!),
      if ((product.specs['Weight'] ?? '').isNotEmpty)
        ('WEIGHT', product.specs['Weight']!),
      if ((product.specs['Dimensions'] ?? '').isNotEmpty)
        ('DIMENSIONS', product.specs['Dimensions']!),
      if ((product.specs['Manufacturer'] ?? '').isNotEmpty)
        ('MANUFACTURER', product.specs['Manufacturer']!),
      if ((product.specs['Warranty'] ?? '').isNotEmpty)
        ('WARRANTY', product.specs['Warranty']!),
      if ((product.specs['Country'] ?? '').isNotEmpty)
        ('COUNTRY OF ORIGIN', product.specs['Country']!),
      if ((product.specs['Certifications'] ?? '').isNotEmpty)
        ('CERTIFICATIONS', product.specs['Certifications']!),
    ];

    // Fallback so specs section always has something
    final specs = specEntries.isNotEmpty
        ? specEntries
        : [('COMPATIBILITY', compatibility)];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF4FA),
          borderRadius: BorderRadius.circular(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined,
                  color: AppPalette.navy, size: 20),
              SizedBox(width: 8),
              Text('Technical Specifications',
                  style: TextStyle(
                      color: AppPalette.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 22),
          for (final spec in specs) ...[
            Text(spec.$1,
                style: const TextStyle(
                    color: Color(0xFF687887),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8)),
            const SizedBox(height: 7),
            Text(spec.$2,
                style: const TextStyle(
                    color: Color(0xFF273746),
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

// ── Price panel ────────────────────────────────────────────────────────────────
class _PricePanel extends StatelessWidget {
  const _PricePanel(
      {required this.product, required this.onAdd, required this.onBuy});
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final discountPct = product.mrp > product.price
        ? (((product.mrp - product.price) / product.mrp) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppPalette.navy,
                      fontSize: 35,
                      fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              if (product.mrp > product.price)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('₹${product.mrp.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Color(0xFF8F9EAA),
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              if (discountPct > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Text('$discountPct% OFF',
                      style: const TextStyle(
                          color: Color(0xFFE22F4A),
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const _Promise(
              icon: Icons.local_shipping_outlined,
              title: 'Standard Delivery',
              subtitle: 'Estimate: 3-5 business days (India)'),
          const SizedBox(height: 16),
          const _Promise(
              icon: Icons.verified_outlined,
              title: 'Precision Guaranteed',
              subtitle: '10-day replacement for manufacturing defects'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: product.stock > 0 ? onAdd : null,
              style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4))),
              child: Text(product.stock > 0 ? 'Add to Cart' : 'Out of Stock',
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FilledButton(
              onPressed: product.stock > 0 ? onBuy : null,
              style: FilledButton.styleFrom(
                  backgroundColor: AppPalette.cyan,
                  foregroundColor: AppPalette.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4))),
              child: const Text('Buy Now',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Promise extends StatelessWidget {
  const _Promise(
      {required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppPalette.navy, size: 21),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 13,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: const TextStyle(
                  color: Color(0xFF5E6E7C),
                  fontSize: 11.5,
                  height: 1.2,
                  fontWeight: FontWeight.w600)),
        ])),
      ],
    );
  }
}

// ── Fitment note ───────────────────────────────────────────────────────────────
class _FitmentNote extends StatelessWidget {
  const _FitmentNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFFEFEAE2),
          borderRadius: BorderRadius.circular(4)),
      child: const Row(children: [
        Icon(Icons.check_circle_outline, color: Color(0xFF635A27), size: 20),
        SizedBox(width: 10),
        Expanded(
            child: Text(
          'Verify fitment with your vehicle registration before ordering.',
          style: TextStyle(
              color: Color(0xFF403B1B),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.25),
        )),
      ]),
    );
  }
}

// ── Insight cards ──────────────────────────────────────────────────────────────
class _InsightCard extends StatelessWidget {
  const _InsightCard(
      {required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 34),
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 49,
          height: 49,
          decoration: BoxDecoration(
              color: const Color(0xFFE5F4FB),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppPalette.navy, size: 22),
        ),
        const SizedBox(height: 26),
        Text(title,
            style: const TextStyle(
                color: Color(0xFF172635),
                fontSize: 15,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text(body,
            style: const TextStyle(
                color: Color(0xFF5E6E7C),
                fontSize: 12.3,
                height: 1.4,
                fontWeight: FontWeight.w600)),
      ]),
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

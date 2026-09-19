import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/catalog_categories.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../models/product.dart';
import '../../providers/user_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/product_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/wishlist_button.dart';
import '../../widgets/product_wishlist_icon.dart';

class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveProductsAsync = ref.watch(productsStreamProvider);

    return WebShell(
      selectedIndex: 1,
      backgroundColor: const Color(0xFFF4F7FB),
      drawer: const EngineeringCatalogDrawer(),
      child: Builder(
        builder: (context) {
          return Center(
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(maxWidth: Responsive.maxWidth(context)),
              child: liveProductsAsync.when(
                loading: () => ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _CatalogHeader(
                        onMenu: () => Scaffold.of(context).openDrawer()),
                    const _HeroIntro(),
                    const _SearchPanel(),
                    const _CategoryChips(),
                    const SizedBox(height: 60),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 18),
                  ],
                ),
                error: (_, __) {
                  return _buildProductList(context, const []);
                },
                data: (liveProducts) {
                  final category = initialCategory == null
                      ? null
                      : canonicalProductCategory(initialCategory!)
                          .toLowerCase();
                  final products = category == null || category.isEmpty
                      ? liveProducts
                      : liveProducts.where((product) {
                          final haystack = '${product.category} ${product.name}'
                              .toLowerCase();
                          return haystack.contains(category);
                        }).toList();
                  return _buildProductList(context, products);
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductList(BuildContext context, List<Product> products) {
    if (products.isEmpty) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          _CatalogHeader(onMenu: () => Scaffold.of(context).openDrawer()),
          const _HeroIntro(),
          const _SearchPanel(),
          _CategoryChips(selected: initialCategory),
          const SizedBox(height: 60),
          const Center(
              child: Text('No products yet. Admin can add products.',
                  style: TextStyle(color: Color(0xFF9CA8B4)))),
          const SizedBox(height: 18),
        ],
      );
    }
    if (!Responsive.isMobile(context)) {
      return ListView(
        padding: EdgeInsets.zero,
        children: [
          const _HeroIntro(),
          const _SearchPanel(),
          _CategoryChips(selected: initialCategory),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 280,
                mainAxisExtent: 360,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (_, index) => ProductCard(product: products[index]),
            ),
          ),
          const _BulkOrderPanel(),
          const _QualityDossier(),
          const SizedBox(height: 18),
        ],
      );
    }
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _CatalogHeader(onMenu: () => Scaffold.of(context).openDrawer()),
        const _HeroIntro(),
        const _SearchPanel(),
        _CategoryChips(selected: initialCategory),
        if (products.length > 1) _FeatureProductCard(product: products[0]),
        for (final p in products.skip(products.length > 1 ? 1 : 0).take(2))
          _CatalogProductCard(product: p),
        const _BulkOrderPanel(),
        for (final p
            in products.skip(products.length > 3 ? 3 : products.length))
          _CatalogProductCard(product: p),
        const _QualityDossier(),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _CatalogHeader extends ConsumerWidget {
  const _CatalogHeader({required this.onMenu});

  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Responsive.isMobile(context)) return const SizedBox.shrink();
    final user = ref.watch(userProvider);
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
          const Text(
            'PARTMO',
            style: TextStyle(
                color: AppPalette.navy,
                fontWeight: FontWeight.w900,
                fontSize: 14),
          ),
          const Spacer(),
          const WishlistButton(),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 34,
              height: 34,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFD9F6FF),
                borderRadius: BorderRadius.circular(18),
              ),
              child: user.photoBytes != null
                  ? Image.memory(user.photoBytes!, fit: BoxFit.cover)
                  : const Icon(Icons.person, color: AppPalette.navy, size: 19),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroIntro extends StatelessWidget {
  const _HeroIntro();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'PartMo',
            style: TextStyle(
                color: AppPalette.navy,
                fontSize: 31,
                height: .92,
                fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 18),
          Text(
            'Access high-end technical components\nfor Toyota Innova Crysta and MG Hector.\nCurated for reliability and mechanical\nexcellence.',
            style: TextStyle(
                color: Color(0xFF5E6E7C),
                fontSize: 14.5,
                height: 1.45,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: () => context.go('/search'),
        child: Container(
          height: 55,
          padding: const EdgeInsets.only(left: 14, right: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE7ECF2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              const Icon(Icons.search, color: Color(0xFF7C8C9A), size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Search by Part Number or\nVehicle Model...',
                  style: TextStyle(
                      color: Color(0xFF778796),
                      fontSize: 11.5,
                      height: 1.12,
                      fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(
                width: 74,
                height: 40,
                child: FilledButton(
                  onPressed: () => context.go('/search'),
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppPalette.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5)),
                  ),
                  child: const Text('FIND',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({this.selected});
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveProducts = ref.watch(productsStreamProvider).value ?? const [];
    final categories = <String>{
      for (final product in liveProducts)
        if (product.category.trim().isNotEmpty) product.category.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, index) {
            final label = index == 0 ? 'All' : categories[index - 1];
            final isSelected = index == 0
                ? selected == null || selected!.trim().isEmpty
                : selected == null
                    ? false
                    : canonicalProductCategory(selected!).toLowerCase() ==
                        label.toLowerCase();
            return _Pill(label: label, selected: isSelected);
          },
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, this.selected = false});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => label == 'All'
          ? context.go('/catalog')
          : context.go('/catalog?category=${Uri.encodeComponent(label)}'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minWidth: 86),
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFBFEFFF) : const Color(0xFFE1E7EE),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: const TextStyle(
                color: Color(0xFF203243),
                fontSize: 11,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _FeatureProductCard extends StatelessWidget {
  const _FeatureProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final discount = product.mrp > 0
        ? (((product.mrp - product.price) / product.mrp) * 100).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 350,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppPalette.navy,
            borderRadius: BorderRadius.circular(5),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 18,
                  offset: Offset(0, 10))
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -24,
                top: 4,
                child: Icon(_partIcon(product.imageIcon),
                    color: Colors.white.withOpacity(.34), size: 175),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (product.badge.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      color: const Color(0xFFFFC400),
                      child: Text(product.badge.toUpperCase(),
                          style: const TextStyle(
                              color: AppPalette.navy,
                              fontSize: 9,
                              fontWeight: FontWeight.w900)),
                    ),
                  const Spacer(),
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: .94,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFFC6D8E7),
                        fontSize: 12.2,
                        height: 1.32,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Text('₹${product.price.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900)),
                      if (discount > 0) ...[
                        const SizedBox(width: 8),
                        Text('$discount% OFF',
                            style: const TextStyle(
                                color: Color(0xFFFFC400),
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ],
                      const Spacer(),
                      Container(
                        width: 110,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4)),
                        child: const Text('INQUIRE',
                            style: TextStyle(
                                color: AppPalette.navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: ProductWishlistIcon(productId: product.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogProductCard extends ConsumerWidget {
  const _CatalogProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(5),
        child: Container(
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(5)),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  _PartImage(
                      icon: _partIcon(product.imageIcon),
                      tall: true,
                      imageUrl: product.imageIcon.startsWith('http')
                          ? product.imageIcon
                          : null),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ProductWishlistIcon(productId: product.id),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(product.category.toString().toUpperCase(),
                      style: const TextStyle(
                          color: Color(0xFF33485A),
                          fontSize: 8,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  const Icon(Icons.info_outline,
                      color: Color(0xFF0D8CA7), size: 14),
                ],
              ),
              const SizedBox(height: 7),
              Text(product.name,
                  style: const TextStyle(
                      color: Color(0xFF172635),
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 5),
              Text(_subtitleFor(product.imageIcon),
                  style: const TextStyle(
                      color: Color(0xFF617180),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Text('₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: AppPalette.navy,
                          fontSize: 19,
                          fontWeight: FontWeight.w900)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      ref.read(cartProvider.notifier).add(product);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${product.name} added to cart'),
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                          color: const Color(0xFFE9EEF5),
                          borderRadius: BorderRadius.circular(5)),
                      child: const Icon(Icons.add_shopping_cart,
                          color: AppPalette.navy, size: 22),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartImage extends StatelessWidget {
  const _PartImage({required this.icon, this.tall = false, this.imageUrl});

  final IconData icon;
  final bool tall;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl != null &&
        imageUrl!.isNotEmpty &&
        imageUrl!.startsWith('http');
    return Container(
      height: tall ? 210 : 150,
      width: double.infinity,
      decoration: BoxDecoration(
          color: const Color(0xFFEFF3F8),
          borderRadius: BorderRadius.circular(3)),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _iconFallback(tall),
              ),
            )
          : _iconFallback(tall),
    );
  }

  Widget _iconFallback(bool tall) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _BlueprintGridPainter())),
        Center(
            child: Icon(icon,
                color: const Color(0xFF738899), size: tall ? 118 : 84)),
      ],
    );
  }
}

class _BulkOrderPanel extends StatelessWidget {
  const _BulkOrderPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Container(
        height: 176,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            color: const Color(0xFF00518D),
            borderRadius: BorderRadius.circular(5)),
        child: Stack(
          children: [
            Positioned(
                right: -18,
                bottom: -28,
                child: Icon(Icons.settings,
                    color: Colors.white.withOpacity(.08), size: 130)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('OEM Bulk Orders',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                const Text(
                  'Certified workshop partners receive priority\nshipping and dynamic technical support\npricing.',
                  style: TextStyle(
                      color: Color(0xFFC5D9E9),
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                      color: AppPalette.cyan,
                      borderRadius: BorderRadius.circular(3)),
                  child: const Text('CONNECT TO MANAGER',
                      style: TextStyle(
                          color: AppPalette.navy,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QualityDossier extends StatelessWidget {
  const _QualityDossier();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 62, 22, 38),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('QUALITY DOSSIER',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.2)),
          const SizedBox(height: 22),
          const Text(
            'All components undergo 4-stage ultrasonic testing\nbefore cataloging. We ensure 99.8% geometric\naccuracy for all critical engine components.',
            style: TextStyle(
                color: Color(0xFF5E6E7C),
                fontSize: 13,
                height: 1.55,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 30),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            children: const [
              _DossierPoint(number: '01', label: 'OEM\nSPECIFICATION\nMATCH'),
              _DossierPoint(number: '03', label: 'TRACEABLE\nSERIAL\nNUMBERS'),
              _DossierPoint(number: '02', label: 'METALLURGICAL\nVERIFICATION'),
              _DossierPoint(number: '04', label: 'TECHNICAL\nHOTLINE\nACCESS'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DossierPoint extends StatelessWidget {
  const _DossierPoint({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(number,
            style: const TextStyle(
                color: Color(0xFFB4DDE8),
                fontSize: 25,
                fontWeight: FontWeight.w900)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF223241),
                    fontSize: 10.5,
                    height: 1.14,
                    fontWeight: FontWeight.w900))),
      ],
    );
  }
}

class EngineeringCatalogDrawer extends ConsumerWidget {
  const EngineeringCatalogDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final isLoggedIn = SupabaseService.isLoggedIn;
    final authUser = SupabaseService.currentUser;

    String displayName = 'Guest';
    String subtitle = 'Tap to sign in';
    if (isLoggedIn) {
      final meta = authUser?.userMetadata;
      final metaName = (meta?['full_name'] ?? meta?['name']) as String?;
      if (metaName != null && metaName.trim().isNotEmpty) {
        displayName = metaName.trim();
      } else if ((authUser?.email ?? '').isNotEmpty) {
        displayName = authUser!.email!.split('@').first;
      } else {
        displayName = user.name;
      }
      subtitle = authUser?.email ?? user.role;
    }
    final initials = displayName
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isEmpty ? '' : w[0].toUpperCase())
        .join();

    return Drawer(
      width: 330,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 0, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 22),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Engineering Catalog',
                          style: TextStyle(
                              color: Color(0xFF233B89),
                              fontSize: 15,
                              fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close,
                          color: Color(0xFF8FA0B2), size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              InkWell(
                onTap: isLoggedIn
                    ? () {
                        Navigator.of(context).pop();
                        context.go('/profile');
                      }
                    : () {
                        Navigator.of(context).pop();
                        context.go('/login?return=/catalog');
                      },
                child: Container(
                  margin: const EdgeInsets.only(right: 28),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF2F5FA),
                      borderRadius: BorderRadius.circular(2)),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                            color: isLoggedIn
                                ? AppPalette.navy
                                : const Color(0xFFB6C2CE),
                            borderRadius: BorderRadius.circular(20)),
                        alignment: Alignment.center,
                        child: isLoggedIn && user.photoBytes != null
                            ? Image.memory(user.photoBytes!,
                                fit: BoxFit.cover, width: 42, height: 42)
                            : isLoggedIn
                                ? Text(initials,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900))
                                : const Icon(Icons.person_outline,
                                    color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName,
                                style: const TextStyle(
                                    color: Color(0xFF172635),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 3),
                            Text(subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Color(0xFF758596),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      if (!isLoggedIn)
                        const Icon(Icons.chevron_right,
                            color: Color(0xFF9CA8B4), size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 42),
              DrawerMenuItem(
                  icon: Icons.search,
                  label: 'Search',
                  selected: true,
                  onTap: () => context.go('/search')),
              DrawerMenuItem(
                  icon: Icons.directions_car_outlined,
                  label: 'Search by Car',
                  onTap: () => context.go('/search')),
              DrawerMenuItem(
                  icon: Icons.confirmation_number_outlined,
                  label: 'Search by Number Plate',
                  onTap: () => context.go('/search')),
              DrawerMenuItem(
                  icon: Icons.category_outlined,
                  label: 'Search by Categories',
                  onTap: () => context.go('/catalog')),
              DrawerMenuItem(
                  icon: Icons.shopping_cart_outlined,
                  label: 'Cart',
                  onTap: () => context.go('/cart')),
              DrawerMenuItem(
                  icon: Icons.favorite_border,
                  label: 'Wishlist',
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/wishlist');
                  }),
              const SizedBox(height: 28),
              DrawerMenuItem(
                  icon: Icons.gavel_outlined,
                  label: 'Legal & Others',
                  onTap: () {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Terms and policies are available in the home footer.')));
                  }),
              if (isLoggedIn)
                DrawerMenuItem(
                  icon: Icons.logout,
                  label: 'Logout',
                  danger: true,
                  onTap: () async {
                    await SupabaseService.signOut();
                    if (context.mounted) context.go('/login');
                  },
                )
              else
                DrawerMenuItem(
                  icon: Icons.login,
                  label: 'Sign In',
                  onTap: () => context.go('/login?return=/catalog'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DrawerMenuItem extends StatelessWidget {
  const DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFD73B3E) : AppPalette.navy;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 54,
        margin: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF5FD) : Colors.transparent,
          border: selected
              ? const Border(
                  left: BorderSide(color: Color(0xFF2D55B7), width: 4))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(width: selected ? 14 : 18),
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 18),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _BlueprintGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.34)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

String _subtitleFor(String key) {
  return switch (key) {
    'brake' => 'Front Axle Set, High-Heat Resistance',
    'air' => 'High-Flow Efficiency, OEM Part #8856',
    'oil' => 'Premium Micro-Fibre, Anti-Drainback',
    'link' => 'Rear Axle Stabilization, HD Grade',
    _ => 'Premium filtration, OEM fitment',
  };
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../providers/catalog_provider.dart';
import '../../models/product.dart';
import '../../widgets/product_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/wishlist_button.dart';
import 'filters_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialFilters});

  final FilterData? initialFilters;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  FilterData? _filters;
  bool _oemOnly = false;
  bool _inStockOnly = false;
  bool _underFiveThousand = false;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilters() async {
    final result = await context.push<FilterData>('/filters', extra: _filters);
    if (result != null && mounted) setState(() => _filters = result);
  }

  bool _matchesFilters(Product product) {
    final searchable = '${product.name} ${product.category} ${product.badge} '
            '${product.description} ${product.compatibility.join(' ')}'
        .toLowerCase();
    if (_oemOnly &&
        !searchable.contains('oem') &&
        !searchable.contains('genuine')) return false;
    if (_inStockOnly && product.stock <= 0) return false;
    if (_underFiveThousand && product.price > 5000) return false;

    final filter = _filters;
    if (filter == null) return true;
    if (product.price < filter.priceRange.start ||
        product.price > filter.priceRange.end) return false;
    if (filter.vehicles.isNotEmpty &&
        !filter.vehicles
            .any((vehicle) => searchable.contains(vehicle.toLowerCase())))
      return false;
    if (filter.partTypes.isNotEmpty &&
        !filter.partTypes
            .any((type) => searchable.contains(type.toLowerCase())))
      return false;
    if (filter.availability.contains('In stock') && product.stock <= 0)
      return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final catalogItems = ref.watch(catalogProvider); // live Supabase catalog

    final bool isSearching = _query.isNotEmpty;

    final displayItems = catalogItems.where((product) {
      final searchable = '${product.name} ${product.category} ${product.badge} '
              '${product.description} ${product.compatibility.join(' ')}'
          .toLowerCase();
      final matchesQuery =
          !isSearching || searchable.contains(_query.toLowerCase());
      return matchesQuery && _matchesFilters(product);
    }).toList();

    return WebShell(
      selectedIndex: 2,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Search Parts',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                  const WishlistButton(),
                  IconButton(
                    onPressed: _openFilters,
                    icon: const Icon(Icons.tune),
                    tooltip: 'Filters',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Pass controller to SearchBarWidget
              SearchBarWidget(
                hint: 'Try "LED headlight" or part number',
                controller: _searchController,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('OEM only'),
                    selected: _oemOnly,
                    onSelected: (value) => setState(() => _oemOnly = value),
                  ),
                  FilterChip(
                    label: const Text('In stock'),
                    selected: _inStockOnly,
                    onSelected: (value) => setState(() => _inStockOnly = value),
                  ),
                  FilterChip(
                    label: const Text('Under ₹5,000'),
                    selected: _underFiveThousand,
                    onSelected: (value) =>
                        setState(() => _underFiveThousand = value),
                  ),
                  if (_filters != null && !_filters!.isEmpty)
                    InputChip(
                      label: const Text('Clear advanced filters'),
                      onDeleted: () => setState(() => _filters = null),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Section label
              Row(
                children: [
                  Text(
                    isSearching ? 'Search Results' : 'Browse Catalog',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${displayItems.length})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Empty state
              if (displayItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('No parts found for "$_query"')),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: displayItems.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: Responsive.gridColumns(context),
                    childAspectRatio: .72,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (_, index) =>
                      ProductCard(product: displayItems[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

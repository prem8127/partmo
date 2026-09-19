import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/catalog_categories.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/product_provider.dart';

class CatalogManagementScreen extends ConsumerStatefulWidget {
  const CatalogManagementScreen({super.key});

  @override
  ConsumerState<CatalogManagementScreen> createState() =>
      _CatalogManagementScreenState();
}

class _CatalogManagementScreenState
    extends ConsumerState<CatalogManagementScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _managedCategories = [];
  bool _loading = true;
  String? _error;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  String _category = 'All';

  List<String> get _categories {
    final cats = <String>{
      for (final p in _products)
        if ((p['category'] as String? ?? '').trim().isNotEmpty)
          canonicalProductCategory(p['category'] as String),
    };
    final sorted = cats.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return ['All', ...sorted];
  }

  List<Map<String, dynamic>> get _filtered {
    return _products.where((p) {
      final name = (p['name'] as String? ?? '').toLowerCase();
      final cat = canonicalProductCategory(p['category'] as String? ?? '');
      final matchesQuery =
          _query.isEmpty || name.contains(_query.toLowerCase());
      final matchesCategory = _category == 'All' || cat == _category;
      return matchesQuery && matchesCategory;
    }).toList();
  }

  Future<void> _adjustStock(Map<String, dynamic> p, int delta) async {
    final current = (p['stock'] as num?)?.toInt() ?? 0;
    final next = (current + delta).clamp(0, 999999);
    if (next == current) return;
    setState(() => p['stock'] = next);
    try {
      await SupabaseService.updateProduct(p['id'] as String, {'stock': next});
      ref.invalidate(productsStreamProvider);
    } catch (e) {
      setState(() => p['stock'] = current);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Stock update failed')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await SupabaseService.fetchProducts();
      final managed = await SupabaseService.fetchProductCategories();
      final existingCategories = data
          .map((product) => product['category'] as String? ?? '')
          .where((category) => category.trim().isNotEmpty)
          .toList();
      for (final product in data) {
        product['category'] = resolveProductCategory(
            product['category'] as String? ?? '', existingCategories);
      }
      setState(() {
        _products = data;
        _managedCategories = managed;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load products.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Remove "$name" from the catalog?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await SupabaseService.deleteProduct(id);
      ref.invalidate(productsStreamProvider);
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    }
  }

  void _openEdit(Map<String, dynamic> product) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _EditProductDialog(product: product),
    );
    if (updated == true) {
      ref.invalidate(productsStreamProvider);
      _load();
    }
  }

  Future<void> _showCategoryManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> refresh() async {
            final rows = await SupabaseService.fetchProductCategories();
            if (!mounted) return;
            setState(() => _managedCategories = rows);
            setSheetState(() {});
          }

          Future<void> edit([Map<String, dynamic>? row]) async {
            final ctrl =
                TextEditingController(text: row?['name']?.toString() ?? '');
            final value = await showDialog<String>(
              context: ctx,
              builder: (dialogCtx) => AlertDialog(
                title: Text(row == null ? 'Add Category' : 'Edit Category'),
                content: TextField(
                  controller: ctrl,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Category name'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogCtx, ctrl.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
            ctrl.dispose();
            if (value == null || value.isEmpty) return;
            if (row == null) {
              await SupabaseService.addProductCategory(value);
            } else {
              await SupabaseService.updateProductCategory(
                row['id'].toString(),
                value,
              );
            }
            await refresh();
          }

          Future<void> delete(Map<String, dynamic> row) async {
            final ok = await showDialog<bool>(
              context: ctx,
              builder: (dialogCtx) => AlertDialog(
                title: const Text('Delete Category?'),
                content: Text(
                    'Delete "${row['name']}"? Existing products keep their current category text.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogCtx, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );
            if (ok != true) return;
            await SupabaseService.deleteProductCategory(row['id'].toString());
            await refresh();
          }

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text('Product Categories',
                              style: TextStyle(
                                  color: AppPalette.navy,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                          onPressed: () => edit(),
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppPalette.navy),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _managedCategories.isEmpty
                          ? const Center(
                              child: Text('No custom categories yet.'))
                          : ListView(
                              children: [
                                for (final row in _managedCategories)
                                  ListTile(
                                    title: Text(row['name']?.toString() ?? ''),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () => edit(row),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          onPressed: () => delete(row),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: AppPalette.danger,
                                          ),
                                        ),
                                      ],
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
        },
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      key: _scaffoldKey,
      drawer: compact
          ? Drawer(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shadowColor: Colors.black26,
              elevation: 18,
              child: _SideBar(),
            )
          : null,
      drawerScrimColor: Colors.transparent,
      backgroundColor: const Color(0xFFEFF4FA),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact) _SideBar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            if (compact)
                              IconButton(
                                onPressed: () =>
                                    _scaffoldKey.currentState?.openDrawer(),
                                icon: const Icon(Icons.menu),
                                tooltip: 'Admin menu',
                              ),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Inventory',
                                    style: TextStyle(
                                        color: AppPalette.navy,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900)),
                                Text('Manage catalog products',
                                    style: TextStyle(
                                        color: AppPalette.muted, fontSize: 11)),
                              ],
                            ),
                          ]),
                          Row(
                            children: [
                              IconButton(
                                  onPressed: _showCategoryManager,
                                  tooltip: 'Manage categories',
                                  icon: const Icon(Icons.category_outlined,
                                      color: AppPalette.navy)),
                              IconButton(
                                  onPressed: _load,
                                  icon: const Icon(Icons.refresh,
                                      color: AppPalette.navy)),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () => context.go('/admin/add-product'),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                      color: AppPalette.navy,
                                      borderRadius: BorderRadius.circular(5)),
                                  child: const Text('+ ADD PART',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Search + filter
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (v) => setState(() => _query = v),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: const TextStyle(
                                    color: Color(0xFFB4BEC8), fontSize: 12),
                                prefixIcon: const Icon(Icons.search,
                                    size: 18, color: AppPalette.muted),
                                isDense: true,
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(5),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(5)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _category,
                                  isExpanded: true,
                                  isDense: true,
                                  icon: const Icon(Icons.filter_list,
                                      size: 16, color: AppPalette.muted),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppPalette.navy,
                                      fontWeight: FontWeight.w700),
                                  items: _categories
                                      .map((c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c,
                                              overflow: TextOverflow.ellipsis)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _category = v ?? 'All'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Content
                    Expanded(
                      child: _loading
                          ? const Center(child: CircularProgressIndicator())
                          : _error != null
                              ? Center(
                                  child: Text(_error!,
                                      style: const TextStyle(
                                          color: AppPalette.danger)))
                              : _products.isEmpty
                                  ? const Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.inventory_2_outlined,
                                              size: 48,
                                              color: AppPalette.muted),
                                          SizedBox(height: 12),
                                          Text('No products yet.',
                                              style: TextStyle(
                                                  color: AppPalette.muted,
                                                  fontSize: 14)),
                                        ],
                                      ),
                                    )
                                  : _filtered.isEmpty
                                      ? const Center(
                                          child: Text(
                                              'No products match your search.',
                                              style: TextStyle(
                                                  color: AppPalette.muted,
                                                  fontSize: 13)),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                              24, 0, 24, 24),
                                          itemCount: _filtered.length,
                                          itemBuilder: (ctx, i) {
                                            final p = _filtered[i];
                                            final imageUrl =
                                                p['image_url'] as String?;
                                            final hasImage = imageUrl != null &&
                                                imageUrl.startsWith('http');
                                            return Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 10),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                boxShadow: const [
                                                  BoxShadow(
                                                      color: Color(0x08000000),
                                                      blurRadius: 6,
                                                      offset: Offset(0, 2))
                                                ],
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                            topLeft:
                                                                Radius.circular(
                                                                    8),
                                                            bottomLeft:
                                                                Radius.circular(
                                                                    8)),
                                                    child: hasImage
                                                        ? Image.network(
                                                            imageUrl,
                                                            width: 80,
                                                            height: 80,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (_,
                                                                    __, ___) =>
                                                                _imagePlaceholder())
                                                        : _imagePlaceholder(),
                                                  ),
                                                  const SizedBox(width: 14),
                                                  Expanded(
                                                    child: Padding(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 12),
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                              p['name']
                                                                      as String? ??
                                                                  '',
                                                              style: const TextStyle(
                                                                  color:
                                                                      AppPalette
                                                                          .navy,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w900,
                                                                  fontSize:
                                                                      14)),
                                                          const SizedBox(
                                                              height: 4),
                                                          Text(
                                                              p['category']
                                                                      as String? ??
                                                                  '',
                                                              style: const TextStyle(
                                                                  color:
                                                                      AppPalette
                                                                          .muted,
                                                                  fontSize:
                                                                      11)),
                                                          const SizedBox(
                                                              height: 4),
                                                          Row(
                                                            children: [
                                                              Text(
                                                                  '₹${(p['price'] as num?)?.toStringAsFixed(0) ?? '-'}',
                                                                  style: const TextStyle(
                                                                      color: AppPalette
                                                                          .navy,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900,
                                                                      fontSize:
                                                                          13)),
                                                              const SizedBox(
                                                                  width: 10),
                                                              Builder(
                                                                  builder: (_) {
                                                                final stock =
                                                                    (p['stock'] as num?)
                                                                            ?.toInt() ??
                                                                        0;
                                                                final low =
                                                                    stock <= 5;
                                                                final color = low
                                                                    ? AppPalette
                                                                        .danger
                                                                    : AppPalette
                                                                        .success;
                                                                final bg = low
                                                                    ? const Color(
                                                                        0xFFFFEEEE)
                                                                    : const Color(
                                                                        0xFFEEFFF4);
                                                                return Row(
                                                                  children: [
                                                                    InkWell(
                                                                      onTap: () =>
                                                                          _adjustStock(
                                                                              p,
                                                                              -1),
                                                                      child: const Icon(
                                                                          Icons
                                                                              .remove_circle_outline,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              AppPalette.muted),
                                                                    ),
                                                                    Container(
                                                                      margin: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              3),
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              6,
                                                                          vertical:
                                                                              2),
                                                                      decoration: BoxDecoration(
                                                                          color:
                                                                              bg,
                                                                          borderRadius:
                                                                              BorderRadius.circular(3)),
                                                                      child: Text(
                                                                          low
                                                                              ? 'Low: $stock'
                                                                              : 'Stock: $stock',
                                                                          style: TextStyle(
                                                                              color: color,
                                                                              fontSize: 9,
                                                                              fontWeight: FontWeight.w900)),
                                                                    ),
                                                                    InkWell(
                                                                      onTap: () =>
                                                                          _adjustStock(
                                                                              p,
                                                                              1),
                                                                      child: const Icon(
                                                                          Icons
                                                                              .add_circle_outline,
                                                                          size:
                                                                              16,
                                                                          color:
                                                                              AppPalette.muted),
                                                                    ),
                                                                  ],
                                                                );
                                                              }),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  // EDIT BUTTON
                                                  IconButton(
                                                    onPressed: () =>
                                                        _openEdit(p),
                                                    tooltip: 'Edit',
                                                    icon: const Icon(
                                                        Icons.edit_outlined,
                                                        color: AppPalette.navy,
                                                        size: 20),
                                                  ),
                                                  // DELETE BUTTON
                                                  IconButton(
                                                    onPressed: () => _delete(
                                                        p['id'] as String,
                                                        p['name'] as String? ??
                                                            'this product'),
                                                    tooltip: 'Delete',
                                                    icon: const Icon(
                                                        Icons.delete_outline,
                                                        color:
                                                            AppPalette.danger,
                                                        size: 20),
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                              ),
                                            );
                                          },
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

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: const Color(0xFFEFF3F8),
      child:
          const Icon(Icons.image_outlined, color: AppPalette.muted, size: 28),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PRODUCT DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product});
  final Map<String, dynamic> product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _mrpCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _badgeCtrl;
  late final TextEditingController _compatCtrl;
  late final TextEditingController _oemCtrl;
  late final TextEditingController _materialCtrl;
  late final TextEditingController _threadCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _dimensionsCtrl;
  late final TextEditingController _colorCtrl;
  late final TextEditingController _mfgNameCtrl;
  late final TextEditingController _mfgCountryCtrl;
  late final TextEditingController _mfgPartNoCtrl;
  late final TextEditingController _warrantyCtrl;
  late final TextEditingController _certCtrl;
  late final TextEditingController _hsnCtrl;

  // Unified multi-image gallery: mix of existing (already-uploaded) URLs
  // and newly-picked local images, in display order. First item is cover.
  final List<_EditImageItem> _images = [];
  static const int _maxImages = 6;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p['name'] as String? ?? '');
    _categoryCtrl = TextEditingController(
        text: canonicalProductCategory(p['category'] as String? ?? ''));
    _priceCtrl =
        TextEditingController(text: (p['price'] as num?)?.toString() ?? '');
    _mrpCtrl =
        TextEditingController(text: (p['mrp'] as num?)?.toString() ?? '');
    _stockCtrl =
        TextEditingController(text: (p['stock'] as num?)?.toString() ?? '');
    _descCtrl = TextEditingController(text: p['description'] as String? ?? '');
    _badgeCtrl = TextEditingController(text: p['badge'] as String? ?? '');
    final compatibility = (p['compatibility'] as List?)
            ?.map((item) => item.toString())
            .join(', ') ??
        '';
    final specs = (p['specs'] as Map?)?.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ) ??
        const <String, String>{};
    _compatCtrl = TextEditingController(text: compatibility);
    _oemCtrl = TextEditingController(text: specs['OEM Number'] ?? '');
    _materialCtrl = TextEditingController(text: specs['Material'] ?? '');
    _threadCtrl = TextEditingController(text: specs['Thread Size'] ?? '');
    _weightCtrl = TextEditingController(text: specs['Weight'] ?? '');
    _dimensionsCtrl = TextEditingController(text: specs['Dimensions'] ?? '');
    _colorCtrl = TextEditingController(text: specs['Color / Finish'] ?? '');
    _mfgNameCtrl = TextEditingController(text: specs['Manufacturer'] ?? '');
    _mfgCountryCtrl = TextEditingController(text: specs['Country'] ?? '');
    _mfgPartNoCtrl = TextEditingController(text: specs['Mfg Part No'] ?? '');
    _warrantyCtrl = TextEditingController(text: specs['Warranty'] ?? '');
    _certCtrl = TextEditingController(text: specs['Certifications'] ?? '');
    _hsnCtrl = TextEditingController(
        text: specs['HSN Code (N)'] ??
            specs['HS Code'] ??
            specs['HSN Code'] ??
            '');
    _priceCtrl.addListener(() => setState(() {}));
    _mrpCtrl.addListener(() => setState(() {}));

    // Seed the gallery from image_urls (preferred) or fall back to the
    // single legacy image_url field so older products still show their image.
    final urls =
        (p['image_urls'] as List?)?.whereType<String>().toList() ?? const [];
    if (urls.isNotEmpty) {
      _images.addAll(urls.map(_EditImageItem.existing));
    } else {
      final legacy = p['image_url'] as String?;
      if (legacy != null && legacy.startsWith('http')) {
        _images.add(_EditImageItem.existing(legacy));
      }
    }
  }

  double? get _discountPercent {
    final price = double.tryParse(_priceCtrl.text.trim());
    final mrp = double.tryParse(_mrpCtrl.text.trim());
    if (price == null || mrp == null || mrp <= 0 || price >= mrp) return null;
    return ((mrp - price) / mrp) * 100;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _priceCtrl.dispose();
    _mrpCtrl.dispose();
    _stockCtrl.dispose();
    _descCtrl.dispose();
    _badgeCtrl.dispose();
    _compatCtrl.dispose();
    _oemCtrl.dispose();
    _materialCtrl.dispose();
    _threadCtrl.dispose();
    _weightCtrl.dispose();
    _dimensionsCtrl.dispose();
    _colorCtrl.dispose();
    _mfgNameCtrl.dispose();
    _mfgCountryCtrl.dispose();
    _mfgPartNoCtrl.dispose();
    _warrantyCtrl.dispose();
    _certCtrl.dispose();
    _hsnCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 images allowed')),
      );
      return;
    }
    final picker = ImagePicker();
    final remaining = _maxImages - _images.length;
    final picked =
        await picker.pickMultiImage(imageQuality: 85, limit: remaining);
    for (final f in picked) {
      final bytes = await f.readAsBytes();
      setState(() => _images.add(_EditImageItem.newImage(bytes, f.name)));
    }
  }

  void _removeImage(int idx) => setState(() => _images.removeAt(idx));

  void _reorderImages(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _images.removeAt(oldIdx);
      _images.insert(newIdx, item);
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final category = _categoryCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim());
    final stock = int.tryParse(_stockCtrl.text.trim());
    if (name.isEmpty || category.isEmpty || price == null || stock == null) {
      setState(() => _error = 'Name, Category, Price and Stock are required.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final safeName = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final imageUrls = <String>[];
      for (int i = 0; i < _images.length; i++) {
        final item = _images[i];
        if (item.url != null) {
          imageUrls.add(item.url!);
        } else {
          final ext = item.fileName!.contains('.')
              ? item.fileName!.split('.').last
              : 'jpg';
          final fileName =
              '${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? 'product' : safeName}_$i.$ext';
          final url = await SupabaseService.uploadProductImageBytes(
              bytes: item.bytes!, fileName: fileName);
          imageUrls.add(url);
        }
      }
      final compatibility = _compatCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final specs = <String, String>{
        if (_oemCtrl.text.trim().isNotEmpty) 'OEM Number': _oemCtrl.text.trim(),
        if (_materialCtrl.text.trim().isNotEmpty)
          'Material': _materialCtrl.text.trim(),
        if (_threadCtrl.text.trim().isNotEmpty)
          'Thread Size': _threadCtrl.text.trim(),
        if (_weightCtrl.text.trim().isNotEmpty)
          'Weight': _weightCtrl.text.trim(),
        if (_dimensionsCtrl.text.trim().isNotEmpty)
          'Dimensions': _dimensionsCtrl.text.trim(),
        if (_colorCtrl.text.trim().isNotEmpty)
          'Color / Finish': _colorCtrl.text.trim(),
        if (_mfgNameCtrl.text.trim().isNotEmpty)
          'Manufacturer': _mfgNameCtrl.text.trim(),
        if (_mfgCountryCtrl.text.trim().isNotEmpty)
          'Country': _mfgCountryCtrl.text.trim(),
        if (_mfgPartNoCtrl.text.trim().isNotEmpty)
          'Mfg Part No': _mfgPartNoCtrl.text.trim(),
        if (_warrantyCtrl.text.trim().isNotEmpty)
          'Warranty': _warrantyCtrl.text.trim(),
        if (_certCtrl.text.trim().isNotEmpty)
          'Certifications': _certCtrl.text.trim(),
        if (_hsnCtrl.text.trim().isNotEmpty)
          'HSN Code (N)': _hsnCtrl.text.trim(),
      };
      final updates = <String, dynamic>{
        'name': name,
        'category': category,
        'price': price,
        'stock': stock,
        'description': _descCtrl.text.trim(),
        'badge': _badgeCtrl.text.trim(),
        'compatibility': compatibility,
        'specs': specs,
        if (_mrpCtrl.text.trim().isNotEmpty)
          'mrp': double.tryParse(_mrpCtrl.text.trim()),
        'image_urls': imageUrls,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : '',
      };
      await SupabaseService.updateProduct(
          widget.product['id'] as String, updates);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Save failed: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF8FAFD),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxWidth: 480, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
              decoration: const BoxDecoration(
                color: AppPalette.navy,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Edit Product',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 15)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context, false),
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PRODUCT IMAGES (${_images.length}/$_maxImages)',
                        style: const TextStyle(
                            color: Color(0xFF4E6070),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .8)),
                    const SizedBox(height: 4),
                    const Text(
                        'First image is the cover image. Drag to reorder.',
                        style:
                            TextStyle(color: Color(0xFF9CA8B4), fontSize: 10)),
                    const SizedBox(height: 10),
                    if (_images.isNotEmpty)
                      SizedBox(
                        height: 100,
                        child: ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _images.length,
                          onReorder: _reorderImages,
                          buildDefaultDragHandles: false,
                          itemBuilder: (_, idx) {
                            final item = _images[idx];
                            return ReorderableDragStartListener(
                              key:
                                  ValueKey('${item.url ?? item.fileName}-$idx'),
                              index: idx,
                              child: Stack(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10),
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: idx == 0
                                          ? Border.all(
                                              color: AppPalette.cyan, width: 2)
                                          : Border.all(
                                              color: const Color(0xFFE0E8F0)),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: item.url != null
                                          ? Image.network(item.url!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.image_outlined,
                                                      color: AppPalette.muted,
                                                      size: 28))
                                          : Image.memory(item.bytes!,
                                              fit: BoxFit.cover),
                                    ),
                                  ),
                                  if (idx == 0)
                                    Positioned(
                                      bottom: 6,
                                      left: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: AppPalette.cyan,
                                            borderRadius:
                                                BorderRadius.circular(3)),
                                        child: const Text('COVER',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 7,
                                                fontWeight: FontWeight.w900)),
                                      ),
                                    ),
                                  Positioned(
                                    top: 4,
                                    right: 14,
                                    child: GestureDetector(
                                      onTap: () => _removeImage(idx),
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                            color: AppPalette.danger,
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 10),
                    if (_images.length < _maxImages)
                      GestureDetector(
                        onTap: _pickImages,
                        child: Container(
                          width: double.infinity,
                          height: _images.isEmpty ? 110 : 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8EDF4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: const Color(0xFFCED8E6), width: 1.5),
                          ),
                          child: _images.isEmpty
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate_outlined,
                                        color: AppPalette.muted, size: 30),
                                    SizedBox(height: 6),
                                    Text('Tap to upload images',
                                        style: TextStyle(
                                            color: AppPalette.muted,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 16,
                                        color: AppPalette.navy),
                                    const SizedBox(width: 8),
                                    Text(
                                        'Add more images (${_images.length}/$_maxImages)',
                                        style: const TextStyle(
                                            color: AppPalette.navy,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _EditField(label: 'Product Name *', controller: _nameCtrl),
                    const SizedBox(height: 12),
                    _EditCategoryField(controller: _categoryCtrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Price (₹) *',
                                controller: _priceCtrl,
                                keyboard: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'MRP (₹)',
                                controller: _mrpCtrl,
                                keyboard: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_discountPercent != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: const Color(0xFFEEFFF4),
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(
                            '${_discountPercent!.toStringAsFixed(0)}% OFF MRP',
                            style: const TextStyle(
                                color: AppPalette.success,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Stock *',
                                controller: _stockCtrl,
                                keyboard: TextInputType.number)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'Badge',
                                controller: _badgeCtrl,
                                hint: 'e.g. OEM, New')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                        label: 'Description',
                        controller: _descCtrl,
                        maxLines: 3),
                    const SizedBox(height: 12),
                    _EditField(
                      label: 'Compatibility',
                      controller: _compatCtrl,
                      hint: 'Comma separated vehicles',
                    ),
                    const SizedBox(height: 18),
                    const _EditSectionTitle('Specifications'),
                    const SizedBox(height: 10),
                    _EditField(label: 'OEM Number', controller: _oemCtrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Material', controller: _materialCtrl)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'Thread Size', controller: _threadCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Weight', controller: _weightCtrl)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'Dimensions',
                                controller: _dimensionsCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EditField(label: 'Color / Finish', controller: _colorCtrl),
                    const SizedBox(height: 18),
                    const _EditSectionTitle('Manufacturer'),
                    const SizedBox(height: 10),
                    _EditField(
                        label: 'Manufacturer Name', controller: _mfgNameCtrl),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Country / Origin',
                                controller: _mfgCountryCtrl)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'MFG Part Number',
                                controller: _mfgPartNoCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                            child: _EditField(
                                label: 'Warranty', controller: _warrantyCtrl)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _EditField(
                                label: 'HSN CODE (N)',
                                controller: _hsnCtrl,
                                keyboard: TextInputType.text)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _EditField(
                        label: 'Certifications',
                        controller: _certCtrl,
                        hint: 'ISO, BIS, ARAI Approved'),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppPalette.danger,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE2EAF2))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _loading ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppPalette.navy),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text('CANCEL',
                          style: TextStyle(
                              color: AppPalette.navy,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _loading ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppPalette.navy,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('SAVE CHANGES',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .8)),
                    ),
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

class _EditImageItem {
  _EditImageItem.existing(this.url)
      : bytes = null,
        fileName = null;
  _EditImageItem.newImage(this.bytes, this.fileName) : url = null;

  final String? url; // already-uploaded image
  final Uint8List? bytes; // newly picked, not yet uploaded
  final String? fileName;
}

class _EditSectionTitle extends StatelessWidget {
  const _EditSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppPalette.navy,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: .9,
      ),
    );
  }
}

class _EditCategoryField extends StatelessWidget {
  const _EditCategoryField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final choices = <String>{
      if (controller.text.trim().isNotEmpty) controller.text.trim(),
      ...productCategories,
    }.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Category *',
          style: TextStyle(
            color: Color(0xFF4E6070),
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue:
              controller.text.trim().isEmpty ? null : controller.text.trim(),
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Select category',
            filled: true,
            fillColor: const Color(0xFFEDF1F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppPalette.cyan),
            ),
          ),
          items: choices
              .map((category) => DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  ))
              .toList(),
          onChanged: (value) => controller.text = value ?? '',
        ),
      ],
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboard = TextInputType.text,
    this.maxLines = 1,
  });
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType keyboard;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF4E6070),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .8)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: maxLines,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF172635)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB4BEC8), fontSize: 12),
            filled: true,
            fillColor: const Color(0xFFEDF1F7),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: AppPalette.cyan)),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDE BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SideBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      color: const Color(0xFFF7FAFD),
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Catalog Admin',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 34),
          _SideItem(
              icon: Icons.dashboard_outlined,
              label: 'Dashboard',
              route: '/admin',
              selected: false),
          _SideItem(
              icon: Icons.tune,
              label: 'Add Part',
              route: '/admin/add-product',
              selected: false),
          _SideItem(
              icon: Icons.inventory_2_outlined,
              label: 'Inventory',
              route: '/admin/catalog',
              selected: true),
          _SideItem(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Admin',
              route: '/admin/profile',
              selected: false),
          const Spacer(),
          GestureDetector(
            onTap: () async {
              await SupabaseService.signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Row(
              children: [
                Icon(Icons.logout, size: 16, color: AppPalette.danger),
                SizedBox(width: 6),
                Text('Logout',
                    style: TextStyle(
                        color: AppPalette.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem(
      {required this.icon,
      required this.label,
      required this.route,
      required this.selected});
  final IconData icon;
  final String label, route;
  final bool selected;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final scaffold = Scaffold.maybeOf(context);
        if (scaffold?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        context.go(route);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color:
              selected ? AppPalette.navy.withOpacity(.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 16, color: selected ? AppPalette.navy : AppPalette.muted),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: selected ? AppPalette.navy : AppPalette.muted,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

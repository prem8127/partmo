import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/catalog_categories.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/product_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends ConsumerState<AddProductScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _formKey = GlobalKey<FormState>();
  final _categoryFieldKey = GlobalKey<_CategoryFieldState>();

  // Basic fields
  final _nameCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _badgeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _compatCtrl = TextEditingController();

  // Specs
  final _oemCtrl = TextEditingController();
  final _materialCtrl = TextEditingController();
  final _threadCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _dimensionsCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();

  // Manufacturer details
  final _mfgNameCtrl = TextEditingController();
  final _mfgCountryCtrl = TextEditingController();
  final _mfgPartNoCtrl = TextEditingController();
  final _warrantyCtrl = TextEditingController();
  final _certCtrl = TextEditingController();
  final _hsCodeCtrl = TextEditingController();

  // Multi-image support
  final List<_ImageEntry> _images = [];
  static const int _maxImages = 6;

  bool _loading = false;
  String? _error;
  String? _success;
  List<String> _availableCategories = productCategories;

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final products = await SupabaseService.fetchProducts();
      final categories = <String>{
        ...productCategories,
        for (final product in products)
          if ((product['category'] as String? ?? '').trim().isNotEmpty)
            canonicalProductCategory(product['category'] as String),
      }.toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      if (mounted) setState(() => _availableCategories = categories);
    } catch (_) {
      // Preset categories remain available if catalog loading fails.
    }
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _categoryCtrl,
      _priceCtrl,
      _mrpCtrl,
      _stockCtrl,
      _badgeCtrl,
      _descCtrl,
      _compatCtrl,
      _oemCtrl,
      _materialCtrl,
      _threadCtrl,
      _weightCtrl,
      _dimensionsCtrl,
      _colorCtrl,
      _mfgNameCtrl,
      _mfgCountryCtrl,
      _mfgPartNoCtrl,
      _warrantyCtrl,
      _certCtrl,
      _hsCodeCtrl,
    ]) c.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ── Pick image ─────────────────────────────────────────────────────────────
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
      setState(() => _images.add(_ImageEntry(bytes, f.name)));
    }
  }

  void _removeImage(int idx) {
    setState(() => _images.removeAt(idx));
  }

  void _reorderImages(int oldIdx, int newIdx) {
    setState(() {
      if (newIdx > oldIdx) newIdx--;
      final item = _images.removeAt(oldIdx);
      _images.insert(newIdx, item);
    });
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _error = 'Please fix the highlighted fields.');
      return;
    }
    final name = _nameCtrl.text.trim();
    final categoryInput = _categoryCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final mrp = double.tryParse(_mrpCtrl.text.trim()) ?? 0;
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final badge = _badgeCtrl.text.trim();
    final desc = _descCtrl.text.trim();
    final compat = _compatCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (name.isEmpty || categoryInput.isEmpty || price <= 0 || desc.isEmpty) {
      setState(
          () => _error = 'Name, category, price and description are required.');
      return;
    }

    final specs = <String, String>{
      if (_oemCtrl.text.trim().isNotEmpty) 'OEM Number': _oemCtrl.text.trim(),
      if (_materialCtrl.text.trim().isNotEmpty)
        'Material': _materialCtrl.text.trim(),
      if (_threadCtrl.text.trim().isNotEmpty)
        'Thread Size': _threadCtrl.text.trim(),
      if (_weightCtrl.text.trim().isNotEmpty) 'Weight': _weightCtrl.text.trim(),
      if (_dimensionsCtrl.text.trim().isNotEmpty)
        'Dimensions': _dimensionsCtrl.text.trim(),
      if (_colorCtrl.text.trim().isNotEmpty)
        'Color / Finish': _colorCtrl.text.trim(),
    };

    final mfg = <String, String>{
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
      if (_hsCodeCtrl.text.trim().isNotEmpty)
        'HS Code': _hsCodeCtrl.text.trim(),
    };

    setState(() {
      _loading = true;
      _error = null;
      _success = null;
    });

    try {
      final existingProducts = await SupabaseService.fetchProducts();
      final category = resolveProductCategory(
        categoryInput,
        existingProducts.map((product) => product['category'] as String? ?? ''),
      );
      final duplicate = existingProducts.any((product) =>
          normalizedProductName(product['name'] as String? ?? '') ==
              normalizedProductName(name) &&
          resolveProductCategory(
                  product['category'] as String? ?? '',
                  existingProducts
                      .map((item) => item['category'] as String? ?? '')) ==
              category);
      if (duplicate) {
        setState(() => _error =
            '"$name" already exists in $category. Edit the existing product instead.');
        return;
      }

      // Upload all images; first one is primary
      final safeName = name
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final imageUrls = <String>[];
      for (int i = 0; i < _images.length; i++) {
        final img = _images[i];
        final ext =
            img.fileName.contains('.') ? img.fileName.split('.').last : 'jpg';
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? 'product' : safeName}_$i.$ext';
        final url = await SupabaseService.uploadProductImageBytes(
            bytes: img.bytes, fileName: fileName);
        imageUrls.add(url);
      }

      await SupabaseService.insertProduct({
        'name': name,
        'category': category,
        'price': price,
        'mrp': mrp > 0 ? mrp : price,
        'stock': stock,
        'badge': badge,
        'description': desc,
        'image_url': imageUrls.isNotEmpty ? imageUrls.first : '',
        'image_urls': imageUrls,
        'compatibility': compat,
        'specs': {...specs, ...mfg},
      });
      ref.invalidate(productsStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('"$name" added to catalog'),
              backgroundColor: AppPalette.success),
        );
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) context.go('/admin/catalog');
      }
    } catch (e) {
      setState(() => _error = 'Failed to add product: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearAll() {
    for (final c in [
      _nameCtrl,
      _categoryCtrl,
      _priceCtrl,
      _mrpCtrl,
      _stockCtrl,
      _badgeCtrl,
      _descCtrl,
      _compatCtrl,
      _oemCtrl,
      _materialCtrl,
      _threadCtrl,
      _weightCtrl,
      _dimensionsCtrl,
      _colorCtrl,
      _mfgNameCtrl,
      _mfgCountryCtrl,
      _mfgPartNoCtrl,
      _warrantyCtrl,
      _certCtrl,
      _hsCodeCtrl,
    ]) c.clear();
    setState(() {
      _images.clear();
      _error = null;
      _success = null;
    });
    _categoryFieldKey.currentState?.reset();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Scaffold(
      key: _scaffoldKey,
      drawer: compact
          ? const Drawer(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shadowColor: Colors.black26,
              elevation: 18,
              child: _CatalogSideBar(),
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
              if (!compact) const _CatalogSideBar(),
              Expanded(
                child: Column(
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                          compact ? 12 : 24,
                          MediaQuery.paddingOf(context).top + 22,
                          compact ? 12 : 24,
                          0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Row(children: [
                              if (compact)
                                IconButton(
                                  onPressed: () =>
                                      _scaffoldKey.currentState?.openDrawer(),
                                  icon: const Icon(Icons.menu),
                                  tooltip: 'Admin menu',
                                ),
                              const SizedBox(width: 4),
                              const Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Add New Part',
                                          style: TextStyle(
                                              color: AppPalette.navy,
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900)),
                                      Text(
                                          'Fill details, upload images, save to catalog',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color: AppPalette.muted,
                                              fontSize: 11)),
                                    ]),
                              ),
                            ]),
                          ),
                          if (!compact)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                  color: AppPalette.navy,
                                  borderRadius: BorderRadius.circular(5)),
                              child: const Text('CATALOG ADMIN',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Tabs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8)),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppPalette.navy,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppPalette.navy,
                          unselectedLabelColor: AppPalette.muted,
                          labelStyle: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w900),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Basic Info'),
                            Tab(text: 'Specifications'),
                            Tab(text: 'Manufacturer'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Form body
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _BasicInfoTab(
                              images: _images,
                              maxImages: _maxImages,
                              onPickImages: _pickImages,
                              onRemoveImage: _removeImage,
                              onReorder: _reorderImages,
                              nameCtrl: _nameCtrl,
                              categoryCtrl: _categoryCtrl,
                              categoryFieldKey: _categoryFieldKey,
                              categories: _availableCategories,
                              priceCtrl: _priceCtrl,
                              mrpCtrl: _mrpCtrl,
                              stockCtrl: _stockCtrl,
                              badgeCtrl: _badgeCtrl,
                              descCtrl: _descCtrl,
                              compatCtrl: _compatCtrl,
                            ),
                            _SpecsTab(
                              oemCtrl: _oemCtrl,
                              materialCtrl: _materialCtrl,
                              threadCtrl: _threadCtrl,
                              weightCtrl: _weightCtrl,
                              dimensionsCtrl: _dimensionsCtrl,
                              colorCtrl: _colorCtrl,
                            ),
                            _ManufacturerTab(
                              mfgNameCtrl: _mfgNameCtrl,
                              mfgCountryCtrl: _mfgCountryCtrl,
                              mfgPartNoCtrl: _mfgPartNoCtrl,
                              warrantyCtrl: _warrantyCtrl,
                              certCtrl: _certCtrl,
                              hsCodeCtrl: _hsCodeCtrl,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Bottom actions
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                      child: Column(
                        children: [
                          if (_error != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFFFEEEE),
                                  borderRadius: BorderRadius.circular(5)),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppPalette.danger, fontSize: 12)),
                            ),
                          Row(children: [
                            SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: _clearAll,
                                style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: AppPalette.muted),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(5)),
                                ),
                                child: const Text('CLEAR',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: AppPalette.muted,
                                        letterSpacing: 1.5)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppPalette.navy,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5)),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Text('ADD TO CATALOG',
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.5)),
                                ),
                              ),
                            ),
                          ]),
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
  }
}

// ─── Image Entry ───────────────────────────────────────────────────────────────
class _ImageEntry {
  _ImageEntry(this.bytes, this.fileName);
  final Uint8List bytes;
  final String fileName;
}

// ─── Tab: Basic Info ──────────────────────────────────────────────────────────
class _BasicInfoTab extends StatelessWidget {
  const _BasicInfoTab({
    required this.images,
    required this.maxImages,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onReorder,
    required this.nameCtrl,
    required this.categoryCtrl,
    required this.categoryFieldKey,
    required this.categories,
    required this.priceCtrl,
    required this.mrpCtrl,
    required this.stockCtrl,
    required this.badgeCtrl,
    required this.descCtrl,
    required this.compatCtrl,
  });

  final List<_ImageEntry> images;
  final int maxImages;
  final VoidCallback onPickImages;
  final void Function(int) onRemoveImage;
  final void Function(int, int) onReorder;
  final TextEditingController nameCtrl,
      categoryCtrl,
      priceCtrl,
      mrpCtrl,
      stockCtrl,
      badgeCtrl,
      descCtrl,
      compatCtrl;
  final List<String> categories;
  final GlobalKey<_CategoryFieldState> categoryFieldKey;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ]),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Multi-image section
            const Text('PRODUCT IMAGES',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
            const SizedBox(height: 4),
            Text(
              'Upload up to $maxImages images. First image is the primary/cover image. Drag to reorder.',
              style: const TextStyle(color: Color(0xFF9CA8B4), fontSize: 10),
            ),
            const SizedBox(height: 12),

            // Image grid
            if (images.isNotEmpty) ...[
              SizedBox(
                height: 110,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  onReorder: onReorder,
                  buildDefaultDragHandles: false,
                  itemBuilder: (_, idx) {
                    return ReorderableDragStartListener(
                      key: ValueKey(idx),
                      index: idx,
                      child: Stack(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 10),
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: idx == 0
                                  ? Border.all(color: AppPalette.cyan, width: 2)
                                  : Border.all(color: const Color(0xFFE0E8F0)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.memory(images[idx].bytes,
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
                                    borderRadius: BorderRadius.circular(3)),
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
                              onTap: () => onRemoveImage(idx),
                              child: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                    color: AppPalette.danger,
                                    borderRadius: BorderRadius.circular(11)),
                                child: const Icon(Icons.close,
                                    color: Colors.white, size: 13),
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
            ],

            // Add images button
            if (images.length < maxImages)
              GestureDetector(
                onTap: onPickImages,
                child: Container(
                  width: double.infinity,
                  height: images.isEmpty ? 140 : 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppPalette.cyan.withOpacity(.4)),
                  ),
                  child: images.isEmpty
                      ? const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              Icon(Icons.add_photo_alternate_outlined,
                                  size: 36, color: AppPalette.cyan),
                              SizedBox(height: 8),
                              Text('Tap to upload product images',
                                  style: TextStyle(
                                      color: AppPalette.muted,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                              Text('Up to 6 images • JPG, PNG',
                                  style: TextStyle(
                                      color: Color(0xFFB0BBC6), fontSize: 10)),
                            ])
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                              const Icon(Icons.add_photo_alternate_outlined,
                                  size: 18, color: AppPalette.cyan),
                              const SizedBox(width: 8),
                              Text(
                                  'Add more images (${images.length}/$maxImages)',
                                  style: const TextStyle(
                                      color: AppPalette.cyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ]),
                ),
              ),

            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE8EFF5)),
            const SizedBox(height: 16),

            const Text('PART INFORMATION',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
            const SizedBox(height: 16),

            _F('PART NAME *', 'e.g. Oil Filter for MG Hector', nameCtrl,
                required: true),
            const SizedBox(height: 14),
            _CategoryField(
                key: categoryFieldKey,
                controller: categoryCtrl,
                categories: categories),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _F('SELLING PRICE ₹ *', '750', priceCtrl,
                      type: TextInputType.number, validator: (v) {
                final p = double.tryParse((v ?? '').trim());
                return (p == null || p <= 0) ? 'Enter valid price' : null;
              })),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _F('MRP ₹', '950', mrpCtrl, type: TextInputType.number)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _F('STOCK QTY', '42', stockCtrl,
                      type: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _F('BADGE', 'Best Seller', badgeCtrl)),
            ]),
            const SizedBox(height: 14),
            _F('DESCRIPTION *', 'Exact product description shown in catalog...',
                descCtrl,
                maxLines: 4, required: true),
            const SizedBox(height: 14),
            _F('COMPATIBILITY', 'MG Hector (2019-2024), MG Hector Plus',
                compatCtrl,
                maxLines: 2),
          ]),
        ),
      ],
    );
  }
}

// ─── Tab: Specifications ──────────────────────────────────────────────────────
class _SpecsTab extends StatelessWidget {
  const _SpecsTab({
    required this.oemCtrl,
    required this.materialCtrl,
    required this.threadCtrl,
    required this.weightCtrl,
    required this.dimensionsCtrl,
    required this.colorCtrl,
  });

  final TextEditingController oemCtrl,
      materialCtrl,
      threadCtrl,
      weightCtrl,
      dimensionsCtrl,
      colorCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ]),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TECHNICAL SPECIFICATIONS',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
            const SizedBox(height: 4),
            const Text('These appear in the product detail specs table.',
                style: TextStyle(color: Color(0xFF9CA8B4), fontSize: 10)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _F('OEM NUMBER', 'MG-44092-2023-F', oemCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _F('MATERIAL', 'Synthetic blend / Steel', materialCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _F('THREAD SIZE', '3/4"-16 UNF', threadCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _F('WEIGHT', '250g / 0.55 lbs', weightCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _F('DIMENSIONS', 'L×W×H in mm', dimensionsCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  child: _F('COLOR / FINISH', 'Black anodized', colorCtrl)),
            ]),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(6)),
              child: const Row(children: [
                Icon(Icons.info_outline, size: 16, color: AppPalette.cyan),
                SizedBox(width: 10),
                Expanded(
                    child: Text(
                        'All spec fields are optional. Only filled fields are shown to customers.',
                        style:
                            TextStyle(color: AppPalette.muted, fontSize: 11))),
              ]),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── Tab: Manufacturer ────────────────────────────────────────────────────────
class _ManufacturerTab extends StatelessWidget {
  const _ManufacturerTab({
    required this.mfgNameCtrl,
    required this.mfgCountryCtrl,
    required this.mfgPartNoCtrl,
    required this.warrantyCtrl,
    required this.certCtrl,
    required this.hsCodeCtrl,
  });

  final TextEditingController mfgNameCtrl,
      mfgCountryCtrl,
      mfgPartNoCtrl,
      warrantyCtrl,
      certCtrl,
      hsCodeCtrl;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      children: [
        Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x10000000),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ]),
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('MANUFACTURER & COMPLIANCE',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4)),
            const SizedBox(height: 4),
            const Text('Source, compliance and traceability information.',
                style: TextStyle(color: Color(0xFF9CA8B4), fontSize: 10)),
            const SizedBox(height: 18),
            _F('MANUFACTURER NAME', 'e.g. Bosch, Denso, TATA AutoComp',
                mfgNameCtrl),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _F('COUNTRY OF ORIGIN', 'India / Germany / Japan',
                      mfgCountryCtrl)),
              const SizedBox(width: 12),
              Expanded(
                  child: _F('MFG PART NUMBER', 'BN-0001-X', mfgPartNoCtrl)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                  child: _F('WARRANTY', '6 months / 1 year', warrantyCtrl)),
              const SizedBox(width: 12),
              Expanded(child: _F('HS CODE', '8708.99.10', hsCodeCtrl)),
            ]),
            const SizedBox(height: 14),
            _F('CERTIFICATIONS', 'ISO 9001, BIS, ARAI Approved', certCtrl,
                maxLines: 2),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(6)),
              child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.verified_outlined,
                          size: 16, color: AppPalette.success),
                      SizedBox(width: 8),
                      Text('Trust signals',
                          style: TextStyle(
                              color: AppPalette.navy,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                    ]),
                    SizedBox(height: 6),
                    Text(
                        'Manufacturer name, warranty, and certifications are displayed as trust badges on the product detail page to boost customer confidence.',
                        style: TextStyle(
                            color: AppPalette.muted,
                            fontSize: 10,
                            height: 1.5)),
                  ]),
            ),
          ]),
        ),
      ],
    );
  }
}

// ─── Shared form field ─────────────────────────────────────────────────────────
class _CategoryField extends StatefulWidget {
  const _CategoryField({
    super.key,
    required this.controller,
    required this.categories,
  });

  final TextEditingController controller;
  final List<String> categories;

  @override
  State<_CategoryField> createState() => _CategoryFieldState();
}

class _CategoryFieldState extends State<_CategoryField> {
  static const _newCategoryValue = '__new_category__';
  String? _selected;
  bool _isNew = false;

  void reset() => setState(() {
        _selected = null;
        _isNew = false;
      });

  @override
  Widget build(BuildContext context) {
    final categories = widget.categories.toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CATEGORY *',
          style: TextStyle(
            color: Color(0xFF4E6070),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selected,
          isExpanded: true,
          validator: (value) =>
              !_isNew && value == null ? 'Select a category' : null,
          decoration: InputDecoration(
            hintText: 'Select product category',
            filled: true,
            fillColor: const Color(0xFFF4F7FB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Color(0xFFE0E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Color(0xFFE0E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppPalette.cyan),
            ),
          ),
          items: [
            ...categories.map((category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                )),
            const DropdownMenuItem(
              value: _newCategoryValue,
              child: Text('+ New category',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selected = value;
              _isNew = value == _newCategoryValue;
              widget.controller.text = _isNew ? '' : value ?? '';
            });
          },
        ),
        if (_isNew) ...[
          const SizedBox(height: 10),
          TextFormField(
            controller: widget.controller,
            autofocus: true,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter the new category name'
                : null,
            decoration: InputDecoration(
              labelText: 'New category name',
              helperText:
                  'Matching names are merged into the existing category.',
              filled: true,
              fillColor: const Color(0xFFF4F7FB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: Color(0xFFE0E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(5),
                borderSide: const BorderSide(color: AppPalette.cyan),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _F extends StatelessWidget {
  const _F(this.label, this.hint, this.controller,
      {this.type = TextInputType.text,
      this.maxLines = 1,
      this.required = false,
      this.validator});
  final String label, hint;
  final TextEditingController controller;
  final TextInputType type;
  final int maxLines;
  final bool required;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              color: Color(0xFF4E6070),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4)),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        keyboardType: type,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFB4BEC8), fontSize: 12),
          filled: true,
          fillColor: const Color(0xFFF4F7FB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Color(0xFFE0E8F0))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: Color(0xFFE0E8F0))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppPalette.cyan)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide: const BorderSide(color: AppPalette.danger)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(5),
              borderSide:
                  const BorderSide(color: AppPalette.danger, width: 1.4)),
          errorStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        ),
      ),
    ]);
  }
}

// ─── Sidebar ───────────────────────────────────────────────────────────────────
class _CatalogSideBar extends StatelessWidget {
  const _CatalogSideBar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      color: const Color(0xFFF7FAFD),
      padding: EdgeInsets.fromLTRB(
          18, MediaQuery.paddingOf(context).top + 28, 18, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Catalog Admin',
            style: TextStyle(
                color: AppPalette.navy,
                fontSize: 14,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 34),
        const _SideItem(
            icon: Icons.dashboard_outlined,
            label: 'Dashboard',
            route: '/admin'),
        const _SideItem(
            icon: Icons.bar_chart,
            label: 'Analytics',
            route: '/admin/analytics'),
        const _SideItem(
            icon: Icons.tune,
            label: 'Add Part',
            selected: true,
            route: '/admin/add-product'),
        const _SideItem(
            icon: Icons.inventory_2_outlined,
            label: 'Inventory',
            route: '/admin/catalog'),
        const _SideItem(
            icon: Icons.admin_panel_settings_outlined,
            label: 'Admin',
            route: '/admin/profile'),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await SupabaseService.signOut();
            if (context.mounted) context.go('/login');
          },
          child: const Row(children: [
            Icon(Icons.logout, size: 16, color: AppPalette.danger),
            SizedBox(width: 6),
            Text('Logout',
                style: TextStyle(
                    color: AppPalette.danger,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
      ]),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem(
      {required this.icon,
      required this.label,
      required this.route,
      this.selected = false});
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
        child: Row(children: [
          Icon(icon,
              size: 16, color: selected ? AppPalette.navy : AppPalette.muted),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: selected ? AppPalette.navy : AppPalette.muted,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600)),
        ]),
      ),
    );
  }
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/search/filters_screen.dart';
import '../../providers/cart_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/product_card.dart';
import '../../widgets/wishlist_button.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = SupabaseService.isAdmin;

    return WebShell(
      selectedIndex: 0,
      backgroundColor: const Color(0xFFF3F6FA),
      drawer: const EngineeringCatalogDrawer(),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'whatsapp_fab',
            backgroundColor: const Color(0xFF25D366),
            onPressed: () => _showProductEnquirySheet(context),
            tooltip: 'Help or product enquiry',
            icon: const Icon(
              Icons.support_agent,
              color: Colors.white,
              size: 22,
            ),
            label: const Text(
              'PRODUCT ENQUIRY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (isAdmin) ...[
            const SizedBox(height: 12),
            FloatingActionButton(
              heroTag: 'admin_fab',
              mini: true,
              backgroundColor: AppPalette.navy,
              onPressed: () => context.go('/admin'),
              tooltip: 'Admin Panel',
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ],
      ),
      child: Builder(
        builder: (context) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
            child: ListView(
              padding: EdgeInsets.zero,
              children: const [
                _LandingHeader(),
                _PromoBanner(), // ← NEW: promo banner ABOVE search
                _VehicleSearchBlock(),
                _HeroBanner(),
                _TrustBadges(),
                _TopRatedProducts(), // ← NEW: top 2 rated catalog products, ABOVE Discover
                _CategorySection(),
                _BrandsSection(),
                _ArticlesSection(),
                _WhySection(),
                _StoriesSection(),
                _SellWithUsSection(),
                _LandingFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProductEnquirySheet(BuildContext context) {
    if (!SupabaseService.isLoggedIn) {
      context.go('/login?return=/home');
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _ProductEnquirySheet(),
    );
  }
}

class _ProductEnquirySheet extends StatefulWidget {
  const _ProductEnquirySheet();

  @override
  State<_ProductEnquirySheet> createState() => _ProductEnquirySheetState();
}

class _ProductEnquirySheetState extends State<_ProductEnquirySheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _sending = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageName = picked.name;
    });
  }

  Future<void> _submit() async {
    final description = _descriptionCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name, phone and details.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_imageBytes != null) {
        imageUrl = await SupabaseService.uploadProductEnquiryImageBytes(
          bytes: _imageBytes!,
          fileName: _imageName ?? 'enquiry.jpg',
        );
      }
      final user = SupabaseService.currentUser;
      await SupabaseService.createProductEnquiry(
        description: description,
        customerName: name,
        customerPhone: phone,
        customerEmail: user?.email ?? '',
        imageUrl: imageUrl,
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product enquiry sent to admin.'),
          backgroundColor: AppPalette.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send enquiry: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 18, 18, bottom + 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Product Enquiry',
                    style: TextStyle(
                      color: AppPalette.navy,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _sending ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Phone / WhatsApp number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sending ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(_imageName == null ? 'Add photo' : 'Change photo'),
            ),
            if (_imageBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.memory(
                  _imageBytes!,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionCtrl,
              minLines: 4,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText:
                    'Tell us the part name, vehicle model, issue, or requirement',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_sending ? 'Sending...' : 'Send Enquiry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER
// ═══════════════════════════════════════════════════════════════════════════

class _LandingHeader extends ConsumerWidget {
  const _LandingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // On desktop, WebShell's own top bar already has the logo + nav + cart —
    // this mobile-style mini header would just duplicate it.
    if (!Responsive.isMobile(context)) return const SizedBox.shrink();
    final cartCount = ref
        .watch(cartProvider)
        .fold<int>(0, (sum, item) => sum + item.quantity);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        12,
        MediaQuery.paddingOf(context).top + 12,
        12,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: AppPalette.navy, size: 21),
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 2),
          const Text(
            'PARTMO',
            style: TextStyle(
              color: AppPalette.navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -.7,
            ),
          ),
          const Spacer(),
          const WishlistButton(),
          IconButton(
            onPressed: () => context.push('/cart'),
            icon: Badge(
              isLabelVisible: cartCount > 0,
              label: Text(
                '$cartCount',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              backgroundColor: AppPalette.danger,
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: AppPalette.navy,
                size: 22,
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PROMO BANNER  — NEW, placed above search
// ═══════════════════════════════════════════════════════════════════════════

class _PromoBanner extends StatefulWidget {
  const _PromoBanner();

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final slideCount = _currentSlideCount;
      if (slideCount < 2) return;
      _controller.animateToPage(
        (_page + 1) % slideCount,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  int _currentSlideCount = 3;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.fetchBanners(placement: 'top'),
      builder: (context, snapshot) {
        final slides = (snapshot.data == null || snapshot.data!.isEmpty)
            ? _fallbackPromoSlides
            : snapshot.data!;
        _currentSlideCount = slides.length;
        return _PromoBannerView(
          controller: _controller,
          page: _page,
          slides: slides,
          onPageChanged: (value) => setState(() => _page = value),
        );
      },
    );
  }
}

class _PromoBannerView extends StatelessWidget {
  const _PromoBannerView({
    required this.controller,
    required this.page,
    required this.slides,
    required this.onPageChanged,
  });

  final PageController controller;
  final int page;
  final List<Map<String, dynamic>> slides;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          SizedBox(
            height: 128,
            child: PageView(
              controller: controller,
              onPageChanged: onPageChanged,
              children: [for (final slide in slides) _PromoSlide(data: slide)],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: page == i
                        ? AppPalette.navy
                        : AppPalette.navy.withOpacity(.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PromoSlide extends StatelessWidget {
  const _PromoSlide({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Up to 30% OFF';
    final subtitle = data['subtitle']?.toString() ?? 'on Engine Parts';
    final badge = data['badge']?.toString() ?? 'LIMITED TIME';
    final cta = data['cta_label']?.toString() ?? 'SHOP NOW';
    final imageUrl = data['image_url']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(7),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl.isNotEmpty)
            imageUrl.startsWith('http')
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const SizedBox.shrink();
                    },
                  )
                : Image.asset(imageUrl, fit: BoxFit.cover),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppPalette.navy.withOpacity(.96),
                  AppPalette.navy.withOpacity(imageUrl.isEmpty ? .76 : .36),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
          ),
          Positioned(
            right: -8,
            top: -16,
            child: Icon(
              Icons.settings,
              color: Colors.white.withOpacity(.08),
              size: 122,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC400),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          badge.toUpperCase(),
                          style: const TextStyle(
                            color: AppPalette.navy,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '$title\n$subtitle',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.go('/catalog'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFC400),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cta.toUpperCase(),
                      style: const TextStyle(
                        color: AppPalette.navy,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _fallbackPromoSlides = [
  {
    'badge': 'LIMITED TIME',
    'title': 'Up to 30% OFF',
    'subtitle': 'on Engine Parts',
    'cta_label': 'Shop Now',
    'image_url': '',
  },
  {
    'badge': 'GARAGE SALE',
    'title': 'Genuine parts',
    'subtitle': 'garage big sale',
    'cta_label': 'Shop Now',
    'image_url': 'assets/promo/promo_1.jpg',
  },
  {
    'badge': 'FAST DELIVERY',
    'title': 'Packed and shipped',
    'subtitle': 'with live order tracking',
    'cta_label': 'Browse',
    'image_url': 'assets/promo/promo_2.jpg',
  },
];

// ═══════════════════════════════════════════════════════════════════════════
// VEHICLE SEARCH BLOCK
// ═══════════════════════════════════════════════════════════════════════════

class _VehicleSearchBlock extends StatelessWidget {
  const _VehicleSearchBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(
                Icons.directions_car_outlined,
                color: AppPalette.navy,
                size: 22,
              ),
              SizedBox(width: 8),
              Text(
                'VEHICLE SEARCH',
                style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .5,
                ),
              ),
              Spacer(),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppPalette.warning,
                  borderRadius: BorderRadius.all(Radius.circular(20)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    'COMING SOON',
                    style: TextStyle(
                      color: AppPalette.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: _LightInput(text: 'MH 12 AB 1234 / VIN')),
              const SizedBox(width: 10),
              SizedBox(
                width: 116,
                height: 48,
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.navy,
                    disabledBackgroundColor: AppPalette.navy,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'SEARCH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: _VehicleChoice(label: 'Select Maker')),
              SizedBox(width: 10),
              Expanded(child: _VehicleChoice(label: 'Model')),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Expanded(child: _VehicleChoice(label: 'Year')),
              SizedBox(width: 10),
              Expanded(child: _VehicleChoice(label: 'Modification')),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => context.go('/search'),
                  child: Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFFDCE5ED)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 16),
                            child: Text(
                              'Part Name / Number / Brand',
                              style: TextStyle(
                                color: Color(0xFF647789),
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 45,
                          height: 45,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: AppPalette.navy,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final filters = await context.push<FilterData>('/filters');
                  if (context.mounted && filters != null) {
                    context.go('/search', extra: filters);
                  }
                },
                borderRadius: BorderRadius.circular(5),
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: const Color(0xFFDCE5ED)),
                  ),
                  child: const Icon(
                    Icons.tune,
                    color: AppPalette.navy,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HIGHLIGHTED CATALOGS  — NEW, placed below search
// ═══════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════
// SHARED INPUT WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _LightInput extends StatelessWidget {
  const _LightInput({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F4F8),
        borderRadius: BorderRadius.circular(5),
      ),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF7D8D9B),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _VehicleChoice extends StatelessWidget {
  const _VehicleChoice({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      label: '$label, coming soon',
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppPalette.navy,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBFD0DE),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF79A0BD),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO BANNER
// ═══════════════════════════════════════════════════════════════════════════

class _HeroBanner extends StatefulWidget {
  const _HeroBanner();

  @override
  State<_HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<_HeroBanner> {
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;
  static const _slideCount = 3;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _slideCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onUserInteraction() {
    _timer?.cancel();
    Future.delayed(const Duration(seconds: 6), () {
      if (mounted) _startAutoSlide();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.fetchBanners(placement: 'middle'),
      builder: (context, snapshot) {
        final customSlides = snapshot.data ?? const <Map<String, dynamic>>[];
        final slideCount =
            customSlides.isEmpty ? _slideCount : customSlides.length;
        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            children: [
              SizedBox(
                height: 160,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n is ScrollStartNotification && n.dragDetails != null) {
                      _onUserInteraction();
                    }
                    return false;
                  },
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: customSlides.isEmpty
                        ? const [
                            _HeroSlideBrand(),
                            _HeroSlidePhoto(
                              imageAsset: 'assets/promo/promo_1.jpg',
                              badge: '30% OFF',
                              heading: 'Genuine parts\ngarage big sale',
                              ctaLabel: 'SHOP NOW',
                            ),
                            _HeroSlidePhoto(
                              imageAsset: 'assets/promo/promo_2.jpg',
                              badge: 'UP TO 50% OFF',
                              heading: 'Book a full\nservice today',
                              ctaLabel: 'BOOK NOW',
                            ),
                          ]
                        : [
                            for (final slide in customSlides)
                              _PromoSlide(data: slide),
                          ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < slideCount; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: _page == i ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppPalette.navy
                            : AppPalette.navy.withOpacity(.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroSlideBrand extends StatelessWidget {
  const _HeroSlideBrand();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 12, 18),
      decoration: BoxDecoration(
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            bottom: -18,
            child: Transform.rotate(
              angle: .2,
              child: Icon(
                Icons.directions_car_filled,
                color: Colors.white.withOpacity(.20),
                size: 122,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Find the right parts,\nfaster than ever, delivered\nwithin an hour',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC400),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.directions_car,
                      color: AppPalette.navy,
                      size: 15,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'ADD TO MY GARAGE',
                      style: TextStyle(
                        color: AppPalette.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroSlidePhoto extends StatelessWidget {
  const _HeroSlidePhoto({
    required this.imageAsset,
    required this.badge,
    required this.heading,
    required this.ctaLabel,
  });
  final String imageAsset;
  final String badge;
  final String heading;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(7),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            imageAsset,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: AppPalette.navy),
          ),
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xE60A2540), Color(0x330A2540)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                stops: [0.0, 0.85],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 12, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC400),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: AppPalette.navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .6,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  heading,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.go('/catalog'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      ctaLabel,
                      style: const TextStyle(
                        color: AppPalette.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TRUST BADGES
// ═══════════════════════════════════════════════════════════════════════════

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
      child: const Row(
        children: [
          Expanded(
            child: _TrustBadge(
              icon: Icons.local_shipping,
              label: 'FREE DELIVERY',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _TrustBadge(icon: Icons.verified, label: 'AUTHENTIC'),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _TrustBadge(
              icon: Icons.currency_rupee,
              label: 'BEST PRICES',
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppPalette.navy, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF223241),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TOP RATED PRODUCTS — NEW, placed above DISCOVER / Browse by Category
// Pulls live data from catalogProvider, shows the 2 highest-rated items.
// ═══════════════════════════════════════════════════════════════════════════

class _TopRatedProducts extends ConsumerWidget {
  const _TopRatedProducts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider);
    if (catalog.isEmpty) return const SizedBox.shrink();

    final sorted = [...catalog]..sort((a, b) => b.rating.compareTo(a.rating));
    final highlighted = sorted.take(2).toList();
    final desktop = !Responsive.isMobile(context);

    return _SectionShell(
      topPadding: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP RATED',
            style: TextStyle(
              color: AppPalette.navy,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text('Highly Rated Parts', style: _sectionHeadingStyle),
              ),
              TextButton(
                onPressed: () => context.go('/search'),
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: Color(0xFF008A9E),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              for (int i = 0; i < highlighted.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: desktop
                      ? SizedBox(
                          height: 340,
                          child: ProductCard(product: highlighted[i]),
                        )
                      : AspectRatio(
                          aspectRatio: .72,
                          child: ProductCard(product: highlighted[i]),
                        ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CATEGORY SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _CategorySection extends StatefulWidget {
  const _CategorySection();

  static const items = [
    (Icons.open_in_full, 'ENGINE', 'assets/categories/engine.png'),
    (Icons.settings, 'STEERING', 'assets/categories/steering.png'),
    (Icons.album, 'BRAKES', 'assets/categories/brakes.png'),
    (Icons.height, 'SUSPENSION', 'assets/categories/suspension.png'),
    (Icons.flash_on, 'ELECTRICAL', 'assets/categories/electrical.png'),
    (
      Icons.settings_input_component,
      'GEAR PARTS',
      'assets/categories/gear_parts.png',
    ),
    (Icons.linear_scale, 'AXLE', 'assets/categories/axle.png'),
    (Icons.view_column, 'FRAMES', 'assets/categories/frames.png'),
    (
      Icons.ac_unit,
      'RADIATOR &\nINTERCOOLER',
      'assets/categories/radiator_intercooler.png',
    ),
    (
      Icons.water_drop,
      'AUTOMOTIVE\nFLUIDS',
      'assets/categories/automotive_fluids.png',
    ),
    (
      Icons.local_gas_station,
      'FUEL SYSTEM',
      'assets/categories/fuel_system.png',
    ),
    (
      Icons.circle,
      'OIL SEALS &\nRUBBER PARTS',
      'assets/categories/oil_seals_rubber.png',
    ),
    (
      Icons.architecture,
      'PROPELLER\nSHAFT',
      'assets/categories/propellar_shaft.png',
    ),
    (Icons.car_repair, 'BODY PARTS', 'assets/categories/body_parts.png'),
    (Icons.settings_applications, 'CLUTCH', 'assets/categories/clutch.png'),
    (Icons.trip_origin, 'WHEELS', 'assets/categories/wheels.png'),
    (Icons.filter_alt, 'FILTERS', 'assets/categories/filter.png'),
    (Icons.more_horiz, 'OTHERS', 'assets/categories/others.png'),
  ];

  @override
  State<_CategorySection> createState() => _CategorySectionState();
}

class _CategorySectionState extends State<_CategorySection> {
  static const _perPage = 2; // 2 bigger tiles per page
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  int get _pageCount => (_CategorySection.items.length / _perPage).ceil();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _pageCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  // Pause briefly when the user manually swipes, then resume auto-play.
  void _onUserInteraction() {
    _timer?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _startAutoSlide();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _CategorySection.items;
    return _SectionShell(
      topPadding: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DISCOVER',
            style: TextStyle(
              color: AppPalette.navy,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text('Browse by Category', style: _sectionHeadingStyle),
              ),
              TextButton(
                onPressed: () => context.go('/catalog'),
                child: const Text(
                  'VIEW ALL',
                  style: TextStyle(
                    color: Color(0xFF008A9E),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 260,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _onUserInteraction();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * _perPage;
                  final pageItems = items.skip(start).take(_perPage).toList();
                  return Row(
                    children: [
                      for (int i = 0; i < pageItems.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: _CategoryTile(
                            icon: pageItems[i].$1,
                            label: pageItems[i].$2,
                            imageAsset: pageItems[i].$3,
                            palette: _palette[(start + i) % _palette.length],
                            index: i,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppPalette.navy
                          : AppPalette.navy.withOpacity(.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatefulWidget {
  const _CategoryTile({
    required this.icon,
    required this.label,
    required this.imageAsset,
    required this.palette,
    this.index = 0,
  });
  final IconData icon;
  final String label;
  final String imageAsset;
  final (Color, Color) palette; // (background, icon/text color)
  final int index;

  @override
  State<_CategoryTile> createState() => _CategoryTileState();
}

class _CategoryTileState extends State<_CategoryTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.palette.$1;
    final fg = widget.palette.$2;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + widget.index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 16),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () => context.go(
          '/catalog?category=${Uri.encodeComponent(widget.label.replaceAll('\n', ' '))}',
        ),
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _pressed
                  ? []
                  : [
                      BoxShadow(
                        color: fg.withOpacity(.14),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(10),
                    width: double.infinity,
                    child: Image.asset(
                      widget.imageAsset,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      // No image dropped in yet? Fall back to the original
                      // colored icon look — just replace the file in
                      // assets/categories/ and this switches automatically.
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(widget.icon, color: fg, size: 46),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _palette = <(Color, Color)>[
  (Color(0xFFE8F4FF), Color(0xFF0A4A8C)), // blue
  (Color(0xFFFFF8E6), Color(0xFFB87800)), // orange
  (Color(0xFFE6FFF8), Color(0xFF007A5A)), // green
  (Color(0xFFF3EEFF), Color(0xFF5A00C8)), // purple
];

// ═══════════════════════════════════════════════════════════════════════════
// BRANDS SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _BrandsSection extends StatefulWidget {
  const _BrandsSection();

  static const items = [
    ('TATA', 'assets/brands/tata.png', false),
    ('MAHINDRA', 'assets/brands/mahindra.png', false),
    ('MARUTI SUZUKI', 'assets/brands/maruti_suzuki.png', false),
    ('NISSAN', 'assets/brands/nissan.png', false),
    ('BMW', 'assets/brands/bmw.png', false),
    ('BOSCH', 'assets/brands/bosch.png', true),
    ('MANN', 'assets/brands/mann.png', false),
    ('SOFIMA', 'assets/brands/sofima.png', false),
    ('MOTHERSON', 'assets/brands/motherson.png', false),
    ('MONROE', 'assets/brands/monroe.png', false),
    ('VALEO', 'assets/brands/valeo.png', false),
    ('ZIP', 'assets/brands/zip.png', false),
    ('LUK', 'assets/brands/luk.png', false),
  ];

  @override
  State<_BrandsSection> createState() => _BrandsSectionState();
}

class _BrandsSectionState extends State<_BrandsSection> {
  static const _perPage = 2;
  late final PageController _controller;
  Timer? _timer;
  int _page = 0;

  int get _pageCount => (_BrandsSection.items.length / _perPage).ceil();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_page + 1) % _pageCount;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onUserInteraction() {
    _timer?.cancel();
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) _startAutoSlide();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _BrandsSection.items;
    return _SectionShell(
      topPadding: 28,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Brands we Trust', style: _sectionHeadingStyle),
          const SizedBox(height: 18),
          SizedBox(
            height: 130,
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _onUserInteraction();
                }
                return false;
              },
              child: PageView.builder(
                controller: _controller,
                itemCount: _pageCount,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, pageIndex) {
                  final start = pageIndex * _perPage;
                  final pageItems = items.skip(start).take(_perPage).toList();
                  return Row(
                    children: [
                      for (int i = 0; i < pageItems.length; i++) ...[
                        if (i > 0) const SizedBox(width: 16),
                        Expanded(
                          child: _BrandCard(
                            label: pageItems[i].$1,
                            logoAsset: pageItems[i].$2,
                            gold: pageItems[i].$3,
                            index: i,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < _pageCount; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _page == i ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _page == i
                          ? AppPalette.navy
                          : AppPalette.navy.withOpacity(.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: GestureDetector(
              onTap: () => _LocalBrandsSheet.show(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFDCE4EA)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.storefront, size: 15, color: Color(0xFF008A9E)),
                    SizedBox(width: 6),
                    Text(
                      'Aftermarket & Local Brands',
                      style: TextStyle(
                        color: Color(0xFF008A9E),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 10,
                      color: Color(0xFF008A9E),
                    ),
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

class _BrandCard extends StatefulWidget {
  const _BrandCard({
    required this.label,
    this.logoAsset,
    this.gold = false,
    this.index = 0,
  });
  final String label;
  final String? logoAsset;
  final bool gold;
  final int index;

  @override
  State<_BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<_BrandCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + widget.index * 90),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) {
        return Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.9 + t * 0.1, child: child),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {},
        child: AnimatedScale(
          scale: _pressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 130,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFEBF0F5)),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.navy.withOpacity(.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: widget.logoAsset == null
                ? _fallback()
                : Image.asset(
                    widget.logoAsset!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => _fallback(),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      alignment: Alignment.center,
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: widget.gold ? const Color(0xFFE3C15B) : Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOCAL / AFTERMARKET BRANDS SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _LocalBrandsSheet extends StatelessWidget {
  const _LocalBrandsSheet();

  // Add your local / aftermarket brand entries here as you get logos from
  // the user, e.g. ('MyBrand', 'assets/brands/local/mybrand.png').
  // Until an asset exists, the tile falls back to a storefront icon.
  static const _localBrands = <(String, String)>[
    ('Local Brand 1', 'assets/brands/local/local1.png'),
    ('Local Brand 2', 'assets/brands/local/local2.png'),
    ('Local Brand 3', 'assets/brands/local/local3.png'),
    ('Local Brand 4', 'assets/brands/local/local4.png'),
  ];

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => const _LocalBrandsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE4EA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Aftermarket & Local Brands',
              style: _sectionHeadingStyle,
            ),
            const SizedBox(height: 4),
            const Text(
              'Trusted local and aftermarket options alongside OEM brands.',
              style: TextStyle(
                color: Color(0xFF7A8A97),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _localBrands.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: .96,
                crossAxisSpacing: 13,
                mainAxisSpacing: 13,
              ),
              itemBuilder: (context, index) {
                final brand = _localBrands[index];
                return InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    context.go('/catalog');
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F6FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Image.asset(
                            brand.$2,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                              Icons.storefront,
                              color: AppPalette.navy,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          brand.$1,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Color(0xFF293948),
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ARTICLES SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _ArticlesSection extends StatelessWidget {
  const _ArticlesSection();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      topPadding: 28,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Expert Articles', style: _sectionHeadingStyle),
          SizedBox(height: 18),
          _ArticleCard(
            icon: Icons.receipt_long,
            tag: 'MAINTENANCE',
            title: 'Top 5 Tips for Seasonal Car\nCare & Efficiency',
            body:
                'Learn how to maintain your vehicle during harsh weather conditions to',
          ),
          SizedBox(height: 12),
          _ArticleCard(
            icon: Icons.article,
            tag: 'ENGINE',
            title: 'Choosing the Right Engine Oil\nfor Your Car Type',
            body:
                'Synthetic vs. Mineral oil - making the right choice can save you...',
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({
    required this.icon,
    required this.tag,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String tag;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final isEngine = tag == 'ENGINE';
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tag,
                style: const TextStyle(
                  color: AppPalette.cyan,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title.replaceAll('\n', ' '),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$body Proper maintenance, correct specifications, and timely replacement help prevent costly failures. Check your owner manual and use verified parts for your vehicle.',
              ),
            ],
          ),
        ),
      ),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 130,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 116,
              height: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C3547),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: Colors.white.withOpacity(.68), size: 58),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    color: isEngine ? AppPalette.navy : const Color(0xFFFFC400),
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: isEngine ? Colors.white : AppPalette.navy,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF172635),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF657583),
                      fontSize: 11,
                      height: 1.2,
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

// ═══════════════════════════════════════════════════════════════════════════
// WHY SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _WhySection extends StatelessWidget {
  const _WhySection();

  @override
  Widget build(BuildContext context) {
    final desktop = !Responsive.isMobile(context);
    return _SectionShell(
      topPadding: desktop ? 36 : 52,
      bottomPadding: desktop ? 28 : 34,
      child: Column(
        children: [
          const Text(
            'Why PartMo?',
            textAlign: TextAlign.center,
            style: _sectionHeadingStyle,
          ),
          const SizedBox(height: 30),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: desktop ? 4 : 2,
            childAspectRatio: desktop ? 1.65 : 1.38,
            mainAxisSpacing: desktop ? 12 : 18,
            crossAxisSpacing: desktop ? 12 : 18,
            children: const [
              _WhyTile(
                icon: Icons.verified_outlined,
                title: '100% Genuine',
                text: 'Sourced directly from\nverified manufacturers',
              ),
              _WhyTile(
                icon: Icons.payments_outlined,
                title: 'Best Value',
                text: 'Unbeatable prices in the\nspare parts market',
              ),
              _WhyTile(
                icon: Icons.history,
                title: 'Easy Returns',
                text: 'Hassle-free 10-day return\npolicy',
              ),
              _WhyTile(
                icon: Icons.support_agent,
                title: 'Expert Help',
                text: 'Technical support from car\npart specialists',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhyTile extends StatelessWidget {
  const _WhyTile({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFD8F4FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppPalette.navy, size: 22),
        ),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF172635),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF657583),
            fontSize: 10.5,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STORIES SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _StoriesSection extends StatelessWidget {
  const _StoriesSection();

  @override
  Widget build(BuildContext context) {
    final desktop = !Responsive.isMobile(context);
    return Container(
      color: AppPalette.navy,
      padding: EdgeInsets.fromLTRB(
        desktop ? 28 : 18,
        desktop ? 26 : 30,
        desktop ? 28 : 18,
        desktop ? 30 : 34,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'User Stories',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 22),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(desktop ? 24 : 22),
            decoration: BoxDecoration(
              color: const Color(0xFF1B527A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '★★★★★',
                  style: TextStyle(
                    color: Color(0xFFFFC400),
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '"Found the exact steering rack for my 2012\nmodel which was unavailable everywhere\nelse. Delivery was fast and the packing was\nsuperb."',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    height: 1.45,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppPalette.cyan,
                      child: Text(
                        'RK',
                        style: TextStyle(
                          color: AppPalette.navy,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rahul K.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Verified Buyer, Delhi',
                          style: TextStyle(
                            color: Color(0xFFB8D3E6),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SELL WITH US SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _SellWithUsSection extends StatelessWidget {
  const _SellWithUsSection();

  @override
  Widget build(BuildContext context) {
    final desktop = !Responsive.isMobile(context);
    return Container(
      margin: EdgeInsets.fromLTRB(desktop ? 0 : 16, 8, desktop ? 0 : 16, 8),
      padding: EdgeInsets.fromLTRB(
        desktop ? 28 : 20,
        desktop ? 26 : 22,
        desktop ? 28 : 20,
        desktop ? 26 : 22,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF073B63), Color(0xFF0D5490)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30073B63),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppPalette.cyan.withOpacity(.18),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SELL WITH US',
                    style: TextStyle(
                      color: AppPalette.cyan,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Want to list and sell\nyour auto parts?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Join thousands of verified sellers on PartMo.',
                  style: TextStyle(
                    color: Color(0xFFB8D3E6),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Opening mail to precisiong@gmail.com...',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppPalette.cyan,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mail_outline,
                          color: AppPalette.navy,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'precisiong@gmail.com',
                          style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: AppPalette.cyan,
                  size: 30,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFFB8D3E6),
                  size: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FOOTER
// ═══════════════════════════════════════════════════════════════════════════

class _LandingFooter extends StatelessWidget {
  const _LandingFooter();

  @override
  Widget build(BuildContext context) {
    final desktop = !Responsive.isMobile(context);
    return Container(
      color: const Color(0xFFE9EEF5),
      padding: EdgeInsets.fromLTRB(
        desktop ? 36 : 28,
        desktop ? 38 : 48,
        desktop ? 36 : 28,
        desktop ? 30 : 36,
      ),
      child: Column(
        children: [
          const Text(
            'PARTMO',
            style: TextStyle(
              color: AppPalette.navy,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -.9,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Your expert partner for automotive spare parts across\nIndia. Thousands of brands, millions of parts.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF657583),
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StoreButton(
                icon: Icons.play_arrow,
                label: 'GET IT ON\nGoogle Play',
              ),
              const SizedBox(width: 12),
              _StoreButton(icon: Icons.apple, label: 'Download on\nApp Store'),
            ],
          ),
          SizedBox(height: desktop ? 34 : 60),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _FooterLinks(
                  title: 'COMPANY',
                  links: ['About Us', 'Contact Us', 'Careers', 'Blog'],
                ),
              ),
              const SizedBox(width: 54),
              Expanded(
                child: _FooterLinks(
                  title: 'SUPPORT',
                  links: [
                    'FAQs',
                    'Return Policy',
                    'Shipping Info',
                    'Terms of Service',
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 34),
          const Text(
            '© 2026 PartMo. All rights reserved.',
            style: TextStyle(
              color: Color(0xFF7F8D99),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PartMo mobile app download is coming soon.'),
        ),
      ),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        height: 43,
        width: 116,
        decoration: BoxDecoration(
          color: AppPalette.navy,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterLinks extends StatelessWidget {
  const _FooterLinks({required this.title, required this.links});
  final String title;
  final List<String> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppPalette.navy,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 18),
        for (final link in links)
          InkWell(
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (context) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      link,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(_footerCopy(link)),
                  ],
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Text(
                link,
                style: const TextStyle(
                  color: Color(0xFF4D5E6D),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _footerCopy(String link) => switch (link) {
        'Contact Us' =>
          'For product help and enquiries, contact PartMo on WhatsApp: +91 90109 07444.',
        'Return Policy' =>
          'Contact support with your order reference. Eligible unused parts can be reviewed for return.',
        'Shipping Info' =>
          'Delivery timing and tracking are shown on each confirmed order.',
        'Terms of Service' =>
          'Orders are subject to availability, verified pricing, payment confirmation and applicable law.',
        'FAQs' =>
          'Use Product Enquiry for fitment, stock, payment, delivery or order questions.',
        _ =>
          'PartMo supplies verified automotive spare parts and practical ownership guidance across India.',
      };
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED SECTION SHELL
// ═══════════════════════════════════════════════════════════════════════════

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.child,
    this.topPadding = 0,
    this.bottomPadding = 28,
  });
  final Widget child;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F6FA),
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      child: child,
    );
  }
}

const _sectionHeadingStyle = TextStyle(
  color: Color(0xFF172635),
  fontSize: 18,
  fontWeight: FontWeight.w900,
  height: 1.05,
);

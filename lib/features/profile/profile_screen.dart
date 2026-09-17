import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/web_shell.dart';
import '../../models/address.dart';
import '../../models/vehicle.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/garage_provider.dart';
import '../../providers/orders_provider.dart';
import '../../providers/user_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ROOT SCREEN
// ═══════════════════════════════════════════════════════════════════════════

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        ref.read(addressesProvider.notifier).load(),
        ref.read(selectedAddressProvider.notifier).load(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = SupabaseService.isLoggedIn;

    return WebShell(
      selectedIndex: 4,
      backgroundColor: const Color(0xFFF4F7FB),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxWidth(context)),
          child: isLoggedIn
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    const _ProfileHeaderBar(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                      child: Column(
                        children: [
                          _StaggerIn(index: 0, child: const _ProfileHeroCard()),
                          const SizedBox(height: 22),
                          _StaggerIn(index: 1, child: const _GarageCard()),
                          const SizedBox(height: 22),
                          _StaggerIn(index: 2, child: const _AddressSection()),
                          const SizedBox(height: 22),
                          _StaggerIn(
                              index: 3, child: const _RecentOrdersSection()),
                          const SizedBox(height: 22),
                          _StaggerIn(index: 4, child: const _PaymentsSection()),
                          const SizedBox(height: 22),
                          _StaggerIn(index: 5, child: const _LogoutButton()),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: EdgeInsets.zero,
                  children: const [
                    _ProfileHeaderBar(),
                    _SignedOutView(),
                  ],
                ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ANIMATION HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Wraps [child] with a one-time fade + upward-slide entrance animation.
/// [index] staggers the start time of each section so the page cascades
/// in rather than popping in all at once.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = Duration(milliseconds: 70 * widget.index);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// A tap target that gently scales down on press for tactile feedback.
/// Use in place of a bare InkWell/GestureDetector where a little life helps.
class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, this.onTap, this.scale = 0.97});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onTap == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SIGNED-OUT STATE
// ═══════════════════════════════════════════════════════════════════════════

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 60, 18, 40),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: AppPalette.navy.withOpacity(.08),
              borderRadius: BorderRadius.circular(24),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_outline_rounded,
                color: AppPalette.navy, size: 44),
          ),
          const SizedBox(height: 28),
          const Text(
            'Sign in to view your profile',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF172635),
                fontSize: 19,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          const Text(
            'Track orders, manage your garage, saved\naddresses and payment methods — all in\none place.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Color(0xFF7D8B97),
                fontSize: 13,
                height: 1.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => context.go('/login?return=/profile'),
              style: FilledButton.styleFrom(
                backgroundColor: AppPalette.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('SIGN IN',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4)),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: () => context.go('/signup'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFD3DEE8)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('CREATE ACCOUNT',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.navy,
                      letterSpacing: 1.2)),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HEADER BAR
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileHeaderBar extends ConsumerWidget {
  const _ProfileHeaderBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Responsive.isMobile(context)) return const SizedBox.shrink();
    final user = ref.watch(userProvider);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.paddingOf(context).top + 12, 14, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.menu, color: AppPalette.navy, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          const Text('PARTMO',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          Container(
            width: 34,
            height: 34,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFD7E0E8),
              borderRadius: BorderRadius.circular(18),
            ),
            child: user.photoBytes != null
                ? Image.memory(user.photoBytes!, fit: BoxFit.cover)
                : const Icon(Icons.person, color: AppPalette.navy, size: 19),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HERO CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileHeroCard extends ConsumerWidget {
  const _ProfileHeroCard();

  Future<void> _pickPhoto(BuildContext context, WidgetRef ref) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 800, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      ref.read(userProvider.notifier).setPhoto(bytes);
      try {
        final url = await SupabaseService.uploadAvatarBytes(
          bytes: bytes,
          fileName:
              '${SupabaseService.currentUser?.id ?? 'guest'}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        ref.read(userProvider.notifier).setPhotoUrl(url);
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not pick photo: $e')));
      }
    }
  }

  void _editProfile(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: _resolveDisplayName());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full name')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              try {
                await SupabaseService.updateDisplayName(name);
                ref.read(userProvider.notifier).updateProfile(name: name);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Could not update profile.')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context) {
    showModalBottomSheet(
        context: context, builder: (_) => const _SettingsSheet());
  }

  /// Derives a display name from Supabase auth:
  /// 1. user_metadata['full_name']
  /// 2. user_metadata['name']
  /// 3. email prefix (part before @)
  /// 4. "User" fallback
  String _resolveDisplayName() {
    final authUser = SupabaseService.currentUser;
    if (authUser == null) return 'User';
    final meta = authUser.userMetadata;
    if (meta != null) {
      final full = meta['full_name'] ?? meta['name'];
      if (full != null && (full as String).trim().isNotEmpty)
        return full.trim();
    }
    final email = authUser.email ?? '';
    if (email.isNotEmpty) return email.split('@').first;
    return 'User';
  }

  String _resolveEmail() {
    return SupabaseService.currentUser?.email ?? '';
  }

  String _resolveMemberSince() {
    final createdAt = SupabaseService.currentUser?.createdAt;
    final created = DateTime.tryParse(createdAt ?? '');
    return created?.year.toString() ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);

    // Use live auth name; fall back to provider name only if auth gives nothing
    final displayName =
        _resolveDisplayName().isNotEmpty && _resolveDisplayName() != 'User'
            ? _resolveDisplayName()
            : user.name;
    final email = _resolveEmail();
    final memberSince = _resolveMemberSince();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(7)),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 126,
                height: 126,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8B179),
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x25000000),
                        blurRadius: 12,
                        offset: Offset(0, 5))
                  ],
                ),
                child: user.photoBytes != null
                    ? Image.memory(user.photoBytes!,
                        fit: BoxFit.cover, width: 126, height: 126)
                    : Center(
                        child: Text(
                          // Initials avatar
                          displayName.trim().isNotEmpty
                              ? displayName
                                  .trim()
                                  .split(' ')
                                  .take(2)
                                  .map((w) => w[0].toUpperCase())
                                  .join()
                              : '?',
                          style: const TextStyle(
                              color: AppPalette.navy,
                              fontSize: 42,
                              fontWeight: FontWeight.w900),
                        ),
                      ),
              ),
              Positioned(
                bottom: -6,
                right: -6,
                child: InkWell(
                  onTap: () => _pickPhoto(context, ref),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppPalette.navy,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 17),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(displayName,
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 25,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          if (email.isNotEmpty)
            Text(email,
                style: const TextStyle(
                    color: Color(0xFF7D8B97),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(memberSince.isEmpty ? 'Member' : 'Member - Since $memberSince',
              style: const TextStyle(
                  color: Color(0xFF5E6E7C),
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 42,
                child: FilledButton(
                  onPressed: () => _editProfile(context, ref),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppPalette.navy,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4))),
                  child: const Text('Edit Profile',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                height: 42,
                child: OutlinedButton(
                  onPressed: () => _openSettings(context),
                  style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4))),
                  child: const Text('Settings',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settings bottom sheet ──────────────────────────────────────────────────

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Settings',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF172635))),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('My orders'),
              subtitle: const Text('Track confirmed orders'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.go('/tracking');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Delivery addresses'),
              subtitle: const Text('Add or edit saved addresses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/addresses');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.favorite_border),
              title: const Text('Saved parts'),
              subtitle: const Text('View your wishlist'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/wishlist');
              },
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(backgroundColor: AppPalette.navy),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GARAGE CARD — empty until user adds a vehicle
// ═══════════════════════════════════════════════════════════════════════════

class _GarageCard extends ConsumerWidget {
  const _GarageCard();

  void _addVehicleDialog(BuildContext context, WidgetRef ref) {
    String selectedType = kVehicleTypes.first;
    final customTypeCtrl = TextEditingController();
    final makeModelCtrl = TextEditingController();
    final yearCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Vehicle',
              style: TextStyle(fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Vehicle type',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF657583))),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  items: [
                    for (final t in kVehicleTypes)
                      DropdownMenuItem(value: t, child: Text(t))
                  ],
                  onChanged: (v) =>
                      setS(() => selectedType = v ?? selectedType),
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(), isDense: true),
                ),
                if (selectedType == 'Other') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: customTypeCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Describe vehicle type',
                        hintText: 'e.g. Tractor, Quad bike'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: makeModelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Make & model',
                      hintText: 'e.g. Maruti Swift VXi'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Year', hintText: 'e.g. 2023'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (makeModelCtrl.text.trim().isEmpty) return;
                final type = selectedType == 'Other' &&
                        customTypeCtrl.text.trim().isNotEmpty
                    ? customTypeCtrl.text.trim()
                    : selectedType;
                ref.read(garageProvider.notifier).addVehicle(
                      type: type,
                      makeModel: makeModelCtrl.text.trim(),
                      year: yearCtrl.text.trim().isEmpty
                          ? '—'
                          : yearCtrl.text.trim(),
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _switchVehicle(BuildContext context, WidgetRef ref,
      List<Vehicle> vehicles, String currentId) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Your vehicles',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
            for (final v in vehicles)
              ListTile(
                leading:
                    const Icon(Icons.directions_car, color: AppPalette.navy),
                title: Text(v.makeModel,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${v.type} • ${v.year}'),
                trailing: v.id == currentId
                    ? const Icon(Icons.check_circle, color: AppPalette.cyan)
                    : null,
                onTap: () {
                  ref.read(garageProvider.notifier).setPrimary(v.id);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garage = ref.watch(garageProvider);
    final vehicle = garage.primary;
    final isEmpty = garage.vehicles.isEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              const Icon(Icons.directions_car_outlined,
                  color: AppPalette.navy, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                  child: Text('My Garage',
                      style: TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              if (garage.vehicles.length > 1)
                TextButton(
                  onPressed: () => _switchVehicle(
                      context, ref, garage.vehicles, vehicle?.id ?? ''),
                  child: const Text('Switch',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              TextButton(
                onPressed: () => _addVehicleDialog(context, ref),
                child: const Text('Add Vehicle',
                    style:
                        TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Empty state ──
          if (isEmpty) ...[
            Container(
              height: 128,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                    color: const Color(0xFFD8E2EA),
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined,
                      color: const Color(0xFF9BAAB6), size: 44),
                  const SizedBox(height: 10),
                  const Text('No vehicle added yet',
                      style: TextStyle(
                          color: Color(0xFF7D8B97),
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                onPressed: () => _addVehicleDialog(context, ref),
                style: FilledButton.styleFrom(
                    backgroundColor: AppPalette.navy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4))),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Your Vehicle',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
              ),
            ),
          ] else ...[
            // ── Vehicle photo ──
            GestureDetector(
              onTap: () async {
                try {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 900,
                      imageQuality: 85);
                  if (picked == null) return;
                  final bytes = await picked.readAsBytes();
                  ref
                      .read(garageProvider.notifier)
                      .setVehiclePhoto(vehicle!.id, bytes);
                } catch (_) {}
              },
              child: Stack(
                children: [
                  Container(
                    height: 128,
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        color: const Color(0xFFDCE6EB),
                        borderRadius: BorderRadius.circular(3)),
                    child: vehicle?.photoBytes != null
                        ? Image.memory(vehicle!.photoBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 128)
                        : const Center(
                            child: Icon(Icons.directions_car_filled,
                                color: Color(0xFF617180), size: 86)),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppPalette.navy.withOpacity(.75),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child:
                          const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Add Photo',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(vehicle!.makeModel,
                          style: const TextStyle(
                              color: Color(0xFF172635),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      Text('${vehicle.type} | ${vehicle.year}',
                          style: const TextStyle(
                              color: Color(0xFF5E6E7C),
                              fontSize: 12,
                              fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: const Color(0xFFD8F4FF),
                  child: const Text('PRIMARY',
                      style: TextStyle(
                          color: AppPalette.navy,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child:
                        _VehicleMeta(title: 'VIN Number', value: vehicle.vin)),
                Expanded(
                    child: _VehicleMeta(
                        title: 'Last Service', value: vehicle.lastService)),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                InkWell(
                  onTap: () => context.go('/tracking'),
                  child: const Row(children: [
                    Icon(Icons.history, color: AppPalette.navy, size: 14),
                    SizedBox(width: 5),
                    Text('SERVICE HISTORY',
                        style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
                const SizedBox(width: 18),
                InkWell(
                  onTap: () => context.go('/catalog'),
                  child: const Row(children: [
                    Icon(Icons.shopping_cart_outlined,
                        color: AppPalette.navy, size: 14),
                    SizedBox(width: 5),
                    Text('SPARE PARTS',
                        style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 10,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VehicleMeta extends StatelessWidget {
  const _VehicleMeta({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(
              color: Color(0xFF7D8B97),
              fontSize: 9.5,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value,
          style: const TextStyle(
              color: Color(0xFF344555),
              fontSize: 11,
              fontWeight: FontWeight.w900)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ADDRESSES
// ═══════════════════════════════════════════════════════════════════════════

class _AddressSection extends ConsumerWidget {
  const _AddressSection();

  void _addOrEditAddress(BuildContext context, WidgetRef ref,
      {Address? existing}) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final lineCtrl = TextEditingController(text: existing?.line ?? '');
    final cityCtrl = TextEditingController(text: existing?.city ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final alternateCtrl =
        TextEditingController(text: existing?.alternatePhone ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Add Address' : 'Edit Address',
            style: const TextStyle(fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Label (e.g. Home, Office)')),
              const SizedBox(height: 10),
              TextField(
                  controller: nameCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Recipient name')),
              const SizedBox(height: 10),
              TextField(
                  controller: lineCtrl,
                  decoration: const InputDecoration(labelText: 'Address line')),
              const SizedBox(height: 10),
              TextField(
                  controller: cityCtrl,
                  decoration:
                      const InputDecoration(labelText: 'City, state, pincode')),
              const SizedBox(height: 10),
              TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '10-digit mobile number',
                      counterText: '')),
              const SizedBox(height: 10),
              TextField(
                  controller: alternateCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Alternative mobile number (optional)',
                      hintText: '10 digits',
                      counterText: '')),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final phone = phoneCtrl.text.trim();
              final alternate = alternateCtrl.text.trim();
              if (labelCtrl.text.trim().isEmpty ||
                  nameCtrl.text.trim().isEmpty ||
                  lineCtrl.text.trim().isEmpty ||
                  cityCtrl.text.trim().isEmpty ||
                  phone.length != 10 ||
                  (alternate.isNotEmpty && alternate.length != 10)) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Complete all required fields and enter exactly 10 digits for mobile numbers.')));
                return;
              }
              final address = Address(
                id: existing?.id ??
                    'addr${DateTime.now().microsecondsSinceEpoch}',
                label: labelCtrl.text.trim(),
                name: nameCtrl.text.trim(),
                line: lineCtrl.text.trim(),
                city: cityCtrl.text.trim(),
                phone: phone,
                alternatePhone: alternate,
                isDefault: existing?.isDefault ?? false,
              );
              if (existing == null) {
                final saved = await ref
                    .read(addressesProvider.notifier)
                    .addAddress(address);
                await ref
                    .read(selectedAddressProvider.notifier)
                    .select(saved.id);
              } else {
                await ref
                    .read(addressesProvider.notifier)
                    .updateAddress(address);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addresses = ref.watch(addressesProvider);
    final isLoading = ref.watch(addressesLoadingProvider);
    final selected = ref.watch(selectedAddressProvider);

    return _ProfileSection(
      icon: Icons.location_on_outlined,
      title: 'Addresses',
      trailing: Icons.add_circle_outline,
      onTrailingTap: () => _addOrEditAddress(context, ref),
      child: isLoading && addresses.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          : addresses.isEmpty
              ? _EmptyState(
                  icon: Icons.location_off_outlined,
                  message: 'No saved addresses yet.',
                  actionLabel: 'Add Address',
                  onAction: () => _addOrEditAddress(context, ref),
                )
              : Column(
                  children: [
                    for (var i = 0; i < addresses.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      _AddressRow(
                        title: addresses[i].label,
                        body: '${addresses[i].line}\n${addresses[i].city}',
                        selected: addresses[i].id == selected,
                        onTapSelect: () => ref
                            .read(selectedAddressProvider.notifier)
                            .select(addresses[i].id),
                        onEdit: () => _addOrEditAddress(context, ref,
                            existing: addresses[i]),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.title,
    required this.body,
    this.selected = false,
    this.onTapSelect,
    this.onEdit,
  });

  final String title;
  final String body;
  final bool selected;
  final VoidCallback? onTapSelect;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTapSelect,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F8),
          border: selected
              ? const Border(
                  left: BorderSide(color: Color(0xFF008A9E), width: 4))
              : null,
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF172635),
                            fontSize: 13,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(body,
                        style: const TextStyle(
                            color: Color(0xFF5E6E7C),
                            fontSize: 11.2,
                            height: 1.25,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            InkWell(
                onTap: onEdit,
                child:
                    const Icon(Icons.edit, color: Color(0xFF657583), size: 15)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RECENT ORDERS — empty until real orders exist
// ═══════════════════════════════════════════════════════════════════════════

class _RecentOrdersSection extends ConsumerWidget {
  const _RecentOrdersSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersState = ref.watch(myOrdersProvider);

    return _ProfileSection(
      icon: Icons.local_shipping_outlined,
      title: 'Recent Orders',
      textTrailing:
          (ordersState.valueOrNull ?? const []).isNotEmpty ? 'View All' : null,
      onTextTrailingTap: () => context.go('/tracking'),
      child: ordersState.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.all(18),
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (_, __) => const _EmptyState(
          icon: Icons.receipt_long_outlined,
          message: 'Could not load orders right now.',
        ),
        data: (orders) {
          if (orders.isEmpty) {
            return const _EmptyState(
              icon: Icons.receipt_long_outlined,
              message:
                  'No orders placed yet.\nStart shopping to see your orders here.',
            );
          }
          final recent = orders.take(3).toList();
          return Column(
            children: [
              for (var i = 0; i < recent.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _OrderRow(
                  icon: Icons.inventory_2_outlined,
                  title: recent[i].items.isNotEmpty
                      ? recent[i].items.first
                      : 'PartMo order',
                  order: [
                    'Order ${recent[i].id}',
                    if (recent[i].placedAt != null)
                      _formatOrderDate(recent[i].placedAt!),
                  ].join(' - '),
                  price:
                      '${AppConstants.currency}${recent[i].amount.toStringAsFixed(0)}',
                  badge: recent[i].status.toUpperCase(),
                  pale: recent[i].status.toLowerCase() != 'delivered',
                  onTap: () => context.go('/tracking'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _formatOrderDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({
    required this.icon,
    required this.title,
    required this.order,
    required this.price,
    required this.badge,
    this.pale = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String order;
  final String price;
  final String badge;
  final bool pale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: const Color(0xFFF0F3F8),
        child: Row(
          children: [
            Container(
                width: 48,
                height: 48,
                color: Colors.white,
                child: Icon(icon, color: AppPalette.navy, size: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFF172635),
                            fontSize: 12.5,
                            height: 1.1,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(order,
                        style: const TextStyle(
                            color: Color(0xFF657583),
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(price,
                    style: const TextStyle(
                        color: AppPalette.navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  color: pale ? const Color(0xFFE4EAF0) : AppPalette.cyan,
                  child: Text(badge,
                      style: const TextStyle(
                          color: AppPalette.navy,
                          fontSize: 8,
                          fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENTS
// ═══════════════════════════════════════════════════════════════════════════

class _PaymentsSection extends StatelessWidget {
  const _PaymentsSection();

  @override
  Widget build(BuildContext context) {
    return const _ProfileSection(
      icon: Icons.credit_card,
      title: 'Payments',
      child: _EmptyState(
        icon: Icons.verified_user_outlined,
        message:
            'Payment is not collected inside the app. Orders are confirmed and saved for follow-up.',
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFFB0BEC5), size: 40),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Color(0xFF7D8B97),
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4))),
              child: Text(actionLabel!,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w900)),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SHARED SECTION WRAPPER
// ═══════════════════════════════════════════════════════════════════════════

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.textTrailing,
    this.onTrailingTap,
    this.onTextTrailingTap,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final IconData? trailing;
  final String? textTrailing;
  final VoidCallback? onTrailingTap;
  final VoidCallback? onTextTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(7)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppPalette.navy, size: 20),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 18,
                          fontWeight: FontWeight.w900))),
              if (trailing != null)
                InkWell(
                    onTap: onTrailingTap,
                    child: Icon(trailing,
                        color: const Color(0xFF344555), size: 19)),
              if (textTrailing != null)
                InkWell(
                  onTap: onTextTrailingTap,
                  child: Text(textTrailing!,
                      style: const TextStyle(
                          color: AppPalette.navy,
                          fontSize: 11,
                          fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// LOGOUT + BOTTOM NAV
// ═══════════════════════════════════════════════════════════════════════════

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign out?'),
              content: const Text(
                  'You will need to sign in again to access your account.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Sign Out')),
              ],
            ),
          );
          if (confirm != true) return;
          await SupabaseService.signOut();
          if (context.mounted) context.go('/login');
        },
        icon: const Icon(Icons.logout, size: 18, color: AppPalette.danger),
        label: const Text('SIGN OUT',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AppPalette.danger,
                letterSpacing: 1.5)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppPalette.danger),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
      ),
    );
  }
}

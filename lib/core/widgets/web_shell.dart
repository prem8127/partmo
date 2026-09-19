// lib/core/widgets/web_shell.dart
//
// Drop this widget around every customer-facing screen.
// On mobile  (< 700 px) → original bottom NavigationBar
// On desktop (≥ 700 px) → sticky top nav bar (no overflow, works in browser)
//
// Usage inside any screen:
//   return WebShell(
//     selectedIndex: 0,   // 0=Home 1=Search 2=Orders 3=Profile
//     child: <your body widget>,
//   );

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_constants.dart';
import '../services/app_lifecycle_service.dart';
import '../../widgets/wishlist_button.dart';

class WebShell extends StatelessWidget {
  const WebShell({
    super.key,
    required this.selectedIndex,
    required this.child,
    this.backgroundColor,
    this.drawer,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });

  final int selectedIndex;
  final Widget child;
  final Color? backgroundColor;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  static const _navItems = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'Home',
        route: '/home'),
    _NavItem(
        icon: Icons.tune,
        activeIcon: Icons.tune,
        label: 'Catalog',
        route: '/catalog'),
    _NavItem(
        icon: Icons.search_outlined,
        activeIcon: Icons.search,
        label: 'Search',
        route: '/search'),
    _NavItem(
        icon: Icons.local_shipping_outlined,
        activeIcon: Icons.local_shipping,
        label: 'Orders',
        route: '/tracking'),
    _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'Profile',
        route: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final shell = _MobileShell(
      selectedIndex: selectedIndex,
      backgroundColor: backgroundColor,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      child: child,
    );

    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (!isAndroid) return shell;

    final canPop = GoRouter.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final location = GoRouterState.of(context).uri.path;
        if (location != '/home') {
          context.go('/home');
          return;
        }
        AppLifecycleService.moveToBackground();
      },
      child: shell,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MOBILE SHELL  (keeps original bottom nav)
// ─────────────────────────────────────────────────────────────────────────────
class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.selectedIndex,
    required this.child,
    this.backgroundColor,
    this.drawer,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });
  final int selectedIndex;
  final Widget child;
  final Color? backgroundColor;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: child,
      bottomNavigationBar: NavigationBar(
        // selectedIndex is -1 on non-tab screens (Cart, Checkout, Wishlist,
        // Product Detail, Order Tracking). NavigationBar requires a valid
        // 0..length-1 index or it throws, so clamp it here.
        selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
        onDestinationSelected: (i) => context.go(WebShell._navItems[i].route),
        destinations: WebShell._navItems
            .map((e) => NavigationDestination(
                  icon: Icon(e.icon),
                  selectedIcon: Icon(e.activeIcon),
                  label: e.label,
                ))
            .toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WEB / DESKTOP SHELL  (sticky top nav, centred content, max-width container)
// ─────────────────────────────────────────────────────────────────────────────
class _WebShell extends StatelessWidget {
  const _WebShell({
    required this.selectedIndex,
    required this.child,
    this.backgroundColor,
    this.drawer,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset,
  });
  final int selectedIndex;
  final Widget child;
  final Color? backgroundColor;
  final Widget? drawer;
  final Widget? floatingActionButton;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      drawer: drawer,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: _WebTopBar(selectedIndex: selectedIndex),
      body: child,
    );
  }
}

class _WebTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _WebTopBar({required this.selectedIndex});
  final int selectedIndex;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: Colors.white,
      child: Row(
        children: [
          const SizedBox(width: 24),
          // Brand logo
          GestureDetector(
            onTap: () => context.go('/home'),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppPalette.navy,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child:
                      const Icon(Icons.settings, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PartMo',
                  style: TextStyle(
                    color: AppPalette.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Nav links
          ...List.generate(WebShell._navItems.length, (i) {
            final item = WebShell._navItems[i];
            final selected = i == selectedIndex;
            return _TopNavLink(
              icon: selected ? item.activeIcon : item.icon,
              label: item.label,
              selected: selected,
              onTap: () => context.go(item.route),
            );
          }),
          const WishlistButton(useGo: true),
          // Cart icon
          _CartButton(),
          const SizedBox(width: 24),
        ],
      ),
    );
  }
}

class _TopNavLink extends StatelessWidget {
  const _TopNavLink({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              selected ? AppPalette.navy.withOpacity(.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 18, color: selected ? AppPalette.navy : AppPalette.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? AppPalette.navy : AppPalette.muted,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => context.go('/cart'),
      icon: const Icon(Icons.shopping_cart_outlined, color: AppPalette.navy),
      tooltip: 'Cart',
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

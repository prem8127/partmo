import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:precision_parts_frontend/providers/wishlist_provider.dart';
import 'package:precision_parts_frontend/widgets/wishlist_button.dart';

class _FakeWishlistNotifier extends WishlistNotifier {}

void main() {
  testWidgets('visible wishlist button opens the wishlist page',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, __) => const Scaffold(body: WishlistButton()),
        ),
        GoRoute(
          path: '/wishlist',
          builder: (_, __) => const Scaffold(body: Text('Wishlist page')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wishlistProvider.overrideWith((_) => _FakeWishlistNotifier()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Wishlist'), findsOneWidget);
    await tester.tap(find.byTooltip('Wishlist'));
    await tester.pumpAndSettle();

    expect(find.text('Wishlist page'), findsOneWidget);
  });
}

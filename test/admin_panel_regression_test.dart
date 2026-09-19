import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/core/constants/catalog_categories.dart';
import 'package:precision_parts_frontend/features/admin/add_product_screen.dart';
import 'package:precision_parts_frontend/features/admin/admin_dashboard_screen.dart';
import 'package:precision_parts_frontend/features/auth/login_screen.dart';

void main() {
  void useMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  test('legacy and misspelled category names reuse canonical categories', () {
    expect(canonicalProductCategory('breaks'), 'Brakes');
    expect(canonicalProductCategory(' brake '), 'Brakes');
    expect(canonicalProductCategory('filter'), 'Filters');
    expect(canonicalProductCategory('Propellar Shaft'), 'Propeller Shaft');
    expect(resolveProductCategory('custom parts', ['Custom Parts']),
        'Custom Parts');

    final productCategoryLabels = ['Brake', 'breaks', 'Engine', 'Brakes']
        .map(canonicalProductCategory)
        .toList();
    expect(productCategoryLabels, hasLength(4));
    expect(productCategoryLabels.where((value) => value == 'Brakes'),
        hasLength(3));
  });

  testWidgets('login form stays full width when the keyboard reduces height',
      (tester) async {
    tester.view.physicalSize = const Size(390, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pump();

    final emailField = find.byType(TextField).first;
    expect(tester.getSize(emailField).width, greaterThan(280));
  });

  testWidgets('admin hamburger opens an opaque navigation drawer',
      (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(const MaterialApp(home: AdminDashboardScreen()));
    await tester.pump();

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.drawerScrimColor, Colors.transparent);

    await tester.tap(find.byIcon(Icons.menu).first);
    await tester.pumpAndSettle();

    final drawer = tester.widget<Drawer>(find.byType(Drawer));
    expect(drawer.backgroundColor, Colors.white);
    expect(drawer.surfaceTintColor, Colors.white);
    expect(find.text('PartMo Admin'), findsOneWidget);
    expect(find.text('Add Product'), findsWidgets);
    expect(find.text('Manage Orders'), findsWidgets);
  });

  testWidgets('add product offers existing categories and new category last',
      (tester) async {
    useMobileViewport(tester);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: AddProductScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CATEGORY *'), findsOneWidget);
    expect(find.text('Select product category'), findsOneWidget);

    final categoryDropdown = find.byType(DropdownButtonFormField<String>);
    expect(categoryDropdown, findsOneWidget);
    await tester.ensureVisible(categoryDropdown);
    await tester.pumpAndSettle();
    await tester.tap(categoryDropdown);
    await tester.pumpAndSettle();

    expect(find.text('Engine'), findsOneWidget);
    expect(find.text('Brakes'), findsOneWidget);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(find.text('+ New category'), findsOneWidget);
  });
}

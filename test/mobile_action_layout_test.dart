import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/features/checkout/payment_selection_screen.dart';
import 'package:precision_parts_frontend/features/search/filters_screen.dart';

void main() {
  testWidgets('filter choices remain visible above the mobile action bar',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: FiltersScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Vehicle'), findsOneWidget);
    expect(find.text('Toyota Innova'), findsOneWidget);
    expect(find.text('Apply Filters'), findsOneWidget);
  });

  testWidgets('Razorpay test checkout is the only payment choice',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PaymentSelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirm now, pay later'), findsNothing);
    expect(find.text('Cash on Delivery'), findsNothing);
    expect(find.text('Razorpay Test Checkout'), findsOneWidget);
    expect(find.text('Razorpay Secure Checkout'), findsNothing);
    expect(find.text('Back to Checkout'), findsOneWidget);
  });
}

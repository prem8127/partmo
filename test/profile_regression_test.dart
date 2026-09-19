import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/providers/checkout_provider.dart';
import 'package:precision_parts_frontend/providers/garage_provider.dart';
import 'package:precision_parts_frontend/providers/user_provider.dart';

void main() {
  test('profile starts without demo customer or vehicle data', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final user = container.read(userProvider);
    final garage = container.read(garageProvider);

    expect(user.name, 'User');
    expect(user.role, 'Member');
    expect(user.vehicle, isEmpty);
    expect(user.memberSince, isEmpty);
    expect(garage.vehicles, isEmpty);
    expect(garage.primaryId, isNull);
  });

  test('checkout has only Razorpay test payment', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final methods = container.read(paymentMethodsProvider);

    expect(methods.map((method) => method.id), ['razorpay']);
    expect(methods.map((method) => method.id), isNot(contains('cod')));
    expect(methods.map((method) => method.id), contains('razorpay'));
    expect(container.read(selectedPaymentProvider), 'razorpay');
  });
}

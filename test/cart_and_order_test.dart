import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/models/product.dart';
import 'package:precision_parts_frontend/providers/cart_provider.dart';
import 'package:precision_parts_frontend/providers/orders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _limitedProduct = Product(
  id: 'limited',
  name: 'Limited stock part',
  category: 'Engine',
  price: 100,
  mrp: 120,
  rating: 4.5,
  stock: 2,
  imageIcon: 'engine',
  badge: '',
  description: '',
  compatibility: [],
  specs: {},
);

const _outOfStockProduct = Product(
  id: 'empty',
  name: 'Unavailable part',
  category: 'Engine',
  price: 100,
  mrp: 120,
  rating: 4.5,
  stock: 0,
  imageIcon: 'engine',
  badge: '',
  description: '',
  compatibility: [],
  specs: {},
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cart never exceeds available stock', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    await cart.restore();

    expect(cart.add(_limitedProduct), isTrue);
    expect(cart.add(_limitedProduct), isTrue);
    expect(cart.add(_limitedProduct), isFalse);
    expect(container.read(cartProvider).single.quantity, 2);

    cart.changeQuantity(_limitedProduct.id, 99);
    expect(container.read(cartProvider).single.quantity, 2);
    await cart.persistenceComplete;
  });

  test('out-of-stock products cannot enter the cart', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(cartProvider.notifier);
    await cart.restore();

    expect(cart.add(_outOfStockProduct), isFalse);
    expect(container.read(cartProvider), isEmpty);
  });

  test('every cart mutation persists across app restarts', () async {
    final first = ProviderContainer();
    final firstCart = first.read(cartProvider.notifier);
    await firstCart.restore();

    expect(firstCart.add(_limitedProduct), isTrue);
    await firstCart.persistenceComplete;
    firstCart.changeQuantity(_limitedProduct.id, 2);
    await firstCart.persistenceComplete;
    first.dispose();

    final second = ProviderContainer();
    final secondCart = second.read(cartProvider.notifier);
    await secondCart.restore();
    expect(second.read(cartProvider).single.quantity, 2);

    secondCart.changeQuantity(_limitedProduct.id, 0);
    await secondCart.persistenceComplete;
    second.dispose();

    final third = ProviderContainer();
    final thirdCart = third.read(cartProvider.notifier);
    await thirdCart.restore();
    expect(third.read(cartProvider), isEmpty);

    expect(thirdCart.add(_limitedProduct), isTrue);
    await thirdCart.persistenceComplete;
    thirdCart.clear();
    await thirdCart.persistenceComplete;
    third.dispose();

    final fourth = ProviderContainer();
    addTearDown(fourth.dispose);
    await fourth.read(cartProvider.notifier).restore();
    expect(fourth.read(cartProvider), isEmpty);
  });

  test('orders use the friendly reference while retaining the database id', () {
    final order = orderFromRow({
      'id': '76b04c6f-3f8a-4fd8-9c53-b188fd9abaaa',
      'order_ref': 'PP-20260901-1234',
      'status': 'confirmed',
      'total': 118,
      'created_at': '2026-09-01T12:00:00Z',
      'order_items': [
        {'product_name': 'Limited stock part'},
      ],
    });

    expect(order.id, 'PP-20260901-1234');
    expect(order.backendId, '76b04c6f-3f8a-4fd8-9c53-b188fd9abaaa');
    expect(order.items, ['Limited stock part']);
  });

  test('legacy numeric orders and price fields map without crashing', () {
    final order = orderFromRow({
      'id': 42,
      'status': 'confirmed',
      'total': 118,
      'created_at': '2026-09-04T06:00:00Z',
      'payment_method': 'Payment Pending',
      'order_items': [
        {
          'product_name': 'Legacy brake pad',
          'quantity': 2,
          'price': 50,
        },
      ],
    });

    expect(order.id, '42');
    expect(order.backendId, '42');
    expect(order.lines.single.unitPrice, 50);
    expect(order.lines.single.quantity, 2);
  });
}

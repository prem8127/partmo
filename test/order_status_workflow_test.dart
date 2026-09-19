import 'package:flutter_test/flutter_test.dart';
import 'package:precision_parts_frontend/core/utils/order_status.dart';
import 'package:precision_parts_frontend/providers/orders_provider.dart';

void main() {
  test('normal delivery flow advances one operational stage at a time', () {
    expect(OrderStatus.recommendedNext(OrderStatus.confirmed),
        OrderStatus.preparing);
    expect(
        OrderStatus.recommendedNext(OrderStatus.preparing), OrderStatus.packed);
    expect(
        OrderStatus.recommendedNext(OrderStatus.packed), OrderStatus.shipped);
    expect(OrderStatus.recommendedNext(OrderStatus.shipped),
        OrderStatus.outForDelivery);
    expect(OrderStatus.recommendedNext(OrderStatus.outForDelivery),
        OrderStatus.delivered);
  });

  test('failed delivery and return branches expose recovery actions', () {
    expect(OrderStatus.nextStatuses(OrderStatus.deliveryFailed),
        containsAll([OrderStatus.outForDelivery, OrderStatus.returnInTransit]));
    expect(OrderStatus.nextStatuses(OrderStatus.delivered),
        [OrderStatus.returnRequested]);
    expect(
        OrderStatus.nextStatuses(OrderStatus.returned), [OrderStatus.refunded]);
  });

  test('legacy dispatched orders map to out for delivery', () {
    expect(OrderStatus.normalize('dispatched'), OrderStatus.outForDelivery);
    expect(OrderStatus.label('dispatched'), 'Out for Delivery');
  });

  test('customer order includes admin delivery controls', () {
    final order = orderFromRow({
      'id': 'db-id',
      'order_ref': 'PP-123',
      'status': 'shipped',
      'total': 499,
      'estimated_delivery': '2026-09-08',
      'courier_name': 'Express Partner',
      'tracking_number': 'AWB123',
      'status_note': 'Package left our warehouse.',
      'order_items': const [],
    });

    expect(order.statusLabel, 'Shipped');
    expect(order.eta, '8 Sep 2026');
    expect(order.courierName, 'Express Partner');
    expect(order.trackingNumber, 'AWB123');
    expect(order.statusNote, 'Package left our warehouse.');
  });
}

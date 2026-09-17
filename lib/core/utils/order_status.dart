import '../../models/order.dart';

/// Canonical fulfilment lifecycle shared by admin and customer tracking.
class OrderStatus {
  OrderStatus._();

  static const confirmed = 'confirmed';
  static const preparing = 'preparing';
  static const packed = 'packed';
  static const shipped = 'shipped';
  static const outForDelivery = 'out_for_delivery';
  static const deliveryFailed = 'delivery_failed';
  static const delivered = 'delivered';
  static const onHold = 'on_hold';
  static const cancelled = 'cancelled';
  static const returnRequested = 'return_requested';
  static const returnInTransit = 'return_in_transit';
  static const returned = 'returned';
  static const refunded = 'refunded';

  /// Kept for orders written by the older app.
  static const dispatched = 'dispatched';

  static const flow = [
    confirmed,
    preparing,
    packed,
    shipped,
    outForDelivery,
    delivered,
  ];

  static const all = [
    confirmed,
    preparing,
    packed,
    shipped,
    outForDelivery,
    deliveryFailed,
    delivered,
    onHold,
    cancelled,
    returnRequested,
    returnInTransit,
    returned,
    refunded,
  ];

  static const issueStatuses = [deliveryFailed, onHold, cancelled];
  static const returnStatuses = [
    returnRequested,
    returnInTransit,
    returned,
    refunded,
  ];

  static String normalize(String raw) {
    final value = raw.toLowerCase().trim().replaceAll(' ', '_');
    if (value == dispatched) return outForDelivery;
    if (value == 'processing') return preparing;
    return all.contains(value) ? value : confirmed;
  }

  static String label(String raw) {
    switch (normalize(raw)) {
      case preparing:
        return 'Processing Order';
      case packed:
        return 'Packed';
      case shipped:
        return 'Shipped';
      case outForDelivery:
        return 'Out for Delivery';
      case deliveryFailed:
        return 'Delivery Attempt Failed';
      case delivered:
        return 'Delivered';
      case onHold:
        return 'On Hold';
      case cancelled:
        return 'Cancelled';
      case returnRequested:
        return 'Return Requested';
      case returnInTransit:
        return 'Return in Transit';
      case returned:
        return 'Returned';
      case refunded:
        return 'Refunded';
      default:
        return 'Order Confirmed';
    }
  }

  static bool isTerminal(String raw) =>
      const [delivered, refunded].contains(normalize(raw));

  static bool isIssue(String raw) => issueStatuses.contains(normalize(raw));

  static bool isReturn(String raw) => returnStatuses.contains(normalize(raw));

  /// Valid operational moves. Admin can still use "Correct status" for an
  /// exceptional manual correction, but the primary action follows this map.
  static List<String> nextStatuses(String raw) {
    switch (normalize(raw)) {
      case confirmed:
        return const [preparing, onHold, cancelled];
      case preparing:
        return const [packed, onHold, cancelled];
      case packed:
        return const [shipped, onHold, cancelled];
      case shipped:
        return const [outForDelivery, deliveryFailed];
      case outForDelivery:
        return const [delivered, deliveryFailed];
      case deliveryFailed:
        return const [outForDelivery, returnInTransit];
      case onHold:
        return const [confirmed, preparing, cancelled];
      case delivered:
        return const [returnRequested];
      case returnRequested:
        return const [returnInTransit];
      case returnInTransit:
        return const [returned];
      case returned:
      case cancelled:
        return const [refunded];
      default:
        return const [];
    }
  }

  static String? recommendedNext(String raw) {
    final options = nextStatuses(raw);
    return options.isEmpty ? null : options.first;
  }

  static List<OrderStep> stepsFor(
    String rawStatus, {
    DateTime? placedAt,
    String eta = '',
  }) {
    final status = normalize(rawStatus);

    if (status == cancelled || status == refunded) {
      return [
        const OrderStep(
            title: 'Order Placed', subtitle: 'Received', done: true),
        OrderStep(
          title: status == refunded ? 'Refund Completed' : 'Order Cancelled',
          subtitle: status == refunded
              ? 'Payment returned to customer'
              : 'Fulfilment stopped',
          done: true,
        ),
      ];
    }

    if (isReturn(status)) {
      final stage = returnStatuses.indexOf(status);
      return [
        const OrderStep(title: 'Delivered', subtitle: 'Completed', done: true),
        OrderStep(
          title: 'Return Requested',
          subtitle: stage == 0 ? 'Under review' : 'Approved',
          done: stage > 0,
          active: stage == 0,
        ),
        OrderStep(
          title: 'Return in Transit',
          subtitle: stage == 1 ? 'On the way back' : 'Upcoming',
          done: stage > 1,
          active: stage == 1,
        ),
        OrderStep(
          title: 'Returned',
          subtitle: stage >= 2 ? 'Received by seller' : 'Upcoming',
          done: stage >= 2,
        ),
      ];
    }

    final effective = status == deliveryFailed ? outForDelivery : status;
    final stage = flow.indexOf(effective).clamp(0, flow.length - 1);
    final titles = [
      'Order Confirmed',
      'Processing Order',
      'Packed',
      'Shipped',
      'Out for Delivery',
      'Delivered',
    ];

    return List.generate(titles.length, (index) {
      final done = index <= stage && status != deliveryFailed;
      final active = index == stage && status != delivered;
      var subtitle = index < stage
          ? 'Completed'
          : index == stage
              ? 'Current status'
              : 'Upcoming';
      if (index == 0 && placedAt != null) subtitle = 'Order received';
      if (index == titles.length - 1 && index > stage && eta.isNotEmpty) {
        subtitle = 'Expected $eta';
      }
      if (status == deliveryFailed && index == 4) {
        subtitle = 'Delivery attempt failed — awaiting admin action';
      }
      if (status == onHold && index == stage) subtitle = 'Temporarily on hold';
      return OrderStep(
        title: titles[index],
        subtitle: subtitle,
        done: done,
        active: active || (status == deliveryFailed && index == 4),
      );
    });
  }
}

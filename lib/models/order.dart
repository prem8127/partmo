import '../core/utils/order_status.dart';

class OrderStep {
  const OrderStep({
    required this.title,
    required this.subtitle,
    required this.done,
    this.active = false,
  });
  final String title;
  final String subtitle;
  final bool done;
  final bool active;
}

class OrderLine {
  const OrderLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.amount,
    required this.eta,
    this.backendId = '',
    this.placedAt,
    this.items = const [],
    this.whatsappNumber = '',
    this.address = '',
    this.courierName = '',
    this.trackingNumber = '',
    this.statusNote = '',
    this.lines = const [],
    this.subtotal = 0,
    this.tax = 0,
    this.paymentMethod = '',
  });

  final String id;
  final String backendId;

  /// Raw status value as stored in Supabase (`confirmed`, `preparing`,
  /// `dispatched`, `delivered`, `cancelled`) — see [OrderStatus].
  final String status;
  final double amount;
  final String eta;
  final DateTime? placedAt;
  final List<String> items;
  final String whatsappNumber;
  final String address;
  final String courierName;
  final String trackingNumber;
  final String statusNote;
  final List<OrderLine> lines;
  final double subtotal;
  final double tax;
  final String paymentMethod;

  /// Display label for the status badge, e.g. "Out for Delivery".
  String get statusLabel => OrderStatus.label(status);

  /// The 5-step tracking timeline, always derived live from [status] so it
  /// can never disagree with the real state of the order.
  List<OrderStep> get steps =>
      OrderStatus.stepsFor(status, placedAt: placedAt, eta: eta);

  Order copyWith({String? status}) => Order(
        id: id,
        backendId: backendId,
        status: status ?? this.status,
        amount: amount,
        eta: eta,
        placedAt: placedAt,
        items: items,
        whatsappNumber: whatsappNumber,
        address: address,
        courierName: courierName,
        trackingNumber: trackingNumber,
        statusNote: statusNote,
        lines: lines,
        subtotal: subtotal,
        tax: tax,
        paymentMethod: paymentMethod,
      );
}

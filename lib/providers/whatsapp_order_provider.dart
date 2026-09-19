import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';

/// Snapshot of the most recently placed order, kept just long enough to
/// carry data from Checkout -> Order Success -> Order Tracking so those
/// screens can compose the WhatsApp delivery-details message without
/// re-fetching everything from Supabase.
class PendingWhatsAppOrder {
  const PendingWhatsAppOrder({
    required this.orderRef,
    required this.whatsappNumber,
    required this.alternateNumber,
    required this.paymentMethod,
    required this.itemLines,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.address,
    required this.estimatedDelivery,
  });

  final String orderRef;
  final String
      whatsappNumber; // digits only, with country code, e.g. 9198xxxxxxx
  final String alternateNumber;
  final String paymentMethod;
  final List<String> itemLines; // "Product Name x2 - ₹1,200"
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String address;
  final String estimatedDelivery;

  /// The message shared with both the admin-notify and self-copy WhatsApp
  /// deep links, and reused on the tracking screen's "Share" action.
  String buildMessage() {
    final itemsBlock = itemLines.map((l) => '• $l').join('\n');
    return 'PartMo Order Confirmation\n'
        'Order Ref: $orderRef\n\n'
        'Items:\n$itemsBlock\n\n'
        'Subtotal: ₹${subtotal.toStringAsFixed(0)}\n'
        'Tax (GST 18%): ₹${tax.toStringAsFixed(0)}\n'
        'Order Total: ₹${total.toStringAsFixed(0)}\n'
        'Payment: $paymentMethod\n\n'
        'Delivering to: $address\n'
        'Estimated Delivery: $estimatedDelivery\n\n'
        'Customer WhatsApp: $whatsappNumber'
        '${alternateNumber.isEmpty ? '' : '\nAlternative Mobile: $alternateNumber'}';
  }
}

final pendingWhatsAppOrderProvider =
    StateProvider<PendingWhatsAppOrder?>((ref) => null);

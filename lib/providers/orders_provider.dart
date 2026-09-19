import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/services/supabase_service.dart';
import '../models/order.dart';

/// Maps a Supabase `orders` row (with nested `order_items`) to our [Order]
/// model. This is the single place raw DB rows become an [Order], so the
/// tracking screen and admin screen can never disagree about the shape.
Order orderFromRow(Map<String, dynamic> row) {
  final itemsRaw = (row['order_items'] as List?) ?? const [];
  final items = itemsRaw
      .map((i) => (i as Map)['product_name'] as String? ?? '')
      .where((n) => n.isNotEmpty)
      .toList();
  final lines = itemsRaw.map((raw) {
    final item = raw as Map;
    return OrderLine(
      name: item['product_name'] as String? ?? 'Automotive spare part',
      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (item['unit_price'] as num?)?.toDouble() ??
          (item['price'] as num?)?.toDouble() ??
          0,
    );
  }).toList();

  final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
  final storedEta =
      DateTime.tryParse(row['estimated_delivery'] as String? ?? '');
  final eta = storedEta != null
      ? _formatEta(storedEta)
      : createdAt != null
          ? _formatEta(createdAt.add(const Duration(days: 4)))
          : '';

  final rawOrderRef = row['order_ref']?.toString().trim() ?? '';
  final rawId = row['id']?.toString() ?? '';

  return Order(
    id: rawOrderRef.isNotEmpty ? rawOrderRef : _displayFallbackRef(rawId),
    backendId: row['id']?.toString() ?? '',
    status: (row['status'] as String? ?? 'confirmed').toLowerCase(),
    amount: (row['total'] as num?)?.toDouble() ?? 0,
    eta: eta,
    placedAt: createdAt,
    items: items,
    whatsappNumber: row['whatsapp_number'] as String? ?? '',
    address: row['delivery_address'] as String? ?? '',
    courierName: row['courier_name'] as String? ?? '',
    trackingNumber: row['tracking_number'] as String? ?? '',
    statusNote: row['status_note'] as String? ?? '',
    lines: lines,
    subtotal: (row['subtotal'] as num?)?.toDouble() ?? 0,
    tax: (row['tax'] as num?)?.toDouble() ?? 0,
    paymentMethod: row['payment_method'] as String? ?? '',
  );
}

String _displayFallbackRef(String id) {
  if (id.isEmpty) return '';
  final compact = id.replaceAll('-', '');
  final suffix = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return '#PM-${suffix.toUpperCase()}';
}

String _formatEta(DateTime d) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// The signed-in customer's real orders, fetched from Supabase — this
/// replaces the old device-only in-memory list, so tracking status is
/// always the actual status admin set, not a hardcoded guess.
class MyOrdersNotifier extends AsyncNotifier<List<Order>> {
  @override
  Future<List<Order>> build() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid != null) {
      final channel = SupabaseService.client
          .channel('customer-orders-$uid')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: uid,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
      ref.onDispose(() => SupabaseService.client.removeChannel(channel));
    }
    final rows = await SupabaseService.fetchMyOrders();
    return rows.map(orderFromRow).toList();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rows = await SupabaseService.fetchMyOrders();
      return rows.map(orderFromRow).toList();
    });
  }
}

final myOrdersProvider = AsyncNotifierProvider<MyOrdersNotifier, List<Order>>(
  MyOrdersNotifier.new,
);

final latestOrderProvider = Provider<Order?>((ref) {
  final orders = ref.watch(myOrdersProvider).valueOrNull ?? const [];
  return orders.isEmpty ? null : orders.first;
});

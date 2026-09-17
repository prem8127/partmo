import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderUpdateResult {
  const OrderUpdateResult({
    required this.statusSaved,
    required this.detailsSaved,
  });

  final bool statusSaved;
  final bool detailsSaved;
}

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static const String adminEmail = 'admin@precisionparts.com';
  static String? lastOrderSaveError;

  static User? get currentUser => client.auth.currentUser;
  static bool get isLoggedIn => currentUser != null;
  static bool get isAdmin =>
      currentUser?.email?.trim().toLowerCase() == adminEmail.toLowerCase();

  // Sign up: creates account, Supabase sends confirmation email
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    return await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
      emailRedirectTo: null, // force OTP mode
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  static Future<void> resetPassword({required String email}) async {
    await client.auth.resetPasswordForEmail(email);
  }

  static Future<void> signOut() async {
    await client.auth.signOut();
  }

  static Future<void> updateDisplayName(String fullName) async {
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': fullName}),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchProducts() async {
    final response = await client
        .from('products')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> insertProduct(Map<String, dynamic> data) async {
    await client.from('products').insert(data);
  }

  // ── Profiles ──────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    return await client.from('profiles').select().eq('id', uid).maybeSingle();
  }

  static Future<void> upsertProfile(Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await client.from('profiles').upsert({'id': uid, ...data});
  }

  static const _addressMetadataKey = 'delivery_addresses';
  static const _ordersMetadataKey = 'partmo_orders';

  static String get _ordersStorageKey =>
      'partmo_orders_${currentUser?.id ?? 'guest'}';

  static List<Map<String, dynamic>> _metadataOrders() {
    final raw = currentUser?.userMetadata?[_ordersMetadataKey];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _storedOrders() async {
    final merged = <String, Map<String, dynamic>>{};
    for (final row in _metadataOrders()) {
      final key = row['order_ref']?.toString() ?? row['id']?.toString();
      if (key != null && key.isNotEmpty) merged[key] = row;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_ordersStorageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded.whereType<Map>()) {
            final row = Map<String, dynamic>.from(item);
            final key = row['order_ref']?.toString() ?? row['id']?.toString();
            if (key != null && key.isNotEmpty) merged[key] = row;
          }
        }
      }
    } catch (_) {}
    return merged.values.toList();
  }

  static String _orderRowKey(Map<String, dynamic> row) {
    final orderRef = row['order_ref']?.toString();
    if (orderRef != null && orderRef.trim().isNotEmpty) return orderRef;
    return row['id']?.toString() ?? '';
  }

  static void _putMergedOrder(
    Map<String, Map<String, dynamic>> target,
    Map<String, dynamic> row, {
    required bool preferRemote,
  }) {
    final keys = {
      row['id']?.toString(),
      row['order_ref']?.toString(),
    }.where((value) => value != null && value.trim().isNotEmpty).cast<String>();
    if (keys.isEmpty) return;

    Map<String, dynamic>? existing;
    for (final key in keys) {
      existing ??= target[key];
    }

    final merged = existing == null
        ? Map<String, dynamic>.from(row)
        : preferRemote
            ? {
                ...existing,
                ...row,
                if ((row['order_ref']?.toString().trim().isEmpty ?? true) &&
                    (existing['order_ref']?.toString().trim().isNotEmpty ??
                        false))
                  'order_ref': existing['order_ref'],
                if ((row['order_items'] as List?)?.isEmpty ?? true)
                  'order_items': existing['order_items'] ?? const [],
              }
            : {
                ...row,
                ...existing,
                if ((existing['order_ref']?.toString().trim().isEmpty ??
                        true) &&
                    (row['order_ref']?.toString().trim().isNotEmpty ?? false))
                  'order_ref': row['order_ref'],
              };

    for (final key in keys) {
      target[key] = merged;
    }
    final canonicalKey = _orderRowKey(merged);
    if (canonicalKey.isNotEmpty) target[canonicalKey] = merged;
  }

  static Future<bool> _saveOrderSnapshot(Map<String, dynamic> order) async {
    final orders = await _storedOrders();
    final key = order['order_ref']?.toString() ?? order['id']?.toString();
    orders.removeWhere((row) =>
        (row['order_ref']?.toString() ?? row['id']?.toString()) == key);
    orders.insert(0, order);
    if (orders.length > 50) orders.removeRange(50, orders.length);

    var saved = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = await prefs.setString(_ordersStorageKey, jsonEncode(orders));
    } catch (_) {}
    try {
      await client.auth.updateUser(
        UserAttributes(data: {_ordersMetadataKey: orders}),
      );
      saved = true;
    } catch (_) {}
    return saved;
  }

  static bool _isMissingAddressTable(Object error) {
    final message = error.toString();
    return message.contains('user_addresses') &&
        (message.contains('PGRST205') || message.contains('schema cache'));
  }

  static List<Map<String, dynamic>> _metadataAddresses() {
    final raw = currentUser?.userMetadata?[_addressMetadataKey];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<void> _saveMetadataAddresses(
      List<Map<String, dynamic>> addresses) async {
    await client.auth.updateUser(
      UserAttributes(data: {_addressMetadataKey: addresses}),
    );
  }

  static Future<List<Map<String, dynamic>>> fetchAddresses() async {
    final uid = currentUser?.id;
    if (uid == null) return const [];
    try {
      final response = await client
          .from('user_addresses')
          .select()
          .eq('user_id', uid)
          .order('is_default', ascending: false)
          .order('created_at');
      final rows = List<Map<String, dynamic>>.from(response);
      return rows.isEmpty && _metadataAddresses().isNotEmpty
          ? _metadataAddresses()
          : rows;
    } catch (error) {
      if (_isMissingAddressTable(error)) return _metadataAddresses();
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> insertAddress(
      Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('Please sign in to save an address.');
    try {
      try {
        return await client
            .from('user_addresses')
            .insert({'user_id': uid, ...data})
            .select()
            .single();
      } catch (error) {
        if (_isMissingAddressTable(error)) rethrow;
        if (!error.toString().contains('alternate_phone')) rethrow;
        final legacyData = Map<String, dynamic>.from(data)
          ..remove('alternate_phone');
        return await client
            .from('user_addresses')
            .insert({'user_id': uid, ...legacyData})
            .select()
            .single();
      }
    } catch (error) {
      if (!_isMissingAddressTable(error)) rethrow;
      final saved = <String, dynamic>{
        'id': 'addr${DateTime.now().microsecondsSinceEpoch}',
        'user_id': uid,
        ...data,
      };
      final addresses = _metadataAddresses()..add(saved);
      await _saveMetadataAddresses(addresses);
      return saved;
    }
  }

  static Future<void> updateAddress(
      String id, Map<String, dynamic> data) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('Please sign in to update an address.');
    try {
      await client
          .from('user_addresses')
          .update(data)
          .eq('id', id)
          .eq('user_id', uid);
    } catch (error) {
      if (_isMissingAddressTable(error)) {
        final addresses = _metadataAddresses();
        final index = addresses.indexWhere((item) => item['id'] == id);
        if (index == -1) {
          addresses.add({'id': id, 'user_id': uid, ...data});
        } else {
          addresses[index] = {...addresses[index], ...data};
        }
        await _saveMetadataAddresses(addresses);
      } else {
        if (!error.toString().contains('alternate_phone')) rethrow;
        final legacyData = Map<String, dynamic>.from(data)
          ..remove('alternate_phone');
        await client
            .from('user_addresses')
            .update(legacyData)
            .eq('id', id)
            .eq('user_id', uid);
      }
    }
  }

  static Future<void> deleteAddress(String id) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await client
          .from('user_addresses')
          .delete()
          .eq('id', id)
          .eq('user_id', uid);
    } catch (error) {
      if (!_isMissingAddressTable(error)) rethrow;
      final addresses = _metadataAddresses()
        ..removeWhere((item) => item['id'] == id);
      await _saveMetadataAddresses(addresses);
    }
  }

  // ── Wishlist ──────────────────────────────────────────────────────────────
  static Future<List<String>> fetchWishlistIds() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    final response =
        await client.from('wishlist').select('product_id').eq('user_id', uid);
    return List<Map<String, dynamic>>.from(response)
        .map((r) => r['product_id'] as String)
        .toList();
  }

  static Future<void> addToWishlist(String productId) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await client
        .from('wishlist')
        .upsert({'user_id': uid, 'product_id': productId});
  }

  static Future<void> removeFromWishlist(String productId) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    await client
        .from('wishlist')
        .delete()
        .eq('user_id', uid)
        .eq('product_id', productId);
  }

  static Future<Map<String, dynamic>?> fetchProductById(String id) async {
    final response =
        await client.from('products').select().eq('id', id).maybeSingle();
    return response;
  }

  static Future<void> deleteProduct(String id) async {
    await client.from('products').delete().eq('id', id);
  }

  static Future<void> updateProduct(
      String id, Map<String, dynamic> data) async {
    await client.from('products').update(data).eq('id', id);
  }

  // ── Orders ───────────────────────────────────────────────────────────────
  // Persists the order + line items so it shows up in the admin dashboard
  // and so the admin can message the customer's WhatsApp number later.
  // Requires an `orders` table with (at least): id, user_id, status, total,
  // whatsapp_number, delivery_address, payment_method, created_at, and an
  // `order_items` table with: order_id, product_name, quantity, price.
  // Best-effort: never throws, so a missing column/table doesn't block
  // checkout — it just means the order won't be visible to admin yet.
  static Future<String?> createOrder({
    required String orderRef,
    required String whatsappNumber,
    String alternateWhatsappNumber = '',
    required String deliveryAddress,
    required String paymentMethod,
    required double subtotal,
    required double tax,
    required double total,
    required List<Map<String, dynamic>> items,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final generatedOrderId = _uuidV4();

    final orderData = <String, dynamic>{
      'id': generatedOrderId,
      'user_id': uid,
      'order_ref': orderRef,
      'status': 'confirmed',
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'whatsapp_number': whatsappNumber,
      'alternate_whatsapp_number': alternateWhatsappNumber,
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod,
    };
    final orderSnapshot = <String, dynamic>{
      'id': generatedOrderId,
      'order_ref': orderRef,
      'user_id': uid,
      'status': 'confirmed',
      'subtotal': subtotal,
      'tax': tax,
      'total': total,
      'whatsapp_number': whatsappNumber,
      'alternate_whatsapp_number': alternateWhatsappNumber,
      'delivery_address': deliveryAddress,
      'payment_method': paymentMethod,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'order_items': [
        for (final item in items) Map<String, dynamic>.from(item)
      ],
    };

    final compatibleData = Map<String, dynamic>.from(orderData);
    const optionalLegacyColumns = [
      'alternate_whatsapp_number',
      'order_ref',
      'subtotal',
      'tax',
      'whatsapp_number',
      'delivery_address',
      'payment_method',
    ];
    lastOrderSaveError = null;

    try {
      Map<String, dynamic>? inserted;
      var insertCompleted = false;

      // Production databases created by older app versions can be missing one
      // or more optional columns. Remove only the column named by PostgREST and
      // retry; required identity/status/total fields are never discarded.
      while (!insertCompleted) {
        try {
          inserted = await client
              .from('orders')
              .insert(compatibleData)
              .select('id')
              .maybeSingle();
          insertCompleted = true;
        } catch (error) {
          lastOrderSaveError = error.toString();
          final message = error.toString();
          String? missingColumn;
          for (final column in optionalLegacyColumns) {
            if (compatibleData.containsKey(column) &&
                message.contains(column)) {
              missingColumn = column;
              break;
            }
          }
          if (missingColumn == null) rethrow;
          compatibleData.remove(missingColumn);
        }
      }

      // Legacy deployments use bigint IDs while the current migration uses
      // UUIDs. Treat both as opaque strings throughout the Flutter app.
      final orderId = inserted?['id']?.toString();

      if (orderId != null && items.isNotEmpty) {
        try {
          await client.from('order_items').insert([
            for (final item in items) {...item, 'order_id': orderId},
          ]);
        } catch (error) {
          try {
            await client.from('order_items').insert([
              for (final item in items)
                {
                  'order_id': orderId,
                  'product_name': item['product_name'],
                  'quantity': item['quantity'],
                  'price': item['unit_price'] ?? item['price'] ?? 0,
                  if (item['image_url'] != null) 'image_url': item['image_url'],
                },
            ]);
          } catch (_) {
            // The order is already saved; an old line-item schema must not
            // cause the customer to place and pay for a duplicate order.
          }
        }
      }
      await _saveOrderSnapshot(orderSnapshot);
      return orderId ?? generatedOrderId;
    } catch (error) {
      lastOrderSaveError = error.toString();
      try {
        await client.from('orders').insert(compatibleData);
        await _saveOrderSnapshot(orderSnapshot);
        return orderRef;
      } catch (fallbackError) {
        lastOrderSaveError = fallbackError.toString();
      }
      await _saveOrderSnapshot(orderSnapshot);
      return null;
    }
  }

  static String _uuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final chars = bytes.map(hex).join();
    return '${chars.substring(0, 8)}-'
        '${chars.substring(8, 12)}-'
        '${chars.substring(12, 16)}-'
        '${chars.substring(16, 20)}-'
        '${chars.substring(20)}';
  }

  static Future<Map<String, dynamic>> fetchDashboardStats() async {
    final products = await client.from('products').select('stock, category');
    final productsList = List<Map<String, dynamic>>.from(products);

    int totalOrders = 0;
    int pendingShipments = 0;
    double monthRevenue = 0;
    int activeUsers = 0;

    try {
      final orders =
          await client.from('orders').select('status, total, created_at');
      final ordersList = List<Map<String, dynamic>>.from(orders);
      totalOrders = ordersList.length;
      final now = DateTime.now();
      for (final o in ordersList) {
        final status = (o['status'] as String? ?? '').toLowerCase();
        if (status != 'delivered' && status != 'cancelled') pendingShipments++;
        final createdAt = DateTime.tryParse(o['created_at'] as String? ?? '');
        if (createdAt != null &&
            createdAt.year == now.year &&
            createdAt.month == now.month) {
          monthRevenue += (o['total'] as num?)?.toDouble() ?? 0;
        }
      }
    } catch (_) {
      // orders table may be empty or inaccessible — fall back to zeros
    }

    try {
      final profiles = await client.from('profiles').select('id');
      activeUsers = (profiles as List).length;
    } catch (_) {}

    final byCategory = <String, List<int>>{};
    for (final p in productsList) {
      final cat = (p['category'] as String? ?? '').trim();
      final key = cat.isEmpty ? 'Other' : cat;
      byCategory
          .putIfAbsent(key, () => [])
          .add((p['stock'] as num?)?.toInt() ?? 0);
    }
    final stockHealth = byCategory.entries.map((e) {
      final healthy = e.value.where((s) => s > 5).length;
      final pct = e.value.isEmpty ? 0.0 : healthy / e.value.length;
      return {'label': e.key, 'value': pct};
    }).toList()
      ..sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));

    return {
      'totalOrders': totalOrders,
      'pendingShipments': pendingShipments,
      'monthRevenue': monthRevenue,
      'activeUsers': activeUsers,
      'stockHealth': stockHealth.take(3).toList(),
    };
  }

  static Future<List<Map<String, dynamic>>> fetchRecentOrders(
      {int limit = 3}) async {
    try {
      final response = await client
          .from('orders')
          .select(
              'id, order_ref, status, total, created_at, whatsapp_number, delivery_address, order_items(product_name, quantity)')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await client
            .from('orders')
            .select(
                'id, status, total, created_at, whatsapp_number, delivery_address, order_items(product_name, quantity)')
            .order('created_at', ascending: false)
            .limit(limit);
        return List<Map<String, dynamic>>.from(response);
      } catch (_) {
        try {
          final response = await client
              .from('orders')
              .select(
                  'id, order_ref, status, total, created_at, whatsapp_number, delivery_address')
              .order('created_at', ascending: false)
              .limit(limit);
          return List<Map<String, dynamic>>.from(response)
              .map((row) => {...row, 'order_items': const []})
              .toList();
        } catch (_) {
          return [];
        }
      }
    }
  }

  // Full order list for the admin "Manage Orders" screen — same shape as
  // fetchRecentOrders but unlimited, so admin can find and update any order.
  static Future<List<Map<String, dynamic>>> fetchAllOrders() async {
    try {
      final response = await client
          .from('orders')
          .select(
              'id, order_ref, status, total, created_at, updated_at, whatsapp_number, delivery_address, payment_method, courier_name, tracking_number, estimated_delivery, status_note, admin_note, order_items(product_name, quantity)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await client
            .from('orders')
            .select(
                'id, order_ref, status, total, created_at, whatsapp_number, delivery_address, order_items(product_name, quantity)')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (_) {
        try {
          final response = await client
              .from('orders')
              .select(
                  'id, status, total, created_at, whatsapp_number, delivery_address, payment_method, order_items(product_name, quantity, price)')
              .order('created_at', ascending: false);
          return List<Map<String, dynamic>>.from(response);
        } catch (_) {
          try {
            final response = await client
                .from('orders')
                .select(
                    'id, order_ref, status, total, created_at, updated_at, whatsapp_number, delivery_address, payment_method, courier_name, tracking_number, estimated_delivery, status_note, admin_note')
                .order('created_at', ascending: false);
            return List<Map<String, dynamic>>.from(response)
                .map((row) => {...row, 'order_items': const []})
                .toList();
          } catch (_) {
            try {
              final response = await client
                  .from('orders')
                  .select(
                      'id, order_ref, status, total, created_at, whatsapp_number, delivery_address, payment_method')
                  .order('created_at', ascending: false);
              return List<Map<String, dynamic>>.from(response)
                  .map((row) => {...row, 'order_items': const []})
                  .toList();
            } catch (_) {
              return [];
            }
          }
        }
      }
    }
  }

  // Admin sets the real status of an order (confirmed / preparing /
  // dispatched / delivered / cancelled — see OrderStatus). This is the only
  // thing that should ever change orders.status, so the customer's tracking
  // screen and this admin action always agree on what's true.
  static Future<OrderUpdateResult> updateOrderStatus({
    required String orderId,
    required String status,
    String? courierName,
    String? trackingNumber,
    String? estimatedDelivery,
    String? statusNote,
    String? adminNote,
  }) async {
    final hasTrackingDetails = courierName != null ||
        trackingNumber != null ||
        estimatedDelivery != null ||
        statusNote != null ||
        adminNote != null;
    try {
      final update = <String, dynamic>{
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (courierName != null) 'courier_name': courierName.trim(),
        if (trackingNumber != null) 'tracking_number': trackingNumber.trim(),
        if (estimatedDelivery != null)
          'estimated_delivery': estimatedDelivery.trim().isEmpty
              ? null
              : estimatedDelivery.trim(),
        if (statusNote != null) 'status_note': statusNote.trim(),
        if (adminNote != null) 'admin_note': adminNote.trim(),
      };
      final updatedRow = await client
          .from('orders')
          .update(update)
          .eq('id', orderId)
          .select('id')
          .maybeSingle();
      if (updatedRow == null) {
        return const OrderUpdateResult(
          statusSaved: false,
          detailsSaved: false,
        );
      }
      try {
        await client.from('order_status_history').insert({
          'order_id': orderId,
          'status': status,
          'note': statusNote?.trim() ?? '',
          'changed_by': currentUser?.id,
        });
      } catch (_) {}
      return const OrderUpdateResult(statusSaved: true, detailsSaved: true);
    } catch (_) {
      // Legacy schema fallback: status control still works before the optional
      // tracking-detail migration is applied.
      try {
        final updatedRow = await client
            .from('orders')
            .update({'status': status})
            .eq('id', orderId)
            .select('id')
            .maybeSingle();
        if (updatedRow == null) {
          return const OrderUpdateResult(
            statusSaved: false,
            detailsSaved: false,
          );
        }
        return OrderUpdateResult(
          statusSaved: true,
          detailsSaved: !hasTrackingDetails,
        );
      } catch (_) {
        return const OrderUpdateResult(statusSaved: false, detailsSaved: false);
      }
    }
  }

  // The signed-in customer's own orders, for the "My Orders" tracking
  // screen. RLS already restricts this to auth.uid() = user_id.
  static Future<List<Map<String, dynamic>>> fetchMyOrders() async {
    final uid = currentUser?.id;
    if (uid == null) return [];
    var remoteRows = <Map<String, dynamic>>[];
    try {
      final response = await client
          .from('orders')
          .select(
              'id, order_ref, status, subtotal, tax, total, payment_method, created_at, whatsapp_number, delivery_address, courier_name, tracking_number, estimated_delivery, status_note, order_items(product_name, quantity, unit_price)')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      remoteRows = List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await client
            .from('orders')
            .select(
                'id, order_ref, status, subtotal, tax, total, payment_method, created_at, whatsapp_number, delivery_address, order_items(product_name, quantity, unit_price)')
            .eq('user_id', uid)
            .order('created_at', ascending: false);
        remoteRows = List<Map<String, dynamic>>.from(response);
      } catch (_) {
        try {
          final response = await client
              .from('orders')
              .select(
                  'id, status, total, payment_method, created_at, whatsapp_number, delivery_address, order_items(product_name, quantity, price)')
              .eq('user_id', uid)
              .order('created_at', ascending: false);
          remoteRows = List<Map<String, dynamic>>.from(response);
        } catch (_) {}
      }
    }

    final mergedByKey = <String, Map<String, dynamic>>{};
    for (final row in await _storedOrders()) {
      _putMergedOrder(mergedByKey, row, preferRemote: false);
    }
    for (final row in remoteRows) {
      _putMergedOrder(mergedByKey, row, preferRemote: true);
    }
    final seen = <Map<String, dynamic>>{};
    final result = <Map<String, dynamic>>[];
    for (final row in mergedByKey.values) {
      if (seen.add(row)) result.add(row);
    }
    result
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));
    return result;
  }

  // Web-safe upload: works on Flutter Web, mobile, and desktop since it
  // never touches dart:io File — just raw bytes.
  static Future<String> uploadProductImageBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final storagePath = 'products/$fileName';
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };

    await client.storage.from('product-images').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );

    return client.storage.from('product-images').getPublicUrl(storagePath);
  }

  // ── Analytics ─────────────────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> fetchAllOrdersForAnalytics() async {
    try {
      final response = await client
          .from('orders')
          .select(
              'id, status, total, created_at, order_items(product_name, quantity)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      try {
        final response = await client
            .from('orders')
            .select('id, status, total, created_at')
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(response)
            .map((row) => {...row, 'order_items': const []})
            .toList();
      } catch (_) {
        return [];
      }
    }
  }

  static Future<List<Map<String, dynamic>>> fetchAllUsersForAnalytics() async {
    try {
      final response = await client.from('profiles').select('id, created_at');
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  static Future<String> uploadAvatarBytes({
    required Uint8List bytes,
    required String fileName,
  }) async {
    const bucket = 'avatars';
    final storagePath = fileName;
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'jpg';
    final contentType = switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    await client.storage.from(bucket).uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return client.storage.from(bucket).getPublicUrl(storagePath);
  }
}

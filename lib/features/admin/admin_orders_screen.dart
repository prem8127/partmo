import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/invoice_service.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/order_status.dart';

/// Lets admin see every order and change its real status. This status is
/// the exact same value the customer's "My Orders" tracking screen reads,
/// so updating it here is what makes tracking accurate.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const [];
  final Set<String> _updating = {};
  final _searchController = TextEditingController();
  String _filter = 'active';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final orders = await SupabaseService.fetchAllOrders();
    if (!mounted) return;
    setState(() {
      _orders = orders;
      _loading = false;
    });
  }

  Future<void> _changeStatus(
    String orderId,
    String newStatus, {
    String? courierName,
    String? trackingNumber,
    String? estimatedDelivery,
    String? statusNote,
    String? adminNote,
  }) async {
    setState(() => _updating.add(orderId));
    final normalizedStatus = OrderStatus.normalize(newStatus);
    final result = await SupabaseService.updateOrderStatus(
      orderId: orderId,
      status: normalizedStatus,
      courierName: courierName,
      trackingNumber: trackingNumber,
      estimatedDelivery: estimatedDelivery,
      statusNote: statusNote,
      adminNote: adminNote,
    );
    if (!mounted) return;
    setState(() {
      _updating.remove(orderId);
      if (result.statusSaved) {
        final i = _orders.indexWhere((o) => o['id']?.toString() == orderId);
        if (i != -1) {
          _orders[i] = {
            ..._orders[i],
            'status': normalizedStatus,
            if (result.detailsSaved && courierName != null)
              'courier_name': courierName,
            if (result.detailsSaved && trackingNumber != null)
              'tracking_number': trackingNumber,
            if (result.detailsSaved && estimatedDelivery != null)
              'estimated_delivery': estimatedDelivery,
            if (result.detailsSaved && statusNote != null)
              'status_note': statusNote,
            if (result.detailsSaved && adminNote != null)
              'admin_note': adminNote,
          };
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.statusSaved
              ? 'Order updated to ${OrderStatus.label(normalizedStatus)}'
              : 'Could not update order — try again',
        ),
      ),
    );
  }

  Future<void> _openControls(
    Map<String, dynamic> order, {
    String? initialStatus,
  }) async {
    final update = await showModalBottomSheet<_OrderUpdate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _OrderControlSheet(order: order, initialStatus: initialStatus),
    );
    if (update == null) return;
    await _changeStatus(
      order['id']?.toString() ?? '',
      update.status,
      courierName: update.courierName,
      trackingNumber: update.trackingNumber,
      estimatedDelivery: update.estimatedDelivery,
      statusNote: update.statusNote,
      adminNote: update.adminNote,
    );
  }

  Future<void> _downloadInvoice(Map<String, dynamic> order) async {
    try {
      final id = order['order_ref']?.toString().trim().isNotEmpty == true
          ? order['order_ref'].toString()
          : order['id']?.toString() ?? 'order';
      final total = (order['total'] as num?)?.toDouble() ?? 0;
      final subtotal = (order['subtotal'] as num?)?.toDouble() ?? total;
      final tax = (order['tax'] as num?)?.toDouble() ?? 0;
      final items = ((order['order_items'] as List?) ?? const [])
          .whereType<Map>()
          .map((raw) => Map<String, dynamic>.from(raw))
          .toList();
      await InvoiceService.downloadInvoice(
        InvoiceData(
          orderId: id,
          orderDate: _formatDate(order['created_at']?.toString()),
          customerName: _customerNameFromOrder(order),
          customerEmail: order['customer_email']?.toString() ?? '',
          deliveryAddress: _customerAddressFromOrder(order).isEmpty
              ? 'Address unavailable'
              : _customerAddressFromOrder(order),
          paymentMethod:
              order['payment_method']?.toString().trim().isNotEmpty == true
                  ? order['payment_method'].toString()
                  : 'Online Payment',
          deliveryCharge: 0,
          subtotalAmount: subtotal > 0 ? subtotal : total,
          gstAmountValue: tax,
          grandTotalAmount: total,
          items: items.isEmpty
              ? [
                  InvoiceItem(
                    name: 'Automotive Spare Part',
                    description: 'PartMo order item',
                    qty: 1,
                    unitPrice: total,
                  ),
                ]
              : items
                  .map(
                    (item) => InvoiceItem(
                      name: item['product_name']?.toString() ?? 'Part',
                      description: 'Automotive spare part',
                      qty: (item['quantity'] as num?)?.toInt() ?? 1,
                      unitPrice: (item['unit_price'] as num?)?.toDouble() ??
                          (item['price'] as num?)?.toDouble() ??
                          0,
                    ),
                  )
                  .toList(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Invoice error: $e')));
    }
  }

  bool _matchesFilter(Map<String, dynamic> order) {
    final status = OrderStatus.normalize(order['status'] as String? ?? '');
    if (_filter == 'active' &&
        (OrderStatus.isTerminal(status) ||
            OrderStatus.isIssue(status) ||
            OrderStatus.isReturn(status))) {
      return false;
    }
    if (_filter == 'delivered' && status != OrderStatus.delivered) return false;
    if (_filter == 'issues' && !OrderStatus.isIssue(status)) return false;
    if (_filter == 'returns' && !OrderStatus.isReturn(status)) return false;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final haystack = '${order['order_ref']} ${order['id']} '
            '${order['whatsapp_number']} ${order['delivery_address']} '
            '${order['tracking_number']} ${order['order_items']}'
        .toLowerCase();
    return haystack.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final visibleOrders = _orders.where(_matchesFilter).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.fromLTRB(
                  14,
                  MediaQuery.paddingOf(context).top + 12,
                  14,
                  12,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.go('/admin'),
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppPalette.navy,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Manage Orders',
                      style: TextStyle(
                        color: AppPalette.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _load,
                      icon: const Icon(
                        Icons.refresh,
                        color: AppPalette.navy,
                        size: 20,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search order, phone or tracking ID',
                        prefixIcon: const Icon(Icons.search, size: 19),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF4F7FB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final entry in const {
                            'active': 'Active',
                            'all': 'All',
                            'delivered': 'Delivered',
                            'issues': 'Issues',
                            'returns': 'Returns',
                          }.entries)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: ChoiceChip(
                                label: Text(entry.value),
                                selected: _filter == entry.key,
                                onSelected: (_) =>
                                    setState(() => _filter = entry.key),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : visibleOrders.isEmpty
                          ? ListView(
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 80),
                                  child: Center(
                                    child: Text(
                                      'No matching orders.',
                                      style: TextStyle(
                                        color: AppPalette.muted,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(14),
                              itemCount: visibleOrders.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) {
                                final o = visibleOrders[i];
                                final id = o['id']?.toString() ?? '';
                                return _AdminOrderCard(
                                  order: o,
                                  isUpdating: _updating.contains(id),
                                  onStatusChanged: (status) =>
                                      _changeStatus(id, status),
                                  onManage: (status) =>
                                      _openControls(o, initialStatus: status),
                                  onInvoice: () => _downloadInvoice(o),
                                );
                              },
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({
    required this.order,
    required this.isUpdating,
    required this.onStatusChanged,
    required this.onManage,
    required this.onInvoice,
  });

  final Map<String, dynamic> order;
  final bool isUpdating;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String?> onManage;
  final VoidCallback onInvoice;

  @override
  Widget build(BuildContext context) {
    final id = order['id']?.toString() ?? '';
    final orderRef = order['order_ref']?.toString().trim() ?? '';
    final displayId = orderRef.isNotEmpty ? orderRef : _displayFallbackRef(id);
    final status = OrderStatus.normalize(
      order['status'] as String? ?? OrderStatus.confirmed,
    );
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final itemsRaw = (order['order_items'] as List?) ?? const [];
    final itemsText = itemsRaw.isEmpty
        ? 'No items on record'
        : itemsRaw
            .map(
              (i) =>
                  '${(i as Map)['product_name'] ?? ''} x${i['quantity'] ?? 1}',
            )
            .join(', ');
    final whatsapp = order['whatsapp_number'] as String? ?? '';
    final address = _customerAddressFromOrder(order);
    final customerName = _customerNameFromOrder(order);
    final courier = order['courier_name'] as String? ?? '';
    final tracking = order['tracking_number'] as String? ?? '';
    final nextStatus = OrderStatus.recommendedNext(status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  displayId,
                  style: const TextStyle(
                    color: AppPalette.navy,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: AppPalette.navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            itemsText,
            style: const TextStyle(
              color: Color(0xFF657583),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (whatsapp.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '$customerName • WhatsApp: $whatsapp',
              style: const TextStyle(
                color: Color(0xFF9AA6B1),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address,
              style: const TextStyle(
                color: Color(0xFF657583),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (courier.isNotEmpty || tracking.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              [
                if (courier.isNotEmpty) courier,
                if (tracking.isNotEmpty) 'AWB $tracking',
              ].join(' • '),
              style: const TextStyle(
                color: AppPalette.navy,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (isUpdating)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'CURRENT STATUS',
                      style: TextStyle(
                        color: Color(0xFF7E8D99),
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: OrderStatus.isIssue(status)
                            ? const Color(0xFFFFE8E8)
                            : const Color(0xFFE7F7EF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        OrderStatus.label(status),
                        style: TextStyle(
                          color: OrderStatus.isIssue(status)
                              ? AppPalette.danger
                              : const Color(0xFF16855A),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: OutlinedButton.icon(
                        onPressed: () => onManage(null),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(92, 38),
                        ),
                        icon: const Icon(Icons.tune, size: 16),
                        label: const FittedBox(child: Text('Manage')),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      child: OutlinedButton(
                        onPressed: onInvoice,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(44, 38),
                        ),
                        child: const Icon(Icons.download_outlined, size: 17),
                      ),
                    ),
                    if (nextStatus != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: nextStatus == OrderStatus.shipped
                              ? () => onManage(nextStatus)
                              : () => onStatusChanged(nextStatus),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppPalette.navy,
                          ),
                          icon: const Icon(Icons.arrow_forward, size: 15),
                          label: Text(
                            OrderStatus.label(nextStatus),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

String _displayFallbackRef(String id) {
  if (id.isEmpty) return '';
  final compact = id.replaceAll('-', '');
  final suffix = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return '#PM-${suffix.toUpperCase()}';
}

String _customerAddressFromOrder(Map<String, dynamic> order) =>
    order['delivery_address']?.toString().trim() ?? '';

String _customerNameFromOrder(Map<String, dynamic> order) {
  final explicit = order['customer_name']?.toString().trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;
  final address = _customerAddressFromOrder(order);
  if (address.contains(',')) {
    final first = address.split(',').first.trim();
    if (first.isNotEmpty) return first;
  }
  final phone = order['whatsapp_number']?.toString().trim();
  if (phone != null && phone.isNotEmpty) return 'Customer $phone';
  return 'Customer';
}

String _formatDate(String? raw) {
  final parsed = DateTime.tryParse(raw ?? '');
  if (parsed == null) return DateTime.now().toString().substring(0, 10);
  return '${parsed.day}/${parsed.month}/${parsed.year}';
}

class _OrderUpdate {
  const _OrderUpdate({
    required this.status,
    required this.courierName,
    required this.trackingNumber,
    required this.estimatedDelivery,
    required this.statusNote,
    required this.adminNote,
  });

  final String status;
  final String courierName;
  final String trackingNumber;
  final String estimatedDelivery;
  final String statusNote;
  final String adminNote;
}

class _OrderControlSheet extends StatefulWidget {
  const _OrderControlSheet({required this.order, this.initialStatus});
  final Map<String, dynamic> order;
  final String? initialStatus;

  @override
  State<_OrderControlSheet> createState() => _OrderControlSheetState();
}

class _OrderControlSheetState extends State<_OrderControlSheet> {
  late String _status;
  late final TextEditingController _courier;
  late final TextEditingController _tracking;
  late final TextEditingController _eta;
  late final TextEditingController _customerNote;
  late final TextEditingController _adminNote;

  @override
  void initState() {
    super.initState();
    _status = OrderStatus.normalize(
      widget.initialStatus ?? (widget.order['status'] as String?) ?? '',
    );
    _courier = TextEditingController(
      text: widget.order['courier_name'] as String? ?? '',
    );
    _tracking = TextEditingController(
      text: widget.order['tracking_number'] as String? ?? '',
    );
    _eta = TextEditingController(
      text: widget.order['estimated_delivery'] as String? ?? '',
    );
    _customerNote = TextEditingController(
      text: widget.order['status_note'] as String? ?? '',
    );
    _adminNote = TextEditingController(
      text: widget.order['admin_note'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _courier.dispose();
    _tracking.dispose();
    _eta.dispose();
    _customerNote.dispose();
    _adminNote.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final needsReason = OrderStatus.isIssue(_status) ||
        OrderStatus.isReturn(_status) ||
        _status == OrderStatus.refunded;
    final needsShipping = const [
      OrderStatus.shipped,
      OrderStatus.outForDelivery,
      OrderStatus.delivered,
    ].contains(_status);
    final statusOptions = {
      _status,
      ...OrderStatus.nextStatuses(_status),
    }.toList();
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .9,
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Control',
              style: TextStyle(
                color: AppPalette.navy,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Update fulfilment and delivery information.',
              style: TextStyle(color: AppPalette.muted, fontSize: 11),
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Order status'),
              items: [
                for (final status in statusOptions)
                  DropdownMenuItem(
                    value: status,
                    child: Text(OrderStatus.label(status)),
                  ),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _field(_courier, 'Courier / delivery partner')),
                const SizedBox(width: 10),
                Expanded(child: _field(_tracking, 'Tracking ID / AWB')),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eta,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Estimated delivery',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 180)),
                  initialDate: DateTime.tryParse(_eta.text) ?? DateTime.now(),
                );
                if (picked != null) {
                  _eta.text = picked.toIso8601String().split('T').first;
                }
              },
            ),
            const SizedBox(height: 12),
            _field(
              _customerNote,
              needsReason ? 'Customer-visible reason *' : 'Customer update',
            ),
            const SizedBox(height: 12),
            _field(_adminNote, 'Private admin note', maxLines: 2),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppPalette.navy),
                onPressed: () {
                  if (needsReason && _customerNote.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Add a customer-visible reason.'),
                      ),
                    );
                    return;
                  }
                  if (needsShipping &&
                      (_courier.text.trim().isEmpty ||
                          _tracking.text.trim().isEmpty)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Courier and tracking ID are required after packing.',
                        ),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    _OrderUpdate(
                      status: _status,
                      courierName: _courier.text,
                      trackingNumber: _tracking.text,
                      estimatedDelivery: _eta.text,
                      statusNote: _customerNote.text,
                      adminNote: _adminNote.text,
                    ),
                  );
                },
                child: const Text(
                  'Save order update',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}

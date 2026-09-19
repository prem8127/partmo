import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class AdminSalesReportsScreen extends StatefulWidget {
  const AdminSalesReportsScreen({super.key});

  @override
  State<AdminSalesReportsScreen> createState() =>
      _AdminSalesReportsScreenState();
}

class _AdminSalesReportsScreenState extends State<AdminSalesReportsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _lowStock = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      SupabaseService.fetchAllOrders(),
      SupabaseService.fetchLowStockProducts(),
    ]);
    if (!mounted) return;
    setState(() {
      _orders = results[0];
      _lowStock = results[1];
      _loading = false;
    });
  }

  List<_SoldRow> get _soldRows {
    final rows = <_SoldRow>[];
    for (final order in _orders) {
      final status = (order['status']?.toString() ?? '').toLowerCase();
      if (status == 'cancelled' || status.startsWith('return')) continue;
      final items = (order['order_items'] as List?) ?? const [];
      for (final raw in items.whereType<Map>()) {
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        final price = (raw['unit_price'] as num?)?.toDouble() ??
            (raw['price'] as num?)?.toDouble() ??
            0;
        rows.add(_SoldRow(
          orderRef:
              order['order_ref']?.toString() ?? order['id']?.toString() ?? '',
          product: raw['product_name']?.toString() ?? 'Product',
          quantity: qty,
          amount: qty * price,
          customer: order['whatsapp_number']?.toString() ?? '',
          date: order['created_at']?.toString().split('T').first ?? '',
        ));
      }
    }
    return rows;
  }

  List<_DailyRow> get _dailyRows {
    final map = <String, _DailyRow>{};
    for (final order in _orders) {
      final status = (order['status']?.toString() ?? '').toLowerCase();
      if (status == 'cancelled' || status.startsWith('return')) continue;
      final date = order['created_at']?.toString().split('T').first ?? '';
      if (date.isEmpty) continue;
      final items = (order['order_items'] as List?) ?? const [];
      final qty = items.whereType<Map>().fold<int>(
            0,
            (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
          );
      final existing = map[date] ?? _DailyRow(date: date);
      map[date] = existing.copyWith(
        orders: existing.orders + 1,
        products: existing.products + qty,
        amount: existing.amount + ((order['total'] as num?)?.toDouble() ?? 0),
      );
    }
    final rows = map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    return rows;
  }

  Future<void> _downloadCsv(String filename, String csv) async {
    final uri = Uri.dataFromString(
      csv,
      mimeType: 'text/csv',
      encoding: utf8,
    );
    await launchUrl(uri, webOnlyWindowName: '_blank');
  }

  String _soldCsv() {
    final lines = ['date,order_ref,product,quantity,amount,customer'];
    for (final row in _soldRows) {
      lines.add([
        row.date,
        row.orderRef,
        row.product,
        row.quantity,
        row.amount.toStringAsFixed(2),
        row.customer,
      ].map((value) => _csv(value.toString())).join(','));
    }
    return lines.join('\n');
  }

  String _dailyCsv() {
    final lines = ['date,orders,products_sold,total_sales'];
    for (final row in _dailyRows) {
      lines.add([
        row.date,
        row.orders,
        row.products,
        row.amount.toStringAsFixed(2),
      ].map((v) => _csv(v.toString())).join(','));
    }
    return lines.join('\n');
  }

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                    8,
                    MediaQuery.paddingOf(context).top + 10,
                    12,
                    12,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => context.go('/admin'),
                        icon: const Icon(Icons.arrow_back,
                            color: AppPalette.navy),
                      ),
                      const Expanded(
                        child: Text(
                          'Sales Reports',
                          style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh, color: AppPalette.navy),
                      ),
                    ],
                  ),
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 90),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _ReportSection(
                          title: 'Low Stock Alerts',
                          action: '${_lowStock.length} products',
                          children: _lowStock.isEmpty
                              ? const [Text('No low stock products.')]
                              : [
                                  for (final p in _lowStock.take(10))
                                    _Line(
                                      '${p['name'] ?? 'Product'}',
                                      'Stock ${(p['stock'] as num?)?.toInt() ?? 0}',
                                    ),
                                ],
                        ),
                        _ReportSection(
                          title: 'Sold Products',
                          action: 'Download',
                          onAction: () =>
                              _downloadCsv('sold-products.csv', _soldCsv()),
                          children: [
                            for (final row in _soldRows.take(15))
                              _Line(
                                row.product,
                                '${row.quantity} pcs • ₹${row.amount.toStringAsFixed(0)}',
                              ),
                          ],
                        ),
                        _ReportSection(
                          title: 'Daily Sales',
                          action: 'Download',
                          onAction: () =>
                              _downloadCsv('daily-sales.csv', _dailyCsv()),
                          children: [
                            for (final row in _dailyRows.take(15))
                              _Line(
                                row.date,
                                '${row.orders} orders • ${row.products} products • ₹${row.amount.toStringAsFixed(0)}',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.action,
    required this.children,
    this.onAction,
  });

  final String title;
  final String action;
  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppPalette.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ),
              TextButton(onPressed: onAction, child: Text(action)),
            ],
          ),
          const SizedBox(height: 8),
          if (children.isEmpty) const Text('No data yet.') else ...children,
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.left, this.right);
  final String left;
  final String right;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(left,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          Text(right,
              style: const TextStyle(
                  color: AppPalette.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SoldRow {
  const _SoldRow({
    required this.orderRef,
    required this.product,
    required this.quantity,
    required this.amount,
    required this.customer,
    required this.date,
  });
  final String orderRef;
  final String product;
  final int quantity;
  final double amount;
  final String customer;
  final String date;
}

class _DailyRow {
  const _DailyRow({
    required this.date,
    this.orders = 0,
    this.products = 0,
    this.amount = 0,
  });
  final String date;
  final int orders;
  final int products;
  final double amount;
  _DailyRow copyWith({int? orders, int? products, double? amount}) => _DailyRow(
        date: date,
        orders: orders ?? this.orders,
        products: products ?? this.products,
        amount: amount ?? this.amount,
      );
}

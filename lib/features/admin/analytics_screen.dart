import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

// ─── Analytics Screen ─────────────────────────────────────────────────────────
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

enum _Period { threeMonths, sixMonths, oneYear, monthly }

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _loading = true;
  _Period _period = _Period.sixMonths;
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _products = const [];
  List<Map<String, dynamic>> _users = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchAllOrdersForAnalytics(),
        SupabaseService.fetchProducts(),
        SupabaseService.fetchAllUsersForAnalytics(),
      ]);
      setState(() {
        _orders = results[0] as List<Map<String, dynamic>>;
        _products = results[1] as List<Map<String, dynamic>>;
        _users = results[2] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  DateTime get _cutoff {
    final now = DateTime.now();
    return switch (_period) {
      _Period.threeMonths => DateTime(now.year, now.month - 3, now.day),
      _Period.sixMonths => DateTime(now.year, now.month - 6, now.day),
      _Period.oneYear => DateTime(now.year - 1, now.month, now.day),
      _Period.monthly => DateTime(now.year, now.month, 1),
    };
  }

  List<Map<String, dynamic>> get _filteredOrders {
    final cut = _cutoff;
    return _orders.where((o) {
      final d = DateTime.tryParse(o['created_at'] as String? ?? '');
      return d != null && d.isAfter(cut);
    }).toList();
  }

  // group orders by month label → {label, revenue, count}
  List<_ChartBar> get _revenueChartData {
    final cut = _cutoff;
    final now = DateTime.now();
    final months = <String, _MutableStat>{};

    // seed all months in range
    var cur = DateTime(cut.year, cut.month, 1);
    while (cur.isBefore(DateTime(now.year, now.month + 1, 1))) {
      final label = _monthLabel(cur);
      months[label] = _MutableStat();
      cur = DateTime(cur.year, cur.month + 1, 1);
    }

    for (final o in _filteredOrders) {
      final d = DateTime.tryParse(o['created_at'] as String? ?? '');
      if (d == null) continue;
      final label = _monthLabel(d);
      months[label]?.revenue += (o['total'] as num?)?.toDouble() ?? 0;
      months[label]?.count++;
    }
    return months.entries
        .map((e) => _ChartBar(e.key, e.value.revenue, e.value.count))
        .toList();
  }

  String _monthLabel(DateTime d) => '${_mon(d.month)} ${d.year % 100}';
  String _mon(int m) => [
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
      ][m - 1];

  // top 5 products by order count from order_items
  List<_TopProduct> get _topProducts {
    final counts = <String, int>{};
    for (final o in _filteredOrders) {
      final items = (o['order_items'] as List?) ?? [];
      for (final item in items) {
        final name = (item as Map)['product_name'] as String? ?? 'Unknown';
        counts[name] = (counts[name] ?? 0) + ((item['quantity'] as int?) ?? 1);
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => _TopProduct(e.key, e.value)).toList();
  }

  // status breakdown
  Map<String, int> get _statusBreakdown {
    final map = <String, int>{};
    for (final o in _filteredOrders) {
      final s = ((o['status'] as String?) ?? 'unknown').toLowerCase();
      map[s] = (map[s] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredOrders;
    final totalRevenue = filtered.fold<double>(
        0, (s, o) => s + ((o['total'] as num?)?.toDouble() ?? 0));
    final avgOrder = filtered.isEmpty ? 0.0 : totalRevenue / filtered.length;
    final bars = _revenueChartData;
    final maxBar = bars.isEmpty
        ? 1.0
        : bars
            .map((b) => b.revenue)
            .reduce(math.max)
            .clamp(1.0, double.infinity);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const _AnalyticsBottomNav(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.fromLTRB(
                      16, MediaQuery.paddingOf(context).top + 14, 14, 12),
                  child: Row(
                    children: [
                      const Text('Analytics',
                          style: TextStyle(
                              color: Color(0xFF172635),
                              fontSize: 16,
                              fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh,
                              color: AppPalette.navy, size: 20),
                          visualDensity: VisualDensity.compact),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Period selector
                            _PeriodSelector(
                                selected: _period,
                                onChanged: (p) => setState(() => _period = p)),
                            const SizedBox(height: 16),

                            // Summary cards row
                            Row(children: [
                              Expanded(
                                  child: _MiniStat(
                                      'REVENUE',
                                      '₹${_compact(totalRevenue)}',
                                      AppPalette.navy,
                                      Icons.payments_outlined)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _MiniStat(
                                      'ORDERS',
                                      '${filtered.length}',
                                      AppPalette.cyan,
                                      Icons.receipt_long_outlined)),
                            ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Expanded(
                                  child: _MiniStat(
                                      'AVG ORDER',
                                      '₹${_compact(avgOrder)}',
                                      const Color(0xFF2FB36D),
                                      Icons.trending_up)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: _MiniStat(
                                      'PRODUCTS',
                                      '${_products.length}',
                                      AppPalette.warning,
                                      Icons.inventory_2_outlined)),
                            ]),
                            const SizedBox(height: 20),

                            // Revenue Bar Chart
                            const _SectionTitle('REVENUE BY MONTH'),
                            const SizedBox(height: 12),
                            if (bars.isEmpty)
                              _EmptyBox('No orders in this period')
                            else
                              _RevenueChart(bars: bars, maxVal: maxBar),
                            const SizedBox(height: 20),

                            // Order Status Breakdown
                            const _SectionTitle('ORDER STATUS BREAKDOWN'),
                            const SizedBox(height: 12),
                            _StatusBreakdown(
                                data: _statusBreakdown, total: filtered.length),
                            const SizedBox(height: 20),

                            // Top Products
                            const _SectionTitle('TOP PRODUCTS (BY QTY SOLD)'),
                            const SizedBox(height: 12),
                            if (_topProducts.isEmpty)
                              _EmptyBox('No product data yet')
                            else
                              _TopProductsList(items: _topProducts),
                            const SizedBox(height: 20),

                            // Users stat
                            const _SectionTitle('REGISTERED USERS'),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              color: Colors.white,
                              child: Row(children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF073B63)
                                          .withOpacity(.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: const Icon(Icons.groups_outlined,
                                      color: AppPalette.navy, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('${_users.length}',
                                          style: const TextStyle(
                                              color: Color(0xFF172635),
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900)),
                                      const Text('Total Registered Users',
                                          style: TextStyle(
                                              color: Color(0xFF657583),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600)),
                                    ]),
                              ]),
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

  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _MutableStat {
  double revenue = 0;
  int count = 0;
}

class _ChartBar {
  const _ChartBar(this.label, this.revenue, this.count);
  final String label;
  final double revenue;
  final int count;
}

class _TopProduct {
  const _TopProduct(this.name, this.qty);
  final String name;
  final int qty;
}

// ── Period Selector ────────────────────────────────────────────────────────────
class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onChanged});
  final _Period selected;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    const options = [
      (_Period.threeMonths, '3M'),
      (_Period.sixMonths, '6M'),
      (_Period.oneYear, '1Y'),
      (_Period.monthly, 'MTD'),
    ];
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: options.map((opt) {
          final active = selected == opt.$1;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(opt.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                decoration: BoxDecoration(
                  color: active ? AppPalette.navy : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  opt.$2,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFF657583),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Revenue Chart ──────────────────────────────────────────────────────────────
class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.bars, required this.maxVal});
  final List<_ChartBar> bars;
  final double maxVal;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: bars.map((bar) {
                final frac = (bar.revenue / maxVal).clamp(0.0, 1.0);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (bar.revenue > 0)
                          Text(
                            _compact(bar.revenue),
                            style: const TextStyle(
                                color: AppPalette.navy,
                                fontSize: 7,
                                fontWeight: FontWeight.w900),
                          ),
                        const SizedBox(height: 3),
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: frac.clamp(0.04, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppPalette.navy,
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: bars
                .map((bar) => Expanded(
                      child: Text(bar.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF657583))),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

// ── Status Breakdown ───────────────────────────────────────────────────────────
class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.data, required this.total});
  final Map<String, int> data;
  final int total;

  static const _colors = {
    'delivered': Color(0xFF2FB36D),
    'processing': Color(0xFFFFC233),
    'confirmed': Color(0xFF18B8E8),
    'shipped': Color(0xFF073B63),
    'cancelled': Color(0xFFE85050),
  };

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return _EmptyBox('No orders yet');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: data.entries.map((e) {
          final pct = total == 0 ? 0.0 : e.value / total;
          final color = _colors[e.key] ?? AppPalette.muted;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(children: [
              Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(e.key.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w900))),
                Text('${e.value} (${(pct * 100).round()}%)',
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 5),
              LinearProgressIndicator(
                  value: pct,
                  minHeight: 4,
                  color: color,
                  backgroundColor: const Color(0xFFE6ECF2)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Top Products ───────────────────────────────────────────────────────────────
class _TopProductsList extends StatelessWidget {
  const _TopProductsList({required this.items});
  final List<_TopProduct> items;

  @override
  Widget build(BuildContext context) {
    final maxQty = items.isEmpty ? 1 : items.first.qty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: items.asMap().entries.map((e) {
          final idx = e.key;
          final item = e.value;
          final pct = maxQty == 0 ? 0.0 : item.qty / maxQty;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              SizedBox(
                width: 18,
                child: Text('${idx + 1}',
                    style: TextStyle(
                      color: idx == 0 ? AppPalette.warning : AppPalette.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    )),
              ),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF172635))),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                          value: pct,
                          minHeight: 4,
                          color: AppPalette.navy,
                          backgroundColor: const Color(0xFFE6ECF2)),
                    ]),
              ),
              const SizedBox(width: 10),
              Text('${item.qty} sold',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppPalette.muted)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── Small Widgets ──────────────────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value, this.color, this.icon);
  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: color, width: 3))),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF657583),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .6)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
        ]),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF657583),
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8));
  }
}

class _EmptyBox extends StatelessWidget {
  const _EmptyBox(this.msg);
  final String msg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      color: Colors.white,
      child: Text(msg,
          style: const TextStyle(
              color: AppPalette.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }
}

// ── Bottom Nav ─────────────────────────────────────────────────────────────────
class _AnalyticsBottomNav extends StatelessWidget {
  const _AnalyticsBottomNav();

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.tune, 'Dashboard', '/admin'),
      (Icons.bar_chart, 'Analytics', '/admin/analytics'),
      (Icons.inventory_2_outlined, 'Catalog', '/admin/catalog'),
      (Icons.add_box_outlined, 'Add Product', '/admin/add-product'),
      (Icons.admin_panel_settings_outlined, 'Admin', '/admin/profile'),
    ];
    return Container(
      height: 70,
      color: Colors.white,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => context.go(items[i].$3),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 27,
                        decoration: BoxDecoration(
                          color: i == 1
                              ? AppPalette.cyan.withOpacity(.35)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child:
                            Icon(items[i].$1, color: AppPalette.navy, size: 18),
                      ),
                      const SizedBox(height: 3),
                      Text(items[i].$2,
                          style: const TextStyle(
                              color: Color(0xFF172635),
                              fontSize: 7,
                              fontWeight: FontWeight.w900)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }
}

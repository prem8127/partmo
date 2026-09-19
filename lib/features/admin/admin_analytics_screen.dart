import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _months = [
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

  static const _revenue = [
    420000.0,
    510000.0,
    390000.0,
    680000.0,
    720000.0,
    850000.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
    0.0,
  ];
  static const _orders = [
    312,
    408,
    295,
    520,
    610,
    742,
    0,
    0,
    0,
    0,
    0,
    0,
  ];
  static const _users = [
    180,
    220,
    175,
    310,
    390,
    465,
    0,
    0,
    0,
    0,
    0,
    0,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const _AdminBottomNav(selectedIndex: 4),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            children: [
              _Header(),
              // Tab bar
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppPalette.navy,
                  unselectedLabelColor: const Color(0xFF9CAAB6),
                  labelStyle: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900),
                  indicatorColor: AppPalette.navy,
                  indicatorWeight: 2.5,
                  tabs: const [
                    Tab(text: 'MONTHLY'),
                    Tab(text: 'Q1–Q2 (3M)'),
                    Tab(text: 'H1 (6M)'),
                    Tab(text: 'FULL YEAR'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _MonthlyTab(
                        months: _months,
                        revenue: _revenue,
                        orders: _orders,
                        users: _users),
                    _PeriodTab(
                      label: 'Last 3 Months',
                      sublabel: 'Apr · May · Jun',
                      monthIndices: [3, 4, 5],
                      months: _months,
                      revenue: _revenue,
                      orders: _orders,
                      users: _users,
                      color: AppPalette.cyan,
                    ),
                    _PeriodTab(
                      label: 'First Half 2026',
                      sublabel: 'Jan – Jun',
                      monthIndices: [0, 1, 2, 3, 4, 5],
                      months: _months,
                      revenue: _revenue,
                      orders: _orders,
                      users: _users,
                      color: AppPalette.success,
                    ),
                    _PeriodTab(
                      label: 'Full Year 2026',
                      sublabel: 'Jan – Dec (YTD)',
                      monthIndices: [0, 1, 2, 3, 4, 5],
                      months: _months,
                      revenue: _revenue,
                      orders: _orders,
                      users: _users,
                      color: AppPalette.navy,
                      isYTD: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Monthly Tab ────────────────────────────────────────────────────────────────

class _MonthlyTab extends StatefulWidget {
  const _MonthlyTab(
      {required this.months,
      required this.revenue,
      required this.orders,
      required this.users});
  final List<String> months;
  final List<double> revenue;
  final List<int> orders;
  final List<int> users;

  @override
  State<_MonthlyTab> createState() => _MonthlyTabState();
}

class _MonthlyTabState extends State<_MonthlyTab> {
  int _selectedMonthIndex = 5;

  double get _maxRevenue => widget.revenue.reduce((a, b) => a > b ? a : b);
  int get _maxOrders => widget.orders.reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    final month = widget.months[_selectedMonthIndex];
    final rev = widget.revenue[_selectedMonthIndex];
    final ord = widget.orders[_selectedMonthIndex];
    final usr = widget.users[_selectedMonthIndex];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _SectionLabel('SELECT MONTH'),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.months.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final selected = i == _selectedMonthIndex;
              final hasData = widget.revenue[i] > 0;
              return GestureDetector(
                onTap: hasData
                    ? () => setState(() => _selectedMonthIndex = i)
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? AppPalette.navy : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: selected
                            ? AppPalette.navy
                            : const Color(0xFFDDE5EE)),
                  ),
                  child: Text(
                    widget.months[i],
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : hasData
                              ? AppPalette.navy
                              : const Color(0xFFB0BEC5),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
              child: _KpiCard(
                  label: 'REVENUE',
                  value: '₹${_fmt(rev)}',
                  icon: Icons.payments_outlined,
                  color: AppPalette.navy)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'ORDERS',
                  value: '$ord',
                  icon: Icons.shopping_bag_outlined,
                  color: AppPalette.cyan)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'NEW USERS',
                  value: '$usr',
                  icon: Icons.person_add_outlined,
                  color: AppPalette.success)),
        ]),
        const SizedBox(height: 20),
        _SectionLabel('REVENUE TREND'),
        const SizedBox(height: 12),
        _BarChart(
          data: widget.revenue,
          maxValue: _maxRevenue,
          months: widget.months,
          selectedIndices: {_selectedMonthIndex},
          color: AppPalette.navy,
          formatValue: (v) => '₹${_fmt(v)}',
        ),
        const SizedBox(height: 20),
        _SectionLabel('ORDERS TREND'),
        const SizedBox(height: 12),
        _BarChart(
          data: widget.orders.map((e) => e.toDouble()).toList(),
          maxValue: _maxOrders.toDouble(),
          months: widget.months,
          selectedIndices: {_selectedMonthIndex},
          color: AppPalette.cyan,
          formatValue: (v) => v.toInt().toString(),
        ),
        const SizedBox(height: 20),
        _SectionLabel('$month BREAKDOWN'),
        const SizedBox(height: 12),
        _BreakdownCard(label: month, revenue: rev, orders: ord, users: usr),
        const SizedBox(height: 20),
        _SectionLabel('CATEGORY SPLIT — $month'),
        const SizedBox(height: 12),
        _CategoryPerformance(ordersCount: ord),
      ],
    );
  }
}

// ── Period Tab (3M / 6M / 12M) ─────────────────────────────────────────────────

class _PeriodTab extends StatelessWidget {
  const _PeriodTab({
    required this.label,
    required this.sublabel,
    required this.monthIndices,
    required this.months,
    required this.revenue,
    required this.orders,
    required this.users,
    required this.color,
    this.isYTD = false,
  });

  final String label, sublabel;
  final List<int> monthIndices;
  final List<String> months;
  final List<double> revenue;
  final List<int> orders;
  final List<int> users;
  final Color color;
  final bool isYTD;

  double get _totalRevenue => monthIndices.fold(0.0, (s, i) => s + revenue[i]);
  int get _totalOrders => monthIndices.fold(0, (s, i) => s + orders[i]);
  int get _totalUsers => monthIndices.fold(0, (s, i) => s + users[i]);
  double get _avgRevenue => _totalRevenue / monthIndices.length;
  double get _avgOrders => _totalOrders / monthIndices.length;
  double get _maxRevenue =>
      monthIndices.map((i) => revenue[i]).reduce((a, b) => a > b ? a : b);
  double get _maxOrders => monthIndices
      .map((i) => orders[i].toDouble())
      .reduce((a, b) => a > b ? a : b);

  String get _bestMonth {
    int best = monthIndices.first;
    for (final i in monthIndices) {
      if (revenue[i] > revenue[best]) best = i;
    }
    return months[best];
  }

  @override
  Widget build(BuildContext context) {
    final periodRevenue = _totalRevenue;
    final periodOrders = _totalOrders;
    final periodUsers = _totalUsers;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // Period banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(sublabel,
                  style: TextStyle(
                      color: Colors.white.withOpacity(.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              if (isYTD) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.2),
                      borderRadius: BorderRadius.circular(10)),
                  child: const Text('YEAR TO DATE',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
              ],
            ]),
            const Spacer(),
            const Icon(Icons.calendar_view_month,
                color: Colors.white54, size: 40),
          ]),
        ),
        const SizedBox(height: 16),

        // KPI totals
        _SectionLabel('PERIOD TOTALS'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _KpiCard(
                  label: 'REVENUE',
                  value: '₹${_fmt(periodRevenue)}',
                  icon: Icons.payments_outlined,
                  color: color)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'ORDERS',
                  value: '$periodOrders',
                  icon: Icons.shopping_bag_outlined,
                  color: AppPalette.cyan)),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'USERS',
                  value: '$periodUsers',
                  icon: Icons.person_add_outlined,
                  color: AppPalette.success)),
        ]),
        const SizedBox(height: 16),

        // Monthly averages
        _SectionLabel('MONTHLY AVERAGES'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _KpiCard(
                  label: 'AVG REVENUE',
                  value: '₹${_fmt(_avgRevenue)}',
                  icon: Icons.trending_up,
                  color: const Color(0xFF8B5CF6))),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'AVG ORDERS',
                  value: _avgOrders.toStringAsFixed(0),
                  icon: Icons.bar_chart,
                  color: const Color(0xFFEF4444))),
          const SizedBox(width: 10),
          Expanded(
              child: _KpiCard(
                  label: 'BEST MONTH',
                  value: _bestMonth,
                  icon: Icons.star_outline,
                  color: AppPalette.warning)),
        ]),
        const SizedBox(height: 20),

        // Revenue bar chart for period
        _SectionLabel('REVENUE — MONTH BY MONTH'),
        const SizedBox(height: 12),
        _BarChart(
          data: revenue,
          maxValue: _maxRevenue,
          months: months,
          selectedIndices: monthIndices.toSet(),
          color: color,
          formatValue: (v) => v > 0 ? '₹${_fmt(v)}' : '',
          dimOutside: true,
        ),
        const SizedBox(height: 20),

        // Orders bar chart for period
        _SectionLabel('ORDERS — MONTH BY MONTH'),
        const SizedBox(height: 12),
        _BarChart(
          data: orders.map((e) => e.toDouble()).toList(),
          maxValue: _maxOrders,
          months: months,
          selectedIndices: monthIndices.toSet(),
          color: AppPalette.cyan,
          formatValue: (v) => v > 0 ? v.toInt().toString() : '',
          dimOutside: true,
        ),
        const SizedBox(height: 20),

        // Month-by-month table
        _SectionLabel('MONTH-BY-MONTH BREAKDOWN'),
        const SizedBox(height: 12),
        _MonthTable(
            monthIndices: monthIndices,
            months: months,
            revenue: revenue,
            orders: orders,
            users: users,
            accentColor: color),
        const SizedBox(height: 20),

        // Period summary card
        _SectionLabel('PERIOD SUMMARY'),
        const SizedBox(height: 12),
        _BreakdownCard(
          label: label,
          revenue: periodRevenue,
          orders: periodOrders,
          users: periodUsers,
          showGrowth: monthIndices.length > 1,
          firstMonthRevenue: revenue[monthIndices.first],
          lastMonthRevenue: revenue[monthIndices.last],
        ),
        const SizedBox(height: 20),
        _SectionLabel('CATEGORY SPLIT'),
        const SizedBox(height: 12),
        _CategoryPerformance(ordersCount: periodOrders),
      ],
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          14, MediaQuery.paddingOf(context).top + 14, 14, 14),
      child: Row(children: [
        IconButton(
            onPressed: () => context.go('/admin'),
            icon:
                const Icon(Icons.arrow_back, color: AppPalette.navy, size: 20),
            visualDensity: VisualDensity.compact),
        const Text('Analytics',
            style: TextStyle(
                color: AppPalette.navy,
                fontSize: 15,
                fontWeight: FontWeight.w900)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: const Color(0xFFE8F4FF),
              borderRadius: BorderRadius.circular(4)),
          child: const Text('2026',
              style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 11,
                  fontWeight: FontWeight.w900)),
        ),
      ]),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF657583),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            letterSpacing: 1));
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          border: Border(top: BorderSide(color: color, width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8A9BAA),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .6)),
      ]),
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.data,
    required this.maxValue,
    required this.months,
    required this.selectedIndices,
    required this.color,
    required this.formatValue,
    this.dimOutside = false,
  });

  final List<double> data;
  final double maxValue;
  final List<String> months;
  final Set<int> selectedIndices;
  final Color color;
  final String Function(double) formatValue;
  final bool dimOutside;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final val = data[i];
              final ratio = maxValue > 0 ? val / maxValue : 0.0;
              final isSelected = selectedIndices.contains(i);
              final hasData = val > 0;
              final isDimmed = dimOutside && !isSelected;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (isSelected && hasData)
                        Text(formatValue(val),
                            style: TextStyle(
                                color: color,
                                fontSize: 6.5,
                                fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOut,
                        height: hasData ? (ratio * 85).clamp(4.0, 85.0) : 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color
                              : isDimmed
                                  ? color.withOpacity(.12)
                                  : hasData
                                      ? color.withOpacity(.3)
                                      : const Color(0xFFEBF0F5),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(
              12,
              (i) => Expanded(
                    child: Text(
                      months[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selectedIndices.contains(i)
                            ? color
                            : const Color(0xFFBDC8D2),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )),
        ),
      ]),
    );
  }
}

class _MonthTable extends StatelessWidget {
  const _MonthTable({
    required this.monthIndices,
    required this.months,
    required this.revenue,
    required this.orders,
    required this.users,
    required this.accentColor,
  });

  final List<int> monthIndices;
  final List<String> months;
  final List<double> revenue;
  final List<int> orders;
  final List<int> users;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
              color: accentColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(4))),
          child: const Row(children: [
            Expanded(
                flex: 2,
                child: Text('MONTH',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))),
            Expanded(
                flex: 3,
                child: Text('REVENUE',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))),
            Expanded(
                flex: 2,
                child: Text('ORDERS',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))),
            Expanded(
                flex: 2,
                child: Text('USERS',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900))),
          ]),
        ),
        for (final i in monthIndices)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
                border:
                    Border(bottom: BorderSide(color: const Color(0xFFF0F4F8)))),
            child: Row(children: [
              Expanded(
                  flex: 2,
                  child: Text(months[i],
                      style: const TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 11,
                          fontWeight: FontWeight.w900))),
              Expanded(
                  flex: 3,
                  child: Text('₹${_fmt(revenue[i])}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFF172635),
                          fontSize: 11,
                          fontWeight: FontWeight.w900))),
              Expanded(
                  flex: 2,
                  child: Text('${orders[i]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFF536372),
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
              Expanded(
                  flex: 2,
                  child: Text('${users[i]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: Color(0xFF536372),
                          fontSize: 11,
                          fontWeight: FontWeight.w700))),
            ]),
          ),
      ]),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.label,
    required this.revenue,
    required this.orders,
    required this.users,
    this.showGrowth = false,
    this.firstMonthRevenue = 0,
    this.lastMonthRevenue = 0,
  });

  final String label;
  final double revenue;
  final int orders;
  final int users;
  final bool showGrowth;
  final double firstMonthRevenue;
  final double lastMonthRevenue;

  double get _growth => firstMonthRevenue > 0
      ? ((lastMonthRevenue - firstMonthRevenue) / firstMonthRevenue) * 100
      : 0;

  @override
  Widget build(BuildContext context) {
    final avgOrderValue = orders > 0 ? revenue / orders : 0.0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppPalette.navy, borderRadius: BorderRadius.circular(4)),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.bar_chart, color: AppPalette.cyan, size: 18),
          const SizedBox(width: 8),
          Text(label.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 16),
        _BRow(label: 'Total Revenue', value: '₹${revenue.toStringAsFixed(0)}'),
        _BRow(label: 'Total Orders', value: '$orders orders'),
        _BRow(label: 'Total New Users', value: '$users users'),
        _BRow(
            label: 'Avg. Order Value',
            value: '₹${avgOrderValue.toStringAsFixed(0)}'),
        if (showGrowth)
          _BRow(
            label: 'Revenue Growth',
            value: '${_growth >= 0 ? '+' : ''}${_growth.toStringAsFixed(1)}%',
            valueColor: _growth >= 0 ? AppPalette.success : AppPalette.danger,
          ),
        _BRow(
          label: 'Conversion Rate',
          value: users > 0
              ? '${((orders / users) * 100).toStringAsFixed(1)}%'
              : '—',
          isLast: true,
        ),
      ]),
    );
  }
}

class _BRow extends StatelessWidget {
  const _BRow(
      {required this.label,
      required this.value,
      this.isLast = false,
      this.valueColor = Colors.white});
  final String label, value;
  final bool isLast;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFF1B527A)))),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFFB9D2E3),
                    fontSize: 11,
                    fontWeight: FontWeight.w700))),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 12, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _CategoryPerformance extends StatelessWidget {
  const _CategoryPerformance({required this.ordersCount});
  final int ordersCount;

  @override
  Widget build(BuildContext context) {
    final cats = [
      ('Mechanical', 0.38, AppPalette.navy),
      ('Electrical', 0.24, AppPalette.cyan),
      ('Body Panels', 0.18, AppPalette.success),
      ('Filters & Fluids', 0.12, AppPalette.warning),
      ('Others', 0.08, const Color(0xFF9CAAB6)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(4)),
      child: Column(
        children: cats.map((c) {
          final count = (ordersCount * c.$2).round();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(children: [
              Row(children: [
                Expanded(
                    child: Text(c.$1,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF172635)))),
                Text('$count orders',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8A9BAA))),
                const SizedBox(width: 8),
                Text('${(c.$2 * 100).toInt()}%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: c.$3)),
              ]),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                    value: c.$2,
                    minHeight: 6,
                    color: c.$3,
                    backgroundColor: const Color(0xFFEBF0F5)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

String _fmt(double v) {
  if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.toStringAsFixed(0);
}

class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({required this.selectedIndex});
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.tune, 'Dashboard', '/admin'),
      (Icons.inventory_2_outlined, 'Catalog', '/admin/catalog'),
      (Icons.add_box_outlined, 'Add', '/admin/add-product'),
      (Icons.admin_panel_settings_outlined, 'Profile', '/admin/profile'),
      (Icons.bar_chart_outlined, 'Analytics', '/admin/analytics'),
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
                        width: 36,
                        height: 26,
                        decoration: BoxDecoration(
                            color: i == selectedIndex
                                ? AppPalette.cyan.withOpacity(.35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(13)),
                        child:
                            Icon(items[i].$1, color: AppPalette.navy, size: 17),
                      ),
                      const SizedBox(height: 3),
                      Text(items[i].$2,
                          style: const TextStyle(
                              color: Color(0xFF172635),
                              fontSize: 7.5,
                              fontWeight: FontWeight.w900)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }
}

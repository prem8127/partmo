import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';
import '../../core/utils/whatsapp_launcher.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _loading = true;
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _recentOrders = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        SupabaseService.fetchDashboardStats(),
        SupabaseService.fetchRecentOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _recentOrders = results[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalOrders = (_stats['totalOrders'] as int?) ?? 0;
    final pending = (_stats['pendingShipments'] as int?) ?? 0;
    final revenue = (_stats['monthRevenue'] as double?) ?? 0;
    final activeUsers = (_stats['activeUsers'] as int?) ?? 0;
    final stockHealth = (_stats['stockHealth'] as List?) ?? const [];

    return Scaffold(
      key: _scaffoldKey,
      drawer: const _AdminDrawer(),
      drawerScrimColor: Colors.transparent,
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const _AdminBottomNav(selectedIndex: 0),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _AdminHeader(
                    onMenu: () => _scaffoldKey.currentState?.openDrawer()),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            const _AdminQuickActions(),
                            const SizedBox(height: 12),
                            _AdminStatCard(
                                icon: Icons.shopping_cart_outlined,
                                title: 'TOTAL ORDERS',
                                value: '$totalOrders'),
                            _AdminStatCard(
                                icon: Icons.local_shipping_outlined,
                                title: 'PENDING SHIPMENTS',
                                value: '$pending',
                                note: pending > 0 ? 'Needs Attention' : null,
                                accent: AppPalette.warning),
                            _AdminRevenueCard(revenue: revenue),
                            _AdminStatCard(
                                icon: Icons.groups_outlined,
                                title: 'ACTIVE USERS',
                                value: '$activeUsers',
                                accent: const Color(0xFF008A9E)),
                            const SizedBox(height: 18),
                            _OperationalDossier(orders: _recentOrders),
                            const SizedBox(height: 18),
                            const _CommandCenter(),
                            const SizedBox(height: 18),
                            _StockHealth(
                                categories:
                                    stockHealth.cast<Map<String, dynamic>>()),
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

class _AdminHeader extends StatelessWidget {
  const _AdminHeader({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
          12, MediaQuery.paddingOf(context).top + 12, 14, 12),
      child: Row(
        children: [
          IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu, color: AppPalette.navy, size: 20),
              visualDensity: VisualDensity.compact),
          const Text('PartMo',
              style: TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 15,
                  fontWeight: FontWeight.w900)),
          const Spacer(),
          IconButton(
            onPressed: () => context.go('/admin/add-product'),
            icon: const Icon(Icons.add_box_outlined,
                color: AppPalette.navy, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => context.go('/admin/catalog'),
            icon: const Icon(Icons.inventory_2_outlined,
                color: AppPalette.navy, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () async {
              await SupabaseService.signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout, color: AppPalette.danger, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          GestureDetector(
            onTap: () => context.go('/admin/profile'),
            child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: const Color(0xFF2A6071),
                    borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 18)),
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer();

  @override
  Widget build(BuildContext context) {
    const destinations = [
      (Icons.dashboard_outlined, 'Dashboard', '/admin'),
      (Icons.bar_chart, 'Analytics', '/admin/analytics'),
      (Icons.add_box_outlined, 'Add Product', '/admin/add-product'),
      (Icons.inventory_2_outlined, 'Catalog', '/admin/catalog'),
      (Icons.local_shipping_outlined, 'Manage Orders', '/admin/orders'),
      (Icons.admin_panel_settings_outlined, 'Admin Profile', '/admin/profile'),
    ];
    return Drawer(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shadowColor: Colors.black26,
      elevation: 18,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('PartMo Admin',
                  style: TextStyle(
                      color: AppPalette.navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
            for (final item in destinations)
              ListTile(
                leading: Icon(item.$1, color: AppPalette.navy),
                title: Text(item.$2,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.$3);
                },
              ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppPalette.danger),
              title: const Text('Logout',
                  style: TextStyle(color: AppPalette.danger)),
              onTap: () async {
                Navigator.of(context).pop();
                await SupabaseService.signOut();
                if (context.mounted) context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminQuickActions extends StatelessWidget {
  const _AdminQuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.add_box_outlined,
                label: 'Add Product',
                onTap: () => context.go('/admin/add-product'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.inventory_2_outlined,
                label: 'Catalog',
                onTap: () => context.go('/admin/catalog'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _QuickActionButton(
            icon: Icons.local_shipping_outlined,
            label: 'Manage Orders',
            onTap: () => context.go('/admin/orders'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppPalette.navy, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: AppPalette.navy,
                    fontSize: 11,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard(
      {required this.icon,
      required this.title,
      required this.value,
      this.delta,
      this.note,
      this.accent = AppPalette.navy});

  final IconData icon;
  final String title;
  final String value;
  final String? delta;
  final String? note;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Color(0xFF657583),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8)),
                const SizedBox(height: 8),
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (delta != null)
            Text(delta!,
                style: const TextStyle(
                    color: AppPalette.success,
                    fontSize: 10,
                    fontWeight: FontWeight.w900)),
          if (note != null)
            Text(note!,
                style: TextStyle(
                    color: accent, fontSize: 9, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _AdminRevenueCard extends StatelessWidget {
  const _AdminRevenueCard({required this.revenue});
  final double revenue;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppPalette.navy, borderRadius: BorderRadius.circular(3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: AppPalette.cyan, size: 22),
          const SizedBox(height: 12),
          const Text('REVENUE (CURRENT MONTH)',
              style: TextStyle(
                  color: Color(0xFFB9D2E3),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8)),
          const SizedBox(height: 7),
          Text('₹${revenue.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _OperationalDossier extends StatelessWidget {
  const _OperationalDossier({required this.orders});
  final List<Map<String, dynamic>> orders;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
                child: Text('RECENT OPERATIONAL\nDOSSIER',
                    style: TextStyle(
                        color: AppPalette.navy,
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: FontWeight.w900))),
            TextButton(
                onPressed: () => context.go('/admin/catalog'),
                child: const Text('View All\nRecords',
                    textAlign: TextAlign.right,
                    style:
                        TextStyle(fontSize: 9, fontWeight: FontWeight.w900))),
          ],
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Text('No orders yet.',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          )
        else
          for (final o in orders)
            _OrderAdminRow(
              order: () {
                final id = o['id']?.toString() ?? '';
                return 'Order #${id.substring(0, id.length.clamp(0, 8))}';
              }(),
              body: () {
                final items = (o['order_items'] as List?) ?? const [];
                if (items.isEmpty)
                  return '${(o['payment_method'] as String? ?? '').toUpperCase()}';
                final first = items.first as Map<String, dynamic>;
                final extra =
                    items.length > 1 ? ' +${items.length - 1} more' : '';
                return '${first['product_name'] ?? ''} • ${first['quantity'] ?? 1} unit$extra';
              }(),
              price: '₹${((o['total'] as num?)?.toStringAsFixed(0)) ?? '0'}',
              status: ((o['status'] as String? ?? 'confirmed')).toUpperCase(),
              orange:
                  (o['status'] as String? ?? '').toLowerCase() == 'processing',
              whatsappNumber: (o['whatsapp_number'] as String?) ?? '',
              onWhatsApp: () async {
                final items = (o['order_items'] as List?) ?? const [];
                final itemsBlock = items.isEmpty
                    ? '• Automotive Spare Part'
                    : items
                        .map((i) =>
                            '• ${(i as Map)['product_name'] ?? ''} x${i['quantity'] ?? 1}')
                        .join('\n');
                final message =
                    'Hi! Update on your PartMo order ${o['id']}:\n\n'
                    'Items:\n$itemsBlock\n\n'
                    'Status: ${((o['status'] as String? ?? 'confirmed')).toUpperCase()}\n'
                    'Total: ₹${((o['total'] as num?)?.toStringAsFixed(0)) ?? '0'}\n'
                    '${(o['delivery_address'] as String?)?.isNotEmpty == true ? 'Delivering to: ${o['delivery_address']}\n' : ''}'
                    '\nThank you for shopping with PartMo!';
                await openWhatsAppChat(
                    number: o['whatsapp_number'] as String?, message: message);
              },
            ),
      ],
    );
  }
}

class _OrderAdminRow extends StatelessWidget {
  const _OrderAdminRow(
      {this.icon = Icons.receipt_long_outlined,
      required this.order,
      required this.body,
      required this.price,
      required this.status,
      this.orange = false,
      this.whatsappNumber = '',
      this.onWhatsApp});

  final IconData icon;
  final String order;
  final String body;
  final String price;
  final String status;
  final bool orange;
  final String whatsappNumber;
  final VoidCallback? onWhatsApp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Container(
              width: 40,
              height: 40,
              color: const Color(0xFFEAF0F6),
              child: Icon(icon, color: AppPalette.navy, size: 19)),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order,
                  style: const TextStyle(
                      color: Color(0xFF172635),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(body,
                  style: const TextStyle(
                      color: Color(0xFF657583),
                      fontSize: 9,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(price,
                style: const TextStyle(
                    color: Color(0xFF172635),
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(status,
                style: TextStyle(
                    color: orange ? AppPalette.warning : AppPalette.success,
                    fontSize: 8,
                    fontWeight: FontWeight.w900)),
          ]),
          if (whatsappNumber.isNotEmpty) ...[
            const SizedBox(width: 6),
            IconButton(
              onPressed: onWhatsApp,
              tooltip: 'Message customer on WhatsApp',
              icon: const Icon(Icons.chat, color: Color(0xFF1DBD79), size: 20),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _CommandCenter extends StatelessWidget {
  const _CommandCenter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppPalette.navy, borderRadius: BorderRadius.circular(3)),
      child: Stack(
        children: [
          Positioned(
              right: -8,
              bottom: -18,
              child: Icon(Icons.vpn_key,
                  color: Colors.white.withOpacity(.12), size: 86)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('COMMAND CENTER',
                  style: TextStyle(
                      color: Color(0xFFB9D2E3),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4)),
              SizedBox(height: 16),
              _CommandButton(
                  label: 'Analytics & Reports', route: '/admin/analytics'),
              _CommandButton(label: 'Manage Orders', route: '/admin/orders'),
              _CommandButton(
                  label: 'Manage Inventory', route: '/admin/catalog'),
              _CommandButton(label: 'Add Product', route: '/admin/add-product'),
              _CommandButton(label: 'Support Tickets', route: null),
              _CommandButton(label: 'Supplier Portal', route: null),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommandButton extends StatelessWidget {
  const _CommandButton({required this.label, required this.route});

  final String label;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (route != null) {
          context.go(route!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$label coming soon')),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        color: const Color(0xFF1B527A),
        child: Text('$label↗',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _StockHealth extends StatelessWidget {
  const _StockHealth({required this.categories});
  final List<Map<String, dynamic>> categories;

  static const _colors = [AppPalette.navy, AppPalette.warning, AppPalette.cyan];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('STOCK HEALTH DENSITY',
              style: TextStyle(
                  color: Color(0xFF657583),
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .8)),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            const Text('No products yet.',
                style: TextStyle(
                    color: AppPalette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600))
          else
            for (int i = 0; i < categories.length; i++)
              _HealthBar(
                label: categories[i]['label'] as String,
                value: categories[i]['value'] as double,
                color: _colors[i % _colors.length],
                percent:
                    '${((categories[i]['value'] as double) * 100).round()}%',
              ),
        ],
      ),
    );
  }
}

class _HealthBar extends StatelessWidget {
  const _HealthBar(
      {required this.label,
      required this.value,
      required this.color,
      required this.percent});

  final String label;
  final double value;
  final Color color;
  final String percent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(children: [
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w900))),
            Text(percent,
                style:
                    const TextStyle(fontSize: 9, fontWeight: FontWeight.w900))
          ]),
          const SizedBox(height: 5),
          LinearProgressIndicator(
              value: value,
              minHeight: 5,
              color: color,
              backgroundColor: const Color(0xFFE6ECF2)),
        ],
      ),
    );
  }
}

class _AdminBottomNav extends StatelessWidget {
  const _AdminBottomNav({required this.selectedIndex});

  final int selectedIndex;

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
                              color: i == selectedIndex
                                  ? AppPalette.cyan.withOpacity(.35)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(13)),
                          child: Icon(items[i].$1,
                              color: AppPalette.navy, size: 18)),
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

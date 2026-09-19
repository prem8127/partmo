import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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
  List<Map<String, dynamic>> _banners = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _allOrders = const [];

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
        SupabaseService.fetchBanners(admin: true),
        SupabaseService.fetchAllUsersForAnalytics(),
        SupabaseService.fetchAllOrders(),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _recentOrders = results[1] as List<Map<String, dynamic>>;
        _banners = results[2] as List<Map<String, dynamic>>;
        _users = results[3] as List<Map<String, dynamic>>;
        _allOrders = results[4] as List<Map<String, dynamic>>;
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
      drawer: _AdminDrawer(
        onActiveUsers: () => _showActiveUsers(context),
        onBanners: () => _showBanners(context),
      ),
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
                  onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 26),
                  child: _loading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 60),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : Column(
                          children: [
                            _AdminQuickActions(
                              onBanners: () => _showBanners(context),
                            ),
                            const SizedBox(height: 12),
                            _AdminStatCard(
                              icon: Icons.shopping_cart_outlined,
                              title: 'TOTAL ORDERS',
                              value: '$totalOrders',
                            ),
                            _AdminStatCard(
                              icon: Icons.local_shipping_outlined,
                              title: 'PENDING SHIPMENTS',
                              value: '$pending',
                              note: pending > 0 ? 'Needs Attention' : null,
                              accent: AppPalette.warning,
                            ),
                            _AdminRevenueCard(revenue: revenue),
                            _AdminStatCard(
                              icon: Icons.groups_outlined,
                              title: 'ACTIVE USERS',
                              value: '$activeUsers',
                              actionLabel: 'View',
                              onAction: () => _showActiveUsers(context),
                              accent: const Color(0xFF008A9E),
                            ),
                            const SizedBox(height: 18),
                            _OperationalDossier(orders: _recentOrders),
                            const SizedBox(height: 18),
                            const _CommandCenter(),
                            const SizedBox(height: 18),
                            _StockHealth(
                              categories:
                                  stockHealth.cast<Map<String, dynamic>>(),
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

  void _showActiveUsers(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Active Users',
                          style: TextStyle(
                              color: AppPalette.navy,
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppPalette.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _ActiveUsersPanel(
                    users: _users,
                    orders: _allOrders,
                    expanded: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBanners(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .82,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Banner Manager',
                        style: TextStyle(
                            color: AppPalette.navy,
                            fontSize: 18,
                            fontWeight: FontWeight.w900),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: AppPalette.navy),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    child: _BannerManager(banners: _banners, onChanged: _load),
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
        12,
        MediaQuery.paddingOf(context).top + 12,
        14,
        12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onMenu,
            icon: const Icon(Icons.menu, color: AppPalette.navy, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          const Text(
            'PartMo',
            style: TextStyle(
              color: Color(0xFF172635),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: () => context.go('/admin/add-product'),
            icon: const Icon(
              Icons.add_box_outlined,
              color: AppPalette.navy,
              size: 20,
            ),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: () => context.go('/admin/catalog'),
            icon: const Icon(
              Icons.inventory_2_outlined,
              color: AppPalette.navy,
              size: 20,
            ),
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
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.admin_panel_settings,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminDrawer extends StatelessWidget {
  const _AdminDrawer({
    required this.onActiveUsers,
    required this.onBanners,
  });

  final VoidCallback onActiveUsers;
  final VoidCallback onBanners;

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
              child: Text(
                'PartMo Admin',
                style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final item in destinations)
              ListTile(
                leading: Icon(item.$1, color: AppPalette.navy),
                title: Text(
                  item.$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  context.go(item.$3);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.groups_outlined, color: AppPalette.navy),
              title: const Text('Active Users',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(context).pop();
                onActiveUsers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.view_carousel_outlined,
                  color: AppPalette.navy),
              title: const Text('Banners',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              onTap: () {
                Navigator.of(context).pop();
                onBanners();
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: AppPalette.danger),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppPalette.danger),
              ),
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
  const _AdminQuickActions({required this.onBanners});

  final VoidCallback onBanners;

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
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                icon: Icons.local_shipping_outlined,
                label: 'Orders',
                onTap: () => context.go('/admin/orders'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickActionButton(
                icon: Icons.view_carousel_outlined,
                label: 'Banners',
                onTap: onBanners,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppPalette.navy, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppPalette.navy,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminStatCard extends StatelessWidget {
  const _AdminStatCard({
    required this.icon,
    required this.title,
    required this.value,
    this.delta,
    this.note,
    this.actionLabel,
    this.onAction,
    this.accent = AppPalette.navy,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? delta;
  final String? note;
  final String? actionLabel;
  final VoidCallback? onAction;
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF657583),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF172635),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          if (delta != null)
            Text(
              delta!,
              style: const TextStyle(
                color: AppPalette.success,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(actionLabel!,
                  style: TextStyle(
                      color: accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w900)),
            )
          else if (note != null)
            Text(
              note!,
              style: TextStyle(
                color: accent,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
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
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.payments_outlined, color: AppPalette.cyan, size: 22),
          const SizedBox(height: 12),
          const Text(
            'REVENUE (CURRENT MONTH)',
            style: TextStyle(
              color: Color(0xFFB9D2E3),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '₹${revenue.toStringAsFixed(0)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveUsersPanel extends StatelessWidget {
  const _ActiveUsersPanel({
    required this.users,
    required this.orders,
    this.expanded = false,
  });

  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> orders;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final orderStats = <String, _UserOrderStats>{};
    for (final order in orders) {
      final userId = order['user_id']?.toString();
      if (userId == null || userId.isEmpty) continue;
      final stats = orderStats.putIfAbsent(userId, _UserOrderStats.new);
      stats.count++;
      final created = DateTime.tryParse(order['created_at']?.toString() ?? '');
      if (created != null &&
          (stats.lastOrderAt == null || created.isAfter(stats.lastOrderAt!))) {
        stats.lastOrderAt = created;
        stats.lastOrderTotal = (order['total'] as num?)?.toDouble() ?? 0;
        stats.lastOrderStatus = order['status']?.toString() ?? 'confirmed';
      }
    }

    final rows = users.where((user) {
      final id = user['id']?.toString() ?? '';
      return id.isNotEmpty;
    }).toList()
      ..sort((a, b) => (b['created_at']?.toString() ?? '')
          .compareTo(a['created_at']?.toString() ?? ''));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!expanded) ...[
            const Row(
              children: [
                Icon(Icons.people_alt_outlined,
                    color: Color(0xFF008A9E), size: 18),
                SizedBox(width: 8),
                Text('CUSTOMERS PREVIEW',
                    style: TextStyle(
                        color: AppPalette.navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          if (rows.isEmpty)
            const Text(
              'No customer profiles available yet. Run the profile email SQL if needed.',
              style: TextStyle(
                  color: AppPalette.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            )
          else
            ExpandedOrColumn(
              expanded: expanded,
              children: [
                for (final user in expanded ? rows : rows.take(4))
                  _ActiveUserTile(
                    user: user,
                    stats: orderStats[user['id']?.toString() ?? ''],
                  ),
                if (!expanded && rows.length > 4) ...[
                  const SizedBox(height: 8),
                  Text(
                      '${rows.length - 4} more users. Tap View on Active Users.',
                      style: const TextStyle(
                          color: Color(0xFF008A9E),
                          fontSize: 10,
                          fontWeight: FontWeight.w900)),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class ExpandedOrColumn extends StatelessWidget {
  const ExpandedOrColumn({required this.expanded, required this.children});

  final bool expanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Column(children: children);
    }
    return Expanded(
      child: ListView(
        padding: EdgeInsets.zero,
        children: children,
      ),
    );
  }
}

class _UserOrderStats {
  int count = 0;
  DateTime? lastOrderAt;
  double lastOrderTotal = 0;
  String lastOrderStatus = '';
}

class _ActiveUserTile extends StatelessWidget {
  const _ActiveUserTile({required this.user, this.stats});

  final Map<String, dynamic> user;
  final _UserOrderStats? stats;

  @override
  Widget build(BuildContext context) {
    final name = user['full_name']?.toString().trim().isNotEmpty == true
        ? user['full_name'].toString()
        : 'Customer';
    final email = user['email']?.toString().trim() ?? '';
    final phone = user['phone']?.toString().trim() ?? '';
    final joined = _shortDate(user['created_at']?.toString());
    final subtitle = [
      if (email.isNotEmpty) email,
      if (phone.isNotEmpty) phone,
      if (joined.isNotEmpty) 'Joined $joined',
    ].join(' • ');
    final orderSummary = stats == null || stats!.count == 0
        ? 'No orders'
        : '${stats!.count} orders • ₹${stats!.lastOrderTotal.toStringAsFixed(0)} • ${stats!.lastOrderStatus.toUpperCase()}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE5EDF3))),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F6F8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.person_outline,
                color: Color(0xFF008A9E), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.navy,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF657583),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(orderSummary,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: Color(0xFF008A9E),
                  fontSize: 9,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

String _shortDate(String? raw) {
  final parsed = DateTime.tryParse(raw ?? '');
  if (parsed == null) return '';
  return '${parsed.day}/${parsed.month}/${parsed.year}';
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
              child: Text(
                'RECENT OPERATIONAL\nDOSSIER',
                style: TextStyle(
                  color: AppPalette.navy,
                  fontSize: 13,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.go('/admin/orders'),
              child: const Text(
                'View All\nRecords',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (orders.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: const Text(
              'No orders yet.',
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          for (final o in orders)
            _OrderAdminRow(
              order: () {
                return 'Order ${_displayOrderRef(o)}';
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
                        .map(
                          (i) =>
                              '• ${(i as Map)['product_name'] ?? ''} x${i['quantity'] ?? 1}',
                        )
                        .join('\n');
                final message =
                    'Hi! Update on your PartMo order ${_displayOrderRef(o)}:\n\n'
                    'Items:\n$itemsBlock\n\n'
                    'Status: ${((o['status'] as String? ?? 'confirmed')).toUpperCase()}\n'
                    'Total: ₹${((o['total'] as num?)?.toStringAsFixed(0)) ?? '0'}\n'
                    '${(o['delivery_address'] as String?)?.isNotEmpty == true ? 'Delivering to: ${o['delivery_address']}\n' : ''}'
                    '\nThank you for shopping with PartMo!';
                await openWhatsAppChat(
                  number: o['whatsapp_number'] as String?,
                  message: message,
                );
              },
            ),
      ],
    );
  }
}

String _displayOrderRef(Map<String, dynamic> order) {
  final orderRef = order['order_ref']?.toString().trim() ?? '';
  if (orderRef.isNotEmpty) return orderRef;
  final id = order['id']?.toString() ?? '';
  if (id.isEmpty) return '#PM-ORDER';
  final compact = id.replaceAll('-', '');
  final suffix = compact.length >= 8 ? compact.substring(0, 8) : compact;
  return '#PM-${suffix.toUpperCase()}';
}

class _OrderAdminRow extends StatelessWidget {
  const _OrderAdminRow({
    this.icon = Icons.receipt_long_outlined,
    required this.order,
    required this.body,
    required this.price,
    required this.status,
    this.orange = false,
    this.whatsappNumber = '',
    this.onWhatsApp,
  });

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
            child: Icon(icon, color: AppPalette.navy, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order,
                  style: const TextStyle(
                    color: Color(0xFF172635),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    color: Color(0xFF657583),
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  color: Color(0xFF172635),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                status,
                style: TextStyle(
                  color: orange ? AppPalette.warning : AppPalette.success,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
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

class _BannerManager extends StatelessWidget {
  const _BannerManager({required this.banners, required this.onChanged});

  final List<Map<String, dynamic>> banners;
  final VoidCallback onChanged;

  Future<void> _edit(
    BuildContext context, [
    Map<String, dynamic>? banner,
  ]) async {
    final title = TextEditingController(
      text: banner?['title']?.toString() ?? '',
    );
    final subtitle = TextEditingController(
      text: banner?['subtitle']?.toString() ?? '',
    );
    final badge = TextEditingController(
      text: banner?['badge']?.toString() ?? '',
    );
    final cta = TextEditingController(
      text: banner?['cta_label']?.toString() ?? 'Shop Now',
    );
    final image = TextEditingController(
      text: banner?['image_url']?.toString() ?? '',
    );
    final sort = TextEditingController(
      text: (banner?['sort_order'] as num?)?.toInt().toString() ??
          '${banners.length + 1}',
    );
    var placement = banner?['placement']?.toString() ?? 'top';
    var active = banner?['is_active'] as bool? ?? true;
    var uploading = false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(banner == null ? 'Create Banner' : 'Edit Banner'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: placement,
                  decoration: const InputDecoration(labelText: 'Banner place'),
                  items: const [
                    DropdownMenuItem(value: 'top', child: Text('Top banner')),
                    DropdownMenuItem(
                        value: 'middle', child: Text('Middle banner')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => placement = value ?? placement),
                ),
                TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: subtitle,
                  decoration: const InputDecoration(labelText: 'Subtitle'),
                ),
                TextField(
                  controller: badge,
                  decoration: const InputDecoration(labelText: 'Badge'),
                ),
                TextField(
                  controller: cta,
                  decoration: const InputDecoration(labelText: 'Button label'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: uploading
                      ? null
                      : () async {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1600,
                            imageQuality: 86,
                          );
                          if (picked == null) return;
                          setDialogState(() => uploading = true);
                          try {
                            final url =
                                await SupabaseService.uploadBannerImageBytes(
                              bytes: await picked.readAsBytes(),
                              fileName: picked.name,
                            );
                            image.text = url;
                          } finally {
                            setDialogState(() => uploading = false);
                          }
                        },
                  icon: uploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(uploading ? 'Uploading...' : 'Upload image'),
                ),
                if (image.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    image.text.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppPalette.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 8),
                TextField(
                  controller: image,
                  decoration: const InputDecoration(
                      labelText: 'Image URL after upload',
                      helperText: 'Auto-filled after upload'),
                  readOnly: true,
                ),
                TextField(
                  controller: sort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                  title: const Text('Active'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                await SupabaseService.upsertBanner({
                  'id': banner?['id'],
                  'placement': placement,
                  'title': title.text.trim(),
                  'subtitle': subtitle.text.trim(),
                  'badge': badge.text.trim(),
                  'cta_label': cta.text.trim(),
                  'image_url': image.text.trim(),
                  'sort_order': int.tryParse(sort.text.trim()) ?? 1,
                  'is_active': active,
                });
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    title.dispose();
    subtitle.dispose();
    badge.dispose();
    cta.dispose();
    image.dispose();
    sort.dispose();
    if (saved == true) onChanged();
  }

  Future<void> _delete(
    BuildContext context,
    Map<String, dynamic> banner,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Banner?'),
        content: Text(banner['title']?.toString() ?? 'This banner'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppPalette.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await SupabaseService.deleteBanner(banner['id'].toString());
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'HOME BANNERS',
                  style: TextStyle(
                    color: AppPalette.navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.add, color: AppPalette.navy),
                tooltip: 'Create banner',
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (banners.isEmpty)
            const Text(
              'No custom banners. Customers see default 3 slides.',
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            for (final banner in banners.take(5))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  banner['title']?.toString() ?? 'Banner',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '${banner['badge'] ?? ''} • ${banner['subtitle'] ?? ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Wrap(
                  spacing: 2,
                  children: [
                    IconButton(
                      onPressed: () => _edit(context, banner),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      onPressed: () => _delete(context, banner),
                      icon: const Icon(
                        Icons.delete_outline,
                        color: AppPalette.danger,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
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
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -8,
            bottom: -18,
            child: Icon(
              Icons.vpn_key,
              color: Colors.white.withOpacity(.12),
              size: 86,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'COMMAND CENTER',
                style: TextStyle(
                  color: Color(0xFFB9D2E3),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              SizedBox(height: 16),
              _CommandButton(
                label: 'Analytics & Reports',
                route: '/admin/analytics',
              ),
              _CommandButton(label: 'Manage Orders', route: '/admin/orders'),
              _CommandButton(
                label: 'Manage Inventory',
                route: '/admin/catalog',
              ),
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('$label coming soon')));
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        color: const Color(0xFF1B527A),
        child: Text(
          '$label↗',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
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
          const Text(
            'STOCK HEALTH DENSITY',
            style: TextStyle(
              color: Color(0xFF657583),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: .8,
            ),
          ),
          const SizedBox(height: 14),
          if (categories.isEmpty)
            const Text(
              'No products yet.',
              style: TextStyle(
                color: AppPalette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            )
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
  const _HealthBar({
    required this.label,
    required this.value,
    required this.color,
    required this.percent,
  });

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
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                percent,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          LinearProgressIndicator(
            value: value,
            minHeight: 5,
            color: color,
            backgroundColor: const Color(0xFFE6ECF2),
          ),
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
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        items[i].$1,
                        color: AppPalette.navy,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      items[i].$2,
                      style: const TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

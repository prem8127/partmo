import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/supabase_service.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await SupabaseService.fetchDashboardStats();
      setState(() {
        _stats = s;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        SupabaseService.currentUser?.email ?? 'admin@precisionparts.com';
    final sinceRaw = SupabaseService.currentUser?.createdAt;
    final since = sinceRaw != null ? DateTime.tryParse(sinceRaw) : null;
    final sinceStr = since != null
        ? '${since.day} ${_mon(since.month)} ${since.year}'
        : 'N/A';

    final totalOrders = (_stats?['totalOrders'] as int?) ?? 0;
    final revenue = (_stats?['monthRevenue'] as double?) ?? 0;
    final users = (_stats?['activeUsers'] as int?) ?? 0;
    final pending = (_stats?['pendingShipments'] as int?) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      bottomNavigationBar: const _AdminProfileBottomNav(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // ── Hero header ──
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppPalette.navy, const Color(0xFF1B527A)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      20, MediaQuery.paddingOf(context).top + 20, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.15),
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.admin_panel_settings,
                              color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              const Text('Administrator',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: AppPalette.cyan.withOpacity(.25),
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text('SUPER ADMIN',
                                    style: TextStyle(
                                        color: AppPalette.cyan,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1)),
                              ),
                            ])),
                      ]),
                      const SizedBox(height: 16),
                      _InfoRow(Icons.email_outlined, email),
                      const SizedBox(height: 8),
                      _InfoRow(
                          Icons.store_outlined, 'Precision Parts — PartMo'),
                      const SizedBox(height: 8),
                      _InfoRow(Icons.calendar_today_outlined,
                          'Account since $sinceStr'),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Quick stats ──
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        const _SectionLabel('STORE OVERVIEW'),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _StatTile(
                                  'TOTAL ORDERS',
                                  '$totalOrders',
                                  Icons.receipt_long_outlined,
                                  AppPalette.navy)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatTile(
                                  'PENDING',
                                  '$pending',
                                  Icons.local_shipping_outlined,
                                  AppPalette.warning)),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                              child: _StatTile(
                                  'THIS MONTH',
                                  '₹${_compact(revenue)}',
                                  Icons.payments_outlined,
                                  AppPalette.success)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _StatTile('USERS', '$users',
                                  Icons.groups_outlined, AppPalette.cyan)),
                        ]),
                        const SizedBox(height: 20),
                      ],

                      // ── Navigation ──
                      const _SectionLabel('NAVIGATION'),
                      const SizedBox(height: 10),
                      _AdminMenuTile(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard',
                          subtitle: 'Overview & stats',
                          onTap: () => context.go('/admin')),
                      _AdminMenuTile(
                          icon: Icons.bar_chart,
                          label: 'Analytics',
                          subtitle: 'Revenue & trends',
                          onTap: () => context.go('/admin/analytics')),
                      _AdminMenuTile(
                          icon: Icons.inventory_2_outlined,
                          label: 'Manage Catalog',
                          subtitle: 'Edit products & stock',
                          onTap: () => context.go('/admin/catalog')),
                      _AdminMenuTile(
                          icon: Icons.add_box_outlined,
                          label: 'Add Product',
                          subtitle: 'List a new part',
                          onTap: () => context.go('/admin/add-product')),
                      const SizedBox(height: 20),

                      // ── Account ──
                      const _SectionLabel('ACCOUNT'),
                      const SizedBox(height: 10),
                      _AdminMenuTile(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        subtitle: 'Reset via email OTP',
                        onTap: () => context.go('/forgot-password'),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await SupabaseService.signOut();
                            if (context.mounted) context.go('/login');
                          },
                          icon: const Icon(Icons.logout,
                              color: AppPalette.danger),
                          label: const Text('Sign Out',
                              style: TextStyle(
                                  color: AppPalette.danger,
                                  fontWeight: FontWeight.w900)),
                          style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppPalette.danger)),
                        ),
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

  static String _mon(int m) => [
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
  static String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: Colors.white60, size: 14),
      const SizedBox(width: 8),
      Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600))),
    ]);
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
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .8));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile(this.label, this.value, this.icon, this.color);
  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: color, width: 3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Color(0xFF172635),
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF657583),
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: .6)),
      ]),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  const _AdminMenuTile(
      {required this.icon,
      required this.label,
      this.subtitle,
      required this.onTap});
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        color: Colors.white,
        child: Row(children: [
          Icon(icon, color: AppPalette.navy, size: 20),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF172635),
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          color: Color(0xFF9CA8B4),
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ])),
          const Icon(Icons.chevron_right, color: Color(0xFF9CA8B4), size: 20),
        ]),
      ),
    );
  }
}

class _AdminProfileBottomNav extends StatelessWidget {
  const _AdminProfileBottomNav();

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
                          color: i == 4
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

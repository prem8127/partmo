import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/admin_stat.dart';

final adminStatsProvider = Provider<List<AdminStat>>((ref) {
  return const [
    AdminStat(title: 'Total Orders', value: '12,842', delta: '+12%'),
    AdminStat(title: 'Pending Approvals', value: '148', delta: '+6'),
    AdminStat(title: 'Revenue', value: '₹42,85,200', delta: '+18%'),
    AdminStat(title: 'Active SKUs', value: '3,205', delta: '+93'),
  ];
});

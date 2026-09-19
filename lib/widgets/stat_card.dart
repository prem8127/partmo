import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/admin_stat.dart';

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.stat});

  final AdminStat stat;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stat.title,
                style: const TextStyle(
                    color: AppPalette.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(stat.value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const Spacer(),
            Text(stat.delta,
                style: const TextStyle(
                    color: AppPalette.success, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

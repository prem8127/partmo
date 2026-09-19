import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class BannerCarousel extends StatelessWidget {
  const BannerCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 144,
      child: PageView(
        children: const [
          _Banner(
              title: 'The Precision Engineer’s Dealer',
              subtitle: 'Verified OEM-compatible parts with same-day dispatch.',
              icon: Icons.engineering),
          _Banner(
              title: 'Garage Priority Supply',
              subtitle: 'Bulk pricing, invoice downloads, and support.',
              icon: Icons.storefront),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(
      {required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppPalette.navy,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(subtitle, style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          Icon(icon, color: AppPalette.cyan, size: 58),
        ],
      ),
    );
  }
}

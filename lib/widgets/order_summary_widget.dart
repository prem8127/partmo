import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';

class OrderSummaryWidget extends StatelessWidget {
  const OrderSummaryWidget({super.key, required this.subtotal});

  final double subtotal;

  @override
  Widget build(BuildContext context) {
    const delivery = 190.0;
    const taxRate = .18;
    final tax = subtotal * taxRate;
    final total = subtotal + delivery + tax;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order Summary',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const Divider(height: 24),
            _Row(label: 'Subtotal', value: subtotal),
            const _Row(label: 'Delivery', value: delivery),
            _Row(label: 'GST', value: tax),
            const Divider(height: 24),
            _Row(label: 'Total Amount', value: total, strong: true),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value, this.strong = false});

  final String label;
  final double value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? const TextStyle(
            fontWeight: FontWeight.w900, color: AppPalette.navy, fontSize: 18)
        : const TextStyle(fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('${AppConstants.currency}${value.toStringAsFixed(0)}',
              style: style),
        ],
      ),
    );
  }
}

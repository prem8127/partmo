import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/payment_method.dart';

class PaymentMethodTile extends StatelessWidget {
  const PaymentMethodTile(
      {super.key,
      required this.method,
      required this.selected,
      required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: AppPalette.navy,
          child: Text(method.iconLabel,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ),
        title: Row(
          children: [
            Expanded(
                child: Text(method.title,
                    style: const TextStyle(fontWeight: FontWeight.w900))),
            if (method.isRecommended) const Chip(label: Text('Recommended')),
          ],
        ),
        subtitle: Text(method.subtitle),
        trailing: Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            color: AppPalette.cyan),
      ),
    );
  }
}

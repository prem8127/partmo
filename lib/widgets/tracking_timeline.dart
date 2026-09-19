import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/order.dart';

class TrackingTimeline extends StatelessWidget {
  const TrackingTimeline({super.key, required this.steps});

  final List<OrderStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(
                      steps[i].done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color:
                          steps[i].done ? AppPalette.cyan : AppPalette.muted),
                  if (i != steps.length - 1)
                    Container(width: 2, height: 42, color: AppPalette.line),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(steps[i].title,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      Text(steps[i].subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppPalette.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

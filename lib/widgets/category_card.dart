import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/category.dart';
import 'hover_lift.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      borderRadius: BorderRadius.circular(8),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(category.icon, color: AppPalette.navy, size: 26),
                const SizedBox(height: 8),
                Text(category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${category.count} parts',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppPalette.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../models/product.dart';

class ProductImageCarousel extends StatelessWidget {
  const ProductImageCarousel({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: PageView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppPalette.line)),
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: _hasRealImage(product.imageIcon)
                        ? Image.network(
                            product.imageIcon,
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => Center(
                              child: Icon(_iconFor(product.imageIcon),
                                  size: 110,
                                  color: AppPalette.navy.withOpacity(.86)),
                            ),
                          )
                        : Center(
                            child: Icon(_iconFor(product.imageIcon),
                                size: 110,
                                color: AppPalette.navy.withOpacity(.86))),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Chip(
                      label: Text(
                          index == 0 ? product.badge : 'View ${index + 1}'),
                      backgroundColor: AppPalette.warning),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

bool _hasRealImage(String value) =>
    value.startsWith('http://') || value.startsWith('https://');

IconData _iconFor(String key) {
  return switch (key) {
    'lamp' => Icons.lightbulb,
    'filter' => Icons.filter_alt,
    'clutch' => Icons.settings,
    _ => Icons.disc_full,
  };
}

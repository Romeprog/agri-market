import 'package:flutter/material.dart';
import '../models/product.dart';


class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.product,
    required this.seedColor,
    this.iconSize = 36,
    this.fit = BoxFit.cover,
    this.iconColor,
  });

  final Product product;
  final Color seedColor;
  final double iconSize;
  final BoxFit fit;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      product.icon,
      color: iconColor ?? seedColor,
      size: iconSize,
    );

    if (product.image.isEmpty) return fallback;

    if (product.image.startsWith('http')) {
      return Image.network(
        product.image,
        fit: fit,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: seedColor),
          );
        },
        errorBuilder: (context, error, stack) => fallback,
      );
    }

    return Image.asset(
      product.image,
      fit: fit,
      errorBuilder: (context, error, stack) => fallback,
    );
  }
}

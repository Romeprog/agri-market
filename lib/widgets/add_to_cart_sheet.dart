import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import 'product_image.dart';

Future<int?> showAddToCartSheet(
  BuildContext context,
  Product product, {
  Color seedColor = const Color(0xFF1F3D2B),
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _AddToCartSheet(product: product, seedColor: seedColor),
  );
}

class _AddToCartSheet extends StatefulWidget {
  const _AddToCartSheet({required this.product, required this.seedColor});

  final Product product;
  final Color seedColor;

  @override
  State<_AddToCartSheet> createState() => _AddToCartSheetState();
}

class _AddToCartSheetState extends State<_AddToCartSheet> {
  int _quantity = 1;

  Product get product => widget.product;
  Color get seedColor => widget.seedColor;

  String get _unitLabel {
    final raw = product.unit.trim();
    if (raw.isEmpty) return '';
    return raw.toLowerCase().startsWith('per ') ? raw : 'per $raw';
  }

  @override
  Widget build(BuildContext context) {
    final subtotal = product.price * _quantity;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Color(0xFFEFF1E4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ProductImage(
                      product: product,
                      seedColor: seedColor.withValues(alpha: 0.5),
                      iconSize: 28,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: seedColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (_unitLabel.isNotEmpty)
                          Text(
                            _unitLabel,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        Text(
                          product.inStock
                              ? '${product.available} available'
                              : 'No stock available',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: product.inStock
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: product.inStock
                                ? Colors.grey[600]
                                : Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Quantity',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: seedColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: Icon(Icons.remove, size: 18),
                          color: seedColor,
                          disabledColor: Colors.grey[300],
                          constraints: BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Center(
                            child: Text(
                              '$_quantity',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _quantity < product.available
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: Icon(Icons.add, size: 18),
                          color: seedColor,
                          disabledColor: Colors.grey[300],
                          constraints: BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: product.inStock
                      ? () => Navigator.pop(context, _quantity)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: seedColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    product.inStock
                        ? 'Add to Cart · ₱${subtotal.toStringAsFixed(2)}'
                        : 'No stock available',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
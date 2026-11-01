import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'press_scale.dart';

enum ProductSortOption { none, priceLowHigh, priceHighLow, newest, rating }

class ProductFilters {
  final ProductSortOption sort;
  final RangeValues? priceRange;

  const ProductFilters({this.sort = ProductSortOption.none, this.priceRange});

  bool get isActive => sort != ProductSortOption.none || priceRange != null;
}

Future<ProductFilters?> showProductFilterSheet({
  required BuildContext context,
  required ProductFilters current,
  required Color seedColor,
  double minPrice = 0,
  double maxPrice = 1000,
}) {
  return showModalBottomSheet<ProductFilters>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Color(0xFFEFF1E4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ProductFilterSheet(
      current: current,
      seedColor: seedColor,
      minPrice: minPrice,
      maxPrice: maxPrice,
    ),
  );
}

class _ProductFilterSheet extends StatefulWidget {
  const _ProductFilterSheet({
    required this.current,
    required this.seedColor,
    required this.minPrice,
    required this.maxPrice,
  });

  final ProductFilters current;
  final Color seedColor;
  final double minPrice;
  final double maxPrice;

  @override
  State<_ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<_ProductFilterSheet> {
  static const _sortLabels = {
    ProductSortOption.none: 'Default',
    ProductSortOption.priceLowHigh: 'Price: Low to High',
    ProductSortOption.priceHighLow: 'Price: High to Low',
    ProductSortOption.newest: 'Newest',
    ProductSortOption.rating: 'Highest Rated',
  };

  late ProductSortOption _sort;
  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    _sort = widget.current.sort;
    _range =
        widget.current.priceRange ??
        RangeValues(widget.minPrice, widget.maxPrice);
  }

  @override
  Widget build(BuildContext context) {
    final seedColor = widget.seedColor;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: seedColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              SizedBox(width: 8),
              Text(
                'Sort & Filter',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: seedColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),
          Text(
            'Sort by',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ProductSortOption.values.map((option) {
              final selected = _sort == option;
              return ChoiceChip(
                label: Text(_sortLabels[option]!),
                selected: selected,
                onSelected: (_) => setState(() => _sort = option),
                showCheckmark: false,
                selectedColor: seedColor,
                backgroundColor: Colors.grey.shade100,
                elevation: selected ? 3 : 0,
                pressElevation: 0,
                shadowColor: seedColor.withValues(alpha: 0.4),
                labelStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : Colors.black87,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: selected ? seedColor : Colors.grey.shade300,
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 22),
          Text(
            'Price range',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          RangeSlider(
            values: RangeValues(
              _range.start.clamp(widget.minPrice, widget.maxPrice),
              _range.end.clamp(widget.minPrice, widget.maxPrice),
            ),
            min: widget.minPrice,
            max: widget.maxPrice,
            divisions: (widget.maxPrice - widget.minPrice).round().clamp(
              1,
              200,
            ),
            activeColor: seedColor,
            inactiveColor: seedColor.withValues(alpha: 0.15),
            labels: RangeLabels(
              '₱${_range.start.round()}',
              '₱${_range.end.round()}',
            ),
            onChanged: (v) => setState(() => _range = v),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seedColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₱${_range.start.round()}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: seedColor,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: seedColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₱${_range.end.round()}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: seedColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, ProductFilters()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: seedColor,
                    side: BorderSide(color: seedColor),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Reset',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: PressScale(
                  child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    ProductFilters(sort: _sort, priceRange: _range),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: seedColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Apply',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
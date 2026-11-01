import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../widgets/add_to_cart_sheet.dart';
import '../widgets/cart_button.dart';
import '../widgets/fade_slide_in.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filter_sheet.dart';
import 'cart_screen.dart';
import 'product_detail_screen.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _accentColor = Color(0xFFE0A63A);
  static const _bgColor = Color(0xFFEFF1E4);

  static const _categoryIcons = {
    'All': Icons.grid_view_rounded,
    'Vegetables': Icons.eco_outlined,
    'Fruits': Icons.apple_outlined,
    'Grains': Icons.grain,
    'Dairy': Icons.local_drink_outlined,
    'Livestock': Icons.pets_outlined,
    'Tools': Icons.handyman_outlined,
  };

  static const _categories = [
    'All',
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Livestock',
    'Tools',
  ];

  String _selectedCategory = 'All';
  String _searchQuery = '';
  ProductFilters _filters = const ProductFilters();

  Stream<List<Product>> _firestoreProductsStream() {
    return FirebaseFirestore.instance.collection('products').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return Product.fromFirestore(doc);
      }).toList();
    });
  }

  List<Product> _combineProducts(List<Product> firestoreProducts) {
    final products = <Product>[];

    products.addAll(firestoreProducts);
    return products;
  }

  List<Product> _filterProducts(List<Product> products) {
    return products.where((product) {
      final matchesCategory =
          _selectedCategory == 'All' || product.category == _selectedCategory;

      final query = _searchQuery.toLowerCase();
      final matchesSearch =
          product.name.toLowerCase().contains(query) ||
          (product.location?.toLowerCase().contains(query) ?? false) ||
          (product.farmerName?.toLowerCase().contains(query) ?? false);

      final matchesPrice =
          _filters.priceRange == null ||
          (product.price >= _filters.priceRange!.start &&
              product.price <= _filters.priceRange!.end);

      return matchesCategory && matchesSearch && matchesPrice;
    }).toList();
  }

  List<Product> _sortProducts(List<Product> products) {
    final sorted = [...products];
    switch (_filters.sort) {
      case ProductSortOption.priceLowHigh:
        sorted.sort((a, b) => a.price.compareTo(b.price));
      case ProductSortOption.priceHighLow:
        sorted.sort((a, b) => b.price.compareTo(a.price));
      case ProductSortOption.newest:
        sorted.sort(
          (a, b) => (b.createdAt ?? DateTime(0)).compareTo(
            a.createdAt ?? DateTime(0),
          ),
        );
      case ProductSortOption.rating:
        sorted.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      case ProductSortOption.none:
        break;
    }
    return sorted;
  }

  bool get _hasActiveFilters =>
      _filters.priceRange != null || _filters.sort != ProductSortOption.none;

  void _openCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
  }

  Future<void> _promptAddToCart(Product product) async {
    if (!product.inStock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} has no stock available.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final quantity = await showAddToCartSheet(
      context,
      product,
      seedColor: _seedColor,
    );
    if (quantity == null) return;
    if (!mounted) return;
    await _addToCart(product, quantity: quantity);
  }

  Future<void> _addToCart(Product product, {int quantity = 1}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to add items to your cart')),
      );
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'cartItems': {product.key: FieldValue.increment(quantity)},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Add to cart failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not add to cart: $e')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${quantity > 1 ? '$quantity × ' : ''}${product.name} added to cart',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _seedColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Explore',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Browse fresh finds from local farmers',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _bgColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: CartButton(onTap: _openCart),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _seedColor.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (query) {
                          setState(() {
                            _searchQuery = query;
                          });
                        },
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Search fresh produce…',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _seedColor.withValues(alpha: 0.6),
                            size: 22,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  InkWell(
                    onTap: () async {
                      final result = await showProductFilterSheet(
                        context: context,
                        current: _filters,
                        seedColor: _seedColor,
                      );
                      if (result != null) {
                        setState(() => _filters = result);
                      }
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: _seedColor,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: _seedColor.withValues(alpha: 0.28),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        if (_hasActiveFilters)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _accentColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: _bgColor, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _SectionHeader(
              title: 'Categories',
              seedColor: _seedColor,
            ),
            SizedBox(height: 6),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, _) => SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final isSelected = category == _selectedCategory;
                  return _CategoryCircleFilter(
                    label: category,
                    icon: _categoryIcons[category] ?? Icons.category_outlined,
                    selected: isSelected,
                    seedColor: _seedColor,
                    onTap: () {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                  );
                },
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Product>>(
                stream: _firestoreProductsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(color: _seedColor),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Unable to load new products.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    );
                  }
                  final firestoreProducts = snapshot.data ?? [];
                  final allProductsCombined = _combineProducts(
                    firestoreProducts,
                  );
                  final filtered = _sortProducts(
                    _filterProducts(allProductsCombined),
                  );
                  return Column(
                    children: [
                      _SectionHeader(
                        title: _selectedCategory == 'All'
                            ? 'All Products'
                            : _selectedCategory,
                        seedColor: _seedColor,
                        trailing: _CountBadge(
                          count: filtered.length,
                          seedColor: _seedColor,
                        ),
                      ),
                      if (filtered.isEmpty)
                        Expanded(child: _EmptyState(seedColor: _seedColor))
                      else
                        Expanded(
                          child: GridView.builder(
                            physics: BouncingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),

                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 0.68,
                                ),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              return FadeSlideIn(
                                key: ValueKey(product.key),
                                index: index,
                                child: ProductCard(
                                product: product,
                                seedColor: _seedColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                                onAddToCart: () {
                                  _promptAddToCart(product);
                                },
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.seedColor,
    this.trailing,
  });

  final String title;
  final Color seedColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
                title,
                style: GoogleFonts.fraunces(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: seedColor,
                ),
              ),
            ],
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.seedColor});

  final int count;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: seedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count item${count == 1 ? '' : 's'}',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: seedColor,
        ),
      ),
    );
  }
}

class _CategoryCircleFilter extends StatelessWidget {
  const _CategoryCircleFilter({
    required this.label,
    required this.icon,
    required this.selected,
    required this.seedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color seedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 64,
        child: Column(
          children: [
            AnimatedContainer(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: selected ? seedColor : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? seedColor
                      : seedColor.withValues(alpha: 0.15),
                  width: selected ? 0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? seedColor.withValues(alpha: 0.32)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: selected ? 12 : 6,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : seedColor,
                size: 24,
              ),
            ),
            SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? seedColor : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: seedColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 38,
                color: seedColor.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: seedColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Try a different search or category',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
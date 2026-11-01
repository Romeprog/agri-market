import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/products.dart';
import '../utils/currency.dart';
import '../widgets/product_image.dart';
import 'checkout_screen.dart';
import 'product_detail_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  final Set<String> _selectedKeys = {};

  void _toggleSelected(String productKey) {
    setState(() {
      if (_selectedKeys.contains(productKey)) {
        _selectedKeys.remove(productKey);
      } else {
        _selectedKeys.add(productKey);
      }
    });
  }

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _productsStream =
      FirebaseFirestore.instance.collection('products').snapshots();

  late final Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream =
      FirebaseAuth.instance.currentUser == null
      ? null
      : FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .snapshots();

  Future<void> _removeFromCart(String productKey) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'cartItems': {productKey: FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  Future<void> _updateQuantity(String productKey, int newQuantity) async {
    if (newQuantity < 1) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'cartItems': {productKey: newQuantity},
    }, SetOptions(merge: true));
  }

  bool _canBuy(Product p) => p.id != null && p.inStock;

  Product? _findProduct(List<Product> catalog, String key) {
    for (final product in catalog) {
      if (product.key == key) return product;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 4,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          leading: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.arrow_back, color: _bgColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          title: Text(
            'Shopping Cart',
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _bgColor,
            ),
          ),
        ),
      ),
      body: user == null
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _seedColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 38,
                        color: _seedColor.withValues(alpha: 0.55),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Please sign in',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Sign in to view items in your cart',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _productsStream,
              builder: (context, productsSnapshot) {
                if (productsSnapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load products: ${productsSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                final firestoreProducts =
                    productsSnapshot.data?.docs
                        .map(Product.fromFirestore)
                        .toList() ??
                    <Product>[];
                final catalog = [...allProducts, ...firestoreProducts];
                return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Could not load your cart: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return Center(
                        child: CircularProgressIndicator(color: _seedColor),
                      );
                    }
                    final cartMap = Map<String, dynamic>.from(
                      snapshot.data?.data()?['cartItems'] as Map? ?? {},
                    );
                    final cartEntries = <(Product, int)>[];
                    cartMap.forEach((key, value) {
                      final product = _findProduct(catalog, key);
                      if (product != null) {
                        final quantity = (value as num?)?.toInt() ?? 1;
                        cartEntries.add((product, quantity));
                      }
                    });
                    if (cartEntries.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.shopping_cart_outlined,
                                size: 44,
                                color: _seedColor.withValues(alpha: 0.4),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Your cart is empty',
                                style: GoogleFonts.fraunces(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _seedColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Add products from Explore to see them here',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    final selectedEntries = cartEntries
                        .where(
                          (entry) =>
                              _selectedKeys.contains(entry.$1.key) &&
                              _canBuy(entry.$1),
                        )
                        .map(
                          (entry) => (
                            entry.$1,
                            entry.$2 > entry.$1.available
                                ? entry.$1.available
                                : entry.$2,
                          ),
                        )
                        .toList();
                    final selectedTotal = selectedEntries.fold<double>(
                      0,
                      (runningTotal, entry) =>
                          runningTotal + entry.$1.price * entry.$2,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
                            itemCount: cartEntries.length,
                            separatorBuilder: (_, _) => SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final (product, quantity) = cartEntries[index];
                              final isSelected =
                                  _selectedKeys.contains(product.key) &&
                                  _canBuy(product);
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _seedColor.withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: _canBuy(product)
                                            ? () => _toggleSelected(product.key)
                                            : null,
                                        child: Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Container(
                                            width: 22,
                                            height: 22,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: isSelected
                                                  ? _seedColor
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: isSelected
                                                    ? _seedColor
                                                    : Colors.grey[400]!,
                                                width: 1.6,
                                              ),
                                            ),
                                            child: isSelected
                                                ? Icon(
                                                    Icons.check_rounded,
                                                    size: 14,
                                                    color: _bgColor,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Expanded(
                                        child: Material(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    ProductDetailScreen(
                                                      product: product,
                                                    ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  clipBehavior: Clip.antiAlias,
                                                  decoration: BoxDecoration(
                                                    color: _seedColor
                                                        .withValues(
                                                          alpha: 0.08,
                                                        ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: ProductImage(
                                                    product: product,
                                                    seedColor: _seedColor,
                                                    iconSize: 26,
                                                  ),
                                                ),
                                                SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        product.name,
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              fontSize: 14,
                                                            ),
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        '${formatPeso(product.price)} \u00b7 ${product.unit}',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 12.5,
                                                              color: Colors
                                                                  .grey[600],
                                                            ),
                                                      ),
                                                      if (!_canBuy(product))
                                                        Text(
                                                          'No stock available',
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                color: Colors
                                                                    .red[700],
                                                              ),
                                                        )
                                                      else if (quantity >
                                                          product.available)
                                                        Text(
                                                          'Only ${product.available} left',
                                                          style:
                                                              GoogleFonts.inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .orange[800],
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Colors.redAccent,
                                              size: 20,
                                            ),
                                            onPressed: () =>
                                                _removeFromCart(product.key),
                                          ),
                                          SizedBox(height: 8),
                                          _QuantityStepper(
                                            quantity: quantity,
                                            unit: product.unit,
                                            seedColor: _seedColor,
                                            onDecrement: () => _updateQuantity(
                                              product.key,
                                              quantity - 1,
                                            ),
                                            onIncrement:
                                                quantity < product.available
                                                ? () => _updateQuantity(
                                                    product.key,
                                                    quantity + 1,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.fromLTRB(20, 18, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.10),
                                blurRadius: 14,
                                offset: Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        formatPeso(selectedTotal),
                                        style: GoogleFonts.fraunces(
                                          fontSize: 19,
                                          fontWeight: FontWeight.bold,
                                          color: _seedColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 14),
                                SizedBox(
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: selectedEntries.isEmpty
                                        ? null
                                        : () => Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => CheckoutScreen(
                                                items: selectedEntries,
                                              ),
                                            ),
                                          ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _seedColor,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: Colors.grey[400],
                                      elevation: 0,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 26,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      selectedEntries.isEmpty
                                          ? 'Check out'
                                          : 'Check out (${selectedEntries.length})',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.unit,
    required this.seedColor,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final String unit;
  final Color seedColor;
  final VoidCallback onDecrement;
  final VoidCallback? onIncrement;

  String get _unitNoun {
    final raw = unit.trim();
    if (raw.isEmpty) return '';
    return raw.toLowerCase().startsWith('per ') ? raw.substring(4).trim() : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(icon: Icons.remove, onTap: onDecrement),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _unitNoun.isEmpty ? '$quantity' : '$quantity $_unitNoun',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _StepperButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(5),
        child: Icon(
          icon,
          size: 15,
          color: onTap == null ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }
}
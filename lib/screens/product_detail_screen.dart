import 'dart:async';
import 'package:agri_market/screens/checkout_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../models/review.dart';
import '../services/review_service.dart';
import '../utils/app_mode.dart';
import '../utils/currency.dart';
import '../widgets/add_to_cart_sheet.dart';
import '../widgets/cart_button.dart';
import '../widgets/fly_to_cart.dart';
import '../widgets/product_image.dart';
import '../widgets/product_card.dart';
import '../widgets/review_card.dart';
import 'cart_screen.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.product,
    this.viewOnly = false,
  });

  final Product product;
  final bool viewOnly;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen>
    with SingleTickerProviderStateMixin {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  int _quantity = 1;

  final GlobalKey _addBtnKey = GlobalKey();
  final GlobalKey _cartKey = GlobalKey();
  final Map<String, GlobalKey> _relatedKeys = {};
  late final AnimationController _cartBump = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 520),
  );
  late final Animation<double> _cartScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 1.3).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.3, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
  ]).animate(_cartBump);
  Product? _live;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _stockSub;
  Product get product => _live ?? widget.product;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _relatedStream;
  double get _subtotal => product.price * _quantity;

  String get _unitNoun {
    final raw = product.unit.trim();
    if (raw.isEmpty) return 'unit';
    return raw.toLowerCase().startsWith('per ') ? raw.substring(4).trim() : raw;
  }

  bool get _isOwner =>
      FirebaseAuth.instance.currentUser?.uid == product.farmerId;
  bool get _isViewOnly => widget.viewOnly;
  /// owner, from view-only previews, and from anyone in seller mode.
  bool get _showRelatedProducts =>
      !_isOwner && !_isViewOnly && activeRoleNotifier.value != AppRole.seller;

  @override
  void initState() {
    super.initState();
    final category = widget.product.category;
    if (category != null && category.isNotEmpty) {
      _relatedStream = FirebaseFirestore.instance
          .collection('products')
          .where('category', isEqualTo: category)
          .limit(30)
          .snapshots();
    }
    final id = widget.product.id;
    if (id == null) return;
    _stockSub = FirebaseFirestore.instance
        .collection('products')
        .doc(id)
        .snapshots()
        .listen((snap) {
          if (!mounted || !snap.exists) return;
          setState(() {
            _live = Product.fromFirestore(snap);
            final max = _live!.available;
            if (max > 0 && _quantity > max) _quantity = max;
          });
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _stockSub?.cancel();
    _cartBump.dispose();
    super.dispose();
  }

  void _showStockMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _playFly(Product flying, int qty, Product? target) {
    if (!mounted) return;
    final fromKey = target == null
        ? _addBtnKey
        : (_relatedKeys[target.key] ?? _addBtnKey);
    flyToCart(
      context: context,
      fromKey: fromKey,
      toKey: _cartKey,
      quantity: qty,
      seedColor: _seedColor,
      thumbnail: ProductImage(
        product: flying,
        seedColor: _seedColor,
        iconSize: 24,
        fit: BoxFit.cover,
      ),
      onArrive: () {
        if (mounted) _cartBump.forward(from: 0);
      },
    );
  }

  Future<void> _addToCart([Product? target]) async {
    final product = target ?? this.product;
    if (!product.inStock) {
      _showStockMessage('${product.name} has no stock available.');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to add items to your cart')),
      );
      return;
    }
    final qty = await showAddToCartSheet(
      context,
      product,
      seedColor: _seedColor,
    );
    if (qty == null) return;
    if (qty > product.available) {
      _showStockMessage('Only ${product.available} left of ${product.name}.');
      return;
    }

    _playFly(product, qty, target);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'cartItems': {product.key: FieldValue.increment(qty)},
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
          '$qty × ${product.name} added to cart',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _seedColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildRelatedProducts() {
    final stream = _relatedStream;
    if (stream == null) return SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return SizedBox.shrink();
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: _seedColor)),
          );
        }
        final related =
            snapshot.data!.docs
                .where((doc) => doc.id != widget.product.id)
                .map(Product.fromFirestore)
                .toList()
              ..sort((a, b) {
                if (a.inStock == b.inStock) return 0;
                return a.inStock ? -1 : 1;
              });
        if (related.isEmpty) return SizedBox.shrink();
        final shown = related.take(10).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 22),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: _seedColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Related Products',
                    style: GoogleFonts.fraunces(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: _seedColor,
                    ),
                  ),
                ],
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final item = shown[index];
                return KeyedSubtree(
                  key: _relatedKeys.putIfAbsent(item.key, () => GlobalKey()),
                  child: ProductCard(
                  product: item,
                  seedColor: _seedColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(
                          product: item,
                          viewOnly: widget.viewOnly,
                        ),
                      ),
                    );
                  },
                  onAddToCart: () => _addToCart(item),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _buyNow() {
    if (!product.inStock) {
      _showStockMessage('${product.name} has no stock available.');
      return;
    }
    if (_quantity > product.available) {
      _showStockMessage('Only ${product.available} left of ${product.name}.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutScreen(items: [(product, _quantity)]),
      ),
    );
  }

  Future<void> _deleteListing() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete this listing?'),
        content: Text(
          'This will permanently remove "${product.name}" from the '
          'marketplace. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: TextButton.styleFrom(foregroundColor: Colors.black),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;
    final id = product.id;
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await FirebaseFirestore.instance.collection('products').doc(id).delete();
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${product.name} was deleted.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: _seedColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not delete listing. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  static const _reportReasons = [
    'Not an agricultural product',
    'Misleading listing',
    'Inappropriate content',
    'Other',
  ];

  Future<void> _reportProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please sign in to report a listing')),
      );
      return;
    }
    final productId = product.id;
    final farmerId = product.farmerId;
    if (productId == null || farmerId == null || farmerId == user.uid) return;

    String selectedReason = _reportReasons.first;
    final detailsController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isOther = selectedReason == 'Other';
            final canSubmit =
                !isOther || detailsController.text.trim().length >= 10;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report this listing',
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _seedColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tell us what\'s wrong with "${product.name}".',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 8),
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (v) => setSheetState(
                      () => selectedReason = v ?? selectedReason,
                    ),
                    child: Column(
                      children: [
                        for (final reason in _reportReasons)
                          RadioListTile<String>(
                            value: reason,
                            activeColor: _seedColor,
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              reason,
                              style: GoogleFonts.inter(fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (isOther) ...[
                    SizedBox(height: 4),
                    TextField(
                      controller: detailsController,
                      maxLength: 300,
                      maxLines: 3,
                      minLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setSheetState(() {}),
                      style: GoogleFonts.inter(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Please describe what is wrong with this listing.',
                        helperText: 'Required, at least 10 characters',
                        hintStyle: GoogleFonts.inter(
                          fontSize: 13.5,
                          color: Colors.grey[500],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _seedColor, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _seedColor,
                        disabledBackgroundColor: _seedColor.withValues(alpha: 0.3),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: canSubmit
                          ? () => Navigator.pop(sheetContext, true)
                          : null,
                      child: Text(
                        'Submit Report',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              ),
            );
          },
        );
      },
    );

    final details = detailsController.text.trim();
    Future.delayed(Duration(milliseconds: 100), detailsController.dispose);

    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final firestore = FirebaseFirestore.instance;
      final reportRef = firestore.collection('reports').doc();

      var reporterName = (user.displayName ?? '').trim();
      try {
        final userDoc = await firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data();
        for (final key in ['name', 'fullName', 'displayName']) {
          final value = data?[key];
          if (value is String && value.trim().isNotEmpty) {
            reporterName = value.trim();
            break;
          }
        }
      } catch (_) {}
      if (reporterName.isEmpty) {
        reporterName = (user.email ?? '').split('@').first;
      }
      if (reporterName.length > 100) {
        reporterName = reporterName.substring(0, 100);
      }

      await reportRef.set({
        'productId': productId,
        'productName': product.name,
        'reportedFarmerId': farmerId,
        'reporterId': user.uid,
        'reporterEmail': user.email,
        'reporterName': reporterName,
        'reason': selectedReason,
        if (selectedReason == 'Other') 'details': details,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Report submission failed: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit report. Please try again.')),
      );
      return;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Thanks — we\'ll review this listing.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _seedColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProductImage() {
    final fallback = Container(
      color: Color(0xFFEFF1E4),
      child: Center(
        child: Icon(
          product.icon,
          size: 100,
          color: _seedColor.withValues(alpha: 0.35),
        ),
      ),
    );

    if (product.image.startsWith('http')) {
      return Image.network(
        product.image,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            color: Color(0xFFEFF1E4),
            child: Center(
              child: CircularProgressIndicator(
                color: _seedColor,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => fallback,
      );
    }

    return Image.asset(
      product.image,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rating = product.rating ?? 0;
    final reviewCount = product.reviewCount ?? 0;
    final sold = product.sold ?? 0;

    return Scaffold(
      backgroundColor: _bgColor,
      extendBodyBehindAppBar: true,
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
            'Product Details',
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _bgColor,
            ),
          ),
          actions: [
            if (_isOwner && !_isViewOnly)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _deleteListing,
                    icon: Icon(Icons.delete_outline, color: _bgColor, size: 20),
                  ),
                ),
              ),
            if (!_isOwner && !_isViewOnly)
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    onPressed: _reportProduct,
                    icon: Icon(Icons.flag_outlined, color: _bgColor, size: 20),
                  ),
                ),
              ),
            if (!_isViewOnly)
              Padding(
                padding: EdgeInsets.only(right: 16),
                child: ScaleTransition(
                  scale: _cartScale,
                  child: Container(
                    key: _cartKey,
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: CartButton(
                      animate: false,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => CartScreen()),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _isViewOnly
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                child: _isOwner
                    ? Row(
                        children: [
                          Icon(Icons.storefront_outlined, color: _seedColor),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "This is your own listing — you can't buy your own product.",
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                color: _seedColor,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                SizedBox(height: 2),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    formatPeso(_subtotal),
                                    style: GoogleFonts.inter(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: _seedColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 10),
                          Tooltip(
                            message: 'Add to cart',
                            child: SizedBox(
                              key: _addBtnKey,
                              width: 50,
                              height: 50,
                              child: OutlinedButton(
                                onPressed: product.inStock ? _addToCart : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _seedColor,
                                  side: BorderSide(
                                    color: product.inStock
                                        ? _seedColor
                                        : Colors.grey[400]!,
                                  ),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Icon(
                                  Icons.add_shopping_cart_outlined,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: product.inStock ? _buyNow : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _seedColor,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.grey[400],
                                  disabledForegroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  product.inStock ? 'Buy Now' : 'Sold Out',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height:
                  330 +
                  MediaQuery.of(context).padding.top +
                  kToolbarHeight +
                  10,
              child: _buildProductImage(),
            ),
            SizedBox(height: 14),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 14),
              padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatPeso(product.price),
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _seedColor,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    product.name,
                    style: GoogleFonts.fraunces(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB300),
                            size: 21,
                          ),
                          SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 18, color: Colors.grey[300]),
                      Text(
                        '$reviewCount Reviews',
                        style: GoogleFonts.inter(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Container(width: 1, height: 18, color: Colors.grey[300]),
                      Text(
                        '$sold Sold',
                        style: GoogleFonts.inter(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (product.category != null)
                        _InfoChip(
                          icon: Icons.category_outlined,
                          label: product.category!,
                        ),
                      _InfoChip(
                        icon: Icons.inventory_2_outlined,
                        label: product.unit,
                      ),
                      _InfoChip(
                        icon: product.inStock
                            ? Icons.check_circle_outline
                            : Icons.remove_shopping_cart_outlined,
                        label: product.inStock
                            ? '${product.available} available'
                            : 'No stock available',
                      ),
                      if (product.location != null &&
                          product.location!.trim().isNotEmpty)
                        _InfoChip(
                          icon: Icons.location_on_outlined,
                          label: product.location!,
                        ),
                    ],
                  ),
                  if (!product.inStock) ...[
                    SizedBox(height: 12),
                    Text(
                      'No stock available',
                      style: GoogleFonts.inter(
                        color: Colors.red[700],
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 14),
              padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: _seedColor.withValues(alpha: 0.1),
                    child: Icon(Icons.storefront_outlined, color: _seedColor),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 2),
                        Text(
                          product.farmerName ?? 'AgriMarket Seller',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!_isOwner && !_isViewOnly && product.farmerId != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              otherUserId: product.farmerId!,
                              otherUserName:
                                  product.farmerName ?? 'AgriMarket Seller',
                              sharedProduct: product,
                            ),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _seedColor,
                        side: BorderSide(color: _seedColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: Icon(Icons.chat_bubble_outline, size: 16),
                      label: Text(
                        'Message',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 10),
            if (!_isOwner && !_isViewOnly)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 14),
                padding: EdgeInsets.fromLTRB(18, 16, 18, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _seedColor.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      'Quantity ($_unitNoun)',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Spacer(),
                    Container(
                      decoration: BoxDecoration(
                        color: _seedColor.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _QuantityButton(
                            icon: Icons.remove,
                            onTap: _quantity > 1
                                ? () => setState(() => _quantity--)
                                : null,
                          ),
                          SizedBox(
                            width: 42,
                            child: Center(
                              child: Text(
                                '$_quantity',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          _QuantityButton(
                            icon: Icons.add,
                            onTap: _quantity < product.available
                                ? () => setState(() => _quantity++)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 14),
              padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Description',
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _seedColor,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    product.description?.trim().isNotEmpty == true
                        ? product.description!
                        : 'No description available for this product.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      height: 1.55,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: EdgeInsets.symmetric(horizontal: 14),
              padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ratings & Reviews',
                    style: GoogleFonts.fraunces(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _seedColor,
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          color: _seedColor,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < rating.round()
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                size: 20,
                                color: Color(0xFFFFB300),
                              ),
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            '$reviewCount customer reviews',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            if (product.id != null)
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(horizontal: 14),
                padding: EdgeInsets.fromLTRB(18, 18, 18, 22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: _seedColor.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Reviews',
                      style: GoogleFonts.fraunces(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 14),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: ReviewService.reviewsForProduct(product.id!),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Text(
                            'Could not load reviews right now.',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(
                                color: _seedColor,
                              ),
                            ),
                          );
                        }
                        final reviews = snapshot.data!.docs
                            .map(Review.fromFirestore)
                            .toList();
                        if (reviews.isEmpty) {
                          return Text(
                            'No reviews yet. Be the first to try this product!',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          );
                        }
                        return Column(
                          children: reviews
                              .map(
                                (r) => ReviewCard(
                                  review: r,
                                  seedColor: _seedColor,
                                  isOwner: _isOwner,
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (_showRelatedProducts) _buildRelatedProducts(),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxChipWidth =
        MediaQuery.of(context).size.width - (14 * 2) - (18 * 2);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxChipWidth),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Color(0xFFEFF1E4),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(width: 1),
            Icon(icon, size: 15, color: Color(0xFF1F3D2B)),
            SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F3D2B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      color: Color(0xFF1F3D2B),
      disabledColor: Colors.grey[300],
      constraints: BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
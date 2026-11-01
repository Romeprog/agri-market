import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../utils/currency.dart';
import 'addresses_screen.dart';

class _OutOfStockException implements Exception {
  _OutOfStockException(this.message);
  final String message;
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key, required this.items});

  final List<(Product product, int quantity)> items;

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  String _paymentMethod = 'Cash on Delivery';
  bool _placingOrder = false;
  bool _orderPlaced = false;
  String _deliveryName = '';
  String _deliveryPhone = '';
  String _deliveryAddress = '';
  String? _selectedAddressId;
  late List<(Product, int)> _items;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.items);
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final (product, quantity) = _items[index];
      final stock = product.stock;
      final maxQty = (stock != null && stock > 0 && stock < 99) ? stock : 99;
      final updated = (quantity + delta).clamp(1, maxQty);
      _items[index] = (product, updated);
    });
  }

  double get _subtotal => _items.fold<double>(
    0,
    (runningTotal, item) => runningTotal + item.$1.price * item.$2,
  );
  bool get _isPickupOnly =>
      _items.any((item) => item.$1.category == 'Livestock');

  double get _shippingFee => _isPickupOnly
      ? 0
      : _items.fold<double>(
          0,
          (runningTotal, item) =>
              runningTotal + item.$1.deliveryFeePerUnit * item.$2,
        );
  double get _total => _subtotal + _shippingFee;

  String get _orderLabel =>
      _items.length == 1 ? _items.first.$1.name : '${_items.length} items';

  Future<void> _placeOrder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please log in to place an order.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _placingOrder = true);

    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc();
      final requested = <String, int>{};
      final names = <String, String>{};
      for (final item in _items) {
        final id = item.$1.id;
        if (id == null) continue;
        requested[id] = (requested[id] ?? 0) + item.$2;
        names[id] = item.$1.name;
      }

      await db.runTransaction((tx) async {
        final productRefs = {
          for (final id in requested.keys)
            id: db.collection('products').doc(id),
        };

        final stocks = <String, int>{};
        for (final entry in requested.entries) {
          final snap = await tx.get(productRefs[entry.key]!);
          final name = names[entry.key]!;
          if (!snap.exists) {
            throw _OutOfStockException('$name is no longer available.');
          }
          final stock = (snap.data()?['stock'] as num?)?.toInt() ?? 0;
          if (stock <= 0) {
            throw _OutOfStockException('$name has no stock available.');
          }
          if (entry.value > stock) {
            throw _OutOfStockException(
              'Only $stock left for $name. Please lower the quantity.',
            );
          }
          stocks[entry.key] = stock;
        }

        for (final entry in requested.entries) {
          tx.update(productRefs[entry.key]!, {
            'stock': stocks[entry.key]! - entry.value,
            'lastOrderId': orderRef.id,
          });
        }

        tx.set(orderRef, {
          'userId': user.uid,
          'farmerId': _items.first.$1.farmerId,
          'items': _items
              .map(
                (item) => {
                  'productId': item.$1.id,
                  'productName': item.$1.name,
                  'productImage': item.$1.image,
                  'unit': item.$1.unit,
                  'unitPrice': item.$1.price,
                  'quantity': item.$2,
                  'subtotal': item.$1.price * item.$2,
                  'farmerId': item.$1.farmerId,
                },
              )
              .toList(),
          'subtotal': _subtotal,
          'shippingFee': _shippingFee,
          'total': _total,
          'paymentMethod': _isPickupOnly ? 'Cash on Pickup' : _paymentMethod,
          'deliveryName': _deliveryName,
          'deliveryPhone': _deliveryPhone,
          'deliveryAddress': _deliveryAddress,
          'addressId': _selectedAddressId,
          'status': 'Pending',
          'isPickupOnly': _isPickupOnly,
          'stockDeducted': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });

      final farmerIds = _items.map((item) => item.$1.farmerId).toSet();
      for (final farmerId in farmerIds) {
        try {
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': farmerId,
            'orderId': orderRef.id,
            'type': 'new_order',
            'title': 'New order received',
            'body': 'You have a new order for $_orderLabel.',
            'read': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint(
            'Could not notify farmer $farmerId for order ${orderRef.id}: $e',
          );
        }
      }
    } on _OutOfStockException catch (e) {
      if (!mounted) return;
      setState(() => _placingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() => _placingOrder = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to place order. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _placingOrder = false;
      _orderPlaced = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Order placed',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 300),
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _OrderSuccessDialog(
            orderLabel: _orderLabel,
            seedColor: _seedColor,
            onDone: () {
              final navigator = Navigator.of(dialogContext);
              navigator.pop(); 
              navigator.pop();
            },
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
            child: child,
          ),
        );
      },
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
            'Checkout',
            style: GoogleFonts.fraunces(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _bgColor,
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 12),
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
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Payment',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      formatPeso(_total),
                      style: GoogleFonts.inter(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: _seedColor,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 14),
              _PlaceOrderButton(
                loading: _placingOrder,
                done: _orderPlaced,
                seedColor: _seedColor,
                onPressed: _placeOrder,
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(top: 14, bottom: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Section(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on_outlined, color: _seedColor, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isPickupOnly
                              ? 'Contact Details (Pickup)'
                              : 'Delivery Address',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          _isPickupOnly
                              ? (_deliveryPhone.isEmpty
                                    ? 'No contact number selected'
                                    : _deliveryName)
                              : (_deliveryAddress.isEmpty
                                    ? 'No delivery address selected'
                                    : _deliveryName),
                          style: GoogleFonts.inter(
                            color: Colors.grey[700],
                            fontSize: 13.5,
                            fontWeight:
                                (_isPickupOnly
                                    ? _deliveryPhone.isEmpty
                                    : _deliveryAddress.isEmpty)
                                ? FontWeight.normal
                                : FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          _isPickupOnly
                              ? (_deliveryPhone.isEmpty
                                    ? 'Add a contact number so the seller '
                                          'can reach you about pickup.'
                                    : _deliveryPhone)
                              : (_deliveryAddress.isEmpty
                                    ? 'Add your address before placing an order.'
                                    : '$_deliveryPhone • $_deliveryAddress'),
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => _pickAddress(context),
                    child: Text(
                      'Change',
                      style: GoogleFonts.inter(
                        color: _seedColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isPickupOnly) ...[
              SizedBox(height: 10),
              _Section(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.storefront_outlined,
                      color: _seedColor,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This order includes livestock, so it is pickup only. '
                        'You will collect it from the seller once they confirm '
                        'it is ready. No delivery fee applies.',
                        style: GoogleFonts.inter(
                          color: Colors.grey[700],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 10),
            _Section(
              title: 'Order Summary',
              child: Column(
                children: [
                  for (var i = 0; i < _items.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                    _OrderItemRow(
                      product: _items[i].$1,
                      quantity: _items[i].$2,
                      seedColor: _seedColor,
                      bgColor: _bgColor,
                      onIncrement: () => _updateQuantity(i, 1),
                      onDecrement: () => _updateQuantity(i, -1),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 10),
            _Section(
              title: 'Payment Method',
              child: Column(
                children: [
                  _PaymentOption(
                    icon: Icons.money_outlined,
                    title: _isPickupOnly
                        ? 'Cash on Pickup'
                        : 'Cash on Delivery',
                    selected: _paymentMethod == 'Cash on Delivery',
                    onTap: () {
                      setState(() => _paymentMethod = 'Cash on Delivery');
                    },
                  ),
                ],
              ),
            ),
            SizedBox(height: 10),
            _Section(
              title: 'Payment Details',
              child: Column(
                children: [
                  _PriceRow(
                    label: 'Merchandise Subtotal',
                    value: formatPeso(_subtotal),
                  ),
                  SizedBox(height: 10),
                  _PriceRow(
                    label: 'Shipping Fee',
                    value: _shippingFee == 0
                        ? (_isPickupOnly ? 'FREE (Pickup)' : 'FREE')
                        : formatPeso(_shippingFee),
                    valueColor: _shippingFee == 0 ? _seedColor : Colors.black87,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    child: Divider(height: 1),
                  ),
                  _PriceRow(
                    label: 'Total',
                    value: formatPeso(_total),
                    labelWeight: FontWeight.w800,
                    valueWeight: FontWeight.w900,
                    valueColor: _seedColor,
                    valueSize: 19,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAddress(BuildContext context) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(builder: (_) => AddressesScreen(selectMode: true)),
    );

    if (result == null || !mounted) return;

    setState(() {
      _deliveryName = result['fullName'] as String? ?? '';
      _deliveryPhone = result['phoneNumber'] as String? ?? '';
      _deliveryAddress = _composeAddressLine(result);
      _selectedAddressId = result['id'] as String?;
    });
  }

  String _composeAddressLine(Map<String, dynamic> data) {
    final parts = [
      data['street'],
      data['barangay'],
      data['city'],
      data['province'],
      data['region'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty);
    final line = parts.join(', ');
    final postal = data['postalCode'] as String? ?? '';
    return postal.isEmpty ? line : '$line $postal';
  }
}

class _OrderItemRow extends StatelessWidget {
  const _OrderItemRow({
    required this.product,
    required this.quantity,
    required this.seedColor,
    required this.bgColor,
    required this.onIncrement,
    required this.onDecrement,
  });

  final Product product;
  final int quantity;
  final Color seedColor;
  final Color bgColor;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 70,
          height: 70,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: product.image.startsWith('http')
              ? Image.network(
                  product.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    product.icon,
                    size: 36,
                    color: seedColor.withValues(alpha: 0.45),
                  ),
                )
              : Image.asset(
                  product.image,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    product.icon,
                    size: 36,
                    color: seedColor.withValues(alpha: 0.45),
                  ),
                ),
        ),
        SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              SizedBox(height: 5),
              Text(
                product.unit,
                style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    formatPeso(product.price),
                    style: GoogleFonts.inter(
                      color: seedColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Spacer(),
                  _QuantityStepper(
                    quantity: quantity,
                    unit: product.unit,
                    seedColor: seedColor,
                    onIncrement: onIncrement,
                    onDecrement: onDecrement,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.unit,
    required this.seedColor,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final String unit;
  final Color seedColor;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  String get _unitNoun {
    final raw = unit.trim();
    if (raw.isEmpty) return '';
    return raw.toLowerCase().startsWith('per ') ? raw.substring(4).trim() : raw;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: seedColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            seedColor: seedColor,
            onTap: quantity > 1 ? onDecrement : null,
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _unitNoun.isEmpty ? '$quantity' : '$quantity $_unitNoun',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            seedColor: seedColor,
            onTap: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.seedColor,
    required this.onTap,
  });

  final IconData icon;
  final Color seedColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 15,
          color: enabled ? seedColor : seedColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.child, this.title});

  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.symmetric(horizontal: 14),
      padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1F3D2B).withValues(alpha: 0.06),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F3D2B),
              ),
            ),
            SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF1F3D2B);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: seedColor.withValues(
                alpha: selected ? 0.85 : 0.08,
              ),
              child: Icon(
                icon,
                color: selected ? Colors.white : seedColor,
                size: 18,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected ? seedColor : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.label,
    required this.value,
    this.labelWeight = FontWeight.w500,
    this.valueWeight = FontWeight.w700,
    this.valueColor,
    this.valueSize = 14,
  });

  final String label;
  final String value;
  final FontWeight labelWeight;
  final FontWeight valueWeight;
  final Color? valueColor;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13.5,
              fontWeight: labelWeight,
              color: Colors.grey[700],
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: valueSize,
            fontWeight: valueWeight,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _PlaceOrderButton extends StatefulWidget {
  const _PlaceOrderButton({
    required this.loading,
    required this.done,
    required this.seedColor,
    required this.onPressed,
  });

  final bool loading;
  final bool done;
  final Color seedColor;
  final VoidCallback onPressed;

  @override
  State<_PlaceOrderButton> createState() => _PlaceOrderButtonState();
}

class _PlaceOrderButtonState extends State<_PlaceOrderButton> {
  static const Color _successColor = Color(0xFF2E7D4F);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.loading || widget.done;
    final color = widget.done ? _successColor : widget.seedColor;

    final Widget content;
    if (widget.done) {
      content = Icon(
        Icons.check_rounded,
        key: ValueKey('done'),
        color: Colors.white,
        size: 28,
      );
    } else if (widget.loading) {
      content = SizedBox(
        key: ValueKey('loading'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
      );
    } else {
      content = Text(
        'Place Order',
        key: ValueKey('idle'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w800,
          fontSize: 14,
          color: Colors.white,
        ),
      );
    }

    return Listener(
      onPointerDown: (_) {
        if (!collapsed) _setPressed(true);
      },
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1,
        duration: Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 340),
          curve: Curves.easeInOutCubic,
          width: collapsed ? 50 : 148,
          height: 50,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(collapsed ? 25 : 14),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: collapsed ? 0.0 : 0.28),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(collapsed ? 25 : 14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: collapsed ? null : widget.onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 240),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderSuccessDialog extends StatefulWidget {
  const _OrderSuccessDialog({
    required this.orderLabel,
    required this.seedColor,
    required this.onDone,
  });

  final String orderLabel;
  final Color seedColor;
  final VoidCallback onDone;

  @override
  State<_OrderSuccessDialog> createState() => _OrderSuccessDialogState();
}

class _OrderSuccessDialogState extends State<_OrderSuccessDialog>
    with SingleTickerProviderStateMixin {
  static const Color _successColor = Color(0xFF2E7D4F);
  static const Color _accentColor = Color(0xFFE0A63A);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _t(double begin, double end, [Curve curve = Curves.easeOut]) {
    final raw = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  Widget _fadeUp(double t, Widget child) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pop = _t(0.0, 0.45, Curves.elasticOut);
            final check = _t(0.22, 0.55, Curves.easeOutCubic);
            final burst = _t(0.18, 1.0, Curves.easeOutCubic);
            final title = _t(0.40, 0.70);
            final body = _t(0.50, 0.80);
            final button = _t(0.62, 0.95);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(124, 124),
                        painter: _BurstPainter(
                          progress: burst,
                          colors: [_accentColor, _successColor, seed],
                        ),
                      ),
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: _successColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _successColor.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(progress: check),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                _fadeUp(
                  title,
                  Text(
                    'Order Placed!',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: seed,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _fadeUp(
                  body,
                  Text(
                    'Your order for ${widget.orderLabel} has been placed '
                    'successfully.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _fadeUp(
                  button,
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: seed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.74, h * 0.36);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors[1].withValues(alpha: (1 - progress) * 0.35);
    canvas.drawCircle(center, 44 + 14 * progress, ring);

    const count = 14;
    final opacity = (1 - progress * progress).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i + (i.isEven ? 0.0 : 0.18);
      final distance = 40 + (i.isEven ? 14.0 : 8.0) * progress;
      final radius = (i.isEven ? 3.6 : 2.6) * (1 - 0.5 * progress);
      final dot = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
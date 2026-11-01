import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'order_screen.dart';
import '../widgets/assign_rider_sheet.dart';
import '../widgets/delivery_proof_card.dart';
import '../services/delivery_service.dart';

OrderStatus _statusFromFirestore(String? value) {
  switch (value) {
    case 'Processing':
      return OrderStatus.processing;
    case 'Completed':
      return OrderStatus.completed;
    case 'Cancelled':
      return OrderStatus.cancelled;
    case 'Pending':
    default:
      return OrderStatus.pending;
  }
}

extension _SellerOrderStatusLabel on OrderStatus {
  String get sellerLabel {
    switch (this) {
      case OrderStatus.pending:
        return 'To Ship';
      case OrderStatus.processing:
        return 'Shipped';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class _SellerOrder {
  final String id;
  final DateTime date;
  final String productName;
  final String productImage;
  final int quantity;
  final double total;
  final OrderStatus status;
  final String buyerId;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;
  final String? riderId;
  final bool isPickupOnly;
  final String? deliveryStatus;
  final DateTime? offerSentAt;
  final String? proofPhotoUrl;
  final DateTime? proofPhotoAt;

  const _SellerOrder({
    required this.id,
    required this.date,
    required this.productName,
    required this.productImage,
    required this.quantity,
    required this.total,
    required this.status,
    required this.buyerId,
    required this.buyerName,
    required this.buyerPhone,
    required this.buyerAddress,
    this.riderId,
    this.isPickupOnly = false,
    this.deliveryStatus,
    this.offerSentAt,
    this.proofPhotoUrl,
    this.proofPhotoAt,
  });

  factory _SellerOrder.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String farmerId,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];
    final rawItems = data['items'];
    final itemMaps = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final item = itemMaps.isEmpty
        ? data
        : itemMaps.firstWhere(
            (entry) => entry['farmerId'] == farmerId,
            orElse: () => itemMaps.first,
          );

    final farmerItems = itemMaps.where(
      (entry) => entry['farmerId'] == farmerId,
    );
    final earnings = itemMaps.isEmpty
        ? (data['total'] as num?)?.toDouble() ?? 0
        : farmerItems.fold<double>(
            0,
            (total, entry) =>
                total + ((entry['subtotal'] as num?)?.toDouble() ?? 0),
          );

    return _SellerOrder(
      id: doc.id,
      date: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      productName: item['productName'] as String? ?? 'Product',
      productImage: item['productImage'] as String? ?? '',
      quantity: (item['quantity'] as num?)?.toInt() ?? 1,
      total: earnings,
      status: _statusFromFirestore(data['status'] as String?),
      buyerId: data['userId'] as String? ?? '',
      buyerName: data['deliveryName'] as String? ?? '',
      buyerPhone: data['deliveryPhone'] as String? ?? '',
      buyerAddress: data['deliveryAddress'] as String? ?? '',
      riderId: data['riderId'] as String?,
      isPickupOnly: data['isPickupOnly'] == true,
      deliveryStatus: data['deliveryStatus'] as String?,
      offerSentAt: data['offerSentAt'] is Timestamp
          ? (data['offerSentAt'] as Timestamp).toDate()
          : null,
      proofPhotoUrl: data['proofPhotoUrl'] as String?,
      proofPhotoAt: data['proofPhotoAt'] is Timestamp
          ? (data['proofPhotoAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  OrderStatus? _selectedStatus;

  List<_SellerOrder> _filterOrders(List<_SellerOrder> orders) {
    if (_selectedStatus == null) return orders;
    return orders.where((o) => o.status == _selectedStatus).toList();
  }

  Future<void> _advanceStatus(_SellerOrder order, String newStatus) async {
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(order.id);

      if (newStatus == 'Completed') {
        final farmerId = FirebaseAuth.instance.currentUser?.uid;
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(orderRef);
          final data = snapshot.data();
          if (data == null || data['status'] == 'Completed') return;
          final rawItems = data['items'];
          final itemMaps = rawItems is List
              ? rawItems.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[];
          for (final item in itemMaps) {
            if (item['farmerId'] != farmerId) continue;
            final productId = item['productId'] as String?;
            final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
            if (productId == null || productId.isEmpty || quantity <= 0) {
              continue;
            }
            final productRef = FirebaseFirestore.instance
                .collection('products')
                .doc(productId);
            transaction.update(productRef, {
              'sold': FieldValue.increment(quantity),
            });
          }

          transaction.update(orderRef, {
            'status': newStatus,
            'completedAt': FieldValue.serverTimestamp(),
          });
        });
      } else {
        final updates = <String, dynamic>{'status': newStatus};
        if (newStatus == 'Processing') {
          updates['processingAt'] = FieldValue.serverTimestamp();
        }
        await orderRef.update(updates);
      }
    } on FirebaseException catch (e) {
      debugPrint(
        'Seller order status update failed for order ${order.id}: '
        '[${e.code}] ${e.message}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.code == 'permission-denied'
                ? 'You don\'t have permission to update this order. '
                      'Check that your account is the seller on this order.'
                : 'Could not update this order (${e.code}). Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Seller order status update failed for order ${order.id}: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update this order. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
          automaticallyImplyLeading: false,
          titleSpacing: widget.showBackButton ? 5 : 16,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          leading: widget.showBackButton
              ? IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, color: _bgColor, size: 20),
                )
              : null,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Sales',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track and fulfill your orders',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _bgColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: OrderStatus.values.length + 1,
                  separatorBuilder: (_, _) => SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _FilterChip(
                        label: 'All',
                        selected: _selectedStatus == null,
                        selectedColor: _seedColor,
                        onTap: () => setState(() => _selectedStatus = null),
                      );
                    }
                    final status = OrderStatus.values[index - 1];
                    return _FilterChip(
                      label: status.sellerLabel,
                      selected: _selectedStatus == status,
                      selectedColor: status == OrderStatus.cancelled
                          ? status.color
                          : _seedColor,
                      onTap: () => setState(() => _selectedStatus = status),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: user == null
                  ? _EmptySales(seedColor: _seedColor)
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('farmerId', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not load your sales right now.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return Center(
                            child: CircularProgressIndicator(color: _seedColor),
                          );
                        }

                        final orders = snapshot.data!.docs
                            .map(
                              (doc) =>
                                  _SellerOrder.fromFirestore(doc, user.uid),
                            )
                            .toList();
                        final filtered = _filterOrders(orders);

                        return filtered.isEmpty
                            ? _EmptySales(seedColor: _seedColor)
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  final order = filtered[index];
                                  return _AssignHighlight(
                                    key: ValueKey(order.id),
                                    color: _seedColor,
                                    builder: (context, pulse) =>
                                        _SellerOrderCard(
                                          order: order,
                                          seedColor: _seedColor,
                                          onAdvance: (status) =>
                                              _advanceStatus(order, status),
                                          onAssigned: pulse,
                                        ),
                                  );
                                },
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

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? selectedColor : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: selectedColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.seedColor});

  final OrderStatus status;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: seedColor, width: 1),
      ),
      child: Text(
        status.sellerLabel,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: seedColor,
        ),
      ),
    );
  }
}

class _SellerOrderCard extends StatelessWidget {
  const _SellerOrderCard({
    required this.order,
    required this.seedColor,
    required this.onAdvance,
    this.onAssigned,
  });

  final _SellerOrder order;
  final Color seedColor;
  final ValueChanged<String> onAdvance;
  final VoidCallback? onAssigned;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String get _formattedDate =>
      '${_months[order.date.month - 1]} ${order.date.day}, ${order.date.year}';
  Future<void> _cancelOffer(BuildContext context) async {
    try {
      await DeliveryService().cancelExpiredOffer(order.id);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not cancel the request. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${order.id.substring(0, order.id.length < 8 ? order.id.length : 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                _StatusBadge(status: order.status, seedColor: seedColor),
              ],
            ),
            SizedBox(height: 2),
            Text(
              _formattedDate,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: seedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Image.network(
                    order.productImage,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        Icon(Icons.shopping_basket_outlined, color: seedColor),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    order.productName,
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
                Text(
                  'x${order.quantity}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: seedColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_shipping_outlined,
                    size: 14,
                    color: seedColor,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deliver to',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        order.buyerName.isEmpty
                            ? 'No name provided'
                            : order.buyerName,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (order.buyerPhone.isNotEmpty ||
                          order.buyerAddress.isNotEmpty)
                        Text(
                          [
                            order.buyerPhone,
                            order.buyerAddress,
                          ].where((s) => s.isNotEmpty).join(' • '),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade100),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '₱${order.total.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: seedColor,
                  ),
                ),
              ],
            ),
            if (order.status == OrderStatus.pending) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => onAdvance('Processing'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: seedColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Start Processing',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ] else if (order.status == OrderStatus.processing) ...[
              SizedBox(height: 12),
              if (order.riderId == null) ...[
                if (order.isPickupOnly)
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: seedColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          size: 16,
                          color: seedColor,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Livestock order: Pickup only. The buyer collects it from you.',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: seedColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final assigned = await showAssignRiderSheet(
                          context,
                          orderId: order.id,
                          buyerId: order.buyerId,
                        );
                        if (assigned == true) onAssigned?.call();
                      },
                      icon: Icon(Icons.moped_outlined, size: 18),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: seedColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Assign a Rider',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => onAdvance('Completed'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: seedColor,
                      side: BorderSide(color: seedColor),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      order.isPickupOnly
                          ? 'Mark as Picked Up'
                          : 'Mark as Completed (No Delivery)',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ] else if (order.deliveryStatus == 'Offered')
                _OfferWaiting(
                  key: ValueKey('offer-${order.id}-${order.offerSentAt?.millisecondsSinceEpoch}'),
                  sentAt: order.offerSentAt,
                  seedColor: seedColor,
                  onAssignAnother: () async {
                    final assigned = await showAssignRiderSheet(
                      context,
                      orderId: order.id,
                      buyerId: order.buyerId,
                      excludeRiderId: order.riderId,
                    );
                    if (assigned == true) onAssigned?.call();
                  },
                  onCancel: () => _cancelOffer(context),
                )
              else if (order.proofPhotoUrl != null)
                DeliveryProofCard(
                  url: order.proofPhotoUrl!,
                  takenAt: order.proofPhotoAt,
                  seedColor: seedColor,
                )
              else
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: seedColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.moped, size: 16, color: seedColor),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A rider is handling this delivery.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: seedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ] else if (order.status == OrderStatus.completed &&
                order.proofPhotoUrl != null) ...[
              SizedBox(height: 12),
              DeliveryProofCard(
                url: order.proofPhotoUrl!,
                takenAt: order.proofPhotoAt,
                seedColor: seedColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssignHighlight extends StatefulWidget {
  const _AssignHighlight({
    super.key,
    required this.color,
    required this.builder,
  });

  final Color color;
  final Widget Function(BuildContext context, VoidCallback pulse) builder;

  @override
  State<_AssignHighlight> createState() => _AssignHighlightState();
}

class _AssignHighlightState extends State<_AssignHighlight>
    with SingleTickerProviderStateMixin {
  // Starts at 1.0 (finished) so nothing shows until pulse() is called.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1400),
    value: 1,
  );

  void _pulse() {
    if (mounted) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final intensity = 1 - Curves.easeOutCubic.transform(t);
        return Transform.scale(
          scale: 1 + 0.02 * math.sin(math.pi * t),
          child: Container(
            foregroundDecoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.12 * intensity),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.color.withValues(alpha: 0.7 * intensity),
                width: 2,
              ),
            ),
            child: child,
          ),
        );
      },
      child: widget.builder(context, _pulse),
    );
  }
}

class _EmptySales extends StatelessWidget {
  const _EmptySales({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
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
                Icons.storefront_outlined,
                size: 38,
                color: seedColor.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'No sales yet',
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: seedColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Orders for your listings will show up here',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferWaiting extends StatefulWidget {
  const _OfferWaiting({
    super.key,
    required this.sentAt,
    required this.seedColor,
    required this.onAssignAnother,
    required this.onCancel,
  });

  final DateTime? sentAt;
  final Color seedColor;
  final VoidCallback onAssignAnother;
  final VoidCallback onCancel;

  @override
  State<_OfferWaiting> createState() => _OfferWaitingState();
}

class _OfferWaitingState extends State<_OfferWaiting> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _left {
    final window = DeliveryService.offerWindow;
    final sent = widget.sentAt;
    if (sent == null) return window;
    final left = window - DateTime.now().difference(sent);
    if (left > window) return window;
    return left.isNegative ? Duration.zero : left;
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    final left = _left;
    final expired = left == Duration.zero;
    final secs = (left.inMilliseconds / 1000).ceil();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: seed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (expired)
                Icon(Icons.timer_off_outlined, size: 16, color: seed)
              else
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    value:
                        left.inMilliseconds /
                        DeliveryService.offerWindow.inMilliseconds,
                    strokeWidth: 2.5,
                    color: seed,
                    backgroundColor: seed.withValues(alpha: 0.15),
                  ),
                ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  expired
                      ? 'The rider didn\'t respond in time.'
                      : 'Waiting for the rider to accept\u2026 ${secs}s',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: seed,
                  ),
                ),
              ),
            ],
          ),
          if (expired) ...[
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: seed,
                      side: BorderSide(color: seed),
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Cancel Request',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: widget.onAssignAnother,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: seed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Assign Another',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../services/review_service.dart';
import '../utils/currency.dart';
import '../widgets/cart_button.dart';
import '../widgets/delivery_proof_card.dart';
import 'cart_screen.dart';
import 'checkout_screen.dart';
import '../widgets/fulfillment_choice_prompt.dart';
import '../widgets/order_progress_tracker.dart';
import 'chat_screen.dart';
import 'write_review_screen.dart';

enum OrderStatus { pending, processing, completed, cancelled }

extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'To Ship';
      case OrderStatus.processing:
        return 'To Receive';
      case OrderStatus.completed:
        return 'To Review';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return Color(0xFFB8860B);
      case OrderStatus.processing:
        return Color(0xFF1D5D9B);
      case OrderStatus.completed:
        return Color(0xFF1F3D2B);
      case OrderStatus.cancelled:
        return Color(0xFFB3261E);
    }
  }
}

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

enum BuyerOrderFilter { toShip, toReceive, toReview, cancelled }

extension BuyerOrderFilterX on BuyerOrderFilter {
  String get label => switch (this) {
    BuyerOrderFilter.toShip => 'To Ship',
    BuyerOrderFilter.toReceive => 'To Receive',
    BuyerOrderFilter.toReview => 'To Review',
    BuyerOrderFilter.cancelled => 'Cancelled',
  };

  Color get color => switch (this) {
    BuyerOrderFilter.toShip => Color(0xFFB8860B),
    BuyerOrderFilter.toReceive => Color(0xFF1D5D9B),
    BuyerOrderFilter.toReview => Color(0xFF1F3D2B),
    BuyerOrderFilter.cancelled => Color(0xFFB3261E),
  };

  bool matches(OrderStatus status) => switch (this) {
    BuyerOrderFilter.toShip => status == OrderStatus.pending,
    BuyerOrderFilter.toReceive => status == OrderStatus.processing,
    BuyerOrderFilter.toReview => status == OrderStatus.completed,
    BuyerOrderFilter.cancelled => status == OrderStatus.cancelled,
  };
}

const _monthNames = [
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

String _formatClock(DateTime d) {
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final minute = d.minute.toString().padLeft(2, '0');
  final period = d.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

String _momentLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  final time = _formatClock(d);
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Yesterday, $time';
  return '${_monthNames[d.month - 1]} ${d.day}, $time';
}

class _OrderItem {
  final String name;
  final int quantity;
  final String image;
  final IconData icon;
  final String productId;

  const _OrderItem({
    required this.name,
    required this.quantity,
    required this.image,
    required this.icon,
    this.productId = '',
  });
}

class _Order {
  final String id;
  final DateTime date;
  final List<_OrderItem> items;
  final double total;
  final OrderStatus status;
  final String unit;
  final double unitPrice;
  final String productId;
  final String farmerId;
  final DateTime? processingAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final String? riderId;
  final String? deliveryStatus;
  final String? fulfillmentChoice;
  final String? riderSearchState;
  final bool isPickupOnly;
  final String riderName;
  final String riderPhone;
  final String? proofPhotoUrl;
  final DateTime? proofPhotoAt;

  const _Order({
    required this.id,
    required this.date,
    required this.items,
    required this.total,
    required this.status,
    required this.unit,
    required this.unitPrice,
    required this.productId,
    required this.farmerId,
    this.processingAt,
    this.completedAt,
    this.cancelledAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.riderId,
    this.deliveryStatus,
    this.fulfillmentChoice,
    this.riderSearchState,
    this.isPickupOnly = false,
    this.riderName = '',
    this.riderPhone = '',
    this.proofPhotoUrl,
    this.proofPhotoAt,
  });

  factory _Order.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final timestamp = data['createdAt'];
    DateTime? statusTime(String key) {
      final value = data[key];
      return value is Timestamp ? value.toDate() : null;
    }

    final rawItems = data['items'];
    final itemMaps = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];

    final items = itemMaps.isNotEmpty
        ? itemMaps
              .map(
                (item) => _OrderItem(
                  productId: item['productId'] as String? ?? '',
                  name: item['productName'] as String? ?? 'Product',
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  image: item['productImage'] as String? ?? '',
                  icon: Icons.shopping_basket_outlined,
                ),
              )
              .toList()
        : [
            _OrderItem(
              productId: data['productId'] as String? ?? '',
              name: data['productName'] as String? ?? 'Product',
              quantity: (data['quantity'] as num?)?.toInt() ?? 1,
              image: data['productImage'] as String? ?? '',
              icon: Icons.shopping_basket_outlined,
            ),
          ];

    final firstItem = itemMaps.isNotEmpty ? itemMaps.first : data;

    return _Order(
      id: doc.id,
      date: timestamp is Timestamp ? timestamp.toDate() : DateTime.now(),
      items: items,
      total: (data['total'] as num?)?.toDouble() ?? 0,
      status: _statusFromFirestore(data['status'] as String?),
      unit: firstItem['unit'] as String? ?? '',
      unitPrice: (firstItem['unitPrice'] as num?)?.toDouble() ?? 0,
      productId: firstItem['productId'] as String? ?? '',
      farmerId: firstItem['farmerId'] as String? ?? '',
      processingAt: statusTime('processingAt'),
      completedAt: statusTime('completedAt'),
      cancelledAt: statusTime('cancelledAt'),
      outForDeliveryAt: statusTime('outForDeliveryAt'),
      deliveredAt: statusTime('deliveredAt'),
      riderId: data['riderId'] as String?,
      deliveryStatus: data['deliveryStatus'] as String?,
      fulfillmentChoice: data['fulfillmentChoice'] as String?,
      riderSearchState: data['riderSearchState'] as String?,
      isPickupOnly: data['isPickupOnly'] == true,
      riderName: data['riderName'] as String? ?? '',
      riderPhone: data['riderPhone'] as String? ?? '',
      proofPhotoUrl: data['proofPhotoUrl'] as String?,
      proofPhotoAt: statusTime('proofPhotoAt'),
    );
  }
}

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  BuyerOrderFilter? _selectedFilter;

  void _openCart() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
  }

  List<_Order> _filterOrders(List<_Order> orders) {
    if (_selectedFilter == null) return orders;
    return orders
        .where((order) => _selectedFilter!.matches(order.status))
        .toList();
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
                'My Orders',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track and manage your purchases',
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
              padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  itemCount: BuyerOrderFilter.values.length + 1,
                  separatorBuilder: (_, _) => SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _StatusFilterChip(
                        label: 'All',
                        selected: _selectedFilter == null,
                        selectedColor: _seedColor,
                        onTap: () => setState(() => _selectedFilter = null),
                      );
                    }
                    final filter = BuyerOrderFilter.values[index - 1];
                    return _StatusFilterChip(
                      label: filter.label,
                      selected: _selectedFilter == filter,
                      selectedColor: filter == BuyerOrderFilter.cancelled
                          ? filter.color
                          : _seedColor,
                      onTap: () => setState(() => _selectedFilter = filter),
                    );
                  },
                ),
              ),
            ),
            Expanded(
              child: user == null
                  ? _EmptyOrders(seedColor: _seedColor)
                  : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .where('userId', isEqualTo: user.uid)
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'Could not load your orders right now.',
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
                            .map(_Order.fromFirestore)
                            .toList();
                        final filtered = _filterOrders(orders);

                        return filtered.isEmpty
                            ? _EmptyOrders(seedColor: _seedColor)
                            : ListView.separated(
                                padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) =>
                                    SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  return _OrderCard(
                                    key: ValueKey(filtered[index].id),
                                    order: filtered[index],
                                    seedColor: _seedColor,
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

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
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
        status.label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: seedColor,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.order,
    required this.seedColor,
    required this.onTap,
  });

  final _Order order;
  final Color seedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final IconData icon;
    final String headline;
    final String subtitle;
    String? moment;

    switch (status) {
      case OrderStatus.pending:
        icon = Icons.receipt_long_rounded;
        headline = 'Order Placed';
        subtitle = 'Waiting for the farmer to prepare your order';
        moment = _momentLabel(order.date);
        break;
      case OrderStatus.processing:
        if (order.riderId == null) {
          switch (order.isPickupOnly ? 'Pickup' : order.fulfillmentChoice) {
            case 'Wait':
              icon = Icons.pending_actions_outlined;
              headline = 'Waiting for a Rider';
              subtitle = 'The farmer will assign one as soon as it\'s free';
              moment = null;
              break;
            case 'Pickup':
              icon = Icons.storefront_outlined;
              headline = "You're Picking This Up";
              subtitle = 'The farmer will mark it complete once you collect it';
              moment = null;
              break;
            default:
              if (order.riderSearchState == 'no_riders_available') {
                icon = Icons.pending_actions_outlined;
                headline = 'Finding a Rider';
                subtitle = 'No rider is free right now — hang tight';
                moment = null;
              } else {
                icon = Icons.inventory_2_outlined;
                headline = 'Being Processed';
                subtitle = 'The farmer is getting everything ready';
                moment = order.processingAt != null
                    ? _momentLabel(order.processingAt!)
                    : null;
              }
          }
        } else {
          switch (order.deliveryStatus) {
            case 'Picked Up':
              icon = Icons.moped_outlined;
              headline = 'Picked Up';
              subtitle = order.riderName.isNotEmpty
                  ? '${order.riderName} has your order'
                  : 'Your rider has your order';
              moment = null;
              break;
            case 'Out for Delivery':
              icon = Icons.delivery_dining_outlined;
              headline = 'Out for Delivery';
              subtitle = order.riderName.isNotEmpty
                  ? '${order.riderName} is bringing your order'
                  : 'A rider is bringing your order';
              moment = order.outForDeliveryAt != null
                  ? _momentLabel(order.outForDeliveryAt!)
                  : null;
              break;
            default:
              icon = Icons.assignment_ind_outlined;
              headline = 'Rider Assigned';
              subtitle = order.riderName.isNotEmpty
                  ? '${order.riderName} will pick it up soon'
                  : 'A rider will pick it up soon';
              moment = null;
          }
        }
        break;
      case OrderStatus.completed:
        icon = Icons.local_shipping_outlined;
        headline = order.riderId != null ? 'Delivered' : 'Picked Up';
        subtitle = order.riderId != null
            ? (order.proofPhotoUrl != null
                  ? 'Delivered · Tap to see the delivery photo'
                  : 'Your package has been delivered')
            : 'You picked this order up';
        moment = _momentLabel(
          order.deliveredAt ?? order.completedAt ?? order.date,
        );
        break;
      case OrderStatus.cancelled:
        icon = Icons.close_rounded;
        headline = 'Order Cancelled';
        subtitle = 'This order will not be processed further';
        moment = order.cancelledAt != null
            ? _momentLabel(order.cancelledAt!)
            : null;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: seedColor, width: 1.2),
        ),
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset(0, 0.3),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: KeyedSubtree(
            key: ValueKey(headline),
            child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: seedColor.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: seedColor, size: 18),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    moment != null ? '$moment  $headline' : headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: seedColor,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: seedColor.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: seedColor, size: 20),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

class _OrderItemThumb extends StatelessWidget {
  const _OrderItemThumb({
    required this.image,
    required this.fallbackIcon,
    required this.seedColor,
  });

  final String image;
  final IconData fallbackIcon;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(fallbackIcon, color: seedColor, size: 18);
    return Container(
      width: 40,
      height: 40,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: seedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: image.startsWith('http')
          ? Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => fallback,
            )
          : Image.asset(
              image,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({super.key, required this.order, required this.seedColor});

  final _Order order;
  final Color seedColor;

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

  Widget _buildTracker() {
    final o = order;
    final completed = o.status == OrderStatus.completed;
    final pickupFlow =
        o.riderId == null &&
        (o.isPickupOnly || o.fulfillmentChoice == 'Pickup' || completed);

    final List<OrderStep> steps;
    var index = 0;
    var finished = false;
    var courier = false;

    if (pickupFlow) {
      steps = const [
        OrderStep('Placed', Icons.receipt_long_rounded),
        OrderStep('Preparing', Icons.inventory_2_outlined),
        OrderStep('Picked up', Icons.storefront_outlined),
      ];
      index = switch (o.status) {
        OrderStatus.pending => 0,
        OrderStatus.processing => 1,
        _ => 2,
      };
      finished = completed;
    } else {
      steps = const [
        OrderStep('Placed', Icons.receipt_long_rounded),
        OrderStep('Preparing', Icons.inventory_2_outlined),
        OrderStep('Rider', Icons.assignment_ind_outlined),
        OrderStep('Picked up', Icons.moped_outlined),
        OrderStep('On the way', Icons.delivery_dining_outlined),
        OrderStep('Delivered', Icons.home_outlined),
      ];
      if (completed) {
        index = 5;
        finished = true;
      } else if (o.status == OrderStatus.pending) {
        index = 0;
      } else if (o.riderId == null) {
        index = 1;
      } else {
        index = switch (o.deliveryStatus) {
          'Picked Up' => 3,
          'Out for Delivery' => 4,
          'Delivered' => 5,
          _ => 2,
        };
        finished = o.deliveryStatus == 'Delivered';
        courier = !finished;
      }
    }

    return OrderProgressTracker(
      steps: steps,
      currentIndex: index,
      finished: finished,
      showCourier: courier,
      seedColor: seedColor,
    );
  }

  String get _formattedDate =>
      '${_months[order.date.month - 1]} ${order.date.day}, ${order.date.year}';

  Future<void> _cancelOrder(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Cancel this order?',
          style: GoogleFonts.fraunces(
            fontWeight: FontWeight.bold,
            color: seedColor,
          ),
        ),
        content: Text(
          "This can't be undone.",
          style: GoogleFonts.inter(color: Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Keep Order',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFB3261E),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Cancel Order',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final db = FirebaseFirestore.instance;
      final orderRef = db.collection('orders').doc(order.id);

      await db.runTransaction((tx) async {
        // Reads first
        final orderSnap = await tx.get(orderRef);
        final data = orderSnap.data();
        if (data == null || data['status'] != 'Pending') {
          throw StateError('order-not-pending');
        }

        final restore = <DocumentReference<Map<String, dynamic>>, int>{};
        if (data['stockDeducted'] == true) {
          final rawItems = data['items'];
          final lines = rawItems is List
              ? rawItems.whereType<Map<String, dynamic>>().toList()
              : <Map<String, dynamic>>[data];
          for (final line in lines) {
            final productId = line['productId'] as String? ?? '';
            final qty = (line['quantity'] as num?)?.toInt() ?? 0;
            if (productId.isEmpty || qty <= 0) continue;
            final ref = db.collection('products').doc(productId);
            restore.update(ref, (v) => v + qty, ifAbsent: () => qty);
          }
        }
        final existing = <DocumentReference<Map<String, dynamic>>, int>{};
        for (final entry in restore.entries) {
          final snap = await tx.get(entry.key);
          if (snap.exists) existing[entry.key] = entry.value; 
        }

        // Then writes
        tx.update(orderRef, {
          'status': 'Cancelled',
          'cancelledAt': FieldValue.serverTimestamp(),
        });
        for (final entry in existing.entries) {
          tx.update(entry.key, {
            'stock': FieldValue.increment(entry.value),
            'lastOrderId': order.id,
          });
        }
      });
    } on StateError {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This order can no longer be cancelled.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not cancel the order. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _buyAgain(BuildContext context) async {
    final db = FirebaseFirestore.instance;
    final items = <(Product, int)>[];
    final problems = <String>[];

    try {
      for (final item in order.items) {
        if (item.productId.isEmpty) {
          problems.add('${item.name} is no longer available.');
          continue;
        }
        final snap = await db.collection('products').doc(item.productId).get();
        if (!snap.exists) {
          problems.add('${item.name} is no longer available.');
          continue;
        }
        final product = Product.fromFirestore(snap);
        if (!product.inStock) {
          problems.add('${item.name} has no stock available.');
          continue;
        }
        final qty = item.quantity > product.available
            ? product.available
            : item.quantity;
        items.add((product, qty));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load the products. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!context.mounted) return;

    if (problems.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            problems.join('\n'),
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (items.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CheckoutScreen(items: items)),
    );
  }

  void _trackOrder(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TrackOrderSheet(order: order, seedColor: seedColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: Offset(0, 5),
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
                    color: Colors.black87,
                  ),
                ),
                _StatusBadge(status: order.status, seedColor: seedColor),
              ],
            ),
            SizedBox(height: 10),
            _StatusBanner(
              order: order,
              seedColor: seedColor,
              onTap: () => _trackOrder(context),
            ),
            if (order.status != OrderStatus.cancelled) ...[
              SizedBox(height: 14),
              _buildTracker(),
              SizedBox(height: 2),
            ],
            if (order.status == OrderStatus.processing && !order.isPickupOnly)
              FulfillmentChoicePrompt(orderId: order.id),
            if (order.riderId != null &&
                order.status == OrderStatus.processing) ...[
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherUserId: order.riderId!,
                          otherUserName: order.riderName.isEmpty
                              ? 'Your rider'
                              : order.riderName,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: seedColor,
                    side: BorderSide(color: seedColor),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  icon: Icon(Icons.chat_bubble_outline, size: 14),
                  label: Text(
                    'Message Rider',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
            SizedBox(height: 10),
            Text(
              _formattedDate,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: 12),
            Column(
              children: [
                for (final item in order.items) ...[
                  Row(
                    children: [
                      _OrderItemThumb(
                        image: item.image,
                        fallbackIcon: item.icon,
                        seedColor: seedColor,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          item.name,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Text(
                        'x${item.quantity}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  if (item != order.items.last) SizedBox(height: 8),
                ],
              ],
            ),
            SizedBox(height: 12),
            Divider(height: 1, color: Colors.grey.shade200),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  formatPeso(order.total),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: seedColor,
                  ),
                ),
              ],
            ),
            if (order.status == OrderStatus.completed) ...[
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _RateProductButton(
                      order: order,
                      seedColor: seedColor,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _buyAgain(context),
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
                        'Buy Again',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (order.status == OrderStatus.pending) ...[
              SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _cancelOrder(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFFB3261E),
                    side: BorderSide(color: Color(0xFFB3261E)),
                    padding: EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'Cancel Order',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackOrderSheet extends StatelessWidget {
  const _TrackOrderSheet({required this.order, required this.seedColor});

  final _Order order;
  final Color seedColor;

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

  String _fmt(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final cancelled = status == OrderStatus.cancelled;
    final pastPending = status != OrderStatus.pending;

    final steps = <Widget>[
      _TrackingStep(
        icon: Icons.receipt_long_rounded,
        title: 'Order Placed',
        subtitle: _fmt(order.date),
        reached: true,
        isCurrent: status == OrderStatus.pending,
        seedColor: seedColor,
        isLast: false,
      ),
      _TrackingStep(
        icon: Icons.inventory_2_outlined,
        title: 'Processing',
        subtitle: pastPending
            ? (order.processingAt != null
                  ? 'Prepared by the farmer · ${_momentLabel(order.processingAt!)}'
                  : 'Prepared by the farmer')
            : 'Waiting for the farmer to start',
        reached: pastPending,
        isCurrent: false,
        seedColor: seedColor,
        isLast: false,
      ),
    ];

    if (order.riderId != null) {
      const stages = ['Assigned', 'Picked Up', 'Out for Delivery', 'Delivered'];
      const stageIcons = [
        Icons.assignment_ind_outlined,
        Icons.moped_outlined,
        Icons.delivery_dining_outlined,
        Icons.local_shipping_outlined,
      ];
      const stageTitles = [
        'Rider Assigned',
        'Picked Up',
        'Out for Delivery',
        'Delivered',
      ];
      final delivered = status == OrderStatus.completed;
      final rawIndex = stages.indexOf(order.deliveryStatus ?? 'Assigned');
      final currentIndex = delivered
          ? stages.length - 1
          : (rawIndex < 0 ? 0 : rawIndex);

      for (var i = 0; i < stages.length; i++) {
        final String subtitle;
        switch (stages[i]) {
          case 'Assigned':
            subtitle = order.riderName.isNotEmpty
                ? '${order.riderName} will pick it up'
                : 'A rider will pick it up';
            break;
          case 'Picked Up':
            subtitle = 'Your order is with the rider';
            break;
          case 'Out for Delivery':
            subtitle = order.riderName.isNotEmpty
                ? '${order.riderName} is on the way'
                : 'A rider is on the way';
            break;
          default:
            subtitle = order.deliveredAt != null
                ? 'Delivered · ${_momentLabel(order.deliveredAt!)}'
                : 'Delivered - enjoy your fresh produce!';
        }
        steps.add(
          _TrackingStep(
            icon: stageIcons[i],
            title: stageTitles[i],
            subtitle: subtitle,
            reached: i <= currentIndex,
            isCurrent: i == currentIndex && !delivered,
            seedColor: seedColor,
            isLast: i == stages.length - 1,
          ),
        );
      }
    } else if (status == OrderStatus.completed) {
      steps.add(
        _TrackingStep(
          icon: Icons.storefront_outlined,
          title: 'Picked Up',
          subtitle: order.completedAt != null
              ? 'Picked up · ${_momentLabel(order.completedAt!)}'
              : 'Picked up',
          reached: true,
          isCurrent: false,
          seedColor: seedColor,
          isLast: true,
        ),
      );
    } else {
      final choosingPickup =
          order.isPickupOnly || order.fulfillmentChoice == 'Pickup';
      steps.add(
        _TrackingStep(
          icon: Icons.storefront_outlined,
          title: choosingPickup ? "You're Picking This Up" : 'Finding a Rider',
          subtitle: choosingPickup
              ? 'The farmer will mark it complete once you collect it'
              : order.fulfillmentChoice == 'Wait'
              ? 'No rider is free right now — hang tight'
              : 'The farmer is still working on it',
          reached: false,
          isCurrent: true,
          seedColor: seedColor,
          isLast: true,
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
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
                margin: EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Order #${order.id.substring(0, order.id.length < 8 ? order.id.length : 8).toUpperCase()}',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: seedColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              cancelled
                  ? 'This order was cancelled.'
                  : "Here's where your order is right now.",
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
            SizedBox(height: 22),
            if (cancelled)
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(0xFFB3261E).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Color(0xFFB3261E),
                      size: 18,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'This order will not be processed further.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              )
            else
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...steps,
                      if (status == OrderStatus.completed &&
                          order.riderId != null &&
                          order.proofPhotoUrl != null)
                        DeliveryProofCard(
                          url: order.proofPhotoUrl!,
                          takenAt: order.proofPhotoAt ?? order.deliveredAt,
                          seedColor: seedColor,
                        ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: seedColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  side: BorderSide(color: seedColor),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: StadiumBorder(),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackingStep extends StatelessWidget {
  const _TrackingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.reached,
    required this.isCurrent,
    required this.seedColor,
    required this.isLast,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool reached;
  final bool isCurrent;
  final Color seedColor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: reached ? seedColor : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  reached ? Icons.check_rounded : icon,
                  color: reached ? Colors.white : Colors.grey[500],
                  size: 18,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.symmetric(vertical: 2),
                    color: reached
                        ? seedColor.withValues(alpha: 0.35)
                        : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: reached ? Colors.black87 : Colors.grey[500],
                        ),
                      ),
                      if (isCurrent) ...[
                        SizedBox(width: 6),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: seedColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'NOW',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: seedColor,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RateProductButton extends StatefulWidget {
  const _RateProductButton({required this.order, required this.seedColor});

  final _Order order;
  final Color seedColor;

  @override
  State<_RateProductButton> createState() => _RateProductButtonState();
}

class _RateProductButtonState extends State<_RateProductButton> {
  late Future<DocumentSnapshot<Map<String, dynamic>>> _reviewFuture;

  bool? _hasReview;

  @override
  void initState() {
    super.initState();
    _hasReview = ReviewService.cachedReviewExists(
      widget.order.id,
      widget.order.productId,
    );
    _fetchReviewStatus();
  }

  @override
  void didUpdateWidget(covariant _RateProductButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.productId != widget.order.productId) {
      _hasReview = ReviewService.cachedReviewExists(
        widget.order.id,
        widget.order.productId,
      );
      _fetchReviewStatus();
    }
  }

  void _fetchReviewStatus() {
    _reviewFuture = ReviewService.existingReview(
      widget.order.id,
      widget.order.productId,
    );
  }

  Future<void> _openReviewScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WriteReviewScreen(
          orderId: widget.order.id,
          productId: widget.order.productId,
          farmerId: widget.order.farmerId,
          productName: widget.order.items.first.name,
          productImage: widget.order.items.first.image,
        ),
      ),
    );

    if (mounted) {
      setState(_fetchReviewStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.order.productId.isEmpty) return SizedBox.shrink();
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _reviewFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            !snapshot.hasError) {
          _hasReview = snapshot.data?.exists ?? false;
        }
        if (_hasReview == null) {
          return OutlinedButton(
            onPressed: null,
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.seedColor,
              disabledForegroundColor: widget.seedColor,
              side: BorderSide(color: widget.seedColor.withValues(alpha: 0.35)),
              padding: EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: SizedBox(
              height: 14,
              width: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: widget.seedColor,
              ),
            ),
          );
        }
        return OutlinedButton(
          onPressed: _openReviewScreen,
          style: OutlinedButton.styleFrom(
            foregroundColor: widget.seedColor,
            side: BorderSide(color: widget.seedColor),
            padding: EdgeInsets.symmetric(vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            _hasReview! ? 'Edit Review' : 'Rate Product',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        );
      },
    );
  }
}

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: seedColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: 12),
          Text(
            'No orders found',
            style: GoogleFonts.fraunces(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: seedColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Your past orders will show up here',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}
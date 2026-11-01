import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/currency.dart';
import 'add_product_screen.dart';
import 'earnings_screen.dart';
import 'seller_shell.dart';

class SellerDashboardScreen extends StatelessWidget {
  const SellerDashboardScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);
  static final Map<String, int> _lastActiveListingsCount = {};

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
          title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: user == null
                ? null
                : FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
            builder: (context, snapshot) {
              final fullName =
                  snapshot.data?.data()?['name'] as String? ??
                  user?.displayName ??
                  '';
              final firstName = fullName.trim().isEmpty
                  ? null
                  : fullName.trim().split(RegExp(r'\s+')).first;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstName == null ? 'Hello!' : 'Hello $firstName!',
                    style: GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _bgColor,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Here\'s how your farm store is doing',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _bgColor.withValues(alpha: 0.75),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: user == null
            ? Center(
                child: Text(
                  'Please sign in.',
                  style: GoogleFonts.inter(color: Colors.grey[600]),
                ),
              )
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (!userSnap.hasData) {
                    return Center(
                      child: CircularProgressIndicator(color: _seedColor),
                    );
                  }
                  final userData = userSnap.data?.data();
                  final isSeller = userData?['isSeller'] == true;
                  final applicationStatus =
                      userData?['sellerApplicationStatus'] as String?;

                  if (!isSeller) {
                    return ListView(
                      padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                      children: [
                        Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: _SellerNotApprovedYet(
                            seedColor: _seedColor,
                            status: applicationStatus,
                          ),
                        ),
                      ],
                    );
                  }

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('orders')
                        .where('farmerId', isEqualTo: user.uid)
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, ordersSnap) {
                      if (ordersSnap.hasError) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Could not load your dashboard right now.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(color: Colors.grey[600]),
                            ),
                          ),
                        );
                      }
                      if (!ordersSnap.hasData) {
                        return Center(
                          child: CircularProgressIndicator(color: _seedColor),
                        );
                      }

                      final orders = ordersSnap.data!.docs
                          .map((doc) => _DashOrder.fromFirestore(doc, user.uid))
                          .toList();
                      final toShip = orders
                          .where((o) => o.status == 'Pending')
                          .length;
                      final totalEarned = orders
                          .where((o) => o.status == 'Completed')
                          .fold<double>(0, (total, o) => total + o.amount);
                      final recent = orders.take(4).toList();

                      return ListView(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                        children: [
                          _EarningsCard(
                            value: totalEarned,
                            seedColor: _seedColor,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EarningsScreen(),
                              ),
                            ),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: Icons.local_shipping_outlined,
                                  label: 'To Ship',
                                  value: '$toShip',
                                  seedColor: _seedColor,
                                  onTap: () => onOpenTab(SellerShell.ordersTab),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child:
                                    StreamBuilder<
                                      QuerySnapshot<Map<String, dynamic>>
                                    >(
                                      stream: FirebaseFirestore.instance
                                          .collection('products')
                                          .where(
                                            'farmerId',
                                            isEqualTo: user.uid,
                                          )
                                          .snapshots(),
                                      builder: (context, productsSnap) {
                                        final liveCount =
                                            productsSnap.data?.docs.length;
                                        if (liveCount != null) {
                                          _lastActiveListingsCount[user.uid] =
                                              liveCount;
                                        }
                                        final count =
                                            liveCount ??
                                            _lastActiveListingsCount[user
                                                .uid] ??
                                            0;
                                        return _StatCard(
                                          icon: Icons.inventory_2_outlined,
                                          label: 'Active Listings',
                                          value: '$count',
                                          seedColor: _seedColor,
                                          onTap: () => onOpenTab(
                                            SellerShell.productsTab,
                                          ),
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                          _SectionHeader(
                            title: 'Quick Actions',
                            seedColor: _seedColor,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddProductScreen(),
                                    ),
                                  ),
                                  icon: Icon(Icons.add, size: 20),
                                  label: Text(
                                    'List a Product',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _seedColor,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      onOpenTab(SellerShell.ordersTab),
                                  icon: Icon(
                                    Icons.receipt_long_outlined,
                                    size: 20,
                                    color: _seedColor,
                                  ),
                                  label: Text(
                                    'View Orders',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _seedColor,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: _seedColor),
                                    padding: EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          _SectionHeader(
                            title: 'Recent Orders',
                            seedColor: _seedColor,
                            trailing: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => onOpenTab(SellerShell.ordersTab),
                              child: _ViewAllChip(seedColor: _seedColor),
                            ),
                          ),
                          if (recent.isEmpty)
                            _EmptyOrders(seedColor: _seedColor)
                          else
                            ...recent.map(
                              (o) => _RecentOrderTile(
                                order: o,
                                seedColor: _seedColor,
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}

class _SellerNotApprovedYet extends StatelessWidget {
  const _SellerNotApprovedYet({required this.seedColor, this.status});

  final Color seedColor;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (status) {
      'pending' => (
        Icons.hourglass_top_rounded,
        'Application under review',
        'We\'ve received your seller application. You\'ll be able to list '
            'and sell products as soon as it\'s approved.',
      ),
      'rejected' => (
        Icons.error_outline_rounded,
        'Application not approved',
        'Your seller application wasn\'t approved this time. Open your '
            'Profile tab to see why and apply again.',
      ),
      _ => (
        Icons.assignment_outlined,
        'Apply to become a seller',
        'You need to apply and get approved before you can list and sell '
            'products. Open your Profile tab to apply.',
      ),
    };

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: seedColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: seedColor.withValues(alpha: 0.7)),
        ),
        SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: seedColor,
          ),
        ),
        SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DashOrder {
  final String productName;
  final String buyerName;
  final String status;
  final double amount;
  final int quantity;
  final String unit;

  const _DashOrder({
    required this.productName,
    required this.buyerName,
    required this.status,
    required this.amount,
    required this.quantity,
    required this.unit,
  });

  factory _DashOrder.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String farmerId,
  ) {
    final data = doc.data();
    final rawItems = data['items'];
    final itemMaps = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final mine = itemMaps.where((i) => i['farmerId'] == farmerId).toList();
    final first = mine.isNotEmpty
        ? mine.first
        : (itemMaps.isNotEmpty ? itemMaps.first : data);
    final amount = itemMaps.isEmpty
        ? (data['total'] as num?)?.toDouble() ?? 0
        : mine.fold<double>(
            0,
            (total, i) => total + ((i['subtotal'] as num?)?.toDouble() ?? 0),
          );

    return _DashOrder(
      productName: first['productName'] as String? ?? 'Product',
      buyerName: data['deliveryName'] as String? ?? '',
      status: data['status'] as String? ?? 'Pending',
      amount: amount,
      quantity: (first['quantity'] as num?)?.toInt() ?? 1,
      unit: first['unit'] as String? ?? '',
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.value,
    required this.seedColor,
    required this.onTap,
  });

  final double value;
  final Color seedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: seedColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Earnings so far',
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        formatPeso(value),
                        style: GoogleFonts.inter(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.seedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color seedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: seedColor.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: seedColor),
                ),
                SizedBox(height: 10),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: seedColor,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
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
      padding: EdgeInsets.fromLTRB(0, 22, 0, 10),
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

class _ViewAllChip extends StatelessWidget {
  const _ViewAllChip({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: seedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'View all',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: seedColor,
            ),
          ),
          SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 16, color: seedColor),
        ],
      ),
    );
  }
}

class _RecentOrderTile extends StatelessWidget {
  const _RecentOrderTile({required this.order, required this.seedColor});

  final _DashOrder order;
  final Color seedColor;

  Color get _statusColor {
    switch (order.status) {
      case 'Completed':
        return seedColor;
      case 'Cancelled':
        return Color(0xFFB3261E);
      case 'Processing':
        return Color(0xFF1D5D9B);
      default:
        return Color(0xFFB8860B);
    }
  }

  String get _statusLabel {
    switch (order.status) {
      case 'Pending':
        return 'To Ship';
      case 'Processing':
        return 'Shipped';
      default:
        return order.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitLabel = order.unit.isEmpty ? 'unit' : order.unit;
    final buyerSuffix = order.buyerName.trim().isNotEmpty
        ? ' · ${order.buyerName}'
        : '';

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${order.quantity} × $unitLabel$buyerSuffix',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPeso(order.amount),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: seedColor,
                ),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
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

class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.storefront_outlined,
              size: 44,
              color: seedColor.withValues(alpha: 0.4),
            ),
            SizedBox(height: 12),
            Text(
              'No sales yet',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: seedColor,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Orders for your listings will show up here',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
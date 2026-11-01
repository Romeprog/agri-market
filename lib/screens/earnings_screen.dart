import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/currency.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

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
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Earnings',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track your sales and income',
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
      body: user == null
          ? Center(
              child: Text(
                'Please sign in to view your earnings.',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            )
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
                        'Could not load your earnings right now.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _seedColor),
                  );
                }
                final sales = <_Sale>[];
                for (final doc in snapshot.data!.docs) {
                  final data = doc.data();
                  final status = data['status'] as String? ?? 'Pending';
                  final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                  final rawItems = data['items'];
                  final itemMaps = rawItems is List
                      ? rawItems.whereType<Map<String, dynamic>>().toList()
                      : <Map<String, dynamic>>[];
                  for (final item in itemMaps) {
                    if (item['farmerId'] != user.uid) continue;
                    sales.add(
                      _Sale(
                        productName:
                            item['productName'] as String? ?? 'Product',
                        quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                        unit: item['unit'] as String? ?? '',
                        amount: (item['subtotal'] as num?)?.toDouble() ?? 0,
                        buyerName: data['deliveryName'] as String?,
                        status: status,
                        date: createdAt,
                      ),
                    );
                  }
                }
                final totalIncome = sales
                    .where((s) => s.status == 'Completed')
                    .fold<double>(0, (total, s) => total + s.amount);
                final pendingIncome = sales
                    .where(
                      (s) => s.status == 'Pending' || s.status == 'Processing',
                    )
                    .fold<double>(0, (total, s) => total + s.amount);
                final now = DateTime.now();
                final thisMonthIncome = sales
                    .where(
                      (s) =>
                          s.status == 'Completed' &&
                          s.date != null &&
                          s.date!.year == now.year &&
                          s.date!.month == now.month,
                    )
                    .fold<double>(0, (total, s) => total + s.amount);
                return ListView(
                  padding: EdgeInsets.fromLTRB(14, 16, 14, 24),
                  children: [
                    _SummaryCard(
                      label: 'Total Income',
                      value: totalIncome,
                      seedColor: _seedColor,
                      highlighted: true,
                    ),
                    SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryCard(
                            label: 'This Month',
                            value: thisMonthIncome,
                            seedColor: _seedColor,
                          ),
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: _SummaryCard(
                            label: 'Pending',
                            value: pendingIncome,
                            seedColor: _seedColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 22),
                    Text(
                      'Recent Sales',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    if (sales.isEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.payments_outlined,
                                size: 44,
                                color: _seedColor.withValues(alpha: 0.4),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'No sales yet',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  color: _seedColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Sales from your listings will show up here',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...sales.map(
                        (s) => _SaleTile(sale: s, seedColor: _seedColor),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _Sale {
  final String productName;
  final int quantity;
  final String unit;
  final double amount;
  final String? buyerName;
  final String status;
  final DateTime? date;

  const _Sale({
    required this.productName,
    required this.quantity,
    required this.unit,
    required this.amount,
    required this.buyerName,
    required this.status,
    required this.date,
  });
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.seedColor,
    this.highlighted = false,
  });

  final String label;
  final double value;
  final Color seedColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlighted ? seedColor : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: highlighted
                  ? Colors.white.withValues(alpha: 0.8)
                  : Colors.grey[600],
            ),
          ),
          SizedBox(height: 6),
          Text(
            formatPeso(value),
            style: GoogleFonts.inter(
              fontSize: highlighted ? 26 : 18,
              fontWeight: FontWeight.w800,
              color: highlighted ? Colors.white : seedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  const _SaleTile({required this.sale, required this.seedColor});

  final _Sale sale;
  final Color seedColor;

  Color get _statusColor {
    switch (sale.status) {
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

  @override
  Widget build(BuildContext context) {
    final unitLabel = sale.unit.isEmpty ? 'unit' : sale.unit;
    final buyerSuffix = (sale.buyerName?.trim().isNotEmpty ?? false)
        ? ' · ${sale.buyerName}'
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
                  sale.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '${sale.quantity} × $unitLabel$buyerSuffix',
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
                '+${formatPeso(sale.amount)}',
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
                  sale.status,
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
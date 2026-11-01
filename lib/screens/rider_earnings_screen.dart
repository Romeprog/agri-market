import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/delivery_service.dart';
import '../utils/currency.dart';

class RiderEarningsScreen extends StatefulWidget {
  const RiderEarningsScreen({super.key});

  @override
  State<RiderEarningsScreen> createState() => _RiderEarningsScreenState();
}

class _RiderEarningsScreenState extends State<RiderEarningsScreen> {
  static const Color _bgColor = Color(0xFFEFF1E4);
  static const Color _seedColor = Color(0xFF1F3D2B);

  final _service = DeliveryService();

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
            child: Container(
              decoration: BoxDecoration(color: _seedColor),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Earnings',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track your delivery payouts',
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _service.streamMyCompletedDeliveries(),
        builder: (context, snapshot) {
          return CustomScrollView(
            slivers: [
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _ErrorState(error: '${snapshot.error}'),
                )
              else if (!snapshot.hasData)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: _seedColor),
                  ),
                )
              else
                _buildContent(snapshot.data!.docs),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final deliveries = docs.map(_Delivery.fromDoc).toList();

    if (deliveries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _EmptyState(),
      );
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: 7));

    double sumWhere(bool Function(_Delivery) test) =>
        deliveries.where(test).fold<double>(0, (total, d) => total + d.fee);

    final todayTotal = sumWhere(
      (d) => d.deliveredAt != null && !d.deliveredAt!.isBefore(todayStart),
    );
    final weekTotal = sumWhere(
      (d) => d.deliveredAt != null && d.deliveredAt!.isAfter(weekStart),
    );
    final allTimeTotal = deliveries.fold<double>(0, (t, d) => t + d.fee);

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          Row(
            children: [
              Expanded(
                child: _StatCard(label: 'Today', amount: todayTotal),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'This Week',
                  amount: weekTotal,
                  highlight: true,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StatCard(label: 'All-Time', amount: allTimeTotal),
              ),
            ],
          ),
          SizedBox(height: 24),
          Text(
            'Delivery History',
            style: GoogleFonts.fraunces(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _seedColor,
            ),
          ),
          SizedBox(height: 12),
          ...deliveries.map(
            (d) => Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _DeliveryTile(delivery: d),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.amount,
    this.highlight = false,
  });

  final String label;
  final double amount;
  final bool highlight;

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _accentColor = Color(0xFFE0A63A);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: highlight ? _seedColor : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.08),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: highlight ? _accentColor : Colors.grey[600],
            ),
          ),
          SizedBox(height: 6),
          Text(
            formatPeso(amount),
            style: GoogleFonts.fraunces(
              fontSize: 16.5,
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.white : _seedColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  const _DeliveryTile({required this.delivery});

  final _Delivery delivery;

  static const Color _seedColor = Color(0xFF1F3D2B);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _seedColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.moped, color: _seedColor, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivery.label,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                 SizedBox(height: 2),
                Text(
                  delivery.deliveredAt != null
                      ? _formatDate(delivery.deliveredAt!)
                      : 'Date unavailable',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${formatPeso(delivery.fee)}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: _seedColor,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime date) {
    const months = [
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
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  static const Color _seedColor = Color(0xFF1F3D2B);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _seedColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.savings_outlined,
              size: 30,
              color: _seedColor,
            ),
          ),
          SizedBox(height: 14),
          Text(
            'No earnings yet',
            style: GoogleFonts.fraunces(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _seedColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Completed deliveries and their payouts will show up here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 36, color: Colors.grey[500]),
          SizedBox(height: 10),
          Text(
            "Couldn't load your earnings.",
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 4),
          Text(
            error,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _Delivery {
  const _Delivery({
    required this.id,
    required this.fee,
    required this.deliveredAt,
    required this.label,
  });

  final String id;
  final double fee;
  final DateTime? deliveredAt;
  final String label;

  factory _Delivery.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final items = data['items'] as List<dynamic>? ?? const [];
    final label = items.length == 1
        ? (items.first as Map<String, dynamic>)['productName'] as String? ??
              'Order'
        : '${items.length} items';

    return _Delivery(
      id: doc.id,
      fee: (data['shippingFee'] as num?)?.toDouble() ?? 0,
      deliveredAt: (data['deliveredAt'] as Timestamp?)?.toDate(),
      label: label,
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum NotificationRole { buyer, seller, rider }

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key, this.role = NotificationRole.buyer});

  final NotificationRole role;

  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  Map<String, (String, String)> get _prefLabels {
    switch (role) {
      case NotificationRole.seller:
        return const {
          'newOrders': ('New Orders', 'When a buyer places an order with you'),
          'orderChanges': (
            'Order Changes',
            'When a buyer cancels or picks an order up',
          ),
          'reviews': ('Reviews', 'When buyers review your products'),
        };
      case NotificationRole.rider:
        return const {
          'newDeliveries': (
            'New Deliveries',
            'When a seller assigns you an order',
          ),
          'deliveryUpdates': (
            'Delivery Updates',
            'Changes to your active deliveries',
          ),
        };
      case NotificationRole.buyer:
        return const {
          'orderUpdates': ('Order Updates', 'Status changes on your orders'),
          'promotions': ('Promotions', 'Deals and seasonal discounts'),
          'priceAlerts': ('Price Alerts', 'When saved items drop in price'),
          'newArrivals': ('New Arrivals', 'Fresh produce added by farmers'),
        };
    }
  }

  String get _subtitle {
    switch (role) {
      case NotificationRole.seller:
        return 'New orders and shop activity';
      case NotificationRole.rider:
        return 'Deliveries and assignments';
      case NotificationRole.buyer:
        return 'Stay on top of orders and deals';
    }
  }

  String get _emptyMessage {
    switch (role) {
      case NotificationRole.seller:
        return 'No new orders yet. We\'ll alert you when a buyer orders.';
      case NotificationRole.rider:
        return 'No deliveries yet. Stay available to get assigned orders.';
      case NotificationRole.buyer:
        return 'No notifications yet.';
    }
  }

  static NotificationRole? _roleOf(Map<String, dynamic> data) {
    final explicit = data['role'] as String?;
    if (explicit != null) return NotificationRole.values.asNameMap()[explicit];
    switch (data['type'] as String? ?? '') {
      case 'new_order':
        return NotificationRole.seller;
      case 'rider_assigned':
      case 'delivery_assigned':
        return NotificationRole.rider;
      case 'order_processing':
      case 'order_completed':
      case 'no_rider_available':
        return NotificationRole.buyer;
      default:
        return null;
    }
  }

  bool _isForThisRole(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final target = _roleOf(doc.data());
    return target == null || target == role;
  }

  Future<void> _setPref(String key, bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'notificationPrefs': {key: value},
    }, SetOptions(merge: true));
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
          titleSpacing: 5,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          leading: Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(19),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: _bgColor, size: 20),
              ),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Notifications',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                _subtitle,
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
          ? Center(child: Text('Please sign in.'))
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Text(
                  'Recent',
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _seedColor,
                  ),
                ),
                SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('notifications')
                      .where('userId', isEqualTo: user.uid)
                      .orderBy('createdAt', descending: true)
                      .limit(80)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'Could not load notifications right now.',
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(color: _seedColor),
                        ),
                      );
                    }
                    final docs = snapshot.data!.docs
                        .where(_isForThisRole)
                        .toList();
                    if (docs.isEmpty) {
                      return Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _emptyMessage,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(color: Colors.grey[600]),
                        ),
                      );
                    }
                    final hasUnread = docs.any(
                      (d) => (d.data()['read'] as bool? ?? false) == false,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasUnread)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _markAllRead(docs),
                              child: Text(
                                'Mark all as read',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _seedColor,
                                ),
                              ),
                            ),
                          ),
                        for (final doc in docs)
                          _NotificationTile(doc: doc, seedColor: _seedColor),
                      ],
                    );
                  },
                ),
                SizedBox(height: 22),
                Text(
                  'Preferences',
                  style: GoogleFonts.fraunces(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _seedColor,
                  ),
                ),
                SizedBox(height: 10),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final prefs = Map<String, dynamic>.from(
                      snapshot.data?.data()?['notificationPrefs']
                              as Map<String, dynamic>? ??
                          {},
                    );

                    return Column(
                      children: _prefLabels.entries.map((entry) {
                        final key = entry.key;
                        final (title, subtitle) = entry.value;
                        final value = prefs[key] as bool? ?? true;

                        return Container(
                          margin: EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: SwitchListTile(
                            activeThumbColor: _seedColor,
                            title: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            value: value,
                            onChanged: (v) => _setPref(key, v),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
    );
  }

  Future<void> _markAllRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unread = docs.where(
      (d) => (d.data()['read'] as bool? ?? false) == false,
    );
    if (unread.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unread) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.doc, required this.seedColor});

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final Color seedColor;

  static IconData _iconFor(String type) {
    switch (type) {
      case 'new_order':
        return Icons.shopping_bag_outlined;
      case 'delivery_assigned':
      case 'rider_assigned':
        return Icons.local_shipping_outlined;
      case 'order_processing':
        return Icons.inventory_2_outlined;
      case 'order_completed':
        return Icons.check_circle_outline;
      case 'no_rider_available':
        return Icons.moped_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  static String _timeAgo(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final read = data['read'] as bool? ?? false;
    final type = data['type'] as String? ?? '';
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: read ? null : () => doc.reference.update({'read': true}),
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: seedColor.withValues(alpha: read ? 0.06 : 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_iconFor(type), size: 18, color: seedColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['title'] as String? ?? 'Notification',
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: read ? FontWeight.w600 : FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      data['body'] as String? ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _timeAgo(createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
              if (!read)
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: seedColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
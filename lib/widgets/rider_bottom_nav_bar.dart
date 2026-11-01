import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pill_nav_bar.dart';
import '../services/delivery_service.dart';

class RiderBottomNavBar extends StatelessWidget {
  const RiderBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    PillNavItem(
      icon: Icons.local_shipping_outlined,
      activeIcon: Icons.local_shipping,
      label: 'Deliveries',
    ),
    PillNavItem(
      icon: Icons.payments_outlined,
      activeIcon: Icons.payments,
      label: 'Earnings',
    ),
    PillNavItem(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Chat',
    ),
    PillNavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    PillNavBar bar(int activeDeliveries, int unreadChats) => PillNavBar(
      items: _items,
      currentIndex: currentIndex,
      onTap: onTap,
      badges: {0: activeDeliveries, 2: unreadChats},
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return bar(0, 0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: DeliveryService().streamMyDeliveries(),
      builder: (context, deliverySnapshot) {
        final activeDeliveries = deliverySnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: user.uid)
              .snapshots(),
          builder: (context, chatSnapshot) {
            final unreadChats =
                chatSnapshot.data?.docs.where((doc) {
                  final unreadBy = doc.data()['unreadBy'];
                  return unreadBy is List && unreadBy.contains(user.uid);
                }).length ??
                0;
            return bar(activeDeliveries, unreadChats);
          },
        );
      },
    );
  }
}
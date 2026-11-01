import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'pill_nav_bar.dart';

class SellerBottomNavBar extends StatelessWidget {
  const SellerBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    PillNavItem(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard,
      label: 'Dashboard',
    ),
    PillNavItem(
      icon: Icons.inventory_2_outlined,
      activeIcon: Icons.inventory_2,
      label: 'Products',
    ),
    PillNavItem(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
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
    PillNavBar bar(int pending, int unreadChats, bool isSeller) => PillNavBar(
      items: _items,
      currentIndex: currentIndex,
      onTap: (index) {
        if (!isSeller && (index == 1 || index == 2)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'You can use this once your seller application is approved. '
                'Check your Profile tab for status.',
              ),
            ),
          );
          return;
        }
        onTap(index);
      },
      badges: {2: pending, 3: unreadChats},
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return bar(0, 0, false);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final isSeller = userSnapshot.data?.data()?['isSeller'] == true;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('farmerId', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, orderSnapshot) {
            final pending =
                orderSnapshot.data?.docs
                    .where((doc) => doc.data()['status'] == 'Pending')
                    .length ??
                0;

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
                return bar(pending, unreadChats, isSeller);
              },
            );
          },
        );
      },
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _seedColor = Color(0xFF1F3D2B);

  static const _items = [
    _NavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'Home',
    ),
    _NavItemData(
      icon: Icons.explore_outlined,
      activeIcon: Icons.explore,
      label: 'Explore',
    ),
    _NavItemData(
      icon: Icons.chat_bubble_outline,
      activeIcon: Icons.chat_bubble,
      label: 'Chat',
    ),
    _NavItemData(
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long,
      label: 'Orders',
    ),
    _NavItemData(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    Widget buildRow(int orderCount, int unreadChatCount) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          boxShadow: [
            BoxShadow(
              color: _seedColor.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_items.length, (index) {
                final data = _items[index];
                final badgeCount = switch (data.label) {
                  'Orders' => orderCount,
                  'Chat' => unreadChatCount,
                  _ => 0,
                };
                return _NavItem(
                  data: data,
                  selected: index == currentIndex,
                  seedColor: _seedColor,
                  onTap: () => onTap(index),
                  badgeCount: badgeCount,
                );
              }),
            ),
          ),
        ),
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return buildRow(0, 0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('userId', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, orderSnapshot) {
        final activeCount =
            orderSnapshot.data?.docs.where((doc) {
              final status = doc.data()['status'] as String?;
              return status != 'Completed' && status != 'Cancelled';
            }).length ??
            0;

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('chats')
              .where('participants', arrayContains: user.uid)
              .snapshots(),
          builder: (context, chatSnapshot) {
            final unreadChatCount =
                chatSnapshot.data?.docs.where((doc) {
                  final unreadBy = doc.data()['unreadBy'];
                  return unreadBy is List && unreadBy.contains(user.uid);
                }).length ??
                0;
            return buildRow(activeCount, unreadChatCount);
          },
        );
      },
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.seedColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final _NavItemData data;
  final bool selected;
  final Color seedColor;
  final VoidCallback onTap;
  final int badgeCount;

  static const _accentColor = Color(0xFFE0A63A);

  Widget _buildIcon() {
    final icon = Icon(
      selected ? data.activeIcon : data.icon,
      color: selected ? seedColor : Colors.grey[400],
      size: 23,
    );

    if (badgeCount <= 0) return icon;

    return SizedBox(
      width: 23,
      height: 23,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: seedColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? seedColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            AnimatedSize(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        data.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: seedColor,
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
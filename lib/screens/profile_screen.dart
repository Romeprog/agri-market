import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'edit_profile_screen.dart';
import 'addresses_screen.dart';
import 'saved_items_screen.dart';
import 'notifications_screen.dart';
import 'help_center_screen.dart';
import 'about_screen.dart';
import 'cart_screen.dart';
import '../utils/admin_access.dart';
import '../utils/app_mode.dart';
import 'seller_orders_screen.dart';
import 'earnings_screen.dart';
import 'seller_application_status_screen.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/cart_button.dart';

class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItemData(this.icon, this.title, this.onTap);
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  List<_MenuItemData> _accountItems(BuildContext context) => [
    _MenuItemData(
      Icons.person_outline,
      'Edit Profile',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditProfileScreen()),
      ),
    ),
    _MenuItemData(
      Icons.location_on_outlined,
      'My Addresses',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AddressesScreen()),
      ),
    ),
  ];

  List<_MenuItemData> _sellingItems(
    BuildContext context, {
    required bool hasListings,
  }) {
    final items = <_MenuItemData>[];
    if (hasListings) {
      items.add(
        _MenuItemData(
          Icons.receipt_long_outlined,
          'My Sales',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SellerOrdersScreen()),
          ),
        ),
      );
      items.add(
        _MenuItemData(
          Icons.payments_outlined,
          'Earnings',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EarningsScreen()),
          ),
        ),
      );
    }
    return items;
  }

  List<_MenuItemData> _sellerGateItems(BuildContext context, String? status) {
    if (status == 'pending') {
      return [
        _MenuItemData(
          Icons.hourglass_top_outlined,
          'Seller Application: Pending Review',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SellerApplicationStatusScreen()),
          ),
        ),
      ];
    }
    if (status == 'rejected') {
      return [
        _MenuItemData(
          Icons.storefront_outlined,
          'Seller Application: Not Approved',
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SellerApplicationStatusScreen()),
          ),
        ),
      ];
    }
    return [];
  }

  List<_MenuItemData> _adminItems(BuildContext context) => [
    _MenuItemData(
      Icons.admin_panel_settings_outlined,
      'Admin Dashboard',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AdminDashboardScreen()),
      ),
    ),
  ];

  List<_MenuItemData> _activityItems(BuildContext context) => [
    _MenuItemData(
      Icons.favorite_border,
      'Saved Items',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SavedItemsScreen()),
      ),
    ),
    _MenuItemData(
      Icons.notifications_none,
      'Notifications',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NotificationsScreen()),
      ),
    ),
  ];

  List<_MenuItemData> _supportItems(BuildContext context) => [
    _MenuItemData(
      Icons.help_outline,
      'Help Center',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HelpCenterScreen()),
      ),
    ),
    _MenuItemData(
      Icons.info_outline,
      'About AgriMarket',
      () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AboutScreen()),
      ),
    ),
  ];

  void _openCart(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CartScreen()));
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to log out of your account?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await FirebaseAuth.instance.signOut();
              activeRoleNotifier.value = null;
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFB3261E),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

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
                'Profile',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your account and settings',
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
                child: CartButton(onTap: () => _openCart(context)),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: currentUser == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final name =
                    data?['name'] as String? ??
                    currentUser?.displayName ??
                    'User';
                final email =
                    data?['email'] as String? ?? currentUser?.email ?? '';
                final photoUrl =
                    data?['photoUrl'] as String? ?? currentUser?.photoURL ?? '';
                return Center(
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: _seedColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: photoUrl.isNotEmpty
                              ? Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.person,
                                    color: _seedColor,
                                    size: 40,
                                  ),
                                )
                              : Image.asset(
                                  'assets/profile.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Icon(
                                    Icons.person,
                                    color: _seedColor,
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _seedColor,
                          ),
                        )
                      else ...[
                        Text(
                          name,
                          style: GoogleFonts.fraunces(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          email,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 12),
            _MenuSection(
              title: 'Account',
              items: _accountItems(context),
              seedColor: _seedColor,
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: currentUser == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
              builder: (context, userSnapshot) {
                final userData = userSnapshot.data?.data();
                final isSeller = userData?['isSeller'] == true;
                final applicationStatus =
                    userData?['sellerApplicationStatus'] as String?;

                if (!isSeller) {
                  final gateItems = _sellerGateItems(
                    context,
                    applicationStatus,
                  );
                  if (gateItems.isEmpty) return SizedBox.shrink();
                  return _MenuSection(
                    title: 'Selling',
                    items: gateItems,
                    seedColor: _seedColor,
                  );
                }

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('products')
                      .where('farmerId', isEqualTo: currentUser!.uid)
                      .limit(1)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final hasListings = (snapshot.data?.docs.length ?? 0) > 0;
                    final sellingItems = _sellingItems(
                      context,
                      hasListings: hasListings,
                    );
                    if (sellingItems.isEmpty) return SizedBox.shrink();
                    return _MenuSection(
                      title: 'Selling',
                      items: sellingItems,
                      seedColor: _seedColor,
                    );
                  },
                );
              },
            ),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: currentUser == null
                  ? null
                  : FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .snapshots(),
              builder: (context, riderSnapshot) {
                if (riderSnapshot.data?.data()?['isRider'] != true) {
                  return SizedBox.shrink();
                }
                return _MenuSection(
                  title: 'Delivery',
                  items: [
                    _MenuItemData(
                      Icons.two_wheeler_outlined,
                      'Rider Center',
                      () => activeRoleNotifier.value = AppRole.rider,
                    ),
                  ],
                  seedColor: _seedColor,
                );
              },
            ),
            _MenuSection(
              title: 'Activity',
              items: _activityItems(context),
              seedColor: _seedColor,
            ),
            _MenuSection(
              title: 'Support',
              items: _supportItems(context),
              seedColor: _seedColor,
            ),
            if (isAdminUser(currentUser))
              _MenuSection(
                title: 'Admin',
                items: _adminItems(context),
                seedColor: _seedColor,
              ),
            SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: Icon(Icons.logout, color: Color(0xFFB3261E)),
                label: Text(
                  'Log Out',
                  style: GoogleFonts.inter(
                    color: Color(0xFFB3261E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Color(0xFFB3261E)),
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  const _MenuSection({
    required this.title,
    required this.items,
    required this.seedColor,
  });

  final String title;
  final List<_MenuItemData> items;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: seedColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: seedColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final item in items) ...[
                  InkWell(
                    onTap: item.onTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, color: seedColor, size: 22),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item != items.last)
                    Divider(height: 1, indent: 50, color: Colors.grey.shade200),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
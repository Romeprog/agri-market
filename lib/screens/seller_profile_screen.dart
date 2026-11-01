import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'notifications_screen.dart';
import 'seller_application_screen.dart';
import 'seller_application_status_screen.dart';
import '../models/seller_application.dart';
import '../services/seller_application_service.dart';
import '../utils/app_mode.dart';

class _MenuItemData {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuItemData(this.icon, this.title, this.onTap);
}

class SellerProfileScreen extends StatelessWidget {
  const SellerProfileScreen({super.key});

  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

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

    final accountItems = [
      _MenuItemData(
        Icons.person_outline,
        'Edit Profile',
        () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => EditProfileScreen()),
        ),
      ),
      _MenuItemData(
        Icons.notifications_none,
        'Notifications',
        () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotificationsScreen(role: NotificationRole.seller),
          ),
        ),
      ),
    ];
    final supportItems = [
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
                'Manage your store and account',
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
            SizedBox(height: 16),
            _SellerApplicationCard(),
            _MenuSection(
              title: 'Account',
              items: accountItems,
              seedColor: _seedColor,
            ),
            _MenuSection(
              title: 'Support',
              items: supportItems,
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

class _SellerApplicationCard extends StatelessWidget {
  const _SellerApplicationCard();

  static const _seedColor = SellerProfileScreen._seedColor;

  void _openApplication(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerApplicationScreen()),
    );
  }

  void _openStatus(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerApplicationStatusScreen()),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
    VoidCallback? onTap,
  }) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _seedColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _seedColor, size: 20),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.fraunces(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _seedColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
              if (action != null) ...[SizedBox(height: 12), action],
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _seedColor.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: EdgeInsets.all(16), child: content),
        ),
      ),
    );
  }

  Widget _applyButton(BuildContext context, String label) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _openApplication(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _seedColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SellerApplication?>(
      stream: SellerApplicationService.myApplication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        }

        final app = snapshot.data;

        if (app == null) {
          return _card(
            icon: Icons.eco_outlined,
            title: 'Become a Seller',
            body:
                'Apply to start listing and selling your produce on '
                'AgriMarket.',
            action: _applyButton(context, 'Apply Now'),
          );
        }

        switch (app.status) {
          case SellerApplicationStatus.pending:
            return _card(
              icon: Icons.hourglass_top_rounded,
              title: 'Application under review',
              body:
                  'We\'ve received your seller application. You\'ll be able '
                  'to start selling as soon as it\'s approved.',
              onTap: () => _openStatus(context),
            );
          case SellerApplicationStatus.rejected:
            final reason = app.rejectionReason?.trim();
            return _card(
              icon: Icons.error_outline_rounded,
              title: 'Application not approved',
              body: (reason == null || reason.isEmpty)
                  ? 'Your seller application wasn\'t approved this time. '
                        'You can update your details and apply again.'
                  : reason,
              action: _applyButton(context, 'Apply Again'),
              onTap: () => _openStatus(context),
            );
          case SellerApplicationStatus.approved:
            return _card(
              icon: Icons.verified_outlined,
              title: 'You\'re an approved seller',
              body: 'You can list products and sell on AgriMarket.',
              onTap: () => _openStatus(context),
            );
        }
      },
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
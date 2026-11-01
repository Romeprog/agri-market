import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'about_screen.dart';
import 'edit_profile_screen.dart';
import 'help_center_screen.dart';
import 'notifications_screen.dart';
import 'rider_application_screen.dart';
import '../models/rider_application.dart';
import '../services/rider_application_service.dart';
import '../utils/app_mode.dart';
import '../widgets/profile_menu_section.dart';

class RiderProfileScreen extends StatelessWidget {
  const RiderProfileScreen({super.key});

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
                'Manage your rider account',
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
            const _RiderApplicationCard(),
            ProfileMenuSection(
              title: 'Account',
              items: [
                ProfileMenuItem(
                  Icons.person_outline,
                  'Edit Profile',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditProfileScreen()),
                  ),
                ),
                ProfileMenuItem(
                  Icons.notifications_none,
                  'Notifications',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationsScreen(role: NotificationRole.rider),
                    ),
                  ),
                ),
              ],
            ),
            ProfileMenuSection(
              title: 'Support',
              items: [
                ProfileMenuItem(
                  Icons.help_outline,
                  'Help Center',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => HelpCenterScreen()),
                  ),
                ),
                ProfileMenuItem(
                  Icons.info_outline,
                  'About AgriMarket',
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => AboutScreen()),
                  ),
                ),
              ],
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

class _RiderApplicationCard extends StatelessWidget {
  const _RiderApplicationCard();

  static const _seedColor = RiderProfileScreen._seedColor;

  void _openApplication(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => RiderApplicationScreen()),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String body,
    Widget? action,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
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
      child: Row(
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
        ],
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
    return StreamBuilder<RiderApplication?>(
      stream: RiderApplicationService.myApplication(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        }

        final app = snapshot.data;

        if (app == null) {
          return _card(
            icon: Icons.local_shipping_outlined,
            title: 'Become a Rider',
            body:
                'Apply to start accepting and delivering orders on '
                'AgriMarket.',
            action: _applyButton(context, 'Apply Now'),
          );
        }

        switch (app.status) {
          case RiderApplicationStatus.pending:
            return _card(
              icon: Icons.hourglass_top_rounded,
              title: 'Application under review',
              body:
                  'We\'ve received your rider application. You\'ll be able '
                  'to start delivering as soon as it\'s approved.',
            );
          case RiderApplicationStatus.rejected:
            final reason = app.rejectionReason?.trim();
            return _card(
              icon: Icons.error_outline_rounded,
              title: 'Application not approved',
              body: (reason == null || reason.isEmpty)
                  ? 'Your rider application wasn\'t approved this time. '
                        'You can update your details and apply again.'
                  : reason,
              action: _applyButton(context, 'Apply Again'),
            );
          case RiderApplicationStatus.approved:
            return _card(
              icon: Icons.verified_outlined,
              title: 'You\'re an approved rider',
              body: 'You can accept and deliver orders on AgriMarket.',
            );
        }
      },
    );
  }
}
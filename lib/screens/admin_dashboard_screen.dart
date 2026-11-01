import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/admin_access.dart';
import 'admin_reports_screen.dart';
import 'admin_rider_applications_screen.dart';
import 'admin_products_screen.dart';
import 'admin_seller_applications_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  late final Stream<int> _pendingReports;
  late final Stream<int> _pendingApplications;
  late final Stream<int> _pendingRiderApplications;

  @override
  void initState() {
    super.initState();
    _pendingReports = _pendingCount('reports');
    _pendingApplications = _pendingCount('sellerApplications');
    _pendingRiderApplications = _pendingCount('riderApplications');
  }

  Stream<int> _pendingCount(String collection) {
    if (!isAdminUser(FirebaseAuth.instance.currentUser)) {
      return Stream.value(0);
    }
    return FirebaseFirestore.instance
        .collection(collection)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.size)
        .handleError((_) {});
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Log Out',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'You\'ll need to sign back in to access the admin tools.',
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
    if (!isAdminUser(FirebaseAuth.instance.currentUser)) {
      return Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _seedColor,
          foregroundColor: _bgColor,
          elevation: 0,
          title: Text(
            'Admin',
            style: GoogleFonts.fraunces(
              color: _bgColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text(
              'This section is only available to AgriMarket administrators.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[700], 
                fontSize: 14
              ),
            ),
          ),
        ),
      );
    }

    final canPop = Navigator.canPop(context);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _seedColor,
          foregroundColor: _bgColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: kToolbarHeight + 10,
          automaticallyImplyLeading: canPop,
          titleSpacing: canPop ? null : 16,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello Admin!',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Review reports, applications and listings',
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(Icons.logout_rounded, color: _bgColor, size: 20),
                  tooltip: 'Log out',
                  onPressed: _confirmLogout,
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorColor: _bgColor,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: _bgColor,
                unselectedLabelColor: _bgColor.withValues(alpha: 0.6),
                labelStyle: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                tabs: [
                  _BadgeTab(label: 'Reports', countStream: _pendingReports),
                  _BadgeTab(
                    label: 'Seller Applications',
                    countStream: _pendingApplications,
                  ),
                  _BadgeTab(
                    label: 'Rider Applications',
                    countStream: _pendingRiderApplications,
                  ),
                  Tab(text: 'Listings'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            AdminReportsTab(),
            AdminSellerApplicationsTab(),
            AdminRiderApplicationsTab(),
            AdminProductsTab(),
          ],
        ),
      ),
    );
  }
}

class _BadgeTab extends StatelessWidget {
  const _BadgeTab({required this.label, required this.countStream});

  final String label;
  final Stream<int> countStream;

  @override
  Widget build(BuildContext context) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          StreamBuilder<int>(
            stream: countStream,
            builder: (context, snap) {
              final count = snap.data ?? 0;
              if (count == 0) return SizedBox.shrink();
              return Container(
                margin: EdgeInsets.only(left: 6),
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(0xFFB8860B),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
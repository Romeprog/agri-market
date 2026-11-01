import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/seller_application.dart';
import '../services/seller_application_service.dart';
import '../utils/app_mode.dart';
import 'seller_application_screen.dart';

class SellerApplicationStatusScreen extends StatelessWidget {
  const SellerApplicationStatusScreen({super.key});

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _seedColor,
        foregroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: kToolbarHeight + 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        ),
        title: Text(
          'Seller Application',
          style: GoogleFonts.fraunces(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: _bgColor,
          ),
        ),
        actions: [
          if (!canPop)
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
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    activeRoleNotifier.value = null;
                  },
                ),
              ),
            ),
        ],
      ),
      body: StreamBuilder<SellerApplication?>(
        stream: SellerApplicationService.myApplication(),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: _seedColor));
          }
          final app = snapshot.data;
          if (app == null) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You haven\'t applied yet.',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerApplicationScreen(),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _seedColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Complete Your Application',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final isPending = app.status == SellerApplicationStatus.pending;
          final isRejected = app.status == SellerApplicationStatus.rejected;

          return ListView(
            padding: EdgeInsets.all(18),
            children: [
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isPending
                      ? Color(0xFFFFF4E5)
                      : isRejected
                      ? Color(0xFFFDEBEA)
                      : Color(0xFFE9F7EE),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPending
                          ? Icons.hourglass_top_rounded
                          : isRejected
                          ? Icons.cancel_outlined
                          : Icons.check_circle_outline,
                      color: isPending
                          ? Color(0xFFB26A00)
                          : isRejected
                          ? Color(0xFFB3261E)
                          : Color(0xFF1F7A3D),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        isPending
                            ? 'Your application is pending review.'
                            : isRejected
                            ? 'Your application was not approved.'
                            : 'Your application was approved.',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isRejected && app.rejectionReason != null) ...[
                SizedBox(height: 14),
                Text(
                  'Reviewer note',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  app.rejectionReason!,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              SizedBox(height: 20),
              _detailCard(app),
              if (isRejected) ...[
                SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SellerApplicationScreen(),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _seedColor,
                      padding: EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Reapply',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _detailCard(SellerApplication app) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Farm / Business', app.farmName),
          _row('Location', app.farmLocation),
          _row('Contact', app.contactNumber),
          _row('Sells', app.productCategories.join(', ')),
          SizedBox(height: 8),
          Text(
            app.farmDescription,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value, style: GoogleFonts.inter(fontSize: 13))),
        ],
      ),
    );
  }
}
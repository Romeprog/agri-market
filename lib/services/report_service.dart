import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product.dart';
import '../models/report.dart';

class ReportService {
  ReportService._();

  static const String adminEmail = 'agrimarket.support@gmail.com';

  static bool get currentUserIsAdmin =>
      FirebaseAuth.instance.currentUser?.email == adminEmail;

  static Stream<List<Report>> pendingReports() {
    return FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromFirestore).toList());
  }

  static Stream<List<Report>> allReports() {
    return FirebaseFirestore.instance
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Report.fromFirestore).toList());
  }

  static Future<void> resolveReport({
    required String reportId,
    required String resolution,
    String? note,
  }) {
    final admin = FirebaseAuth.instance.currentUser;
    return FirebaseFirestore.instance
        .collection('reports')
        .doc(reportId)
        .update({
          'status': resolution,
          'resolvedAt': FieldValue.serverTimestamp(),
          'resolvedBy': admin?.uid,
          if (note != null && note.isNotEmpty) 'resolutionNote': note,
        });
  }

  static Future<void> deleteReportedProduct(String productId) {
    return FirebaseFirestore.instance
        .collection('products')
        .doc(productId)
        .delete();
  }

  static Future<String?> fetchUserName(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final data = doc.data();
      for (final key in ['name', 'fullName', 'displayName']) {
        final value = data?[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Product?> fetchProduct(String productId) async {
    if (productId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();
      if (!doc.exists) return null;
      return Product.fromFirestore(doc);
    } catch (_) {
      return null;
    }
  }
}
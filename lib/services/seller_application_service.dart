import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/seller_application.dart';

class SellerApplicationService {
  SellerApplicationService._();

  static const List<String> categories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Livestock',
    'Tools',
  ];

  static const List<String> sellerTypes = [
    'Individual farmer',
    'Farm or cooperative',
    'Reseller or supplier',
  ];

  static const List<String> experienceLevels = [
    'Less than 1 year',
    '1-3 years',
    '4-10 years',
    'More than 10 years',
  ];

  static const List<String> farmingPractices = [
    'Organic',
    'Pesticide-free',
    'Conventional',
    'Greenhouse / hydroponic',
    'Free-range',
  ];

  static const List<String> fulfillmentOptions = [
    'Pickup',
    'Local delivery',
    'Courier shipping',
  ];

  static DocumentReference<Map<String, dynamic>> _appRef(String uid) =>
      FirebaseFirestore.instance.collection('sellerApplications').doc(uid);

  static Stream<SellerApplication?> myApplication() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _appRef(uid)
        .snapshots()
        .map((doc) => doc.exists ? SellerApplication.fromFirestore(doc) : null);
  }

  static Stream<Map<String, dynamic>> myUserDoc() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const {});
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  static Future<void> submitApplication({
    required String farmName,
    required String farmLocation,
    required String contactNumber,
    required String farmDescription,
    required List<String> productCategories,
    required String sellerType,
    required String yearsOfExperience,
    required List<String> fulfillmentOptions,
    required bool agreedToTerms,
    String farmSize = '',
    List<String> farmingPractices = const [],
    String sampleProducts = '',
    String socialLink = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You need to be signed in.');

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.set(_appRef(user.uid), {
      'userId': user.uid,
      'farmName': farmName,
      'farmLocation': farmLocation,
      'contactNumber': contactNumber,
      'farmDescription': farmDescription,
      'productCategories': productCategories,
      'sellerType': sellerType,
      'yearsOfExperience': yearsOfExperience,
      'fulfillmentOptions': fulfillmentOptions,
      'agreedToTerms': agreedToTerms,
      if (farmSize.isNotEmpty) 'farmSize': farmSize,
      if (farmingPractices.isNotEmpty) 'farmingPractices': farmingPractices,
      if (sampleProducts.isNotEmpty) 'sampleProducts': sampleProducts,
      if (socialLink.isNotEmpty) 'socialLink': socialLink,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('users').doc(user.uid), {
      'sellerApplicationStatus': 'pending',
    });
    batch.set(db.collection('mail').doc(), {
      'to': ['agrimarket.support@gmail.com'],
      'message': {
        'subject': 'New seller application submitted',
        'text':
            'A new seller application was submitted by $farmName '
            '($contactNumber), location: $farmLocation. '
            'Please review it in the admin dashboard.',
      },
      'applicationId': user.uid,
      'applicationType': 'seller',
      'reporterId': user.uid,
    });
    await batch.commit();
  }

  static Stream<List<SellerApplication>> pendingApplications() {
    return FirebaseFirestore.instance
        .collection('sellerApplications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final apps = snap.docs.map(SellerApplication.fromFirestore).toList();
          final now =
              DateTime.now();
          apps.sort(
            (a, b) => (b.submittedAt ?? now).compareTo(a.submittedAt ?? now),
          );
          return apps;
        });
  }

  static Future<void> approve(String userId) async {
    final admin = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_appRef(userId), {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
    });
    batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
      'isSeller': true,
      'sellerApplicationStatus': 'approved',
    });
    await batch.commit();
  }

  static Future<void> reject(String userId, {String? reason}) async {
    final admin = FirebaseAuth.instance.currentUser;
    final batch = FirebaseFirestore.instance.batch();
    batch.update(_appRef(userId), {
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': admin?.uid,
      if (reason != null && reason.isNotEmpty) 'rejectionReason': reason,
    });
    batch.update(FirebaseFirestore.instance.collection('users').doc(userId), {
      'isSeller': false,
      'sellerApplicationStatus': 'rejected',
    });
    await batch.commit();
  }
}
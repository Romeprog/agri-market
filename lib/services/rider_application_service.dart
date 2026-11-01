import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rider_application.dart';

class RiderApplicationService {
  RiderApplicationService._();

  static const List<String> vehicleTypes = ['Motorcycle', 'Tricycle'];

  static const List<String> experienceLevels = [
    'Less than 1 year',
    '1-3 years',
    '4-10 years',
    'More than 10 years',
  ];

  static DocumentReference<Map<String, dynamic>> _appRef(String uid) =>
      FirebaseFirestore.instance.collection('riderApplications').doc(uid);

  static Stream<RiderApplication?> myApplication() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _appRef(uid)
        .snapshots()
        .map((doc) => doc.exists ? RiderApplication.fromFirestore(doc) : null);
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
    required String fullName,
    required String contactNumber,
    required String vehicleType,
    required String vehiclePlateNumber,
    required String serviceArea,
    required bool agreedToTerms,
    String driverLicenseNumber = '',
    String yearsOfExperience = '',
    String additionalNotes = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You need to be signed in.');

    final db = FirebaseFirestore.instance;
    final batch = db.batch();
    batch.set(_appRef(user.uid), {
      'userId': user.uid,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'vehicleType': vehicleType,
      'vehiclePlateNumber': vehiclePlateNumber,
      'serviceArea': serviceArea,
      'agreedToTerms': agreedToTerms,
      if (driverLicenseNumber.isNotEmpty)
        'driverLicenseNumber': driverLicenseNumber,
      if (yearsOfExperience.isNotEmpty) 'yearsOfExperience': yearsOfExperience,
      if (additionalNotes.isNotEmpty) 'additionalNotes': additionalNotes,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
    batch.update(db.collection('users').doc(user.uid), {
      'riderApplicationStatus': 'pending',
    });
    batch.set(db.collection('mail').doc(), {
      'to': ['agrimarket.support@gmail.com'],
      'message': {
        'subject': 'New rider application submitted',
        'text':
            'A new rider application was submitted by $fullName '
            '($contactNumber), service area: $serviceArea. '
            'Please review it in the admin dashboard.',
      },
      'applicationId': user.uid,
      'applicationType': 'rider',
      'reporterId': user.uid,
    });
    await batch.commit();
  }

  static Stream<List<RiderApplication>> pendingApplications() {
    return FirebaseFirestore.instance
        .collection('riderApplications')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) {
          final apps = snap.docs.map(RiderApplication.fromFirestore).toList();
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
      'isRider': true,
      'riderApplicationStatus': 'approved',
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
      'isRider': false,
      'riderApplicationStatus': 'rejected',
    });
    await batch.commit();
  }
}
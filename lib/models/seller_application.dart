import 'package:cloud_firestore/cloud_firestore.dart';

enum SellerApplicationStatus { pending, approved, rejected }

SellerApplicationStatus _statusFromString(String value) {
  switch (value) {
    case 'approved':
      return SellerApplicationStatus.approved;
    case 'rejected':
      return SellerApplicationStatus.rejected;
    case 'pending':
    default:
      return SellerApplicationStatus.pending;
  }
}

String _str(Object? v) => v is String ? v : (v?.toString() ?? '');

String? _strOrNull(Object? v) => v is String ? v : null;

List<String> _stringList(Object? v) =>
    v is List ? v.map((e) => e.toString()).toList() : <String>[];

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

class SellerApplication {
  const SellerApplication({
    required this.userId,
    required this.farmName,
    required this.farmLocation,
    required this.contactNumber,
    required this.farmDescription,
    required this.productCategories,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.sellerType = '',
    this.yearsOfExperience = '',
    this.farmSize = '',
    this.farmingPractices = const [],
    this.sampleProducts = '',
    this.fulfillmentOptions = const [],
    this.socialLink = '',
  });

  final String userId;
  final String farmName;
  final String farmLocation;
  final String contactNumber;
  final String farmDescription;
  final List<String> productCategories;
  final SellerApplicationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  final String sellerType;
  final String yearsOfExperience;
  final String farmSize;
  final List<String> farmingPractices;
  final String sampleProducts;
  final List<String> fulfillmentOptions;
  final String socialLink;

  factory SellerApplication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SellerApplication(
      userId: data['userId'] is String ? data['userId'] as String : doc.id,
      farmName: _str(data['farmName']),
      farmLocation: _str(data['farmLocation']),
      contactNumber: _str(data['contactNumber']),
      farmDescription: _str(data['farmDescription']),
      productCategories: _stringList(data['productCategories']),
      status: _statusFromString(_str(data['status'])),
      submittedAt: _date(data['submittedAt']),
      reviewedAt: _date(data['reviewedAt']),
      rejectionReason: _strOrNull(data['rejectionReason']),
      sellerType: _str(data['sellerType']),
      yearsOfExperience: _str(data['yearsOfExperience']),
      farmSize: _str(data['farmSize']),
      farmingPractices: _stringList(data['farmingPractices']),
      sampleProducts: _str(data['sampleProducts']),
      fulfillmentOptions: _stringList(data['fulfillmentOptions']),
      socialLink: _str(data['socialLink']),
    );
  }
}
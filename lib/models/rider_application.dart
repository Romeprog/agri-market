import 'package:cloud_firestore/cloud_firestore.dart';

enum RiderApplicationStatus { pending, approved, rejected }

RiderApplicationStatus _statusFromString(String value) {
  switch (value) {
    case 'approved':
      return RiderApplicationStatus.approved;
    case 'rejected':
      return RiderApplicationStatus.rejected;
    case 'pending':
    default:
      return RiderApplicationStatus.pending;
  }
}

String _str(Object? v) => v is String ? v : (v?.toString() ?? '');

String? _strOrNull(Object? v) => v is String ? v : null;

DateTime? _date(Object? v) => v is Timestamp ? v.toDate() : null;

class RiderApplication {
  const RiderApplication({
    required this.userId,
    required this.fullName,
    required this.contactNumber,
    required this.vehicleType,
    required this.vehiclePlateNumber,
    required this.serviceArea,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.rejectionReason,
    this.driverLicenseNumber = '',
    this.yearsOfExperience = '',
    this.additionalNotes = '',
  });

  final String userId;
  final String fullName;
  final String contactNumber;
  final String vehicleType;
  final String vehiclePlateNumber;
  final String serviceArea;
  final RiderApplicationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  final String driverLicenseNumber;
  final String yearsOfExperience;
  final String additionalNotes;

  factory RiderApplication.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    return RiderApplication(
      userId: data['userId'] is String ? data['userId'] as String : doc.id,
      fullName: _str(data['fullName']),
      contactNumber: _str(data['contactNumber']),
      vehicleType: _str(data['vehicleType']),
      vehiclePlateNumber: _str(data['vehiclePlateNumber']),
      serviceArea: _str(data['serviceArea']),
      status: _statusFromString(_str(data['status'])),
      submittedAt: _date(data['submittedAt']),
      reviewedAt: _date(data['reviewedAt']),
      rejectionReason: _strOrNull(data['rejectionReason']),
      driverLicenseNumber: _str(data['driverLicenseNumber']),
      yearsOfExperience: _str(data['yearsOfExperience']),
      additionalNotes: _str(data['additionalNotes']),
    );
  }
}
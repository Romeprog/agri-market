import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus { pending, dismissed, actioned }

ReportStatus _statusFromString(String value) {
  switch (value) {
    case 'dismissed':
      return ReportStatus.dismissed;
    case 'actioned':
      return ReportStatus.actioned;
    case 'pending':
    default:
      return ReportStatus.pending;
  }
}

class Report {
  const Report({
    required this.id,
    required this.productId,
    required this.productName,
    required this.reportedFarmerId,
    required this.reporterId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNote,
    this.reporterName,
    this.reporterEmail,
    this.details,
  });

  final String id;
  final String productId;
  final String productName;
  final String reportedFarmerId;
  final String reporterId;
  final String reason;
  final ReportStatus status;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNote;
  final String? reporterName;
  final String? reporterEmail;
  final String? details;

  bool get isResolved => status != ReportStatus.pending;

  factory Report.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return Report(
      id: doc.id,
      productId: data['productId'] as String? ?? '',
      productName: data['productName'] as String? ?? 'Untitled listing',
      reportedFarmerId: data['reportedFarmerId'] as String? ?? '',
      reporterId: data['reporterId'] as String? ?? '',
      reason: data['reason'] as String? ?? 'Other',
      status: _statusFromString(data['status'] as String? ?? 'pending'),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedBy: data['resolvedBy'] as String?,
      resolutionNote: data['resolutionNote'] as String?,
      reporterName: data['reporterName'] as String?,
      reporterEmail: data['reporterEmail'] as String?,
      details: data['details'] as String?,
    );
  }
}
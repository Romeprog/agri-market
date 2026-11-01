import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String id;
  final String orderId;
  final String productId;
  final String buyerId;
  final String buyerName;
  final String farmerId;
  final int rating;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? sellerReplyText;
  final DateTime? sellerRepliedAt;
  final List<String> images;

  const Review({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.buyerId,
    required this.buyerName,
    required this.farmerId,
    required this.rating,
    required this.comment,
    this.createdAt,
    this.updatedAt,
    this.sellerReplyText,
    this.sellerRepliedAt,
    this.images = const [],
  });

  factory Review.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final reply = data['sellerReply'] as Map<String, dynamic>?;
    return Review(
      id: doc.id,
      orderId: data['orderId'] as String? ?? '',
      productId: data['productId'] as String? ?? '',
      buyerId: data['buyerId'] as String? ?? '',
      buyerName: data['buyerName'] as String? ?? 'AgriMarket Buyer',
      farmerId: data['farmerId'] as String? ?? '',
      rating: (data['rating'] as num?)?.toInt() ?? 5,
      comment: data['comment'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      sellerReplyText: reply?['text'] as String?,
      sellerRepliedAt: (reply?['repliedAt'] as Timestamp?)?.toDate(),
      images: (data['images'] is List)
          ? (data['images'] as List).whereType<String>().toList()
          : const [],
    );
  }
}
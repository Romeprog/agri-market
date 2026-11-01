import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReviewService {
  ReviewService._();

  static final _db = FirebaseFirestore.instance;
  static final Map<String, bool> _reviewExistsCache = {};

  static String reviewId(String orderId, String productId) =>
      '${orderId}_$productId';

  static bool? cachedReviewExists(String orderId, String productId) =>
      _reviewExistsCache[reviewId(orderId, productId)];

  static Future<void> submitReview({
    required String orderId,
    required String productId,
    required String farmerId,
    required int rating,
    required String comment,
    List<String> images = const [],
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('You need to sign in first.');

    final reviewRef = _db
        .collection('reviews')
        .doc(reviewId(orderId, productId));
    final productRef = _db.collection('products').doc(productId);

    await _db.runTransaction((tx) async {
      final reviewSnap = await tx.get(reviewRef);
      final productSnap = await tx.get(productRef);

      final isNewReview = !reviewSnap.exists;
      final oldRating = (reviewSnap.data()?['rating'] as num?)?.toInt();
      final currentAvg =
          (productSnap.data()?['rating'] as num?)?.toDouble() ?? 0;
      final currentCount =
          (productSnap.data()?['reviewCount'] as num?)?.toInt() ?? 0;

      late final double newAvg;
      late final int newCount;
      if (isNewReview || oldRating == null) {
        newCount = currentCount + 1;
        newAvg = ((currentAvg * currentCount) + rating) / newCount;
      } else {
        newCount = currentCount == 0 ? 1 : currentCount;
        newAvg = currentCount == 0
            ? rating.toDouble()
            : ((currentAvg * currentCount) - oldRating + rating) / currentCount;
      }

      final payload = <String, dynamic>{
        'orderId': orderId,
        'productId': productId,
        'buyerId': user.uid,
        'farmerId': farmerId,
        'rating': rating,
        'comment': comment,
        'images': images,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (isNewReview) {
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['buyerName'] = await _resolveBuyerName(user);
      }

      tx.set(reviewRef, payload, SetOptions(merge: true));
      tx.update(productRef, {
        'rating': double.parse(newAvg.toStringAsFixed(2)),
        'reviewCount': newCount,
      });
    });

    _reviewExistsCache[reviewId(orderId, productId)] = true;
  }

  static Future<String> _resolveBuyerName(User user) async {
    if (user.displayName?.trim().isNotEmpty == true) {
      return user.displayName!.trim();
    }
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final name = userDoc.data()?['name'] as String?;
    return name?.trim().isNotEmpty == true ? name!.trim() : 'AgriMarket Buyer';
  }

  static Future<void> replyToReview({
    required String reviewId,
    required String replyText,
  }) {
    return _db.collection('reviews').doc(reviewId).update({
      'sellerReply': {
        'text': replyText,
        'repliedAt': FieldValue.serverTimestamp(),
      },
    });
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> reviewsForProduct(
    String productId,
  ) {
    return _db
        .collection('reviews')
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> existingReview(
    String orderId,
    String productId,
  ) async {
    final snap = await _db
        .collection('reviews')
        .doc(reviewId(orderId, productId))
        .get();
    _reviewExistsCache[reviewId(orderId, productId)] = snap.exists;
    return snap;
  }
}
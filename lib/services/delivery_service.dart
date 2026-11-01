import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'cloudinary_service.dart';

class DeliveryService {
  DeliveryService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection('orders');
  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _notifications =>
      _db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get _products =>
      _db.collection('products');

  String? get _uid => _auth.currentUser?.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> streamAvailableRiders() {
    return _users
        .where('isRider', isEqualTo: true)
        .where('isAvailable', isEqualTo: true)
        .snapshots();
  }

  static const Duration offerWindow = Duration(seconds: 30);

  Future<void> offerToRider({
    required String orderId,
    required String riderId,
  }) async {
    await _orders.doc(orderId).update({
      'riderId': riderId,
      'deliveryStatus': 'Offered',
      'offerSentAt': FieldValue.serverTimestamp(),
      'riderSearchState': FieldValue.delete(),
    });

    try {
      await _notifications.add({
        'userId': riderId,
        'orderId': orderId,
        'type': 'delivery_offer',
        'title': 'New delivery request',
        'body': 'Open the app and accept within 30 seconds.',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> notifyBuyerNoRiderAvailable({
    required String orderId,
    required String buyerId,
  }) async {
    await _orders.doc(orderId).update({
      'riderSearchState': 'no_riders_available',
      'riderSearchAttemptedAt': FieldValue.serverTimestamp(),
    });

    await _notifications.add({
      'userId': buyerId,
      'orderId': orderId,
      'type': 'no_rider_available',
      'title': 'No rider available yet',
      'body': 'Choose pickup or wait for the next available rider.',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyDeliveries({
    bool activeOnly = true,
  }) {
    Query<Map<String, dynamic>> q = _orders.where('riderId', isEqualTo: _uid);
    if (activeOnly) {
      q = q.where(
        'deliveryStatus',
        whereIn: ['Assigned', 'Picked Up', 'Out for Delivery'],
      );
    }
    return q.snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyCompletedDeliveries() {
    return _orders
        .where('riderId', isEqualTo: _uid)
        .where('deliveryStatus', isEqualTo: 'Delivered')
        .orderBy('deliveredAt', descending: true)
        .snapshots();
  }

  Future<void> markPickedUp(String orderId) {
    return _orders.doc(orderId).update({
      'deliveryStatus': 'Picked Up',
      'pickedUpAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markOutForDelivery(String orderId) {
    return _orders.doc(orderId).update({
      'deliveryStatus': 'Out for Delivery',
      'outForDeliveryAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markDelivered(String orderId, File proofPhoto) async {
    final upload = await uploadImageToCloudinary(
      proofPhoto,
    ).timeout(const Duration(seconds: 60));
    if (upload == null) {
      throw Exception('The delivery photo could not be uploaded.');
    }

    final orderRef = _orders.doc(orderId);
    final orderSnap = await orderRef.get();
    final orderData = orderSnap.data();
    if (orderData == null) {
      throw Exception('This order could not be found.');
    }
    if (orderData['status'] == 'Completed') return;

    final orderFarmerId = orderData['farmerId'] as String?;
    final rawItems = orderData['items'];
    final items = rawItems is List ? rawItems : const [];

    final soldByProduct = <String, int>{};
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      if (item['farmerId'] != orderFarmerId) continue;
      final productId = item['productId'] as String?;
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId == null || productId.isEmpty || qty <= 0) continue;
      soldByProduct[productId] = (soldByProduct[productId] ?? 0) + qty;
    }

    final batch = _db.batch();

    batch.update(orderRef, {
      'deliveryStatus': 'Delivered',
      'status': 'Completed',
      'deliveredAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'proofPhotoUrl': upload.secureUrl,
      'proofPhotoAt': FieldValue.serverTimestamp(),
    });

    soldByProduct.forEach((productId, qty) {
      batch.update(_products.doc(productId), {
        'sold': FieldValue.increment(qty),
        'lastSoldOrderId': orderId,
      });
    });

    await batch.commit();
  }

  Future<void> advanceDeliveryStatus(String orderId, String currentStatus) {
    switch (currentStatus) {
      case 'Assigned':
        return markPickedUp(orderId);
      case 'Picked Up':
        return markOutForDelivery(orderId);
      case 'Out for Delivery':
        throw StateError(
          'A delivery photo is required. Use markDelivered(orderId, photo).',
        );
      default:
        throw StateError('No next status after "$currentStatus"');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamMyOffers() {
    return _orders
        .where('riderId', isEqualTo: _uid)
        .where('deliveryStatus', isEqualTo: 'Offered')
        .snapshots();
  }

  Future<void> acceptOffer(String orderId) {
    return _orders.doc(orderId).update({
      'deliveryStatus': 'Assigned',
      'riderAssignedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> declineOffer(String orderId) => _clearOffer(orderId);

  Future<void> cancelExpiredOffer(String orderId) => _clearOffer(orderId);

  Future<void> _clearOffer(String orderId) {
    return _orders.doc(orderId).update({
      'riderId': FieldValue.delete(),
      'deliveryStatus': FieldValue.delete(),
    });
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> streamMyUserDoc() {
    return _users.doc(_uid).snapshots();
  }

  Future<void> setRiderAvailability(bool isAvailable) {
    return _users.doc(_uid).update({'isAvailable': isAvailable});
  }

  Future<void> setFulfillmentChoice({
    required String orderId,
    required String choice,
  }) {
    assert(choice == 'Pickup' || choice == 'Wait');
    return _orders.doc(orderId).update({
      'fulfillmentChoice': choice,
      'fulfillmentChoiceAt': FieldValue.serverTimestamp(),
    });
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Product {
  final String? id;
  final String name;
  final String unit;
  final double price;
  final double deliveryFeePerUnit;
  final String image;
  final String? imagePublicId;
  final IconData icon;

  final String? category;
  final String? description;
  final double? rating;
  final int? reviewCount;
  final int? sold;
  final String? farmerName;
  final String? farmerId;
  final String? location;
  final int? stock;
  final DateTime? createdAt;

  const Product({
    this.id,
    required this.name,
    required this.unit,
    required this.price,
    this.deliveryFeePerUnit = 0,
    required this.image,
    this.imagePublicId,
    required this.icon,
    this.category,
    this.description,
    this.rating,
    this.reviewCount,
    this.sold,
    this.farmerName,
    this.farmerId,
    this.location,
    this.stock,
    this.createdAt,
  });

  String get key => id ?? name;

  int get available => (stock ?? 0) < 0 ? 0 : (stock ?? 0);
  bool get inStock => available > 0;

  factory Product.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Product(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed product',
      unit: data['unit'] as String? ?? 'per kg',
      price: (data['price'] as num?)?.toDouble() ?? 0,
      deliveryFeePerUnit: (data['deliveryFeePerUnit'] as num?)?.toDouble() ?? 0,
      image: data['image'] as String? ?? '',
      imagePublicId: data['imagePublicId'] as String?,
      icon: iconForCategory(data['category'] as String?),
      category: data['category'] as String?,
      description: data['description'] as String?,
      rating: (data['rating'] as num?)?.toDouble(),
      reviewCount: data['reviewCount'] as int?,
      sold: data['sold'] as int?,
      farmerName: data['farmerName'] as String?,
      farmerId: data['farmerId'] as String?,
      location: data['location'] as String?,
      stock: data['stock'] as int?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'unit': unit,
      'price': price,
      'deliveryFeePerUnit': deliveryFeePerUnit,
      'image': image,
      'imagePublicId': imagePublicId,
      'category': category,
      'description': description,
      'rating': rating,
      'reviewCount': reviewCount ?? 0,
      'sold': sold ?? 0,
      'farmerName': farmerName,
      'farmerId': farmerId,
      'location': location,
      'stock': stock ?? 0,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static IconData iconForCategory(String? category) {
    switch (category) {
      case 'Vegetables':
        return Icons.eco_outlined;
      case 'Fruits':
        return Icons.apple_outlined;
      case 'Grains':
        return Icons.grain;
      case 'Dairy':
        return Icons.local_drink_outlined;
      case 'Livestock':
        return Icons.pets_outlined;
      case 'Tools':
        return Icons.handyman_outlined;
      default:
        return Icons.eco_outlined;
    }
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../utils/currency.dart';
import 'heart_button.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    required this.seedColor,
    required this.onTap,
    required this.onAddToCart,
  });

  final Product product;
  final Color seedColor;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  static const _accentColor = Color(0xFFE0A63A);
  static const List<double> _greyscaleMatrix = [
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ];

  Future<void> _toggleSaved(BuildContext context, bool isSaved) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || product.id == null) return;
    final userDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    await userDoc.set({
      'savedProducts': isSaved
          ? FieldValue.arrayRemove([product.id])
          : FieldValue.arrayUnion([product.id]),
    }, SetOptions(merge: true));
  }

  Widget _buildImage() {
    final fallback = Container(
      alignment: Alignment.center,
      child: Icon(product.icon, color: seedColor, size: 36),
    );

    if (product.image.startsWith('http')) {
      return Image.network(
        product.image,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: seedColor),
          );
        },
        errorBuilder: (context, error, stack) => fallback,
      );
    }

    return Image.asset(
      product.image,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isOwner = user != null && user.uid == product.farmerId;

    final bool outOfStock = !product.inStock;
    final bool lowStock = product.inStock && product.available <= 5;

    final int? ratingCount = product.reviewCount ?? product.sold;
    final String? ratingText = product.rating == null
        ? null
        : product.rating!.toStringAsFixed(1) +
              (ratingCount != null ? ' ($ratingCount)' : '');

    final String? subtitle = product.location ?? product.farmerName;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                        child: Container(
                          color: seedColor.withValues(alpha: 0.06),
                          child: outOfStock
                              ? ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    _greyscaleMatrix,
                                  ),
                                  child: _buildImage(),
                                )
                              : _buildImage(),
                        ),
                      ),
                    ),
                    if (outOfStock)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.28),
                            alignment: Alignment.center,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Out of Stock',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (lowStock || product.category != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: lowStock
                                ? _accentColor
                                : Colors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            lowStock
                                ? 'Only ${product.available} left'
                                : product.category!,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: lowStock ? Colors.white : seedColor,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child:
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: user == null
                                ? null
                                : FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(user.uid)
                                      .snapshots(),
                            builder: (context, snapshot) {
                              final saved = List<String>.from(
                                snapshot.data?.data()?['savedProducts']
                                        as List? ??
                                    [],
                              ).contains(product.id);

                              return HeartButton(
                                saved: saved,
                                onTap: () => _toggleSaved(context, saved),
                              );
                            },
                          ),
                    ),
                    if (ratingText != null)
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: _accentColor,
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                ratingText,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 11,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: Colors.grey[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  formatPeso(product.price),
                                  maxLines: 1,
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: seedColor,
                                  ),
                                ),
                              ),
                              Text(
                                product.unit,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner)
                          _StatusPill(label: 'Your listing', color: seedColor)
                        else if (outOfStock)
                          _StatusPill(
                            label: 'Out of stock',
                            color: Colors.grey[500]!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
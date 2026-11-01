import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/product_screening.dart';

const _seedColor = Color(0xFF1F3D2B);
const _bgColor = Color(0xFFEFF1E4);

const _categories = [
  'Vegetables',
  'Fruits',
  'Grains',
  'Dairy',
  'Livestock',
  'Tools',
];

const _removalReasons = [
  'Not an agricultural product',
  'Prohibited item',
  'Misleading listing',
  'Inappropriate content',
  'Other',
];

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

enum _AuditOutcome { checked, removed }

class _AdminProduct {
  final String id;
  final String name;
  final String imageUrl;
  final String category;
  final String description;
  final String farmerId;
  final String? farmerName;
  final String? unit;
  final double price;
  final int stock;
  final int sold;
  final double rating;
  final int reviewCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastAuditedAt;
  final List<String> flaggedTerms;
  final String searchText;

  const _AdminProduct({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.description,
    required this.farmerId,
    required this.farmerName,
    required this.unit,
    required this.price,
    required this.stock,
    required this.sold,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    required this.lastAuditedAt,
    required this.flaggedTerms,
    required this.searchText,
  });

  bool get isChecked {
    final audited = lastAuditedAt;
    if (audited == null) return false;
    final edited = updatedAt;
    return edited == null || !edited.isAfter(audited);
  }

  bool get needsLook => flaggedTerms.isNotEmpty && !isChecked;

  factory _AdminProduct.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data();

    String? str(List<String> keys) {
      for (final k in keys) {
        final v = d[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
      return null;
    }

    DateTime? date(dynamic v) => v is Timestamp ? v.toDate() : null;

    var image = str(['imageUrl', 'image', 'productImage', 'photoUrl']) ?? '';
    if (image.isEmpty && d['images'] is List) {
      image = (d['images'] as List).whereType<String>().firstOrNull ?? '';
    }

    final name = str(['name', 'productName', 'title']) ?? 'Unnamed product';
    final description = str(['description', 'details']) ?? '';
    final category = str(['category']) ?? 'Uncategorized';
    final farmerName = str(['farmerName', 'sellerName', 'farmName']);

    final flagged = nonAgriMatches('$name $description');

    return _AdminProduct(
      id: doc.id,
      name: name,
      imageUrl: image,
      category: category,
      description: description,
      farmerId: d['farmerId'] as String? ?? '',
      farmerName: farmerName,
      unit: str(['unit']),
      price: (d['price'] as num?)?.toDouble() ?? 0,
      stock: (d['stock'] as num?)?.toInt() ?? 0,
      sold: (d['sold'] as num?)?.toInt() ?? 0,
      rating: (d['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (d['reviewCount'] as num?)?.toInt() ?? 0,
      createdAt: date(d['createdAt']),
      updatedAt: date(d['updatedAt']),
      lastAuditedAt: date(d['lastAuditedAt']),
      flaggedTerms: flagged,
      searchText: '$name $category ${farmerName ?? ''} $description'
          .toLowerCase(),
    );
  }
}

Stream<int> adminFlaggedListingCount() {
  return FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((snap) => snap.docs.map(_AdminProduct.fromDoc).where((p) => p.needsLook).length)
      .handleError((_) {});
}

class AdminProductsTab extends StatefulWidget {
  const AdminProductsTab({super.key});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  final _searchController = TextEditingController();
  final _random = Random();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream =
      FirebaseFirestore.instance.collection('products').snapshots();

  String _query = '';
  String _filter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesFilter(_AdminProduct p) {
    switch (_filter) {
      case 'All':
        return true;
      case 'Unchecked':
        return !p.isChecked;
      default:
        return p.category == _filter;
    }
  }

  bool _matchesQuery(_AdminProduct p) {
    final tokens = _query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty);
    return tokens.every(p.searchText.contains);
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: error ? Colors.red[700] : _seedColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openDetail(_AdminProduct product) async {
    final result = await showModalBottomSheet<_AuditOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(product: product),
    );
    if (!mounted || result == null) return;
    _showSnack(
      result == _AuditOutcome.checked
          ? 'Marked as checked'
          : 'Listing removed and the seller was notified',
    );
  }

  void _spotCheck(List<_AdminProduct> all) {
    if (all.isEmpty) return;
    final unchecked = all.where((p) => !p.isChecked).toList();
    final pool = unchecked.isNotEmpty ? unchecked : all;
    _openDetail(pool[_random.nextInt(pool.length)]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: _SearchField(
            controller: _searchController,
            onChanged: (v) => setState(() => _query = v),
            onClear: () {
              _searchController.clear();
              setState(() => _query = '');
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Could not load product listings right now.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: _seedColor),
                );
              }

              final all = snapshot.data!.docs
                  .map(_AdminProduct.fromDoc)
                  .toList()
                ..sort((a, b) {
                  final ad = a.createdAt;
                  final bd = b.createdAt;
                  if (ad == null && bd == null) return 0;
                  if (ad == null) return 1;
                  if (bd == null) return -1;
                  return bd.compareTo(ad);
                });

              final uncheckedCount = all.where((p) => !p.isChecked).length;
              final filtered = all
                  .where((p) => _matchesFilter(p) && _matchesQuery(p))
                  .toList();

              final chips = <(String, String)>[
                ('All', 'All'),
                ('Unchecked', 'Unchecked ($uncheckedCount)'),
                for (final c in _categories) (c, c),
              ];

              return Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 14, 0, 8),
                    child: SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        itemCount: chips.length,
                        separatorBuilder: (_, _) =>
                            SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final (value, label) = chips[index];
                          return _AdminFilterChip(
                            label: label,
                            selected: _filter == value,
                            onTap: () => setState(() => _filter = value),
                          );
                        },
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 0, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${filtered.length} of ${all.length} listings',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: all.isEmpty
                              ? null
                              : () => _spotCheck(all),
                          icon: Icon(Icons.shuffle_rounded, size: 16),
                          label: Text(
                            'Spot check',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: _seedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _EmptyListings(
                            hasListings: all.isNotEmpty,
                          )
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              4,
                              16,
                              24,
                            ),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final product = filtered[index];
                              return _ProductAuditCard(
                                product: product,
                                onTap: () => _openDetail(product),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: GoogleFonts.inter(fontSize: 13.5),
        decoration: InputDecoration(
          hintText: 'Search products, sellers, categories',
          hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[600]),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? SizedBox.shrink()
                : IconButton(
                    onPressed: onClear,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                  ),
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _AdminFilterChip extends StatelessWidget {
  const _AdminFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _seedColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _seedColor : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            SizedBox(width: 4),
          ],
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditStatusBadge extends StatelessWidget {
  const _AuditStatusBadge({required this.product});

  final _AdminProduct product;

  @override
  Widget build(BuildContext context) {
    if (product.needsLook) {
      return _Badge(
        label: 'Needs a look',
        color: Colors.red.shade700,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (product.isChecked) {
      return const _Badge(
        label: 'Checked',
        color: _seedColor,
        icon: Icons.verified_outlined,
      );
    }
    return _Badge(label: 'Not checked', color: Colors.grey.shade600);
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.url, required this.size, this.radius});

  final String url;
  final double? size;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: _seedColor.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(Icons.shopping_basket_outlined, color: _seedColor),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _seedColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(radius ?? 12),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stack) => fallback,
            ),
    );
  }
}

class _ProductAuditCard extends StatelessWidget {
  const _ProductAuditCard({required this.product, required this.onTap});

  final _AdminProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final priceText =
        '₱${product.price.toStringAsFixed(2)}${product.unit != null ? ' / ${product.unit}' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProductImage(url: product.imageUrl, size: 64),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        priceText,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _seedColor,
                        ),
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _Badge(label: product.category, color: _seedColor),
                          _AuditStatusBadge(product: product),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        [
                          if (product.farmerName != null) product.farmerName!,
                          'Stock ${product.stock}',
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  const _EmptyListings({required this.hasListings});

  final bool hasListings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: _seedColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasListings
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 38,
                color: _seedColor.withValues(alpha: 0.55),
              ),
            ),
            SizedBox(height: 16),
            Text(
              hasListings ? 'No matching listings' : 'No listings yet',
              style: GoogleFonts.fraunces(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: _seedColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              hasListings
                  ? 'Try a different search or filter'
                  : 'Seller product listings will show up here',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductDetailSheet extends StatefulWidget {
  const _ProductDetailSheet({required this.product});

  final _AdminProduct product;

  @override
  State<_ProductDetailSheet> createState() => _ProductDetailSheetState();
}

class _ProductDetailSheetState extends State<_ProductDetailSheet> {
  late final Future<Map<String, dynamic>?> _sellerFuture = _loadSeller();
  bool _busy = false;
  String? _error;

  _AdminProduct get _p => widget.product;

  Future<Map<String, dynamic>?> _loadSeller() async {
    if (_p.farmerId.isEmpty) return null;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('sellerApplications')
          .doc(_p.farmerId)
          .get();
      return snap.data();
    } catch (_) {
      return null;
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      return 'Permission denied. Make sure you are signed in as the admin '
          'and the latest Firestore rules are published.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<void> _markChecked() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(_p.id)
          .update({
            'lastAuditedAt': FieldValue.serverTimestamp(),
            'lastAuditedBy': FirebaseAuth.instance.currentUser?.uid,
          });
      if (mounted) Navigator.of(context).pop(_AuditOutcome.checked);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _friendlyError(e);
        });
      }
    }
  }

  Future<void> _remove() async {
    final choice = await showDialog<_RemovalChoice>(
      context: context,
      builder: (_) => _RemoveListingDialog(productName: _p.name),
    );
    if (choice == null || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(_p.id)
          .delete();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _friendlyError(e);
        });
      }
      return;
    }

    if (_p.farmerId.isNotEmpty) {
      try {
        final note = choice.note.isEmpty ? '' : ' ${choice.note}';
        await FirebaseFirestore.instance.collection('notifications').add({
          'userId': _p.farmerId,
          'type': 'listing_removed',
          'title': 'Listing removed',
          'body':
              'Your listing "${_p.name}" was removed by AgriMarket: '
              '${choice.reason}.$note',
          'read': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }

    if (mounted) Navigator.of(context).pop(_AuditOutcome.removed);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    final maxHeight = MediaQuery.of(context).size.height * 0.88;
    final priceText =
        '₱${p.price.toStringAsFixed(2)}${p.unit != null ? ' / ${p.unit}' : ''}';

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _seedColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 10,
                      child: _ProductImage(
                        url: p.imageUrl,
                        size: null,
                        radius: 16,
                      ),
                    ),
                    SizedBox(height: 14),
                    Text(
                      p.name,
                      style: GoogleFonts.fraunces(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      priceText,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(label: p.category, color: _seedColor),
                        _AuditStatusBadge(product: p),
                      ],
                    ),
                    if (p.needsLook) ...[
                      SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 18,
                              color: Colors.red.shade700,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This may not be an agricultural item '
                                '(matched: ${p.flaggedTerms.join(', ')}). '
                                'Check the photo and description before '
                                'deciding.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 14),
                    _InfoCard(
                      rows: [
                        _InfoRowData(
                          'Seller',
                          child: FutureBuilder<Map<String, dynamic>?>(
                            future: _sellerFuture,
                            builder: (context, snap) {
                              final farmName =
                                  snap.data?['farmName'] as String?;
                              return _InfoValue(
                                farmName ??
                                    p.farmerName ??
                                    (snap.connectionState ==
                                            ConnectionState.waiting
                                        ? 'Loading…'
                                        : 'Unknown seller'),
                              );
                            },
                          ),
                        ),
                        _InfoRowData(
                          'Contact',
                          child: FutureBuilder<Map<String, dynamic>?>(
                            future: _sellerFuture,
                            builder: (context, snap) => _InfoValue(
                              (snap.data?['contactNumber'] as String?) ?? '—',
                            ),
                          ),
                        ),
                        _InfoRowData('Stock', value: '${p.stock}'),
                        _InfoRowData('Sold', value: '${p.sold}'),
                        _InfoRowData(
                          'Rating',
                          value: p.reviewCount == 0
                              ? 'No reviews yet'
                              : '${p.rating.toStringAsFixed(1)} '
                                    '(${p.reviewCount})',
                        ),
                        _InfoRowData(
                          'Listed',
                          value: p.createdAt == null
                              ? '—'
                              : _fmtDate(p.createdAt!),
                        ),
                        _InfoRowData(
                          'Last Checked',
                          value: p.lastAuditedAt == null
                              ? 'Never'
                              : _fmtDate(p.lastAuditedAt!),
                        ),
                      ],
                    ),
                    SizedBox(height: 14),
                    Text(
                      'Description',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _seedColor,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      p.description.isEmpty
                          ? 'No description provided.'
                          : p.description,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.4,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 8),
              Text(
                _error!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _remove,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red[700],
                      side: BorderSide(color: Colors.red.shade700),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Remove Listing',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (_busy || p.isChecked) ? null : _markChecked,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _seedColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _seedColor.withValues(
                        alpha: 0.25,
                      ),
                      disabledForegroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _busy
                        ? SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            p.isChecked ? 'Checked' : 'Mark as checked',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData(this.label, {this.value, this.child});

  final String label;
  final String? value;
  final Widget? child;
}

class _InfoValue extends StatelessWidget {
  const _InfoValue(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.rows});

  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade100),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    rows[i].label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                   SizedBox(width: 12),
                  Flexible(
                    child:
                        rows[i].child ?? _InfoValue(rows[i].value ?? '—'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemovalChoice {
  const _RemovalChoice(this.reason, this.note);

  final String reason;
  final String note;
}

class _RemoveListingDialog extends StatefulWidget {
  const _RemoveListingDialog({required this.productName});

  final String productName;

  @override
  State<_RemoveListingDialog> createState() => _RemoveListingDialogState();
}

class _RemoveListingDialogState extends State<_RemoveListingDialog> {
  final _noteController = TextEditingController();
  String? _reason;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_reason == null) return false;
    if (_reason == 'Other') return _noteController.text.trim().isNotEmpty;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        'Remove Listing?',
        style: GoogleFonts.fraunces(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _seedColor,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${widget.productName}" will be deleted and the seller will be '
              'told why. This can\'t be undone.',
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[700]),
            ),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _removalReasons)
                  ChoiceChip(
                    label: Text(r),
                    selected: _reason == r,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _reason = r),
                    selectedColor: _seedColor,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _reason == r
                          ? _seedColor
                          : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _reason == r ? Colors.white : Colors.black87,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 14),
            TextField(
              controller: _noteController,
              onChanged: (_) => setState(() {}),
              maxLength: 200,
              maxLines: 2,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: _reason == 'Other'
                    ? 'Explain the reason (required)'
                    : 'Add a note for the seller (optional)',
                hintStyle: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.grey[500],
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: _seedColor),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          onPressed: _canSubmit
              ? () => Navigator.of(
                  context,
                ).pop(_RemovalChoice(_reason!, _noteController.text.trim()))
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[700],
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.red.shade700.withValues(
              alpha: 0.25,
            ),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            'Remove',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
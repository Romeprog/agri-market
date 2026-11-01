import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/product.dart';
import '../utils/currency.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';

class SellerProductsScreen extends StatelessWidget {
  const SellerProductsScreen({super.key});

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Products',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Manage your listings',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: _bgColor.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _seedColor,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddProductScreen()),
        ),
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Product',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: user == null
          ? Center(
              child: Text(
                'Please sign in.',
                style: GoogleFonts.inter(color: Colors.grey[600]),
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('farmerId', isEqualTo: user.uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load your products right now.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(color: Colors.grey[600]),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(color: _seedColor),
                  );
                }
                final products = snapshot.data!.docs
                    .map(Product.fromFirestore)
                    .toList();
                if (products.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 44,
                            color: _seedColor.withValues(alpha: 0.4),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'You haven\'t listed anything yet',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: _seedColor,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tap "Add Product" to list your first item',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(14, 16, 14, 90),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductRow(product: product, seedColor: _seedColor);
                  },
                );
              },
            ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.seedColor});

  final Product product;
  final Color seedColor;

  Future<void> _updateStock(BuildContext context) async {
    final result = await showDialog<(bool, int)>(
      context: context,
      builder: (_) => _StockDialog(
        productName: product.name,
        current: product.available,
        seedColor: seedColor,
      ),
    );
    if (result == null || product.id == null) return;
    final (addMode, value) = result;

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(product.id)
          .update({'stock': addMode ? FieldValue.increment(value) : value});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            addMode
                ? 'Added $value to ${product.name}'
                : 'Stock of ${product.name} set to $value',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: seedColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update stock. Please try again.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: product),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: product.image.isNotEmpty
                      ? Image.network(
                          product.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: seedColor.withValues(alpha: 0.08),
                            child: Icon(product.icon, color: seedColor),
                          ),
                        )
                      : Container(
                          color: seedColor.withValues(alpha: 0.08),
                          child: Icon(product.icon, color: seedColor),
                        ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
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
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '${formatPeso(product.price)} \u00b7 ${product.unit}',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: 3),
                    product.inStock
                        ? Text(
                            'Stock: ${product.available}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          )
                        : Text(
                            'Sold out - tap the box icon to restock',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red[700],
                            ),
                          ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Update stock',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add_box_outlined, color: seedColor),
                onPressed: () => _updateStock(context),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}

class _StockDialog extends StatefulWidget {
  const _StockDialog({
    required this.productName,
    required this.current,
    required this.seedColor,
  });

  final String productName;
  final int current;
  final Color seedColor;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _addMode = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, (_addMode, int.parse(_controller.text.trim())));
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Update stock',
        style: GoogleFonts.fraunces(fontWeight: FontWeight.bold, color: seed),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.productName} \u00b7 current stock: ${widget.current}',
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
            ),
            SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Add stock'),
                  selected: _addMode,
                  selectedColor: seed.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _addMode = true),
                ),
                ChoiceChip(
                  label: Text('Set to'),
                  selected: !_addMode,
                  selectedColor: seed.withValues(alpha: 0.18),
                  onSelected: (_) => setState(() => _addMode = false),
                ),
              ],
            ),
            SizedBox(height: 12),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _addMode ? 'Quantity to add' : 'New stock amount',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                if (n == null || n > 1000000) return 'Enter a whole number';
                if (_addMode && n < 1) return 'Enter at least 1';
                return null;
              },
              onFieldSubmitted: (_) => _save(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: Colors.grey[700]),
          ),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: seed,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Save',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
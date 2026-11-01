import 'dart:io';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';
import '../widgets/psgc_location_picker.dart';
import '../models/product.dart';
import '../utils/product_screening.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _accentColor = Color(0xFFE0A63A);
  static const Color _bgColor = Color(0xFFEFF1E4);

  static const _categories = [
    'Vegetables',
    'Fruits',
    'Grains',
    'Dairy',
    'Livestock',
    'Tools',
  ];

  static const _units = [
    'per kg',
    'per piece',
    'per bundle',
    'per sack',
    'per liter',
    'per dozen',
  ];

  String? _agriRelevanceError(String text) {
    if (looksNonAgricultural(text)) {
      return "This doesn't look like an agricultural product. AgriMarket "
          "only lists farm produce, livestock, and related goods.";
    }
    return null;
  }

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _deliveryFeeController = TextEditingController();
  final _stockController = TextEditingController();

  String _region = '';
  String _province = '';
  String _city = '';
  String _barangay = '';

  String _category = _categories.first;
  String _unit = _units.first;
  File? _imageFile;
  bool _isSaving = false;
  bool _listed = false;
  bool _isLoadingLocation = true;
  bool get _isLivestock => _category == 'Livestock';
  bool get _hasLocation =>
      _region.isNotEmpty &&
      _province.isNotEmpty &&
      _city.isNotEmpty &&
      _barangay.isNotEmpty;

  String get _locationSummary {
    final parts = [
      _region,
      _province,
      _city,
      _barangay,
    ].where((s) => s.isNotEmpty);
    return parts.isEmpty
        ? 'Tap to select Region, Province, City, Barangay'
        : parts.join(', ');
  }

  String get _composedFarmLocation {
    final parts = [_barangay, _city, _province].where((s) => s.isNotEmpty);
    return parts.join(', ');
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userStream;

  @override
  void initState() {
    super.initState();
    _prefillLocationFromProfile();
    final currentUser = FirebaseAuth.instance.currentUser;
    _userStream = currentUser == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots();
  }

  Future<void> _prefillLocationFromProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingLocation = false);
      return;
    }

    try {
      final addressesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      var snap = await addressesRef
          .where('isDefault', isEqualTo: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        snap = await addressesRef
            .orderBy('createdAt', descending: true)
            .limit(1)
            .get();
      }

      if (snap.docs.isNotEmpty && mounted) {
        final data = snap.docs.first.data();
        setState(() {
          _region = data['region'] as String? ?? '';
          _province = data['province'] as String? ?? '';
          _city = data['city'] as String? ?? '';
          _barangay = data['barangay'] as String? ?? '';
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _deliveryFeeController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<ImageSource?> _chooseImageSource() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(
              'Add Photo',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _seedColor,
              ),
            ),
            SizedBox(height: 16),
            _imageSourceTile(
              icon: Icons.camera_alt_outlined,
              label: 'Take a Photo',
              source: ImageSource.camera,
            ),
            SizedBox(height: 10),
            _imageSourceTile(
              icon: Icons.photo_library_outlined,
              label: 'Choose from Gallery',
              source: ImageSource.gallery,
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageSourceTile({
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.pop(context, source),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _seedColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: _seedColor),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _editLocation() async {
    final result = await showPsgcLocationPicker(
      context,
      seedColor: _seedColor,
      bgColor: _bgColor,
      initialRegion: _region,
      initialProvince: _province,
      initialCity: _city,
      initialBarangay: _barangay,
    );

    if (result != null) {
      setState(() {
        _region = result['region'] ?? '';
        _province = result['province'] ?? '';
        _city = result['city'] ?? '';
        _barangay = result['barangay'] ?? '';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please add a photo of your product')),
      );
      return;
    }
    if (!_hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select your farm's location")),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final uploadResult = await uploadImageToCloudinary(_imageFile!);
      if (uploadResult == null) {
        throw Exception('Image upload failed. Please try again.');
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final farmerName =
          userDoc.data()?['name'] as String? ?? user.displayName ?? 'Farmer';

      final product = Product(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.replaceAll(',', '').trim()),
        deliveryFeePerUnit: _isLivestock
            ? 0
            : double.parse(
                _deliveryFeeController.text.replaceAll(',', '').trim(),
              ),
        unit: _unit,
        category: _category,
        stock: int.parse(_stockController.text.trim()),
        location: _composedFarmLocation,
        image: uploadResult.secureUrl,
        imagePublicId: uploadResult.publicId,
        icon: Product.iconForCategory(_category),
        farmerId: user.uid,
        farmerName: farmerName,
      );

      final docRef = await FirebaseFirestore.instance
          .collection('products')
          .add(product.toFirestore());

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isSaving = false;
        _listed = true; // button morphs into a green check circle
      });

      // Let the button finish morphing into a check before the card appears.
      await Future<void>.delayed(const Duration(milliseconds: 650));
      if (!mounted) return;

      final productName = _nameController.text.trim();
      final navigator = Navigator.of(context);
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierLabel: 'Product listed',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (dialogContext, animation, secondaryAnimation) =>
            PopScope(
              canPop: false,
              child: _ProductListedDialog(
                productName: productName,
                seedColor: _seedColor,
                onDone: () {
                  Navigator.of(dialogContext).pop(); // close the card
                  // Leave this screen and send the new product's id back so
                  // the list can slide that card in.
                  navigator.pop(docRef.id);
                },
              ),
            ),
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          );
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.85, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Something went wrong: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _userStream,
      builder: (context, userSnapshot) {
        final hasConfirmedData =
            userSnapshot.connectionState != ConnectionState.waiting &&
            userSnapshot.data != null;
        final isSeller = !hasConfirmedData
            ? true
            : userSnapshot.data!.data()?['isSeller'] == true;
        if (!isSeller) {
          return _NotApprovedYetScaffold(
            seedColor: _seedColor,
            bgColor: _bgColor,
          );
        }
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 5,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(decoration: BoxDecoration(color: _seedColor)),
          ),
          leading: Center(
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(19),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_back, color: _bgColor, size: 20),
              ),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'List a Product',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Share what you\'re growing with buyers',
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(18, 20, 18, 32),
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _seedColor.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _seedColor.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add_a_photo_outlined,
                                size: 24,
                                color: _seedColor.withValues(alpha: 0.6),
                              ),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Add a product photo',
                              style: GoogleFonts.inter(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(_imageFile!, fit: BoxFit.cover),
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _accentColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: 24),
              _FieldLabel('Product name'),
              _fieldShadow(
                child: TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('e.g. Fresh Tomatoes'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Enter a product name';
                    return _agriRelevanceError(text);
                  },
                ),
              ),
              SizedBox(height: 16),
              _FieldLabel('Description'),
              _fieldShadow(
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _inputDecoration('Describe your product'),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Enter a description';
                    return _agriRelevanceError(text);
                  },
                ),
              ),
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldColumn(
                      label: 'Price (₱)',
                      child: _fieldShadow(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          decoration: _inputDecoration('0.00'),
                          validator: (v) {
                            final raw = (v ?? '').replaceAll(',', '').trim();
                            final n = double.tryParse(raw);
                            if (n == null || n <= 0) return 'Invalid price';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FieldColumn(
                      label: 'Unit',
                      child: _fieldShadow(
                        child: DropdownButtonFormField<String>(
                          initialValue: _unit,
                          decoration: _inputDecoration(null),
                          items: _units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _unit = v ?? _unit),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              if (_isLivestock)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 18,
                        color: _seedColor,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Livestock is pickup only — no delivery fee and no rider needed.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: _seedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                _FieldColumn(
                  label: 'Delivery fee per unit (₱)',
                  child: _fieldShadow(
                    child: TextFormField(
                      controller: _deliveryFeeController,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [_ThousandsSeparatorInputFormatter()],
                      decoration: _inputDecoration('e.g. 30'),
                      validator: (v) {
                        final raw = (v ?? '').replaceAll(',', '').trim();
                        final n = double.tryParse(raw);
                        if (n == null || n < 0) return 'Invalid amount';
                        return null;
                      },
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'Charged $_unit ordered — covers the rider\'s payout for this item.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _FieldColumn(
                      label: 'Stock available',
                      child: _fieldShadow(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: _inputDecoration('e.g. 50'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 0) return 'Invalid amount';
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: _FieldColumn(
                      label: 'Category',
                      child: _fieldShadow(
                        child: DropdownButtonFormField<String>(
                          initialValue: _category,
                          decoration: _inputDecoration(null),
                          items: _categories
                              .map(
                                (c) =>
                                    DropdownMenuItem(value: c, child: Text(c)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _category = v ?? _category;
                            if (_isLivestock) _deliveryFeeController.clear();
                          }),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _FieldLabel('Farm location'),
              _fieldShadow(
                child: InkWell(
                  onTap: _isLoadingLocation ? null : _editLocation,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _isLoadingLocation
                                ? 'Loading your saved location…'
                                : _locationSummary,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: _hasLocation
                                  ? Colors.black87
                                  : Colors.grey[500],
                            ),
                          ),
                        ),
                        if (_isLoadingLocation)
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _seedColor,
                            ),
                          )
                        else
                          Icon(Icons.chevron_right, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                ),
              ),
              if (_hasLocation && !_isLoadingLocation) ...[
                SizedBox(height: 4),
                Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Text(
                    'From your saved address · tap to change for this listing',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
              ],
              SizedBox(height: 28),
              _ListProductButton(
                loading: _isSaving,
                done: _listed,
                seedColor: _seedColor,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldShadow({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(fontSize: 14, color: Colors.grey[500]),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _seedColor, width: 1.5),
      ),
    );
  }
}

class _NotApprovedYetScaffold extends StatelessWidget {
  const _NotApprovedYetScaffold({
    required this.seedColor,
    required this.bgColor,
  });

  final Color seedColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: seedColor,
        foregroundColor: bgColor,
        elevation: 0,
        title: Text(
          'List a Product',
          style: GoogleFonts.fraunces(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: bgColor,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: seedColor.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.hourglass_top_rounded,
                  size: 32,
                  color: seedColor.withValues(alpha: 0.7),
                ),
              ),
              SizedBox(height: 16),
              Text(
                'You need an approved seller account',
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: seedColor,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Check your Profile tab for your application status before '
                'listing a product.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: seedColor),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Go Back',
                  style: GoogleFonts.inter(
                    color: seedColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    String cleaned = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');

    final firstDot = cleaned.indexOf('.');
    if (firstDot != -1) {
      cleaned =
          cleaned.substring(0, firstDot + 1) +
          cleaned.substring(firstDot + 1).replaceAll('.', '');
    }

    String wholePart = cleaned;
    String? decimalPart;
    final dotIndex = cleaned.indexOf('.');
    if (dotIndex != -1) {
      wholePart = cleaned.substring(0, dotIndex);
      decimalPart = cleaned.substring(dotIndex + 1);
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }
    }

    wholePart = wholePart.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final buffer = StringBuffer();
    for (int i = 0; i < wholePart.length; i++) {
      final digitsLeft = wholePart.length - i;
      buffer.write(wholePart[i]);
      if (digitsLeft > 1 && digitsLeft % 3 == 1) buffer.write(',');
    }
    String formattedWhole = buffer.toString();
    if (formattedWhole.isEmpty && dotIndex != -1) formattedWhole = '0';

    final formatted = decimalPart == null
        ? formattedWhole
        : '$formattedWhole.$decimalPart';

    final distanceFromEnd = newValue.text.length - newValue.selection.end;
    final newOffset = (formatted.length - distanceFromEnd).clamp(
      0,
      formatted.length,
    );

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _FieldColumn extends StatelessWidget {
  const _FieldColumn({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_FieldLabel(label), child],
    );
  }
}


/// "List Product" button that morphs: label -> spinner circle -> check circle.
class _ListProductButton extends StatefulWidget {
  const _ListProductButton({
    required this.loading,
    required this.done,
    required this.seedColor,
    required this.onPressed,
  });

  final bool loading;
  final bool done;
  final Color seedColor;
  final VoidCallback onPressed;

  @override
  State<_ListProductButton> createState() => _ListProductButtonState();
}

class _ListProductButtonState extends State<_ListProductButton> {
  static const Color _successColor = Color(0xFF2E7D4F);
  static const double _height = 52;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.loading || widget.done;
    final color = widget.done ? _successColor : widget.seedColor;

    final Widget content;
    if (widget.done) {
      content = const _DrawnCheck(key: ValueKey('done'));
    } else if (widget.loading) {
      content = const SizedBox(
        key: ValueKey('loading'),
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
    } else {
      content = Text(
        'List Product',
        key: const ValueKey('idle'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.white,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth =
            constraints.hasBoundedWidth ? constraints.maxWidth : 220.0;
        return Center(
          child: Listener(
            onPointerDown: (_) {
              if (!collapsed) _setPressed(true);
            },
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: AnimatedScale(
              scale: _pressed ? 0.97 : 1,
              duration: const Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 340),
                curve: Curves.easeInOutCubic,
                width: collapsed ? _height : fullWidth,
                height: _height,
                // Fill and shadow are drawn as ONE shape, so there is no
                // outline or seam around the button.
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(
                    collapsed ? _height / 2 : 14,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: collapsed ? 0.0 : 0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    collapsed ? _height / 2 : 14,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: collapsed ? null : widget.onPressed,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// White check mark that traces itself when it first appears.
class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => CustomPaint(
        size: const Size(28, 28),
        painter: _ButtonCheckPainter(progress: value),
      ),
    );
  }
}

class _ButtonCheckPainter extends CustomPainter {
  _ButtonCheckPainter({required this.progress});
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.14, size.height * 0.54)
      ..lineTo(size.width * 0.40, size.height * 0.78)
      ..lineTo(size.width * 0.86, size.height * 0.26);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_ButtonCheckPainter old) => old.progress != progress;
}


/// Success card: pop-in circle, check that draws itself, particle burst,
/// then the text and button fade up one after another.
class _ProductListedDialog extends StatefulWidget {
  const _ProductListedDialog({
    required this.productName,
    required this.seedColor,
    required this.onDone,
  });

  final String productName;
  final Color seedColor;
  final VoidCallback onDone;

  @override
  State<_ProductListedDialog> createState() => _ProductListedDialogState();
}

class _ProductListedDialogState extends State<_ProductListedDialog>
    with SingleTickerProviderStateMixin {
  static const Color _successColor = Color(0xFF2E7D4F);
  static const Color _accentColor = Color(0xFFE0A63A);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _t(double begin, double end, [Curve curve = Curves.easeOut]) {
    final raw = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  Widget _fadeUp(double t, Widget child) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pop = _t(0.0, 0.45, Curves.elasticOut);
            final check = _t(0.22, 0.55, Curves.easeOutCubic);
            final burst = _t(0.18, 1.0, Curves.easeOutCubic);
            final title = _t(0.40, 0.70);
            final body = _t(0.50, 0.80);
            final button = _t(0.62, 0.95);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(124, 124),
                        painter: _BurstPainter(
                          progress: burst,
                          colors: [_accentColor, _successColor, seed],
                        ),
                      ),
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: _successColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _successColor.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(progress: check),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _fadeUp(
                  title,
                  Text(
                    'Product Listed!',
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: seed,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _fadeUp(
                  body,
                  Text(
                    '${widget.productName} has been listed successfully.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _fadeUp(
                  button,
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: seed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Done',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Draws a white check mark that traces itself as [progress] goes 0 -> 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.74, h * 0.36);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Expanding ring plus small dots that fly outward and fade.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors[1].withValues(alpha: (1 - progress) * 0.35);
    canvas.drawCircle(center, 44 + 14 * progress, ring);

    const count = 14;
    final opacity = (1 - progress * progress).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i + (i.isEven ? 0.0 : 0.18);
      final distance = 40 + (i.isEven ? 14.0 : 8.0) * progress;
      final radius = (i.isEven ? 3.6 : 2.6) * (1 - 0.5 * progress);
      final dot = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
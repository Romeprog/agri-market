import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/psgc_service.dart';

class AddressesScreen extends StatelessWidget {
  const AddressesScreen({super.key, this.selectMode = false});

  final bool selectMode;

  static const _seedColor = Color(0xFF1F3D2B);
  static const _accentColor = Color(0xFFE0A63A);
  static const _bgColor = Color(0xFFEFF1E4);

  CollectionReference<Map<String, dynamic>>? _addressesRef() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('addresses');
  }

  Future<void> _openAddressForm(
    BuildContext context, {
    String? docId,
    Map<String, dynamic>? existing,
  }) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => _AddressFormScreen(
          docId: docId,
          existing: existing,
          selectMode: selectMode,
        ),
      ),
    );
    if (selectMode && result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _deleteAddress(BuildContext context, String docId) async {
    final ref = _addressesRef();
    if (ref == null) return;
    await ref.doc(docId).delete();
  }

  String _composeAddressLine(Map<String, dynamic> data) {
    final parts = [
      data['street'],
      data['barangay'],
      data['city'],
      data['province'],
      data['region'],
    ].whereType<String>().where((s) => s.trim().isNotEmpty);
    final line = parts.join(', ');
    final postal = data['postalCode'] as String? ?? '';
    return postal.isEmpty ? line : '$line $postal';
  }

  PreferredSizeWidget _appBar(
    BuildContext context, {
    required String title,
    required String subtitle,
  }) {
    return PreferredSize(
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back,
                color: _bgColor,
                size: 20,
              ),
            ),
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.fraunces(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _bgColor,
              ),
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _bgColor.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ref = _addressesRef();

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: _appBar(
        context,
        title: 'My Addresses',
        subtitle: 'Manage your delivery locations',
      ),
      floatingActionButton: InkWell(
        onTap: () => _openAddressForm(context),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _seedColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _seedColor.withValues(alpha: 0.32),
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
      body: ref == null
          ? Center(child: Text('Please sign in.', style: GoogleFonts.inter()))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: ref.orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _seedColor),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
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
                              Icons.location_off_outlined,
                              size: 38,
                              color: _seedColor.withValues(alpha: 0.55),
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No address yet',
                            style: GoogleFonts.fraunces(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _seedColor,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tap the + button to add a new address',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 90),
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final isDefault = data['isDefault'] as bool? ?? false;
                    final label = data['label'] as String? ?? 'Home';

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
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => selectMode
                            ? Navigator.pop(context, {'id': doc.id, ...data})
                            : _openAddressForm(
                                context,
                                docId: doc.id,
                                existing: data,
                              ),
                        child: Padding(
                          padding: EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: _seedColor.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on_outlined,
                                  color: _seedColor,
                                  size: 18,
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _seedColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            label,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: _seedColor,
                                            ),
                                          ),
                                        ),
                                        if (isDefault) ...[
                                          SizedBox(width: 6),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _accentColor.withValues(
                                                alpha: 0.18,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Default',
                                              style: GoogleFonts.inter(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF8A5A12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      data['fullName'] as String? ?? 'Address',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if ((data['phoneNumber'] as String? ?? '')
                                        .isNotEmpty)
                                      Text(
                                        data['phoneNumber'] as String,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    SizedBox(height: 2),
                                    Text(
                                      _composeAddressLine(data),
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _deleteAddress(context, doc.id),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class _AddressFormScreen extends StatefulWidget {
  const _AddressFormScreen({
    this.docId,
    this.existing,
    this.selectMode = false,
  });

  final String? docId;
  final Map<String, dynamic>? existing;
  final bool selectMode;

  @override
  State<_AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<_AddressFormScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  final _quickFillController = TextEditingController();

  late final _fullNameController = TextEditingController(
    text: widget.existing?['fullName'] as String? ?? '',
  );
  late final _phoneController = TextEditingController(
    text: widget.existing?['phoneNumber'] as String? ?? '',
  );
  late final _postalController = TextEditingController(
    text: widget.existing?['postalCode'] as String? ?? '',
  );
  late final _streetController = TextEditingController(
    text: widget.existing?['street'] as String? ?? '',
  );

  late String _region = widget.existing?['region'] as String? ?? '';
  late String _province = widget.existing?['province'] as String? ?? '';
  late String _city = widget.existing?['city'] as String? ?? '';
  late String _barangay = widget.existing?['barangay'] as String? ?? '';

  late bool _isDefault = widget.existing?['isDefault'] as bool? ?? false;
  late String _label = widget.existing?['label'] as String? ?? 'Home';

  bool _isSaving = false;

  @override
  void dispose() {
    _quickFillController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _postalController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _fullNameController.text.trim().isNotEmpty &&
      _phoneController.text.trim().isNotEmpty &&
      _region.isNotEmpty &&
      _province.isNotEmpty &&
      _city.isNotEmpty &&
      _barangay.isNotEmpty &&
      _streetController.text.trim().isNotEmpty;

  String get _locationSummary {
    final parts = [
      _region,
      _province,
      _city,
      _barangay,
    ].where((s) => s.isNotEmpty);
    return parts.isEmpty
        ? 'Region, Province, City, Barangay'
        : parts.join(', ');
  }

  Future<void> _editLocation() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        seedColor: _seedColor,
        bgColor: _bgColor,
        initialRegion: _region,
        initialProvince: _province,
        initialCity: _city,
        initialBarangay: _barangay,
      ),
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

  Future<void> _save() async {
    if (!_isValid) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSaving = true);

    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('addresses');

      final data = {
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'region': _region,
        'province': _province,
        'city': _city,
        'barangay': _barangay,
        'postalCode': _postalController.text.trim(),
        'street': _streetController.text.trim(),
        'isDefault': _isDefault,
        'label': _label,
        'createdAt': FieldValue.serverTimestamp(),
      };

      String savedId;
      if (widget.docId == null) {
        final docRef = await ref.add(data).timeout(Duration(seconds: 10));
        savedId = docRef.id;
      } else {
        savedId = widget.docId!;
        await ref
            .doc(savedId)
            .set(data, SetOptions(merge: true))
            .timeout(Duration(seconds: 10));
      }

      if (!mounted) return;
      Navigator.pop(
        context,
        widget.selectMode ? {'id': savedId, ...data} : null,
      );
    } catch (e) {
      debugPrint('Address save failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save address. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _plainDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14.5),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 14,
            decoration: BoxDecoration(
              color: _seedColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.fraunces(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _seedColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 0,
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
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: _bgColor,
                  size: 16,
                ),
              ),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.docId == null ? 'New Address' : 'Edit Address',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                widget.docId == null
                    ? 'Add a new delivery address'
                    : 'Update your delivery details',
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
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _sectionLabel('Address'),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
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
                        _plainField(
                          controller: _fullNameController,
                          hint: 'Full Name',
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _plainField(
                          controller: _phoneController,
                          hint: 'Phone Number',
                          keyboardType: TextInputType.phone,
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        InkWell(
                          onTap: _editLocation,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _locationSummary,
                                    style: GoogleFonts.inter(
                                      fontSize: 14.5,
                                      color: _region.isEmpty
                                          ? Colors.grey[400]
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _plainField(
                          controller: _postalController,
                          hint: 'Postal Code',
                          keyboardType: TextInputType.number,
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        _plainField(
                          controller: _streetController,
                          hint: 'Street Name, Building, House No.',
                          bottomPadding: 14,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  _sectionLabel('Preferences'),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          activeThumbColor: _seedColor,
                          title: Text(
                            'Set as Default Address',
                            style: GoogleFonts.inter(fontSize: 14.5),
                          ),
                          value: _isDefault,
                          onChanged: (v) => setState(() => _isDefault = v),
                        ),
                        Divider(height: 1, color: Colors.grey.shade100),
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              Text(
                                'Label As:',
                                style: GoogleFonts.inter(fontSize: 14.5),
                              ),
                              Spacer(),
                              _labelChip('Work'),
                              SizedBox(width: 8),
                              _labelChip('Home'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: (_isValid && !_isSaving)
                      ? [
                          BoxShadow(
                            color: _seedColor.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isValid && !_isSaving) ? _save : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _seedColor,
                      disabledBackgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plainField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    double bottomPadding = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(top: 14, bottom: bottomPadding),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14.5),
        decoration: _plainDecoration(hint),
      ),
    );
  }

  Widget _labelChip(String label) {
    final selected = _label == label;
    return InkWell(
      onTap: () => setState(() => _label = label),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _seedColor : _seedColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _seedColor,
          ),
        ),
      ),
    );
  }
}

class _LocationPickerSheet extends StatefulWidget {
  const _LocationPickerSheet({
    required this.seedColor,
    required this.bgColor,
    required this.initialRegion,
    required this.initialProvince,
    required this.initialCity,
    required this.initialBarangay,
  });

  final Color seedColor;
  final Color bgColor;
  final String initialRegion;
  final String initialProvince;
  final String initialCity;
  final String initialBarangay;

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  bool _bootstrapping = true;
  String? _bootstrapError;

  List<PsgcItem> _regions = [];
  List<PsgcItem> _provinces = [];
  List<PsgcItem> _cities = [];
  List<PsgcItem> _barangays = [];

  PsgcItem? _selectedRegion;
  PsgcItem? _selectedProvince;
  PsgcItem? _selectedCity;
  PsgcItem? _selectedBarangay;

  bool _loadingProvinces = false;
  bool _loadingCities = false;
  bool _loadingBarangays = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  PsgcItem? _findByName(List<PsgcItem> items, String name) {
    final needle = name.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final item in items) {
      if (item.name.trim().toLowerCase() == needle) return item;
    }
    return null;
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _bootstrapError = null;
    });
    try {
      final regions = await PsgcService.fetchRegions();
      if (!mounted) return;
      setState(() => _regions = regions);

      final region = _findByName(regions, widget.initialRegion);
      if (region == null) return;
      setState(() => _selectedRegion = region);

      final provinces = await PsgcService.fetchProvinces(region.code);
      if (!mounted) return;
      setState(() => _provinces = provinces);

      final province = _findByName(provinces, widget.initialProvince);
      if (province == null) return;
      setState(() => _selectedProvince = province);

      final cities = await PsgcService.fetchCitiesMunicipalities(province.code);
      if (!mounted) return;
      setState(() => _cities = cities);

      final city = _findByName(cities, widget.initialCity);
      if (city == null) return;
      setState(() => _selectedCity = city);

      final barangays = await PsgcService.fetchBarangays(city.code);
      if (!mounted) return;
      setState(() => _barangays = barangays);

      final barangay = _findByName(barangays, widget.initialBarangay);
      if (barangay != null) {
        setState(() => _selectedBarangay = barangay);
      }
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _bootstrapError =
            "Couldn't load locations. Check your connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _bootstrapping = false);
    }
  }

  Future<void> _onSelectRegion() async {
    final region = await _showPicker('Select Region', _regions);
    if (region == null || region.code == _selectedRegion?.code) return;

    setState(() {
      _selectedRegion = region;
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _provinces = [];
      _cities = [];
      _barangays = [];
      _loadingProvinces = true;
    });
    try {
      final provinces = await PsgcService.fetchProvinces(region.code);
      if (!mounted) return;
      setState(() => _provinces = provinces);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingProvinces = false);
    }
  }

  Future<void> _onSelectProvince() async {
    if (_selectedRegion == null) return;
    final province = await _showPicker('Select Province', _provinces);
    if (province == null || province.code == _selectedProvince?.code) return;

    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cities = [];
      _barangays = [];
      _loadingCities = true;
    });
    try {
      final cities = await PsgcService.fetchCitiesMunicipalities(province.code);
      if (!mounted) return;
      setState(() => _cities = cities);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingCities = false);
    }
  }

  Future<void> _onSelectCity() async {
    if (_selectedProvince == null) return;
    final city = await _showPicker('Select City / Municipality', _cities);
    if (city == null || city.code == _selectedCity?.code) return;

    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangays = [];
      _loadingBarangays = true;
    });
    try {
      final barangays = await PsgcService.fetchBarangays(city.code);
      if (!mounted) return;
      setState(() => _barangays = barangays);
    } catch (_) {
      if (mounted) _showLoadError();
    } finally {
      if (mounted) setState(() => _loadingBarangays = false);
    }
  }

  Future<void> _onSelectBarangay() async {
    if (_selectedCity == null) return;
    final barangay = await _showPicker('Select Barangay', _barangays);
    if (barangay == null) return;
    setState(() => _selectedBarangay = barangay);
  }

  void _showLoadError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Couldn't load that list. Please try again.")),
    );
  }

  Future<PsgcItem?> _showPicker(String title, List<PsgcItem> items) {
    return showModalBottomSheet<PsgcItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PsgcPickerSheet(
        title: title,
        items: items,
        seedColor: widget.seedColor,
        bgColor: widget.bgColor,
      ),
    );
  }

  bool get _canConfirm =>
      _selectedRegion != null &&
      _selectedProvince != null &&
      _selectedCity != null &&
      _selectedBarangay != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: SafeArea(
        top: false,
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
              'Location',
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.seedColor,
              ),
            ),
            SizedBox(height: 16),
            if (_bootstrapping)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: widget.seedColor),
                ),
              )
            else if (_bootstrapError != null) ...[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _bootstrapError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.black54),
                ),
              ),
              SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _bootstrap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.seedColor,
                    side: BorderSide(color: widget.seedColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else ...[
              _locationField(
                label: 'Region',
                value: _selectedRegion?.name,
                enabled: _regions.isNotEmpty,
                loading: false,
                onTap: _onSelectRegion,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'Province',
                value: _selectedProvince?.name,
                enabled: _selectedRegion != null,
                loading: _loadingProvinces,
                onTap: _onSelectProvince,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'City / Municipality',
                value: _selectedCity?.name,
                enabled: _selectedProvince != null,
                loading: _loadingCities,
                onTap: _onSelectCity,
              ),
              SizedBox(height: 12),
              _locationField(
                label: 'Barangay',
                value: _selectedBarangay?.name,
                enabled: _selectedCity != null,
                loading: _loadingBarangays,
                onTap: _onSelectBarangay,
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _canConfirm
                      ? () => Navigator.pop(context, {
                          'region': _selectedRegion!.name,
                          'province': _selectedProvince!.name,
                          'city': _selectedCity!.name,
                          'barangay': _selectedBarangay!.name,
                        })
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.seedColor,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Confirm',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationField({
    required String label,
    required String? value,
    required bool enabled,
    required bool loading,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled && !loading ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: widget.seedColor.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: Colors.black54,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    value ?? 'Select $label',
                    style: GoogleFonts.inter(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: value != null ? Colors.black87 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: widget.seedColor,
                ),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? widget.seedColor : Colors.black26,
              ),
          ],
        ),
      ),
    );
  }
}

class _PsgcPickerSheet extends StatefulWidget {
  const _PsgcPickerSheet({
    required this.title,
    required this.items,
    required this.seedColor,
    required this.bgColor,
  });

  final String title;
  final List<PsgcItem> items;
  final Color seedColor;
  final Color bgColor;

  @override
  State<_PsgcPickerSheet> createState() => _PsgcPickerSheetState();
}

class _PsgcPickerSheetState extends State<_PsgcPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.items
        : widget.items
              .where((i) => i.name.toLowerCase().contains(_query))
              .toList();

    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: Container(
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
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
              widget.title,
              style: GoogleFonts.fraunces(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: widget.seedColor,
              ),
            ),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
                style: GoogleFonts.inter(fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: widget.items.isEmpty
                  ? Center(
                      child: Text(
                        'No options available.',
                        style: GoogleFonts.inter(color: Colors.black54),
                      ),
                    )
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matches found.',
                        style: GoogleFonts.inter(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: Colors.black12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return ListTile(
                          title: Text(
                            item.name,
                            style: GoogleFonts.inter(fontSize: 14.5),
                          ),
                          onTap: () => Navigator.pop(context, item),
                        );
                      },
                    ),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
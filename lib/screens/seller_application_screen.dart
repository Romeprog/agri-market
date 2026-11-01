import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/seller_application_service.dart';
import '../widgets/morphing_submit_button.dart';
import '../widgets/psgc_location_picker.dart';
import '../widgets/success_dialog.dart';

class SellerApplicationScreen extends StatefulWidget {
  const SellerApplicationScreen({super.key});

  @override
  State<SellerApplicationScreen> createState() =>
      _SellerApplicationScreenState();
}

class _SellerApplicationScreenState extends State<SellerApplicationScreen> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  final _formKey = GlobalKey<FormState>();
  final _farmNameController = TextEditingController();
  final _farmLocationController = TextEditingController();
  final _streetController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _farmSizeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sampleProductsController = TextEditingController();

  Map<String, String>? _location;
  String? _sellerType;
  String? _experience;
  final Set<String> _selectedCategories = {};
  final Set<String> _selectedPractices = {};
  final Set<String> _selectedFulfillment = {};
  bool _agreed = false;
  bool _attempted = false;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmLocationController.dispose();
    _streetController.dispose();
    _contactNumberController.dispose();
    _farmSizeController.dispose();
    _descriptionController.dispose();
    _sampleProductsController.dispose();
    super.dispose();
  }

  bool get _choicesValid =>
      _sellerType != null &&
      _experience != null &&
      _selectedCategories.isNotEmpty &&
      _selectedFulfillment.isNotEmpty &&
      _agreed;

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  static String _cleanPhone(String v) => v.replaceAll(RegExp(r'[\s\-()]'), '');

  String? _validatePhone(String? v) {
    final raw = _cleanPhone(v ?? '');
    if (raw.isEmpty) return 'Required';
    if (!RegExp(r'^(09|\+639)\d{9}$').hasMatch(raw)) {
      return 'Enter a valid mobile number, e.g. 09XX XXX XXXX';
    }
    return null;
  }

  String? _validateDescription(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'Required';
    if (text.length < 20) return 'Tell us a bit more (at least 20 characters)';
    return null;
  }

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final result = await showPsgcLocationPicker(
      context,
      seedColor: _seedColor,
      bgColor: _bgColor,
      initialRegion: _location?['region'] ?? '',
      initialProvince: _location?['province'] ?? '',
      initialCity: _location?['city'] ?? '',
      initialBarangay: _location?['barangay'] ?? '',
    );
    if (result == null || !mounted) return;
    setState(() {
      _location = result;
      _farmLocationController.text =
          '${result['barangay']}, ${result['city']}, ${result['province']}';
    });
  }

  Future<void> _submit() async {
    setState(() => _attempted = true);
    final formOk = _formKey.currentState!.validate();
    if (!formOk || !_choicesValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please complete the highlighted fields.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      List<String> ordered(List<String> options, Set<String> chosen) =>
          options.where(chosen.contains).toList();

      await SellerApplicationService.submitApplication(
        farmName: _farmNameController.text.trim(),
        farmLocation: [
          if (_streetController.text.trim().isNotEmpty)
            _streetController.text.trim(),
          _farmLocationController.text.trim(),
        ].join(', '),
        contactNumber: _cleanPhone(_contactNumberController.text),
        farmDescription: _descriptionController.text.trim(),
        productCategories: ordered(
          SellerApplicationService.categories,
          _selectedCategories,
        ),
        sellerType: _sellerType!,
        yearsOfExperience: _experience!,
        fulfillmentOptions: ordered(
          SellerApplicationService.fulfillmentOptions,
          _selectedFulfillment,
        ),
        agreedToTerms: _agreed,
        farmSize: _farmSizeController.text.trim(),
        farmingPractices: ordered(
          SellerApplicationService.farmingPractices,
          _selectedPractices,
        ),
        sampleProducts: _sampleProductsController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _done = true;
      });

      await Future<void>.delayed(Duration(milliseconds: 650));
      if (!mounted) return;

      await showSuccessDialog(
        context: context,
        title: 'Application Submitted!',
        message:
            'Your seller application has been submitted. '
            'We\'ll review it and get back to you soon.',
        seedColor: _seedColor,
        onDone: () {
          final navigator = Navigator.of(context);
          navigator.pop(); 
          navigator.pop(); 
        },
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Could not submit application: $e')),
      );
      setState(() => _submitting = false);
    }
  }

  InputDecoration _decoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
      hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
      filled: true,
      fillColor: _bgColor.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _seedColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent.shade100),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.redAccent, width: 1.6),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _seedColor.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(icon, title, subtitle),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _seedColor.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: _seedColor, size: 19),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.fraunces(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _seedColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _groupLabel(String text, {String? hint}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          text: text,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: Colors.grey[850],
          ),
          children: [
            if (hint != null)
              TextSpan(
                text: '  $hint',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w400,
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _choiceChips({
    required List<String> options,
    required bool Function(String) isSelected,
    required void Function(String) onTap,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final selected = isSelected(option);
        return FilterChip(
          label: Text(option),
          selected: selected,
          onSelected: (_) => onTap(option),
          showCheckmark: false,
          avatar: selected
              ? Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
          labelStyle: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : _seedColor,
          ),
          selectedColor: _seedColor,
          backgroundColor: _bgColor.withValues(alpha: 0.55),
          elevation: 0,
          pressElevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(
            color: selected ? _seedColor : _seedColor.withValues(alpha: 0.22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(100),
          ),
        );
      }).toList(),
    );
  }

  Widget _errorText(String message, {required bool show}) {
    if (!show) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 8, left: 4),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: Colors.red[700]),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red[700]),
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
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: _bgColor),
          titleSpacing: 0,
          flexibleSpace: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: _seedColor,
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
            ),
          ),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Become a Seller',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Apply to start selling on AgriMarket',
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
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _seedColor.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.eco_outlined, color: _seedColor, size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tell us about your farm or business. Approved '
                              'sellers can list products for sale on '
                              'AgriMarket.',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: Colors.grey[800],
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 18),
                    _sectionCard(
                      icon: Icons.agriculture_outlined,
                      title: 'About your farm',
                      subtitle:
                          'Basic details we\'ll use to review your '
                          'application.',
                      children: [
                        TextFormField(
                          controller: _farmNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(100),
                          ],
                          decoration: _decoration(
                            'Farm / Business Name',
                            'e.g. Dela Cruz Family Farm',
                          ),
                          validator: _required,
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _farmLocationController,
                          readOnly: true,
                          showCursor: false,
                          onTap: _pickLocation,
                          decoration:
                              _decoration(
                                'Farm Location',
                                'Tap to select province, city and barangay',
                              ).copyWith(
                                suffixIcon: Icon(
                                  Icons.location_on_outlined,
                                  color: _seedColor,
                                ),
                              ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Select your farm location'
                              : null,
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _streetController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(60),
                          ],
                          decoration: _decoration(
                            'Street / Purok / Sitio (optional)',
                            'e.g. Purok 3, near the barangay hall',
                          ),
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _contactNumberController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\s\-()]'),
                            ),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          decoration: _decoration(
                            'Contact Number',
                            '09XX XXX XXXX',
                          ),
                          validator: _validatePhone,
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _farmSizeController,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(60),
                          ],
                          decoration: _decoration(
                            'Farm Size (optional)',
                            'e.g. 2 hectares, 500 sq m',
                          ),
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 1000,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'About your farm',
                            'What do you grow or produce? How long have '
                                'you been farming?',
                          ),
                          validator: _validateDescription,
                        ),
                      ],
                    ),
                    _sectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Your selling profile',
                      subtitle: 'Help us understand who you are as a seller.',
                      children: [
                        _groupLabel('I am a...'),
                        _choiceChips(
                          options: SellerApplicationService.sellerTypes,
                          isSelected: (o) => _sellerType == o,
                          onTap: (o) => setState(() => _sellerType = o),
                        ),
                        _errorText(
                          'Please choose one.',
                          show: _attempted && _sellerType == null,
                        ),
                        SizedBox(height: 20),
                        _groupLabel('Years of experience'),
                        _choiceChips(
                          options: SellerApplicationService.experienceLevels,
                          isSelected: (o) => _experience == o,
                          onTap: (o) => setState(() => _experience = o),
                        ),
                        _errorText(
                          'Please choose one.',
                          show: _attempted && _experience == null,
                        ),
                        SizedBox(height: 20),
                        _groupLabel(
                          'Farming practices',
                          hint: 'Optional, pick any',
                        ),
                        _choiceChips(
                          options: SellerApplicationService.farmingPractices,
                          isSelected: _selectedPractices.contains,
                          onTap: (o) => setState(() {
                            if (!_selectedPractices.remove(o)) {
                              _selectedPractices.add(o);
                            }
                          }),
                        ),
                      ],
                    ),
                    _sectionCard(
                      icon: Icons.grid_view_rounded,
                      title: 'What you\'ll sell',
                      subtitle:
                          'These match the categories buyers browse in '
                          'the app.',
                      children: [
                        _groupLabel('Product categories'),
                        _choiceChips(
                          options: SellerApplicationService.categories,
                          isSelected: _selectedCategories.contains,
                          onTap: (o) => setState(() {
                            if (!_selectedCategories.remove(o)) {
                              _selectedCategories.add(o);
                            }
                          }),
                        ),
                        _errorText(
                          'Select at least one product category.',
                          show: _attempted && _selectedCategories.isEmpty,
                        ),
                        SizedBox(height: 16),
                        TextFormField(
                          controller: _sampleProductsController,
                          maxLines: 2,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(300),
                          ],
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'What will you list first? (optional)',
                            'e.g. Native tomatoes, sweet corn, free-range '
                                'eggs',
                          ),
                        ),
                      ],
                    ),
                    _sectionCard(
                      icon: Icons.local_shipping_outlined,
                      title: 'Getting orders to buyers',
                      subtitle:
                          'Buyers will chat with you to arrange the '
                          'details.',
                      children: [
                        _groupLabel('How can buyers receive their orders?'),
                        _choiceChips(
                          options: SellerApplicationService.fulfillmentOptions,
                          isSelected: _selectedFulfillment.contains,
                          onTap: (o) => setState(() {
                            if (!_selectedFulfillment.remove(o)) {
                              _selectedFulfillment.add(o);
                            }
                          }),
                        ),
                        _errorText(
                          'Select at least one option.',
                          show: _attempted && _selectedFulfillment.isEmpty,
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.fromLTRB(14, 6, 14, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _seedColor.withValues(alpha: 0.07),
                        ),
                      ),
                      child: Column(
                        children: [
                          CheckboxListTile(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                            activeColor: _seedColor,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              'I confirm the information above is accurate, '
                              'and that I will only list agricultural '
                              'products or farm tools on AgriMarket.',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: Colors.grey[800],
                                height: 1.45,
                              ),
                            ),
                          ),
                          _errorText(
                            'Please confirm to continue.',
                            show: _attempted && !_agreed,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: _bgColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: MorphingSubmitButton(
                    label: 'Submit Application',
                    loading: _submitting,
                    done: _done,
                    seedColor: _seedColor,
                    onPressed: _submit,
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
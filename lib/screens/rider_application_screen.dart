import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/rider_application_service.dart';
import '../widgets/morphing_submit_button.dart';
import '../widgets/success_dialog.dart';

class RiderApplicationScreen extends StatefulWidget {
  const RiderApplicationScreen({super.key});

  @override
  State<RiderApplicationScreen> createState() => _RiderApplicationScreenState();
}

class _RiderApplicationScreenState extends State<RiderApplicationScreen> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _plateNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final _notesController = TextEditingController();

  String? _vehicleType;
  String? _experience;
  bool _agreed = false;
  bool _attempted = false;
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _plateNumberController.dispose();
    _licenseNumberController.dispose();
    _serviceAreaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _choicesValid => _vehicleType != null && _agreed;

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
      await RiderApplicationService.submitApplication(
        fullName: _fullNameController.text.trim(),
        contactNumber: _cleanPhone(_contactNumberController.text),
        vehicleType: _vehicleType!,
        vehiclePlateNumber: _plateNumberController.text.trim(),
        serviceArea: _serviceAreaController.text.trim(),
        agreedToTerms: _agreed,
        driverLicenseNumber: _licenseNumberController.text.trim(),
        yearsOfExperience: _experience ?? '',
        additionalNotes: _notesController.text.trim(),
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
            'Your rider application has been submitted. '
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
          titleSpacing: 5,
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
                child: Icon(Icons.arrow_back, color: _bgColor, size: 20),
              ),
            ),
          ),
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
                'Become a Rider',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Apply to start delivering on AgriMarket',
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
                          Icon(
                            Icons.local_shipping_outlined,
                            color: _seedColor,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tell us about yourself and your vehicle. '
                              'Approved riders can accept and deliver '
                              'orders on AgriMarket.',
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
                      icon: Icons.person_outline_rounded,
                      title: 'About you',
                      subtitle:
                          'Basic details we\'ll use to review your '
                          'application.',
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(100),
                          ],
                          decoration: _decoration(
                            'Full Name',
                            'e.g. Juan Dela Cruz',
                          ),
                          validator: _required,
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
                          controller: _serviceAreaController,
                          textCapitalization: TextCapitalization.words,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(80),
                          ],
                          decoration: _decoration(
                            'Service Area',
                            'e.g. Hinigaran Poblacion',
                          ),
                          validator: _required,
                        ),
                      ],
                    ),
                    _sectionCard(
                      icon: Icons.two_wheeler_outlined,
                      title: 'Your vehicle',
                      subtitle:
                          'What you\'ll use to pick up and deliver orders.',
                      children: [
                        _groupLabel('Vehicle type'),
                        _choiceChips(
                          options: RiderApplicationService.vehicleTypes,
                          isSelected: (o) => _vehicleType == o,
                          onTap: (o) => setState(() => _vehicleType = o),
                        ),
                        _errorText(
                          'Please choose one.',
                          show: _attempted && _vehicleType == null,
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _plateNumberController,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(20),
                          ],
                          decoration: _decoration(
                            'Vehicle Plate Number',
                            'e.g. ABC 1234',
                          ),
                          validator: _required,
                        ),
                        SizedBox(height: 14),
                        TextFormField(
                          controller: _licenseNumberController,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(30),
                          ],
                          decoration: _decoration(
                            'Driver\'s License Number (optional)',
                            'e.g. N01-23-456789',
                          ),
                        ),
                        SizedBox(height: 20),
                        _groupLabel('Years of experience', hint: 'Optional'),
                        _choiceChips(
                          options: RiderApplicationService.experienceLevels,
                          isSelected: (o) => _experience == o,
                          onTap: (o) => setState(() => _experience = o),
                        ),
                      ],
                    ),
                    _sectionCard(
                      icon: Icons.notes_outlined,
                      title: 'Anything else?',
                      subtitle: 'Optional, but it helps us review faster.',
                      children: [
                        TextFormField(
                          controller: _notesController,
                          maxLines: 3,
                          maxLength: 500,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _decoration(
                            'Additional notes (optional)',
                            'Availability, past delivery experience, etc.',
                          ),
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
                              'and that I hold a valid license and the '
                              'required documents for this vehicle.',
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
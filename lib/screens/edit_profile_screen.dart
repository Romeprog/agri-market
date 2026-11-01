import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/cloudinary_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _accentColor = Color(0xFFE0A63A);
  static const _bgColor = Color(0xFFEFF1E4);

  bool _isFetching = true;

  String _name = '';
  String _bio = '';
  String _gender = '';
  String _birthday = '';
  String _phone = '';
  String _photoUrl = '';
  File? _imageFile;
  bool _isUploadingPhoto = false;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = _user;
    if (user == null) {
      setState(() => _isFetching = false);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    setState(() {
      _name = data?['name'] as String? ?? user.displayName ?? '';
      _bio = data?['bio'] as String? ?? '';
      _gender = data?['gender'] as String? ?? '';
      _birthday = data?['birthday'] as String? ?? '';
      _phone = data?['phone'] as String? ?? '';
      _photoUrl = data?['photoUrl'] as String? ?? user.photoURL ?? '';
      _isFetching = false;
    });
  }

  Future<void> _updateField(String field, String value) async {
    final user = _user;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      field: value,
    }, SetOptions(merge: true));
    if (field == 'name') {
      await user.updateDisplayName(value);
    }
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
            _sheetHandle(),
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

  Future<void> _pickProfilePhoto() async {
    final source = await _chooseImageSource();
    if (source == null) return;
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;

    final imageFile = File(picked.path);
    setState(() {
      _imageFile = imageFile;
      _isUploadingPhoto = true;
    });

    final uploadResult = await uploadImageToCloudinary(imageFile);
    if (!mounted) return;

    if (uploadResult == null) {
      setState(() => _isUploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not upload photo. Please try again.')),
      );
      return;
    }

    final user = _user;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'photoUrl': uploadResult.secureUrl,
        'photoPublicId': uploadResult.publicId,
      }, SetOptions(merge: true));
      await user.updatePhotoURL(uploadResult.secureUrl);
    }

    if (!mounted) return;
    setState(() {
      _photoUrl = uploadResult.secureUrl;
      _isUploadingPhoto = false;
    });
  }

  String _maskPhone(String phone) {
    if (phone.isEmpty) return 'Set Now';
    final digits = phone.replaceAll(RegExp(r'\s+'), '');
    if (digits.length <= 2) return digits;
    final visible = digits.substring(digits.length - 2);
    return '${'*' * (digits.length - 2)}$visible';
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return '';
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final first = email.substring(0, 1);
    final domain = email.substring(at);
    final maskedLen = at - 2;
    return '$first${'*' * (maskedLen < 0 ? 0 : maskedLen)}${email.substring(at - 1, at)}$domain';
  }

  String _maskBirthday(String birthday) {
    if (birthday.isEmpty) return 'Set Now';
    final parts = birthday.split('-');
    if (parts.length != 3) return birthday;
    return '**/**/${parts[0]}';
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Future<void> _editTextField({
    required String title,
    required String field,
    required String currentValue,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
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
              _sheetHandle(),
              Text(
                title,
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _seedColor,
                ),
              ),
              SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _seedColor.withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLines: maxLines,
                  autofocus: true,
                  style: GoogleFonts.inter(fontSize: 14.5),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _seedColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        switch (field) {
          case 'name':
            _name = result;
          case 'bio':
            _bio = result;
          case 'phone':
            _phone = result;
        }
      });
      await _updateField(field, result);
    }
  }

  Future<void> _editGender() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      builder: (_) => SafeArea(
        child: RadioGroup<String>(
          groupValue: _gender,
          onChanged: (value) => Navigator.pop(context, value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sheetHandle(),
                    Text(
                      'Gender',
                      style: GoogleFonts.fraunces(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (final option in ['Male', 'Female', 'Prefer not to say'])
                RadioListTile<String>(
                  value: option,
                  activeColor: _seedColor,
                  title: Text(option, style: GoogleFonts.inter(fontSize: 14.5)),
                ),
              SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );

    if (result != null) {
      setState(() => _gender = result);
      await _updateField('gender', result);
    }
  }

  Future<void> _editBirthday() async {
    final initial = _birthday.isNotEmpty
        ? DateTime.tryParse(_birthday) ?? DateTime(2000, 1, 1)
        : DateTime(2000, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme
              .copyWith(primary: _seedColor),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      final formatted =
          '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      setState(() => _birthday = formatted);
      await _updateField('birthday', formatted);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.fromLTRB(4, 4, 4, 8),
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

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
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
      child: Column(children: children),
    );
  }

  Widget _row({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isPlaceholder = false,
    Widget? trailingHelp,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _seedColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 16, color: _seedColor),
            ),
            SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 14.5, color: Colors.black87),
            ),
            if (trailingHelp != null) ...[SizedBox(width: 4), trailingHelp],
            SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: isPlaceholder ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Colors.grey.shade100,
  );

  @override
  Widget build(BuildContext context) {
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
                'Edit Profile',
                style: GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _bgColor,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Keep your details up to date',
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
      body: _isFetching
          ? Center(child: CircularProgressIndicator(color: _seedColor))
          : SafeArea(
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: _seedColor.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _seedColor.withValues(alpha: 0.15),
                                    blurRadius: 18,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: ClipOval(
                                child: SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: _imageFile != null
                                      ? Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                        )
                                      : _photoUrl.isNotEmpty
                                      ? Image.network(
                                          _photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              Image.asset(
                                                'assets/profile.png',
                                                fit: BoxFit.cover,
                                              ),
                                        )
                                      : Image.asset(
                                          'assets/profile.png',
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                            ),
                            if (_isUploadingPhoto)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.35),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: InkWell(
                                onTap: _isUploadingPhoto
                                    ? null
                                    : _pickProfilePhoto,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: _accentColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _bgColor,
                                      width: 2.5,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Text(
                          _name.isEmpty ? 'Your name' : _name,
                          style: GoogleFonts.fraunces(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _seedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  _sectionLabel('Profile'),
                  _sectionCard(
                    children: [
                      _row(
                        label: 'Name',
                        icon: Icons.person_outline,
                        value: _name.isEmpty ? 'Set Now' : _name,
                        isPlaceholder: _name.isEmpty,
                        onTap: () => _editTextField(
                          title: 'Edit Name',
                          field: 'name',
                          currentValue: _name,
                        ),
                      ),
                      _divider(),
                      _row(
                        label: 'Bio',
                        icon: Icons.short_text_rounded,
                        value: _bio.isEmpty ? 'Set Now' : _bio,
                        isPlaceholder: _bio.isEmpty,
                        onTap: () => _editTextField(
                          title: 'Edit Bio',
                          field: 'bio',
                          currentValue: _bio,
                          maxLines: 3,
                        ),
                      ),
                    ],
                  ),
                  _sectionLabel('Personal Details'),
                  _sectionCard(
                    children: [
                      _row(
                        label: 'Gender',
                        icon: Icons.wc_outlined,
                        value: _gender.isEmpty ? 'Set Now' : _gender,
                        isPlaceholder: _gender.isEmpty,
                        onTap: _editGender,
                      ),
                      _divider(),
                      _row(
                        label: 'Birthday',
                        icon: Icons.cake_outlined,
                        value: _maskBirthday(_birthday),
                        isPlaceholder: _birthday.isEmpty,
                        onTap: _editBirthday,
                      ),
                    ],
                  ),
                  _sectionLabel('Contact'),
                  _sectionCard(
                    children: [
                      _row(
                        label: 'Phone',
                        icon: Icons.call_outlined,
                        value: _maskPhone(_phone),
                        isPlaceholder: _phone.isEmpty,
                        onTap: () => _editTextField(
                          title: 'Edit Phone Number',
                          field: 'phone',
                          currentValue: _phone,
                          keyboardType: TextInputType.phone,
                        ),
                      ),
                      _divider(),
                      _row(
                        label: 'Email',
                        icon: Icons.alternate_email_rounded,
                        value: _maskEmail(_user?.email ?? ''),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              title: Text(
                                'Email',
                                style: GoogleFonts.fraunces(
                                  fontWeight: FontWeight.bold,
                                  color: _seedColor,
                                ),
                              ),
                              content: Text(
                                'Your email is tied to your login and can\'t '
                                'be changed here. Contact support if you need '
                                'to update it.',
                                style: GoogleFonts.inter(fontSize: 13.5),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'OK',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: _seedColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
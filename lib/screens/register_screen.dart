import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_mode.dart';
import '../widgets/auth_scaffold.dart';
import 'login_screen.dart';

Future<void> openRoleSelectSheet(
  BuildContext context, {
  bool replace = false,
}) async {
  final selected = await showModalBottomSheet<AppRole>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _RoleSelectSheet(),
  );
  if (selected == null || !context.mounted) return;

  final route = MaterialPageRoute(
    builder: (_) => RegisterScreen(role: selected),
  );
  if (replace) {
    Navigator.pushReplacement(context, route);
  } else {
    Navigator.push(context, route);
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.role});

  final AppRole role;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _seedColor = AuthScaffold.seedColor;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _farmNameController = TextEditingController();
  final _farmLocationController = TextEditingController();
  final _serviceAreaController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _farmNameController.dispose();
    _farmLocationController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  String get _roleTagline => switch (widget.role) {
    AppRole.buyer => 'Fresh produce, straight from local farms to you.',
    AppRole.seller => 'List your harvest and reach buyers in your area.',
    AppRole.rider => 'Deliver fresh produce and earn on every trip.',
  };

  Map<String, dynamic> _roleFields() {
    switch (widget.role) {
      case AppRole.seller:
        return {
          'farmName': _farmNameController.text.trim(),
          'farmLocation': _farmLocationController.text.trim(),
        };
      case AppRole.rider:
        return {
          'riderServiceArea': _serviceAreaController.text.trim(),
          'riderSince': FieldValue.serverTimestamp(),
        };
      case AppRole.buyer:
        return {'sellerOnly': false};
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final role = widget.role;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      activeRoleNotifier.value = role;
      UserCredential credential;
      var existingAccount = false;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') rethrow;
        try {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } on FirebaseAuthException catch (_) {
          throw _MessageException(
            'An account with this email already exists. Enter that account\'s '
            'password to add a ${role.label} account, or log in instead.',
          );
        }
        existingAccount = true;
      }
      final user = credential.user!;
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final baseFields = {
        'uid': user.uid,
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (!existingAccount) {
        await user.updateDisplayName(name);
        await userRef.set({
          ...baseFields,
          ..._roleFields(),
          if (role == AppRole.seller) 'sellerOnly': true,
          if (role == AppRole.rider) 'riderOnly': true,
        });
      } else {
        final snapshot = await userRef.get();
        final data = snapshot.data();
        if (data == null) {
          await userRef.set({
            ...baseFields,
            ..._roleFields(),
            if (role == AppRole.seller) 'sellerOnly': true,
            if (role == AppRole.rider) 'riderOnly': true,
          });
        } else if (role == AppRole.rider && data['isRider'] == true) {
        } else {
          await userRef.set(_roleFields(), SetOptions(merge: true));
        }
      }

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on _MessageException catch (e) {
      activeRoleNotifier.value = null;
      setState(() => _errorMessage = e.message);
    } on FirebaseAuthException catch (e) {
      activeRoleNotifier.value = null;
      setState(() {
        _errorMessage = switch (e.code) {
          'invalid-email' => 'Invalid email address.',
          'weak-password' =>
            'Choose a stronger password (at least 6 characters).',
          'network-request-failed' =>
            'No internet connection. Please check your network.',
          _ => e.message ?? 'Something went wrong. Please try again.',
        };
      });
    } catch (e) {
      debugPrint('Register error: $e');
      activeRoleNotifier.value = null;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
      decoration: authFieldDecoration(hint, Icons.lock_outline_rounded)
          .copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: Colors.grey[600],
                size: 20,
              ),
              onPressed: onToggle,
            ),
          ),
      validator: validator,
    );
  }

  String? _required(String? value, String message) =>
      (value == null || value.trim().isEmpty) ? message : null;

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    return AuthScaffold(
      showBack: true,
      centerContent: true,
      fitContent: false,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: _seedColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              _roleTagline,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13.5, color: Colors.grey[600]),
            ),
            SizedBox(height: 20),
            if (_errorMessage != null) ...[
              AuthErrorBox(message: _errorMessage!),
              SizedBox(height: 16),
            ],
            if (role == AppRole.seller) ...[
              TextFormField(
                controller: _farmNameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                decoration: authFieldDecoration(
                  'Farm or store name',
                  Icons.storefront_outlined,
                ),
                validator: (v) => _required(v, 'Enter your farm or store name'),
              ),
              SizedBox(height: 14),
              TextFormField(
                controller: _farmLocationController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                decoration: authFieldDecoration(
                  'Farm location (Barangay, Town)',
                  Icons.location_on_outlined,
                ),
                validator: (v) => _required(v, 'Enter your farm location'),
              ),
              SizedBox(height: 14),
            ],
            if (role == AppRole.rider) ...[
              TextFormField(
                controller: _serviceAreaController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                decoration: authFieldDecoration(
                  'Service area (e.g. Hinigaran Poblacion)',
                  Icons.map_outlined,
                ),
                validator: (v) => _required(v, 'Enter your service area'),
              ),
              SizedBox(height: 14),
            ],
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
              decoration: authFieldDecoration(
                'Full name',
                Icons.person_outline_rounded,
              ),
              validator: (v) => _required(v, 'Enter your name'),
            ),
            SizedBox(height: 14),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
              decoration: authFieldDecoration(
                'Enter your email',
                Icons.mail_outline_rounded,
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (v.isEmpty) return 'Enter your email';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            SizedBox(height: 14),
            _passwordField(
              controller: _passwordController,
              hint: 'Enter your password',
              obscure: _obscurePassword,
              onToggle: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Enter a password';
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            SizedBox(height: 14),
            _passwordField(
              controller: _confirmPasswordController,
              hint: 'Confirm password',
              obscure: _obscureConfirmPassword,
              onToggle: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              validator: (value) => value != _passwordController.text
                  ? 'Passwords do not match'
                  : null,
            ),
            if (role == AppRole.seller) ...[
              SizedBox(height: 12),
              Text(
                'Seller accounts are reviewed before you can list products. '
                'You can apply from your Profile tab after signing up.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (role == AppRole.rider) ...[
              SizedBox(height: 12),
              Text(
                'Rider accounts are reviewed before you can accept '
                'deliveries. You can apply from your Profile tab after '
                'signing up.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            SizedBox(height: 24),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _seedColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isLoading
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Create ${role.label} Account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: Colors.grey[600],
                  ),
                ),
                GestureDetector(
                  onTap: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => LoginScreen()),
                        ),
                  child: Text(
                    'Log In',
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _seedColor,
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

class _MessageException implements Exception {
  _MessageException(this.message);
  final String message;
}
class _RoleSelectSheet extends StatelessWidget {
  const _RoleSelectSheet();

  static const _seedColor = AuthScaffold.seedColor;

  String _descriptionFor(AppRole role) => switch (role) {
    AppRole.buyer => 'Fresh produce, straight from local farms to you.',
    AppRole.seller => 'List your harvest and reach buyers in your area.',
    AppRole.rider => 'Deliver fresh produce and earn on every trip.',
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: AuthScaffold.bgColor,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
        ),
        padding: EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Select a role',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: _seedColor,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'How would you like to use AgriMarket?',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
            ),
            SizedBox(height: 22),
            for (final role in AppRole.values) ...[
              _RoleOptionTile(
                role: role,
                description: _descriptionFor(role),
                onTap: () => Navigator.pop(context, role),
              ),
              if (role != AppRole.values.last) SizedBox(height: 12),
            ],
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _RoleOptionTile extends StatelessWidget {
  const _RoleOptionTile({
    required this.role,
    required this.description,
    required this.onTap,
  });

  final AppRole role;
  final String description;
  final VoidCallback onTap;

  static const _seedColor = AuthScaffold.seedColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _seedColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(role.icon, color: _seedColor, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
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
    );
  }
}
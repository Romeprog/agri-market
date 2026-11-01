import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.child,
    this.showBack = false,
    this.centerContent = false,
    this.fitContent = false,
  });

  final Widget child;
  final bool showBack;
  final bool centerContent;
  final bool fitContent;

  static const seedColor = Color(0xFF1F3D2B);
  static const bgColor = Color(0xFFEFF1E4);

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold> {
  double _maxKeyboard = 300;

  Widget _header(double topPadding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, topPadding + 28, 24, 28),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: AuthScaffold.seedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.asset('assets/logo.png', fit: BoxFit.cover),
            ),
            SizedBox(height: 22),
            Text(
              'AgriMarket',
              textAlign: TextAlign.center,
              style: GoogleFonts.fraunces(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Connecting Farms to Fresh Markets',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                letterSpacing: 0.4,
                color: Colors.white.withValues(alpha: 0.78),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return widget.centerContent
        ? Align(alignment: Alignment(0, -0.35), child: widget.child)
        : widget.child;
  }

  Widget _sheet() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AuthScaffold.bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: widget.fitContent
            ? Padding(
                padding: EdgeInsets.fromLTRB(28, 36, 28, 24),
                child: _content(),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(28, 36, 28, 24),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: math.max(0, constraints.maxHeight - 60),
                      ),
                      child: _content(),
                    ),
                  );
                },
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final screenHeight = MediaQuery.of(context).size.height;
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    if (inset > _maxKeyboard) _maxKeyboard = inset;
    final t = (inset / _maxKeyboard).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: AuthScaffold.seedColor,
      body: Stack(
        children: [
          Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenHeight * 0.46),
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1 - t,
                    child: Opacity(opacity: 1 - t, child: _header(topPadding)),
                  ),
                ),
              ),
              SizedBox(height: (topPadding + 16) * t),
              if (widget.fitContent) ...[
                Expanded(child: SizedBox()),
                _sheet(),
              ] else
                Expanded(child: _sheet()),
            ],
          ),
          if (widget.showBack)
            Positioned(
              top: topPadding + 8,
              left: 16,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.arrow_back,
                    color: AuthScaffold.bgColor,
                    size: 20,
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

InputDecoration authFieldDecoration(String hint, IconData icon) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.inter(fontSize: 15, color: Colors.grey[500]),
    prefixIcon: Icon(icon, color: Colors.grey[600], size: 22),
    filled: true,
    fillColor: Colors.white,
    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 4),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: AuthScaffold.seedColor, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

class AuthErrorBox extends StatelessWidget {
  const AuthErrorBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }
}
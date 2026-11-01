import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

class LoginOrRegister extends StatelessWidget {
  const LoginOrRegister({super.key});

  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _seedColor,
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding + 16, bottom: 16),
              child: Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: _Hero()),
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * 48),
                child: child,
              ),
            ),
            child: _Sheet(),
          ),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 124,
          height: 124,
          decoration: BoxDecoration(
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
    );
  }
}

class _Sheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: LoginOrRegister._bgColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(36),
          topRight: Radius.circular(36),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(28, 30, 28, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Fresh from the farm,\nstraight to your door',
                textAlign: TextAlign.center,
                style: GoogleFonts.fraunces(
                  fontSize: 25,
                  height: 1.2,
                  fontWeight: FontWeight.bold,
                  color: LoginOrRegister._seedColor,
                ),
              ),
              SizedBox(height: 10),
              Text(
                'From local farms to your everyday needs.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LoginOrRegister._seedColor,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: LoginOrRegister._seedColor.withValues(
                      alpha: 0.4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: () => openRoleSelectSheet(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: LoginOrRegister._seedColor,
                      width: 1.6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Sign Up',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: LoginOrRegister._seedColor,
                    ),
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
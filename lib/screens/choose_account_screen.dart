import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_mode.dart';
import '../widgets/auth_scaffold.dart';

class ChooseAccountScreen extends StatelessWidget {
  const ChooseAccountScreen({super.key, required this.roles});

  final List<AppRole> roles;

  static const _seedColor = AuthScaffold.seedColor;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Choose an Account',
            textAlign: TextAlign.center,
            style: GoogleFonts.fraunces(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: _seedColor,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'This login has more than one account. Where to?',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
          ),
          SizedBox(height: 24),
          for (final role in roles) ...[
            _AccountTile(
              role: role,
              onTap: () => activeRoleNotifier.value = role,
            ),
            SizedBox(height: 12),
          ],
          SizedBox(height: 8),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              activeRoleNotifier.value = null;
            },
            child: Text(
              'Log Out',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFFB3261E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.role, required this.onTap});

  final AppRole role;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = role.color;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AuthScaffold.seedColor.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    role.icon,
                    color: role == AppRole.seller ? Color(0xFF9A6A10) : color,
                  ),
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
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        role.tagline,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
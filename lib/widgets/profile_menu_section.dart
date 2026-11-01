import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileMenuItem {
  const ProfileMenuItem(this.icon, this.title, this.onTap);

  final IconData icon;
  final String title;
  final VoidCallback onTap;
}

class ProfileMenuSection extends StatelessWidget {
  const ProfileMenuSection({
    super.key,
    required this.title,
    required this.items,
    this.seedColor = const Color(0xFF1F3D2B),
  });

  final String title;
  final List<ProfileMenuItem> items;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(4, 20, 4, 8),
          child: Text(
            title,
            style: GoogleFonts.fraunces(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: seedColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: seedColor.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final item in items) ...[
                  InkWell(
                    onTap: item.onTap,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(item.icon, color: seedColor, size: 22),
                          SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item != items.last)
                    Divider(height: 1, indent: 50, color: Colors.grey.shade200),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
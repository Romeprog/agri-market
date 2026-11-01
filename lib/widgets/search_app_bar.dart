import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'cart_button.dart';

class SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SearchAppBar({
    super.key,
    this.hintText = 'Search',
    this.controller,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onCartTap,
    this.cartItemCount,
    this.showCartIcon = true,
    this.leading,
  });

  final String hintText;
  final TextEditingController? controller;
  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback? onCartTap;
  final int? cartItemCount;
  final bool showCartIcon;
  final Widget? leading;

  static const _seedColor = Color(0xFF1F3D2B);
  static const _seedColorLight = Color(0xFF2E5A3E);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + 10);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      toolbarHeight: kToolbarHeight + 10,
      flexibleSpace: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_seedColorLight, _seedColor],
            ),
          ),
        ),
      ),
      title: Row(
        children: [
          if (leading != null) ...[leading!, SizedBox(width: 8)],
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: _seedColor.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: TextField(
                controller: controller,
                onChanged: onSearchChanged,
                onSubmitted: onSearchSubmitted,
                style: GoogleFonts.inter(fontSize: 15, color: Colors.black87),
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: hintText,
                  hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: _seedColor.withValues(alpha: 0.6),
                    size: 22,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          if (showCartIcon) ...[
            SizedBox(width: 10),
            Container(
              padding: EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: CartButton(onTap: onCartTap, itemCount: cartItemCount),
            ),
          ],
        ],
      ),
    );
  }
}
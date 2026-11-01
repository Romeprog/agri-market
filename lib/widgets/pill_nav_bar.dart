import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PillNavItem {
  const PillNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class PillNavBar extends StatelessWidget {
  const PillNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.badges = const {},
  });

  final List<PillNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final Map<int, int> badges;

  static const _seedColor = Color(0xFF1F3D2B);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: _seedColor.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              return _NavItem(
                data: items[index],
                selected: index == currentIndex,
                seedColor: _seedColor,
                onTap: () => onTap(index),
                badgeCount: badges[index] ?? 0,
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.selected,
    required this.seedColor,
    required this.onTap,
    this.badgeCount = 0,
  });

  final PillNavItem data;
  final bool selected;
  final Color seedColor;
  final VoidCallback onTap;
  final int badgeCount;

  static const _accentColor = Color(0xFFE0A63A);

  Widget _buildIcon() {
    final icon = Icon(
      selected ? data.activeIcon : data.icon,
      color: selected ? seedColor : Colors.grey[400],
      size: 23,
    );

    if (badgeCount <= 0) return icon;

    return SizedBox(
      width: 23,
      height: 23,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          icon,
          Positioned(
            top: -6,
            right: -8,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: seedColor,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: selected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? seedColor.withValues(alpha: 0.10)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildIcon(),
            AnimatedSize(
              duration: Duration(milliseconds: 180),
              curve: Curves.easeOut,
              child: selected
                  ? Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Text(
                        data.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: seedColor,
                        ),
                      ),
                    )
                  : SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
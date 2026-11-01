import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ExpandableApplicationCard extends StatefulWidget {
  const ExpandableApplicationCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.expanded,
    required this.onToggle,
    required this.children,
    this.removed = false,
  });

  final String title;
  final String subtitle;
  final String hint;
  final bool expanded;
  final VoidCallback onToggle;
  final List<Widget> children;
  final bool removed;

  @override
  State<ExpandableApplicationCard> createState() =>
      _ExpandableApplicationCardState();
}

class _ExpandableApplicationCardState extends State<ExpandableApplicationCard>
    with TickerProviderStateMixin {
  static const Color _seedColor = Color(0xFF1F3D2B);

  late final AnimationController _expand;
  late final AnimationController _remove;
  late final CurvedAnimation _size;
  late final CurvedAnimation _removeCurve;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 380),
      value: widget.expanded ? 1 : 0,
    );
    _remove = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 320),
      value: widget.removed ? 0 : 1,
    );
    _size = CurvedAnimation(parent: _expand, curve: Curves.easeInOutCubic);
    _removeCurve = CurvedAnimation(parent: _remove, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant ExpandableApplicationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded != oldWidget.expanded) {
      if (widget.expanded) {
        _expand.forward();
        _scrollIntoViewWhenOpen();
      } else {
        _expand.reverse();
      }
    }
    if (widget.removed && !oldWidget.removed) {
      _remove.reverse();
    }
  }

  void _scrollIntoViewWhenOpen() {
    Future.delayed(Duration(milliseconds: 420), () {
      if (!mounted || !widget.expanded) return;
      Scrollable.ensureVisible(
        context,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  void dispose() {
    _size.dispose();
    _removeCurve.dispose();
    _expand.dispose();
    _remove.dispose();
    super.dispose();
  }

  Widget _reveal(int index, Widget child) {
    final start = (0.15 + index * 0.08).clamp(0.0, 0.6).toDouble();
    final end = (start + 0.4).clamp(0.0, 1.0).toDouble();
    final anim = _expand.drive(
      CurveTween(curve: Interval(start, end, curve: Curves.easeOut)),
    );
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: anim.drive(
          Tween<Offset>(begin: Offset(0, 0.12), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  Widget _header() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: widget.onToggle,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: GoogleFonts.fraunces(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _seedColor,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    widget.subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _seedColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: RotationTransition(
                turns: Tween<double>(begin: 0, end: 0.5).animate(_size),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _seedColor,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collapsedFactor = ReverseAnimation(_size);

    return IgnorePointer(
      ignoring: widget.removed,
      child: SizeTransition(
        sizeFactor: _removeCurve,
        alignment: Alignment.topCenter,
        child: FadeTransition(
          opacity: _removeCurve,
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _size,
              builder: (context, child) {
                final t = _size.value;
                return Container(
                  margin: EdgeInsets.only(bottom: 12),
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _seedColor.withValues(alpha: 0.06 + 0.08 * t),
                        blurRadius: 14 + 8 * t,
                        offset: Offset(0, 4 + 2 * t),
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _header(),
                  SizeTransition(
                    sizeFactor: collapsedFactor,
                    alignment: Alignment.topCenter,
                    child: FadeTransition(
                      opacity: collapsedFactor,
                      child: Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          widget.hint,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizeTransition(
                    sizeFactor: _size,
                    alignment: Alignment.topCenter,
                    child: IgnorePointer(
                      ignoring: !widget.expanded,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 10),
                          for (var i = 0; i < widget.children.length; i++)
                            _reveal(i, widget.children[i]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
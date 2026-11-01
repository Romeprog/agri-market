import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MorphingSubmitButton extends StatefulWidget {
  const MorphingSubmitButton({
    super.key,
    required this.label,
    required this.loading,
    required this.done,
    required this.seedColor,
    required this.onPressed,
    this.height = 52,
  });

  final String label;
  final bool loading;
  final bool done;
  final Color seedColor;
  final VoidCallback onPressed;
  final double height;

  @override
  State<MorphingSubmitButton> createState() => _MorphingSubmitButtonState();
}

class _MorphingSubmitButtonState extends State<MorphingSubmitButton> {
  static const Color _successColor = Color(0xFF2E7D4F);
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final collapsed = widget.loading || widget.done;
    final color = widget.done ? _successColor : widget.seedColor;
    final collapsedSize = widget.height;

    final Widget content;
    if (widget.done) {
      content = Icon(
        Icons.check_rounded,
        key: ValueKey('done'),
        color: Colors.white,
        size: widget.height * 0.5,
      );
    } else if (widget.loading) {
      content = SizedBox(
        key: ValueKey('loading'),
        width: widget.height * 0.4,
        height: widget.height * 0.4,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          color: Colors.white,
        ),
      );
    } else {
      content = Text(
        widget.label,
        key: ValueKey('idle'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: Colors.white,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final idleWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : collapsedSize;
        return Center(
          child: Listener(
            onPointerDown: (_) {
              if (!collapsed) _setPressed(true);
            },
            onPointerUp: (_) => _setPressed(false),
            onPointerCancel: (_) => _setPressed(false),
            child: AnimatedScale(
              scale: _pressed ? 0.95 : 1,
              duration: Duration(milliseconds: 110),
              curve: Curves.easeOut,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 340),
                curve: Curves.easeInOutCubic,
                width: collapsed ? collapsedSize : idleWidth,
                height: widget.height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(
                    collapsed ? collapsedSize / 2 : 14,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: collapsed ? 0.0 : 0.28),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(
                    collapsed ? collapsedSize / 2 : 14,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: collapsed ? null : widget.onPressed,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeIn,
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: content,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminMorphController {
  _AdminMorphButtonState? _state;

  void _attach(_AdminMorphButtonState state) => _state = state;

  Future<void> play() async {
    final state = _state;
    if (state == null || !state.mounted) return;
    await state._play();
  }

  void reset() => _state?._reset();
}
class AdminMorphButton extends StatefulWidget {
  const AdminMorphButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.controller,
    this.leadingIcon,
    this.filled = false,
    this.width = 148,
    this.height = 48,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final AdminMorphController controller;
  final IconData? leadingIcon;
  final bool filled;
  final double width;
  final double height;

  @override
  State<AdminMorphButton> createState() => _AdminMorphButtonState();
}

class _AdminMorphButtonState extends State<AdminMorphButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _collapse;
  late final Animation<double> _iconScale;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);

    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 420),
    );

    _collapse = CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.55, curve: Curves.easeInOut),
    );

    _iconScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 45),
    ]).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    if (_controller.isAnimating) return;
    await _controller.forward();
  }

  void _reset() {
    if (!mounted) return;
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final width = _lerp(widget.width, widget.height, _collapse.value);
          final radius = widget.height / 2;

          final restBg = widget.filled
              ? widget.color
              : widget.color.withValues(alpha: 0.08);
          final labelColor = widget.filled ? Colors.white : widget.color;

          return Opacity(
            opacity: 1,
            child: Container(
              width: width,
              height: widget.height,
              decoration: BoxDecoration(
                color: Color.lerp(restBg, widget.color, _collapse.value),
                borderRadius: BorderRadius.circular(radius),
                border: widget.filled
                    ? null
                    : Border.all(
                        color: widget.color.withValues(
                          alpha: 1 - _collapse.value * 0.7,
                        ),
                        width: 1.4,
                      ),
                boxShadow: widget.filled
                    ? [
                        BoxShadow(
                          color: widget.color.withValues(alpha: 0.28),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: _collapse.value < 0.5
                  ? Opacity(
                      opacity: (1 - _collapse.value * 2).clamp(0.0, 1.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.leadingIcon != null) ...[
                            Icon(
                              widget.leadingIcon,
                              size: 17,
                              color: labelColor,
                            ),
                            SizedBox(width: 6),
                          ],
                          Text(
                            widget.label,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Transform.scale(
                      scale: _iconScale.value,
                      child: Icon(widget.icon, color: Colors.white, size: 20),
                    ),
            ),
          );
        },
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
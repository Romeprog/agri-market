import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class FloatingGain extends StatefulWidget {
  const FloatingGain({
    super.key,
    required this.active,
    required this.text,
    required this.child,
    this.seedColor = const Color(0xFF1F3D2B),
    this.accentColor = const Color(0xFFE0A63A),
  });

  final bool active;
  final String text;
  final Widget child;
  final Color seedColor;
  final Color accentColor;

  @override
  State<FloatingGain> createState() => _FloatingGainState();
}

class _FloatingGainState extends State<FloatingGain>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 1800),
  );

  @override
  void didUpdateWidget(covariant FloatingGain oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      HapticFeedback.lightImpact();
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          right: 16,
          top: 86,
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value;
                if (t == 0 || t == 1) return SizedBox.shrink();
                final opacity = t < 0.15
                    ? t / 0.15
                    : (t > 0.65 ? (1 - (t - 0.65) / 0.35) : 1.0);
                final rise = Curves.easeOutCubic.transform(t) * 64;
                final scale = t < 0.2
                    ? 0.7 + 1.5 * t 
                    : 1.0;

                return Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -rise),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text(
                          widget.text,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: widget.seedColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
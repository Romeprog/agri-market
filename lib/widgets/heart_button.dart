import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HeartButton extends StatefulWidget {
  const HeartButton({
    super.key,
    required this.saved,
    required this.onTap,
    this.iconSize = 16,
    this.padding = 6,
    this.activeColor = Colors.redAccent,
  });

  final bool saved;
  final VoidCallback onTap;
  final double iconSize;
  final double padding;
  final Color activeColor;

  @override
  State<HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<HeartButton>
    with SingleTickerProviderStateMixin {
  static const Color _accent = Color(0xFFE0A63A);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 800),
  );

  late final Animation<double> _saveScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.7).chain(CurveTween(curve: Curves.easeIn)),
      weight: 14,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.7, end: 1.45).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.45, end: 0.92).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 24,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.92, end: 1.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 32,
    ),
  ]).animate(_c);

  late final Animation<double> _unsaveScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.78).chain(CurveTween(curve: Curves.easeIn)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.78, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)),
      weight: 65,
    ),
  ]).animate(_c);

  bool _pressed = false;
  bool _burst = false;
  DateTime? _tappedAt;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(HeartButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.saved == widget.saved) return;

    final tapped = _tappedAt;
    final byTap =
        tapped != null &&
        DateTime.now().difference(tapped) < const Duration(seconds: 3);
    if (!byTap) return;
    _tappedAt = null;

    _burst = widget.saved;
    if (widget.saved) HapticFeedback.lightImpact();
    _c.forward(from: 0);
  }

  void _handleTap() {
    _tappedAt = DateTime.now();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.saved;
    final box = widget.iconSize + widget.padding * 2;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (_burst)
              Positioned.fill(
                child: IgnorePointer(
                  child: OverflowBox(
                    maxWidth: box * 3,
                    maxHeight: box * 3,
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) {
                        final t = Curves.easeOutCubic.transform(
                          ((_c.value - 0.12) / 0.88).clamp(0.0, 1.0),
                        );
                        return CustomPaint(
                          size: Size.square(box * 3),
                          painter: _HeartBurstPainter(
                            progress: t,
                            baseRadius: box / 2,
                            color: widget.activeColor,
                            accent: _accent,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            AnimatedScale(
              scale: _pressed ? 0.86 : 1,
              duration: Duration(milliseconds: 90),
              curve: Curves.easeOut,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, child) => Transform.scale(
                  scale: (saved ? _saveScale : _unsaveScale).value,
                  child: child,
                ),
                child: Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    saved ? Icons.favorite : Icons.favorite_border,
                    size: widget.iconSize,
                    color: saved ? widget.activeColor : Colors.grey[500],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartBurstPainter extends CustomPainter {
  _HeartBurstPainter({
    required this.progress,
    required this.baseRadius,
    required this.color,
    required this.accent,
  });

  final double progress;
  final double baseRadius;
  final Color color;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final center = size.center(Offset.zero);
    final fade = (1 - progress).clamp(0.0, 1.0);

    // Expanding ring.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4 * fade + 0.4
      ..color = color.withValues(alpha: fade * 0.55);
    canvas.drawCircle(center, baseRadius * 0.7 + baseRadius * 0.9 * progress, ring);

    // Dots flying outward.
    const count = 8;
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i + math.pi / 8;
      final dist = baseRadius * 0.9 + baseRadius * 0.95 * progress;
      final radius = (i.isEven ? 2.8 : 2.0) * fade;
      final paint = Paint()
        ..color = (i % 3 == 0 ? accent : (i.isEven ? color : Colors.pinkAccent))
            .withValues(alpha: fade);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * dist,
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HeartBurstPainter old) => old.progress != progress;
}
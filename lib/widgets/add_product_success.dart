import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kSeed = Color(0xFF1F3D2B);
const _kBg = Color(0xFFEFF1E4);
const _kAccent = Color(0xFF6FB04A);

Future<void> showAddProductSuccess(
  BuildContext context, {
  String title = 'Product added!',
  String subtitle = 'Your product has been saved.',
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => PopScope(
      canPop: false,
      child: _SuccessDialog(title: title, subtitle: subtitle),
    ),
  );
}

class _SuccessDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  const _SuccessDialog({required this.title, required this.subtitle});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300),
    );
    _c.forward().whenComplete(() async {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _t(double a, double b, Curve curve) =>
      Interval(a, b, curve: curve).transform(_c.value);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: _kBg,
      insetPadding: EdgeInsets.symmetric(horizontal: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final pop = _t(0.0, 0.35, Curves.easeOutBack); 
          final draw = _t(0.3, 0.7, Curves.easeInOut); 
          final ring = _t(0.6, 1.0, Curves.easeOut); 
          final text = _t(0.55, 0.85, Curves.easeOut); 

          return Padding(
            padding: EdgeInsets.fromLTRB(32, 28, 32, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (ring > 0)
                        Opacity(
                          opacity: (1 - ring) * 0.5,
                          child: Transform.scale(
                            scale: 1 + ring * 0.45,
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _kAccent, width: 3),
                              ),
                            ),
                          ),
                        ),
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _kSeed,
                            boxShadow: [
                              BoxShadow(
                                color: _kSeed.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(progress: draw),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Opacity(
                  opacity: text,
                  child: Transform.translate(
                    offset: Offset(0, (1 - text) * 12),
                    child: Column(
                      children: [
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.fraunces(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _kSeed,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          widget.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.27, size.height * 0.53)
      ..lineTo(size.width * 0.43, size.height * 0.68)
      ..lineTo(size.width * 0.73, size.height * 0.36);

    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter old) => old.progress != progress;
}

class NewItemEntrance extends StatefulWidget {
  final bool animate;
  final Widget child;

  final double highlightRadius;

  const NewItemEntrance({
    super.key,
    required this.animate,
    required this.child,
    this.highlightRadius = 16,
  });

  @override
  State<NewItemEntrance> createState() => _NewItemEntranceState();
}

class _NewItemEntranceState extends State<NewItemEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.animate) {
      _c.forward();
    } else {
      _c.value = 1; 
    }
  }

  @override
  void didUpdateWidget(covariant NewItemEntrance old) {
    super.didUpdateWidget(old);
    if (widget.animate && !old.animate) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = const Interval(0.0, 0.6, curve: Curves.easeOutCubic)
                .transform(_c.value);
            final glowT =
                const Interval(0.45, 1.0).transform(_c.value);
            final glow = math.sin(math.pi * glowT); // 0 -> 1 -> 0

            return Align(
              alignment: Alignment.topCenter,
              heightFactor: t,
              child: SizedBox(
                width: constraints.hasBoundedWidth ? constraints.maxWidth : null,
                child: Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset((1 - t) * 80, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(widget.highlightRadius),
                        boxShadow: [
                          BoxShadow(
                            color: _kAccent.withValues(alpha: 0.5 * glow),
                            blurRadius: 20 * glow,
                            spreadRadius: 2 * glow,
                          ),
                        ],
                      ),
                      child: child,
                    ),
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        );
      },
    );
  }
}
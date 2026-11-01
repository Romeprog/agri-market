import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> showSuccessDialog({
  required BuildContext context,
  required String title,
  required String message,
  required Color seedColor,
  required VoidCallback onDone,
  String buttonLabel = 'Done',
  Color successColor = const Color(0xFF2E7D4F),
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: title,
    barrierColor: Colors.black54,
    transitionDuration: Duration(milliseconds: 300),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        SuccessDialog(
          title: title,
          message: message,
          seedColor: seedColor,
          buttonLabel: buttonLabel,
          successColor: successColor,
          onDone: onDone,
        ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.85 + 0.15 * curved.value, child: child),
      );
    },
  );
}

class SuccessDialog extends StatefulWidget {
  const SuccessDialog({
    super.key,
    required this.title,
    required this.message,
    required this.seedColor,
    required this.onDone,
    this.buttonLabel = 'Done',
    this.successColor = const Color(0xFF2E7D4F),
  });

  final String title;
  final String message;
  final Color seedColor;
  final VoidCallback onDone;
  final String buttonLabel;
  final Color successColor;

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  static const Color _accentColor = Color(0xFFE0A63A);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _t(double begin, double end, [Curve curve = Curves.easeOut]) {
    final raw = ((_controller.value - begin) / (end - begin)).clamp(0.0, 1.0);
    return curve.transform(raw);
  }

  Widget _fadeUp(double t, Widget child) {
    return Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 12), child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 28, 24, 22),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final pop = _t(0.0, 0.45, Curves.elasticOut);
            final check = _t(0.22, 0.55, Curves.easeOutCubic);
            final burst = _t(0.18, 1.0, Curves.easeOutCubic);
            final title = _t(0.40, 0.70);
            final body = _t(0.50, 0.80);
            final button = _t(0.62, 0.95);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 124,
                  height: 124,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: Size(124, 124),
                        painter: _BurstPainter(
                          progress: burst,
                          colors: [_accentColor, widget.successColor, seed],
                        ),
                      ),
                      Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: widget.successColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: widget.successColor.withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _CheckPainter(progress: check),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14),
                _fadeUp(
                  title,
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: seed,
                    ),
                  ),
                ),
                SizedBox(height: 8),
                _fadeUp(
                  body,
                  Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(height: 20),
                _fadeUp(
                  button,
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: widget.onDone,
                      style: FilledButton.styleFrom(
                        backgroundColor: seed,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        widget.buttonLabel,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.44, h * 0.68)
      ..lineTo(w * 0.74, h * 0.36);
    final metric = path.computeMetrics().first;
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.progress, required this.colors});

  final double progress;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = colors[1].withValues(alpha: (1 - progress) * 0.35);
    canvas.drawCircle(center, 44 + 14 * progress, ring);

    const count = 14;
    final opacity = (1 - progress * progress).clamp(0.0, 1.0);
    for (var i = 0; i < count; i++) {
      final angle = (2 * math.pi / count) * i + (i.isEven ? 0.0 : 0.18);
      final distance = 40 + (i.isEven ? 14.0 : 8.0) * progress;
      final radius = (i.isEven ? 3.6 : 2.6) * (1 - 0.5 * progress);
      final dot = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
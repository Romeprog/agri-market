import 'dart:math' as math;
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

Offset? _centerOf(GlobalKey key) {
  final box = key.currentContext?.findRenderObject();
  if (box is! RenderBox || !box.attached || !box.hasSize) return null;
  return box.localToGlobal(box.size.center(Offset.zero));
}

void flyToCart({
  required BuildContext context,
  required GlobalKey fromKey,
  required GlobalKey toKey,
  required Widget thumbnail,
  int quantity = 1,
  VoidCallback? onArrive,
  Color seedColor = const Color(0xFF1F3D2B),
  Color accentColor = const Color(0xFFE0A63A),
}) {
  final start = _centerOf(fromKey);
  final end = _centerOf(toKey);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (start == null || end == null || overlay == null) {
    onArrive?.call();
    return;
  }
  final screenWidth = MediaQuery.sizeOf(context).width;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FlyToCartOverlay(
      start: start,
      end: end,
      screenWidth: screenWidth,
      thumbnail: thumbnail,
      quantity: quantity,
      seedColor: seedColor,
      accentColor: accentColor,
      onArrive: onArrive,
      onDone: () {
        entry.remove();
        WidgetsBinding.instance.addPostFrameCallback((_) => entry.dispose());
      },
    ),
  );
  overlay.insert(entry);
  HapticFeedback.selectionClick();
}

class _FlyToCartOverlay extends StatefulWidget {
  const _FlyToCartOverlay({
    required this.start,
    required this.end,
    required this.screenWidth,
    required this.thumbnail,
    required this.quantity,
    required this.seedColor,
    required this.accentColor,
    required this.onDone,
    this.onArrive,
  });

  final Offset start;
  final Offset end;
  final double screenWidth;
  final Widget thumbnail;
  final int quantity;
  final Color seedColor;
  final Color accentColor;
  final VoidCallback? onArrive;
  final VoidCallback onDone;

  @override
  State<_FlyToCartOverlay> createState() => _FlyToCartOverlayState();
}

class _FlyToCartOverlayState extends State<_FlyToCartOverlay>
    with SingleTickerProviderStateMixin {
  static const double _startSize = 68;
  static const double _endSize = 24;
  static const double _popEnd = 0.10;
  static const double _flightStart = 0.08;
  static const double _arrive = 0.62;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  late final Offset _control = _computeControl();
  bool _arrived = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
    _c.forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onTick() {
    if (!_arrived && _c.value >= _arrive) {
      _arrived = true;
      widget.onArrive?.call();
      HapticFeedback.lightImpact();
    }
  }

  Offset _computeControl() {
    final s = widget.start;
    final e = widget.end;
    final mid = (s + e) / 2;
    final d = e - s;
    final len = d.distance;
    if (len < 1) return mid;
    final n = Offset(-d.dy, d.dx) / len;
    final cx = widget.screenWidth / 2;
    final toward = ((mid + n).dx - cx).abs() < ((mid - n).dx - cx).abs()
        ? n
        : -n;
    return mid + toward * (len * 0.30);
  }

  Offset _bezier(double t) {
    final u = 1 - t;
    return widget.start * (u * u) +
        _control * (2 * u * t) +
        widget.end * (t * t);
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.seedColor;
    final accent = widget.accentColor;
    final end = widget.end;

    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              final children = <Widget>[];
              final flightRaw = ((v - _flightStart) / (_arrive - _flightStart))
                  .clamp(0.0, 1.0);
              final flightT = Curves.easeInOutCubic.transform(flightRaw);
              if (v > _flightStart && v < _arrive) {
                final fade =
                    1 - ((v - 0.54) / (_arrive - 0.54)).clamp(0.0, 1.0);
                for (var k = 1; k <= 6; k++) {
                  final raw = flightRaw - k * 0.05;
                  if (raw <= 0) continue;
                  final p = _bezier(Curves.easeInOutCubic.transform(raw));
                  final size = (11 - k * 1.3) * (1 - flightRaw * 0.25);
                  final alpha = ((0.6 - k * 0.08) * fade).clamp(0.0, 1.0);
                  children.add(
                    Positioned(
                      left: p.dx - size / 2,
                      top: p.dy - size / 2,
                      width: size,
                      height: size,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (k.isEven ? seed : accent).withValues(
                            alpha: alpha,
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }
              }
              if (v < _arrive) {
                final popT = Curves.easeOutBack.transform(
                  (v / _popEnd).clamp(0.0, 1.0),
                );
                final shrink = Curves.easeInOut.transform(flightRaw);
                final landing = ((v - 0.56) / (_arrive - 0.56)).clamp(0.0, 1.0);
                final size = lerpDouble(_startSize, _endSize, shrink)!;
                final radius = lerpDouble(16, size / 2, shrink)!;
                final pos = flightRaw <= 0 ? widget.start : _bezier(flightT);
                children.add(
                  Positioned(
                    left: pos.dx - size / 2,
                    top: pos.dy - size / 2,
                    width: size,
                    height: size,
                    child: Transform.rotate(
                      angle: flightT * 0.5,
                      child: Transform.scale(
                        scale: popT * (1 - landing),
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(radius),
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: seed.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: widget.thumbnail,
                        ),
                      ),
                    ),
                  ),
                );
              }
              if (v >= _arrive) {
                final a = ((v - _arrive) / (1 - _arrive)).clamp(0.0, 1.0);
                final ease = Curves.easeOutCubic.transform(a);

                final ringR = lerpDouble(10, 34, ease)!;
                children.add(
                  Positioned(
                    left: end.dx - ringR,
                    top: end.dy - ringR,
                    width: ringR * 2,
                    height: ringR * 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: (1 - a) * 0.85),
                          width: 3 * (1 - a) + 0.5,
                        ),
                      ),
                    ),
                  ),
                );
                const dots = 8;
                for (var i = 0; i < dots; i++) {
                  final angle = (2 * math.pi / dots) * i;
                  final dist = lerpDouble(12, 32, ease)!;
                  final r = 3.4 * (1 - a);
                  children.add(
                    Positioned(
                      left: end.dx + math.cos(angle) * dist - r,
                      top: end.dy + math.sin(angle) * dist - r,
                      width: r * 2,
                      height: r * 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: (i.isEven ? accent : seed).withValues(
                            alpha: (1 - a).clamp(0.0, 1.0),
                          ),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }
                final pillIn = Curves.easeOutBack.transform(
                  (a / 0.35).clamp(0.0, 1.0),
                );
                final pillOut = ((a - 0.65) / 0.35).clamp(0.0, 1.0);
                final dy = 26 + 22 * Curves.easeOut.transform(a);
                children.add(
                  Positioned(
                    left: (end.dx - 28).clamp(4.0, widget.screenWidth - 60),
                    top: end.dy + dy,
                    width: 56,
                    child: Center(
                      child: Opacity(
                        opacity: (1 - pillOut).clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale: pillIn,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              '+${widget.quantity}',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: seed,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Stack(clipBehavior: Clip.none, children: children);
            },
          ),
        ),
      ),
    );
  }
}
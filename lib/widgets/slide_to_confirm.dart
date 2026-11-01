import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    super.key,
    required this.label,
    required this.onConfirm,
    this.enabled = true,
    this.color = const Color(0xFF1F3D2B),
    this.height = 58,
  });

  final String label;
  final Future<bool> Function() onConfirm;
  final bool enabled;
  final Color color;
  final double height;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm>
    with TickerProviderStateMixin {
  static const double _pad = 5;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  late final AnimationController _hint = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  bool _busy = false;
  bool _success = false;
  bool _pastHalf = false;

  @override
  void dispose() {
    _c.dispose();
    _hint.dispose();
    super.dispose();
  }

  bool get _locked => _busy || _success || !widget.enabled;

  void _onDragUpdate(DragUpdateDetails d, double maxDrag) {
    if (_locked || maxDrag <= 0) return;
    _c.value = (_c.value + d.delta.dx / maxDrag).clamp(0.0, 1.0);
    if (_c.value > 0.5 && !_pastHalf) {
      _pastHalf = true;
      HapticFeedback.selectionClick();
    } else if (_c.value <= 0.5) {
      _pastHalf = false;
    }
  }

  void _onDragEnd(DragEndDetails d) {
    if (_locked) return;
    final fast = (d.primaryVelocity ?? 0) > 900 && _c.value > 0.4;
    if (_c.value >= 0.85 || fast) {
      _confirm();
    } else {
      _pastHalf = false;
      _c.animateTo(0, duration: Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    }
  }

  Future<void> _nudge() async {
    if (_locked) return;
    HapticFeedback.lightImpact();
    await _c.animateTo(0.22, duration: Duration(milliseconds: 170), curve: Curves.easeOut);
    if (!mounted || _locked) return;
    await _c.animateTo(0, duration: Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await _c.animateTo(1, duration: Duration(milliseconds: 140), curve: Curves.easeOut);
    if (!mounted) return;
    HapticFeedback.mediumImpact();

    var ok = false;
    try {
      ok = await widget.onConfirm();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;

    if (ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _success = true;
      });
      await Future<void>.delayed(Duration(milliseconds: 650));
    } else {
      HapticFeedback.vibrate();
      setState(() => _busy = false);
    }
    if (!mounted) return;
    await _c.animateTo(0, duration: Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    if (!mounted) return;
    setState(() {
      _success = false;
      _pastHalf = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final h = widget.height;
    final handle = h - _pad * 2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDrag = constraints.maxWidth - handle - _pad * 2;

        return Opacity(
          opacity: widget.enabled ? 1 : 0.5,
          child: SizedBox(
            height: h,
            child: AnimatedBuilder(
              animation: Listenable.merge([_c, _hint]),
              builder: (context, _) {
                final p = _c.value;
                final x = _pad + maxDrag * p;
                final fillWidth = x + handle + _pad;
                final labelOpacity = (1 - p * 1.7).clamp(0.0, 1.0);
                final doneOpacity = ((p - 0.7) / 0.3).clamp(0.0, 1.0);
                final showDone = _busy || _success;
                final hintDx = (_busy || _success || p > 0.02)
                    ? 0.0
                    : Curves.easeInOut.transform(_hint.value) * 4;

                final Widget handleIcon;
                if (_success) {
                  handleIcon = Icon(Icons.check_rounded, key: ValueKey('ok'), color: color, size: 26);
                } else if (_busy) {
                  handleIcon = SizedBox(
                    key: ValueKey('busy'),
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.6, color: color),
                  );
                } else {
                  handleIcon = Transform.translate(
                    key: ValueKey('arrow'),
                    offset: Offset(hintDx, 0),
                    child: Icon(Icons.keyboard_double_arrow_right_rounded, color: color, size: 26),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Track.
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(h / 2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: fillWidth.clamp(0.0, constraints.maxWidth),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.lerp(color, Colors.white, 0.22),
                          borderRadius: BorderRadius.circular(h / 2),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(left: handle + _pad * 2 + 6, right: 18),
                        child: Center(
                          child: Opacity(
                            opacity: labelOpacity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withValues(alpha: 0.92),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showDone)
                      Positioned.fill(
                        child: Padding(
                          padding: EdgeInsets.only(right: handle + _pad * 2),
                          child: Center(
                            child: Opacity(
                              opacity: doneOpacity,
                              child: Text(
                                _success ? 'Done!' : 'Updating...',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    // Handle.
                    Positioned(
                      left: x,
                      top: _pad,
                      width: handle,
                      height: handle,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _nudge,
                        onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxDrag),
                        onHorizontalDragEnd: _onDragEnd,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutBack,
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(scale: animation, child: child),
                              child: handleIcon,
                            ),
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
      },
    );
  }
}
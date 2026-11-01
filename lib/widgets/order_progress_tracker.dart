import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderStep {
  const OrderStep(this.label, this.icon);

  final String label;
  final IconData icon;
}

class OrderProgressTracker extends StatefulWidget {
  const OrderProgressTracker({
    super.key,
    required this.steps,
    required this.currentIndex,
    this.finished = false,
    this.showCourier = false,
    this.seedColor = const Color(0xFF1F3D2B),
  });

  final List<OrderStep> steps;
  final int currentIndex;
  final bool finished;
  final bool showCourier;
  final Color seedColor;

  @override
  State<OrderProgressTracker> createState() => _OrderProgressTrackerState();
}

class _OrderProgressTrackerState extends State<OrderProgressTracker>
    with SingleTickerProviderStateMixin {
  static const double _node = 28;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void initState() {
    super.initState();
    if (!widget.finished) _pulse.repeat();
  }

  @override
  void didUpdateWidget(OrderProgressTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.finished) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Widget _courier() {
    final seed = widget.seedColor;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final bob = math.sin(_pulse.value * 2 * math.pi) * 1.5;
        return Transform.translate(
          offset: Offset(0, bob),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: seed, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: seed.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.moped_rounded, size: 14, color: seed),
          ),
        );
      },
    );
  }

  Widget _step(int i, double progress, int current) {
    final seed = widget.seedColor;
    final n = widget.steps.length;
    final pos = i / (n - 1);
    final reached = progress >= pos - 0.0005;
    final isCurrent = !widget.finished && i == current && reached;
    final isDone = reached && (widget.finished || i < current);
    final step = widget.steps[i];
    final icon = isDone ? Icons.check_rounded : step.icon;

    return Column(
      children: [
        SizedBox(
          width: _node,
          height: _node,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (isCurrent)
                Positioned.fill(
                  child: OverflowBox(
                    maxWidth: _node + 24,
                    maxHeight: _node + 24,
                    child: AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, _) {
                        final t = Curves.easeOut.transform(_pulse.value);
                        final size = _node + 20 * t;
                        return Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: seed.withValues(alpha: (1 - t) * 0.25),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              Positioned.fill(
                child: AnimatedScale(
                  scale: reached ? 1.0 : 0.88,
                  duration: Duration(milliseconds: 380),
                  curve: Curves.easeOutBack,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: reached ? seed : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: reached ? seed : seed.withValues(alpha: 0.25),
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: Duration(milliseconds: 250),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Icon(
                          icon,
                          key: ValueKey('$i-${icon.codePoint}'),
                          size: 15,
                          color: reached
                              ? Colors.white
                              : seed.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 6),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 1),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              step.label,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: reached ? FontWeight.w800 : FontWeight.w600,
                color: reached ? seed : seed.withValues(alpha: 0.45),
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.steps;
    final n = steps.length;
    final seed = widget.seedColor;
    final lastIndex = n - 1;
    final current = widget.finished
        ? lastIndex
        : widget.currentIndex.clamp(0, lastIndex);
    final target = current / lastIndex;

    return LayoutBuilder(
      builder: (context, constraints) {
        final colW = constraints.maxWidth / n;
        final spanLeft = colW / 2;
        final spanW = constraints.maxWidth - colW;

        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: target),
          duration: Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
          builder: (context, progress, _) {
            final traveling =
                widget.showCourier &&
                !widget.finished &&
                progress > 0 &&
                progress < target - 0.003;

            return SizedBox(
              height: _node + 6 + 16,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: spanLeft,
                    top: _node / 2 - 2,
                    width: spanW,
                    height: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ColoredBox(
                              color: seed.withValues(alpha: 0.12),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: spanW * progress.clamp(0.0, 1.0),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    seed,
                                    Color.lerp(seed, Colors.white, 0.28)!,
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(child: _step(i, progress, current)),
                    ],
                  ),
                  if (traveling)
                    Positioned(
                      left: spanLeft + spanW * progress - 11,
                      top: _node / 2 - 11,
                      width: 22,
                      height: 22,
                      child: _courier(),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DeliveryProgressTrack extends StatelessWidget {
  const DeliveryProgressTrack({
    super.key,
    required this.status,
    required this.seedColor,
  });

  final String status;
  final Color seedColor;

  static const _steps = ['Assigned', 'Picked Up', 'Out for Delivery', 'Delivered'];
  static const _labels = ['Assigned', 'Picked up', 'On the way', 'Delivered'];

  static const _slide = Duration(milliseconds: 800);
  static const _curve = Curves.easeInOutCubic;

  @override
  Widget build(BuildContext context) {
    final found = _steps.indexOf(status);
    final current = found < 0 ? 0 : found;

    return SizedBox(
      height: 74,
      child: LayoutBuilder(
        builder: (context, constraints) {
          const inset = 18.0;
          const trackY = 40.0;
          final width = constraints.maxWidth;
          final usable = width - inset * 2;
          double x(int i) => inset + usable * i / (_steps.length - 1);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Grey track.
              Positioned(
                left: x(0),
                right: width - x(_steps.length - 1),
                top: trackY - 2,
                height: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: _slide,
                curve: _curve,
                left: x(0),
                top: trackY - 2,
                height: 4,
                width: x(current) - x(0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: seedColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              for (var i = 0; i < _steps.length; i++) ...[
                Positioned(
                  left: x(i) - 9,
                  top: trackY - 9,
                  child: _Stop(
                    done: i < current || (i == current && i == _steps.length - 1),
                    current: i == current,
                    seedColor: seedColor,
                  ),
                ),
                Positioned(
                  left: x(i) - 36,
                  top: trackY + 16,
                  width: 72,
                  child: AnimatedDefaultTextStyle(
                    duration: Duration(milliseconds: 300),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: i == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: i <= current ? seedColor : Colors.grey[500],
                    ),
                    child: Text(
                      _labels[i],
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
              // The moped.
              AnimatedPositioned(
                duration: _slide,
                curve: _curve,
                left: x(current) - 15,
                top: 0,
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: seedColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: seedColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(Icons.two_wheeler, color: Colors.white, size: 17),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.done,
    required this.current,
    required this.seedColor,
  });

  final bool done;
  final bool current;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final filled = done;
    return AnimatedContainer(
      duration: Duration(milliseconds: 350),
      curve: Curves.easeOut,
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? seedColor : Colors.white,
        border: Border.all(
          color: (filled || current) ? seedColor : Colors.grey.shade300,
          width: current && !filled ? 4 : 2,
        ),
      ),
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: filled ? 1.0 : 0.0,
        duration: Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        child: Icon(Icons.check_rounded, size: 12, color: Colors.white),
      ),
    );
  }
}
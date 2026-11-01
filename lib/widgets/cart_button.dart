import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CartButton extends StatelessWidget {
  const CartButton({
    super.key,
    this.onTap,
    this.itemCount,
    this.animate = true,
  });

  final VoidCallback? onTap;
  final int? itemCount;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (itemCount != null) {
      return _CartIcon(
        count: itemCount!,
        pulse: animate ? itemCount : null,
        onTap: onTap,
      );
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return _CartIcon(count: 0, pulse: null, onTap: onTap);
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final cartItems =
            snapshot.data?.data()?['cartItems'] as Map? ?? const {};
        final count = cartItems.length;
        final int? pulse = (animate && snapshot.hasData)
            ? cartItems.values
                  .fold<num>(0, (total, v) => total + (v is num ? v : 0))
                  .round()
            : null;

        return _CartIcon(count: count, pulse: pulse, onTap: onTap);
      },
    );
  }
}

class _CartIcon extends StatefulWidget {
  const _CartIcon({
    required this.count,
    required this.pulse,
    required this.onTap,
  });

  final int count;
  final int? pulse;
  final VoidCallback? onTap;

  @override
  State<_CartIcon> createState() => _CartIconState();
}

class _CartIconState extends State<_CartIcon>
    with SingleTickerProviderStateMixin {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _accentColor = Color(0xFFE0A63A);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: 560),
  );

  late final Animation<double> _iconScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.28,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.28,
        end: 0.92,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 25,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 0.92,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 50,
    ),
  ]).animate(_controller);

  late final Animation<double> _badgeScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.7,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.7,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _CartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    final before = oldWidget.pulse;
    final now = widget.pulse;
    if (before != null && now != null && now > before) {
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
    final count = widget.count;

    return ScaleTransition(
      scale: _iconScale,
      child: Material(
        color: Colors.white,
        shape: CircleBorder(),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(8),
            child: SizedBox(
              width: 22,
              height: 22,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    color: _seedColor,
                    size: 22,
                  ),
                  if (count > 0)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: ScaleTransition(
                        scale: _badgeScale,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          constraints: BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _accentColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            count > 99 ? '99+' : '$count',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _seedColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
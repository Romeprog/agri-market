import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/delivery_service.dart';

class _RiderSheetColors {
  static const _seedColor = Color(0xFF1F3D2B);
  static const _bgColor = Color(0xFFEFF1E4);
}

Future<bool?> showAssignRiderSheet(
  BuildContext context, {
  required String orderId,
  required String buyerId,
  bool isPickupOnly = false,
  String? excludeRiderId,
}) {
  if (isPickupOnly) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("This order is pickup only. Riders can't be assigned."),
      ),
    );
    return Future.value(false);
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AssignRiderSheet(
      orderId: orderId,
      buyerId: buyerId,
      excludeRiderId: excludeRiderId,
    ),
  );
}

class AssignRiderSheet extends StatefulWidget {
  const AssignRiderSheet({
    super.key,
    required this.orderId,
    required this.buyerId,
    this.excludeRiderId,
  });

  final String orderId;
  final String buyerId;

  final String? excludeRiderId;

  @override
  State<AssignRiderSheet> createState() => _AssignRiderSheetState();
}

class _AssignRiderSheetState extends State<AssignRiderSheet> {
  final _service = DeliveryService();
  String? _assigningRiderId;
  bool _assigned = false;
  bool _noRiderNotificationSent = false;

  void _notifyBuyerOnce() {
    if (_noRiderNotificationSent) return;
    _noRiderNotificationSent = true;
    _service
        .notifyBuyerNoRiderAvailable(
          orderId: widget.orderId,
          buyerId: widget.buyerId,
        )
        .catchError((_) {});
  }

  Future<void> _assign(String riderId) async {
    setState(() => _assigningRiderId = riderId);
    try {
      await _service.offerToRider(orderId: widget.orderId, riderId: riderId);
      if (!mounted) return;
      // Show the success state briefly, then let the sheet slide away.
      setState(() => _assigned = true);
      await Future.delayed(Duration(milliseconds: 650));
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send request: $e')));
        setState(() => _assigningRiderId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: _RiderSheetColors._bgColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _RiderSheetColors._seedColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _RiderSheetColors._seedColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.moped, color: _RiderSheetColors._bgColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assign a Rider',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _RiderSheetColors._seedColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Only available riders are shown. They have 30 seconds to accept.',
                        style: textTheme.bodySmall?.copyWith(
                          color: _RiderSheetColors._seedColor.withValues(
                            alpha: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _assigningRiderId == null
                      ? () => Navigator.of(context).pop(false)
                      : null,
                  icon: Icon(
                    Icons.close_rounded,
                    color: _RiderSheetColors._seedColor.withValues(alpha: 0.5),
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
            SizedBox(height: 16),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 420),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _service.streamAvailableRiders(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _StateMessage(
                      icon: Icons.error_outline_rounded,
                      title: "Couldn't load available riders.",
                      subtitle: '${snapshot.error}',
                      onClose: () => Navigator.of(context).pop(false),
                    );
                  }
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: _RiderSheetColors._seedColor,
                        ),
                      ),
                    );
                  }
                  final riders = snapshot.data!.docs
                      .where((d) => d.id != widget.excludeRiderId)
                      .toList();
                  if (riders.isEmpty) {
                    if (widget.excludeRiderId == null) {
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _notifyBuyerOnce(),
                      );
                    }
                    return _StateMessage(
                      icon: Icons.moped_outlined,
                      title: 'No riders are available right now.',
                      subtitle: widget.excludeRiderId == null
                          ? 'The buyer will be prompted to choose pickup or '
                                'wait for the next available rider.'
                          : 'No other rider is available at the moment.',
                      onClose: () => Navigator.of(context).pop(false),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: riders.length,
                    separatorBuilder: (context, index) =>
                        SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final doc = riders[index];
                      final data = doc.data();
                      final name =
                          data['fullName'] as String? ??
                          data['name'] as String? ??
                          'Rider';
                      final vehicle = data['vehicleType'] as String?;
                      final isAssigning = _assigningRiderId == doc.id;

                      return _StaggerIn(
                        key: ValueKey(doc.id),
                        index: index,
                        child: AnimatedOpacity(
                          opacity: _assigned && !isAssigning ? 0.3 : 1,
                          duration: Duration(milliseconds: 250),
                          child: _RiderTile(
                            name: name,
                            vehicle: vehicle,
                            isAssigning: isAssigning && !_assigned,
                            isAssigned: isAssigning && _assigned,
                            isDisabled:
                                _assigningRiderId != null && !isAssigning,
                            onAssign: () => _assign(doc.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiderTile extends StatelessWidget {
  const _RiderTile({
    required this.name,
    required this.vehicle,
    required this.isAssigning,
    required this.isAssigned,
    required this.isDisabled,
    required this.onAssign,
  });

  final String name;
  final String? vehicle;
  final bool isAssigning;
  final bool isAssigned;
  final bool isDisabled;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: Duration(milliseconds: 250),
      curve: Curves.easeOut,
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _RiderSheetColors._seedColor.withValues(
          alpha: isAssigned ? 0.14 : 0.05,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _RiderSheetColors._seedColor.withValues(
            alpha: isAssigned ? 0.8 : 0.15,
          ),
          width: isAssigned ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _RiderSheetColors._seedColor.withValues(
              alpha: 0.12,
            ),
            child: Icon(
              Icons.moped,
              color: _RiderSheetColors._seedColor,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: _RiderSheetColors._seedColor,
                  ),
                ),
                if (vehicle != null) ...[
                  SizedBox(height: 2),
                  Text(
                    vehicle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: _RiderSheetColors._seedColor.withValues(
                        alpha: 0.55,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 8),
          isAssigned
              ? _CheckPop()
              : isAssigning
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _RiderSheetColors._seedColor,
                  ),
                )
              : FilledButton(
                  onPressed: isDisabled ? null : onAssign,
                  style: FilledButton.styleFrom(
                    backgroundColor: _RiderSheetColors._seedColor,
                    foregroundColor: _RiderSheetColors._bgColor,
                    disabledBackgroundColor: _RiderSheetColors._seedColor
                        .withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: Text(
                    'Assign',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _RiderSheetColors._seedColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: _RiderSheetColors._seedColor),
          ),
          SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: _RiderSheetColors._seedColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: _RiderSheetColors._seedColor.withValues(alpha: 0.55),
            ),
          ),
          SizedBox(height: 14),
          OutlinedButton(
            onPressed: onClose,
            style: OutlinedButton.styleFrom(
              foregroundColor: _RiderSheetColors._seedColor,
              side: BorderSide(
                color: _RiderSheetColors._seedColor.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Fades and slides a child up, delayed by its position in the list.
class _StaggerIn extends StatefulWidget {
  const _StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<_StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<_StaggerIn>
    with SingleTickerProviderStateMixin {
  static const _step = Duration(milliseconds: 70);
  static const _tileDuration = Duration(milliseconds: 380);

  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    final delay = _step * widget.index.clamp(0, 6);
    final total = delay + _tileDuration;
    _controller = AnimationController(vsync: this, duration: total);
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(
        delay.inMilliseconds / total.inMilliseconds,
        1,
        curve: Curves.easeOutCubic,
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset(0, 0.25),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Check icon that pops in once an offer has been sent.
class _CheckPop extends StatelessWidget {
  const _CheckPop();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350),
      curve: Curves.easeOutBack,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Icon(
        Icons.check_circle_rounded,
        size: 26,
        color: _RiderSheetColors._seedColor,
      ),
    );
  }
}
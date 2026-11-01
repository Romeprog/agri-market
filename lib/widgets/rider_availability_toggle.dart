import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/delivery_service.dart';

class RiderAvailabilityToggle extends StatefulWidget {
  const RiderAvailabilityToggle({super.key});

  @override
  State<RiderAvailabilityToggle> createState() =>
      _RiderAvailabilityToggleState();
}

class _RiderAvailabilityToggleState extends State<RiderAvailabilityToggle> {
  static const _seedColor = Color(0xFF1F3D2B);

  final _service = DeliveryService();
  bool _updating = false;

  Future<void> _toggle(bool value) async {
    setState(() => _updating = true);
    try {
      await _service.setRiderAvailability(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update availability. Please try again.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _service.streamMyUserDoc(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final isAvailable = data?['isAvailable'] as bool? ?? false;
        final canToggle = snapshot.hasData && !_updating;

        return Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _seedColor.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (isAvailable ? _seedColor : Colors.grey).withValues(
                    alpha: 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 200),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      isAvailable ? Icons.moped : Icons.moped_outlined,
                      key: ValueKey(isAvailable),
                      size: 20,
                      color: isAvailable ? _seedColor : Colors.grey[500],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Available for deliveries',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: Duration(milliseconds: 200),
                      child: Text(
                        isAvailable
                            ? 'New orders can reach you right now.'
                            : "New orders can't reach you right now.",
                        key: ValueKey(isAvailable),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              _updating
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _seedColor,
                      ),
                    )
                  : _AvailabilitySwitch(
                      value: isAvailable,
                      enabled: canToggle,
                      onChanged: _toggle,
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _AvailabilitySwitch extends StatelessWidget {
  const _AvailabilitySwitch({
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _offColor = Color(0xFFBFC4B8);

  static const double _width = 58;
  static const double _height = 32;
  static const double _thumbSize = 24;
  static const Duration _duration = Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? () => onChanged(!value) : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          width: _width,
          height: _height,
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: value ? _seedColor : _offColor,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: Stack(
            children: [
              AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOut,
                alignment: value
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    value ? 'ON' : 'OFF',
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ),
              AnimatedAlign(
                duration: _duration,
                curve: Curves.easeOutBack,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: _thumbSize,
                  height: _thumbSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 180),
                      transitionBuilder: (child, animation) =>
                          ScaleTransition(scale: animation, child: child),
                      child: Icon(
                        value ? Icons.moped : Icons.moped_outlined,
                        key: ValueKey(value),
                        size: 14,
                        color: value ? _seedColor : Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/delivery_service.dart';

class FulfillmentChoicePrompt extends StatefulWidget {
  const FulfillmentChoicePrompt({super.key, required this.orderId});

  final String orderId;

  @override
  State<FulfillmentChoicePrompt> createState() =>
      _FulfillmentChoicePromptState();
}

class _FulfillmentChoicePromptState extends State<FulfillmentChoicePrompt> {
  static const Color _seedColor = Color(0xFF1F3D2B);

  final _service = DeliveryService();
  bool _submitting = false;

  Future<void> _choose(String choice) async {
    setState(() => _submitting = true);
    try {
      await _service.setFulfillmentChoice(
        orderId: widget.orderId,
        choice: choice,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save your choice: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _label(String text) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        if (data == null) return const SizedBox.shrink();

        final status = data['status'] as String?;
        final riderId = data['riderId'] as String?;
        final choice = data['fulfillmentChoice'] as String?;
        final riderSearchState = data['riderSearchState'] as String?;

        final searchFailed = riderSearchState == 'no_riders_available';

        if (status != 'Processing' || riderId != null) {
          return const SizedBox.shrink();
        }
        if (!searchFailed && choice == null) {
          return const SizedBox.shrink();
        }

        final hasChoice = choice != null;

        return Container(
          width: double.infinity,
          margin: EdgeInsets.only(top: 10, bottom: 4),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _seedColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _seedColor.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasChoice
                          ? Icons.check_circle_outline
                          : Icons.moped_outlined,
                      color: _seedColor,
                      size: 20,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      hasChoice
                          ? 'Choice saved'
                          : "The seller couldn't find a rider yet",
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _seedColor,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10),
              if (!hasChoice) ...[
                Text(
                  'Would you like to pick this order up yourself, or wait '
                  'for the next available rider?',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => _choose('Pickup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _seedColor,
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: _seedColor.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          minimumSize: Size.fromHeight(48),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _label('Pick up myself'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : () => _choose('Wait'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _seedColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey[300],
                          minimumSize: Size.fromHeight(48),
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _label('Wait for a rider'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  choice == 'Pickup'
                      ? "You've chosen to pick this order up yourself. The seller will be notified."
                      : "You've chosen to wait, we'll let you know as soon as a rider is assigned.",
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.45,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submitting
                        ? null
                        : () => _choose(choice == 'Pickup' ? 'Wait' : 'Pickup'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _seedColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      minimumSize: Size.fromHeight(48),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _label(
                      choice == 'Pickup'
                          ? 'Actually, wait for a rider'
                          : "Actually, I'll pick it up",
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/delivery_service.dart';
import '../widgets/delivery_proof_sheet.dart';
import '../widgets/rider_availability_toggle.dart';
import '../widgets/success_dialog.dart';

class RiderDeliveriesScreen extends StatefulWidget {
  const RiderDeliveriesScreen({super.key});

  @override
  State<RiderDeliveriesScreen> createState() => _RiderDeliveriesScreenState();
}

class _RiderDeliveriesScreenState extends State<RiderDeliveriesScreen> {
  final _service = DeliveryService();
  final Set<String> _updatingOrderIds = {};

  static const _statusLabels = {
    'Assigned': 'Assigned to you',
    'Picked Up': 'Picked up',
    'Out for Delivery': 'Out for delivery',
  };

  static const _nextActionLabels = {
    'Assigned': 'Mark picked up',
    'Picked Up': 'Mark out for delivery',
    'Out for Delivery': 'Take delivery photo',
  };

  /// The last step needs a camera photo as proof before it can be completed.
  Future<void> _completeWithProof(String orderId) async {
    final done = await showDeliveryProofSheet(
      context,
      orderId: orderId,
      service: _service,
    );
    if (done != true || !mounted) return;
    await showSuccessDialog(
      context: context,
      title: 'Delivered!',
      message: 'Nice work! The buyer can now see your delivery photo.',
      seedColor: Color(0xFF1F3D2B),
      onDone: () => Navigator.of(context, rootNavigator: true).pop(),
    );
  }

  Future<void> _advance(String orderId, String currentStatus) async {
    if (currentStatus == 'Out for Delivery') {
      await _completeWithProof(orderId);
      return;
    }
    setState(() => _updatingOrderIds.add(orderId));
    try {
      await _service.advanceDeliveryStatus(orderId, currentStatus);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update delivery: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingOrderIds.remove(orderId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Deliveries')),
      body: Column(
        children: [
          RiderAvailabilityToggle(),
          Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _service.streamMyDeliveries(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No active deliveries right now. Toggle yourself\n'
                        'available above so sellers can assign you orders.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final deliveryStatus =
                        data['deliveryStatus'] as String? ?? 'Assigned';
                    final total = data['total'];
                    final isUpdating = _updatingOrderIds.contains(doc.id);

                    return Card(
                      margin: EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Order #${doc.id.substring(0, 6)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Chip(
                                  label: Text(
                                    _statusLabels[deliveryStatus] ??
                                        deliveryStatus,
                                  ),
                                ),
                              ],
                            ),
                            if (total != null) ...[
                              SizedBox(height: 4),
                              Text('Total: $total'),
                            ],
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    (isUpdating ||
                                        !_nextActionLabels.containsKey(
                                          deliveryStatus,
                                        ))
                                    ? null
                                    : () => _advance(doc.id, deliveryStatus),
                                child: isUpdating
                                    ? SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (deliveryStatus ==
                                              'Out for Delivery') ...[
                                            Icon(
                                              Icons.photo_camera_outlined,
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                          ],
                                          Text(
                                            _nextActionLabels[deliveryStatus] ??
                                                'Up to date',
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ],
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
    );
  }
}
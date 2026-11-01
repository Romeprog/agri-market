import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rider_application.dart';
import '../services/delivery_service.dart';
import '../services/rider_application_service.dart';
import '../utils/currency.dart';
import '../widgets/delivery_progress_track.dart';
import '../widgets/delivery_proof_sheet.dart';
import '../widgets/floating_gain.dart';
import '../widgets/rider_availability_toggle.dart';
import '../widgets/slide_to_confirm.dart';
import 'chat_screen.dart';

class RiderHomeScreen extends StatelessWidget {
  const RiderHomeScreen({super.key});

  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user == null
          ? null
          : FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final fullName = data?['name'] as String? ?? user?.displayName ?? '';
        final firstName = fullName.trim().isEmpty
            ? null
            : fullName.trim().split(RegExp(r'\s+')).first;
        final area = data?['riderServiceArea'] as String? ?? '\u2014';
        final isRider = data?['isRider'] == true;
        final applicationStatus = data?['riderApplicationStatus'] as String?;

        return StreamBuilder<RiderApplication?>(
          stream: RiderApplicationService.myApplication(),
          builder: (context, appSnapshot) {
            final vehicle = appSnapshot.data?.vehicleType ?? '\u2014';

            return Scaffold(
              backgroundColor: _bgColor,
              appBar: PreferredSize(
                preferredSize: Size.fromHeight(kToolbarHeight + 10),
                child: AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  titleSpacing: 16,
                  flexibleSpace: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    child: Container(
                      decoration: BoxDecoration(color: _seedColor),
                    ),
                  ),
                  title: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName == null ? 'Hello!' : 'Hello $firstName!',
                        style: GoogleFonts.fraunces(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _bgColor,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Ready to deliver fresh produce?',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _bgColor.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              body: SafeArea(
                bottom: false,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 24),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.two_wheeler_outlined,
                            label: 'Vehicle',
                            value: vehicle,
                            seedColor: _seedColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.map_outlined,
                            label: 'Service area',
                            value: area,
                            seedColor: _seedColor,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(0, 22, 0, 10),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 16,
                            decoration: BoxDecoration(
                              color: _seedColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Deliveries',
                            style: GoogleFonts.fraunces(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _seedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isRider) ...[
                      Padding(
                        padding: EdgeInsets.only(top: 4, bottom: 10),
                        child: RiderAvailabilityToggle(),
                      ),
                      _OffersSection(seedColor: _seedColor),
                      _DeliveriesSection(seedColor: _seedColor),
                    ] else
                      Padding(
                        padding: EdgeInsets.only(top: 32),
                        child: _RiderNotApprovedYet(
                          seedColor: _seedColor,
                          status: applicationStatus,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.seedColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: seedColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: seedColor),
          ),
          SizedBox(height: 10),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: seedColor,
            ),
          ),
          SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveriesSection extends StatefulWidget {
  const _DeliveriesSection({required this.seedColor});

  final Color seedColor;

  @override
  State<_DeliveriesSection> createState() => _DeliveriesSectionState();
}

class _DeliveriesSectionState extends State<_DeliveriesSection> {
  final _service = DeliveryService();
  final Set<String> _updatingOrderIds = {};

  final Map<String, ({int index, Map<String, dynamic> data})> _justDelivered =
      {};

  static const _statusLabels = {
    'Assigned': 'Assigned to you',
    'Picked Up': 'Picked up',
    'Out for Delivery': 'Out for delivery',
    'Delivered': 'Delivered',
  };

  static const _nextActionLabels = {
    'Assigned': 'Slide to mark picked up',
    'Picked Up': 'Slide to start delivery',
    'Out for Delivery': 'Slide to take delivery photo',
  };

  Future<bool> _advance(
    String orderId,
    String currentStatus, {
    required int index,
    required Map<String, dynamic> data,
  }) async {
    if (!_updatingOrderIds.add(orderId)) return false;
    final finishing = currentStatus == 'Out for Delivery';
    try {
      if (finishing) {
        // Keep the card on screen while the rider takes the delivery photo.
        setState(() {
          _justDelivered[orderId] = (index: index, data: data);
        });
        // The sheet uploads the photo and marks the order delivered.
        final done = await showDeliveryProofSheet(
          context,
          orderId: orderId,
          service: _service,
        );
        if (done != true) {
          // Cancelled: put the card back and let the slider snap back.
          if (mounted) setState(() => _justDelivered.remove(orderId));
          return false;
        }
        if (mounted) {
          setState(() {
            _justDelivered[orderId] = (
              index: index,
              data: {...data, 'deliveryStatus': 'Delivered'},
            );
          });
        }
        Future.delayed(Duration(milliseconds: 2400), () {
          if (mounted) setState(() => _justDelivered.remove(orderId));
        });
        return true;
      }
      await _service.advanceDeliveryStatus(orderId, currentStatus);
      return true;
    } catch (e) {
      if (finishing && mounted) {
        setState(() => _justDelivered.remove(orderId));
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not update delivery. Please try again.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    } finally {
      _updatingOrderIds.remove(orderId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.streamMyDeliveries(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text(
              'Could not load your deliveries right now.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: CircularProgressIndicator(color: widget.seedColor),
            ),
          );
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty && _justDelivered.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 32),
            child: _NoDeliveriesYet(seedColor: widget.seedColor),
          );
        }
        final items = <({String id, Map<String, dynamic> data})>[
          for (final doc in docs)
            (id: doc.id, data: _justDelivered[doc.id]?.data ?? doc.data()),
        ];
        for (final entry in _justDelivered.entries) {
          if (docs.any((d) => d.id == entry.key)) continue;
          final at = entry.value.index.clamp(0, items.length);
          items.insert(at, (id: entry.key, data: entry.value.data));
        }
        return Column(
          children: [
            for (var i = 0; i < items.length; i++)
              Padding(
                key: ValueKey(items[i].id),
                padding: EdgeInsets.only(bottom: 12),
                child: FloatingGain(
                  active: items[i].data['deliveryStatus'] == 'Delivered' &&
                      ((items[i].data['shippingFee'] as num?) ?? 0) > 0,
                  text:
                      '+${formatPeso(((items[i].data['shippingFee'] as num?) ?? 0).toDouble())}',
                  seedColor: widget.seedColor,
                  child: _DeliveryCard(
                  orderId: items[i].id,
                  data: items[i].data,
                  seedColor: widget.seedColor,
                  statusLabels: _statusLabels,
                  nextActionLabel:
                      _nextActionLabels[items[i].data['deliveryStatus']
                              as String? ??
                          ''],
                  onAdvance: () => _advance(
                    items[i].id,
                    items[i].data['deliveryStatus'] as String? ?? 'Assigned',
                    index: i,
                    data: items[i].data,
                  ),
                ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DeliveryCard extends StatelessWidget {
  const _DeliveryCard({
    required this.orderId,
    required this.data,
    required this.seedColor,
    required this.statusLabels,
    required this.nextActionLabel,
    required this.onAdvance,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final Color seedColor;
  final Map<String, String> statusLabels;
  final String? nextActionLabel;
  final Future<bool> Function() onAdvance;

  @override
  Widget build(BuildContext context) {
    final deliveryStatus = data['deliveryStatus'] as String? ?? 'Assigned';
    final total = (data['total'] as num?)?.toDouble() ?? 0;
    final buyerName = data['deliveryName'] as String? ?? '';
    final buyerAddress = data['deliveryAddress'] as String? ?? '';
    final buyerId = data['userId'] as String? ?? '';
    final sellerId = data['farmerId'] as String? ?? '';
    final sellerName = data['farmerName'] as String? ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${orderId.substring(0, orderId.length < 8 ? orderId.length : 8).toUpperCase()}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: seedColor, width: 1),
                  ),
                  child: Text(
                    statusLabels[deliveryStatus] ?? deliveryStatus,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: seedColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            DeliveryProgressTrack(status: deliveryStatus, seedColor: seedColor),
            if (buyerName.isNotEmpty || buyerAddress.isNotEmpty) ...[
              SizedBox(height: 10),
              Divider(height: 1, color: Colors.grey.shade100),
              SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: seedColor.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.place_outlined,
                      size: 14,
                      color: seedColor,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deliver to',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          buyerName.isEmpty ? 'No name provided' : buyerName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (buyerAddress.isNotEmpty)
                          Text(
                            buyerAddress,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (buyerId.isNotEmpty || sellerId.isNotEmpty) ...[
                SizedBox(height: 12),
                Row(
                  children: [
                    if (buyerId.isNotEmpty)
                      Expanded(
                        child: _ContactActionButton(
                          icon: Icons.person_outline,
                          label: 'Message Buyer',
                          seedColor: seedColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: buyerId,
                                  otherUserName: buyerName.isEmpty
                                      ? 'Buyer'
                                      : buyerName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    if (buyerId.isNotEmpty && sellerId.isNotEmpty)
                      SizedBox(width: 8),
                    if (sellerId.isNotEmpty)
                      Expanded(
                        child: _ContactActionButton(
                          icon: Icons.storefront_outlined,
                          label: 'Message Seller',
                          seedColor: seedColor,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  otherUserId: sellerId,
                                  otherUserName: sellerName.isEmpty
                                      ? 'Seller'
                                      : sellerName,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ],
            SizedBox(height: 10),
            Divider(height: 1, color: Colors.grey.shade100),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formatPeso(total),
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: seedColor,
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: nextActionLabel == null
                  ? SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: 12),
                        SlideToConfirm(
                          label: nextActionLabel!,
                          height: 54,
                          color: seedColor,
                          onConfirm: onAdvance,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoDeliveriesYet extends StatelessWidget {
  const _NoDeliveriesYet({required this.seedColor});

  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: seedColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_shipping_outlined,
            size: 38,
            color: seedColor.withValues(alpha: 0.55),
          ),
        ),
        SizedBox(height: 16),
        Text(
          'No deliveries yet',
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: seedColor,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Delivery requests will show up here',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}

class _RiderNotApprovedYet extends StatelessWidget {
  const _RiderNotApprovedYet({required this.seedColor, this.status});

  final Color seedColor;
  final String? status;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (status) {
      'pending' => (
        Icons.hourglass_top_rounded,
        'Application under review',
        'We\'ve received your rider application. You\'ll be able to accept '
            'deliveries as soon as it\'s approved.',
      ),
      'rejected' => (
        Icons.error_outline_rounded,
        'Application not approved',
        'Your rider application wasn\'t approved this time. Open your '
            'Profile tab to see why and apply again.',
      ),
      _ => (
        Icons.assignment_outlined,
        'Apply to become a rider',
        'You need to apply and get approved before you can accept '
            'deliveries. Open your Profile tab to apply.',
      ),
    };

    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: seedColor.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 38, color: seedColor.withValues(alpha: 0.7)),
        ),
        SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.fraunces(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: seedColor,
          ),
        ),
        SizedBox(height: 6),
        Text(
          body,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.seedColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color seedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: seedColor.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: seedColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: seedColor),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: seedColor,
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

class _OffersSection extends StatefulWidget {
  const _OffersSection({required this.seedColor});

  final Color seedColor;

  @override
  State<_OffersSection> createState() => _OffersSectionState();
}

class _OffersSectionState extends State<_OffersSection> {
  static const Color _goldColor = Color(0xFFE0A63A);

  final _service = DeliveryService();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _service
      .streamMyOffers();

  final Set<String> _gone = {};

  String _offerKey(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final sent = doc.data()['offerSentAt'];
    return '${doc.id}:${sent is Timestamp ? sent.millisecondsSinceEpoch : 0}';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snapshot) {
        final docs = (snapshot.data?.docs ?? [])
            .where(
              (doc) =>
                  !_gone.contains(_offerKey(doc)) &&
                  _OfferCard.remainingFor(doc.data()) > Duration.zero,
            )
            .toList();
        if (docs.isEmpty) return SizedBox.shrink();

        return Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: _goldColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'New Requests',
                      style: GoogleFonts.fraunces(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: widget.seedColor,
                      ),
                    ),
                  ],
                ),
              ),
              for (final doc in docs)
                _OfferCard(
                  key: ValueKey(_offerKey(doc)),
                  orderId: doc.id,
                  data: doc.data(),
                  seedColor: widget.seedColor,
                  service: _service,
                  onGone: () {
                    if (mounted) setState(() => _gone.add(_offerKey(doc)));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatefulWidget {
  const _OfferCard({
    super.key,
    required this.orderId,
    required this.data,
    required this.seedColor,
    required this.service,
    required this.onGone,
  });

  final String orderId;
  final Map<String, dynamic> data;
  final Color seedColor;
  final DeliveryService service;
  final VoidCallback onGone;

  static Duration remainingFor(Map<String, dynamic> data) {
    final window = DeliveryService.offerWindow;
    final sent = data['offerSentAt'];
    if (sent is! Timestamp) return window;
    final left = window - DateTime.now().difference(sent.toDate());
    if (left > window) return window;
    return left.isNegative ? Duration.zero : left;
  }

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard>
    with SingleTickerProviderStateMixin {
  static const Color _successColor = Color(0xFF2E7D4F);
  static const Color _goldColor = Color(0xFFE0A63A);
  static const Color _urgentColor = Color(0xFFC62828);

  late final AnimationController _ctrl;
  bool _busy = false;
  bool _expired = false;
  bool _hidden = false;

  @override
  void initState() {
    super.initState();
    final window = DeliveryService.offerWindow;
    final remaining = _OfferCard.remainingFor(widget.data);
    final start = remaining.inMilliseconds / window.inMilliseconds;
    _ctrl = AnimationController(vsync: this, duration: window, value: start)
      ..addStatusListener((status) {
        if (status == AnimationStatus.dismissed) _onExpired();
      });
    HapticFeedback.mediumImpact();
    _ctrl.reverse(from: start);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color _ringColor(double t) {
    if (t > 0.5) {
      return Color.lerp(_goldColor, _successColor, (t - 0.5) / 0.5)!;
    }
    return Color.lerp(_urgentColor, _goldColor, t / 0.5)!;
  }

  void _onExpired() {
    if (!mounted || _expired) return;
    setState(() => _expired = true);
    _collapseSoon();
  }

  void _collapseSoon() {
    Future<void>.delayed(Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _hidden = true);
      Future<void>.delayed(Duration(milliseconds: 350), () {
        if (mounted) widget.onGone();
      });
    });
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: error ? Colors.red[700] : widget.seedColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _accept() async {
    if (_busy || _expired) return;
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    try {
      await widget.service.acceptOffer(widget.orderId);
      if (mounted) _ctrl.stop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      if (e.code == 'permission-denied') {
        _ctrl.stop();
        setState(() {
          _busy = false;
          _expired = true;
        });
        _showSnack('This request expired or went to another rider.', error: true);
        _collapseSoon();
      } else {
        setState(() => _busy = false);
        _showSnack('Could not accept. Please try again.', error: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack('Could not accept. Please try again.', error: true);
    }
  }

  Future<void> _decline() async {
    if (_busy || _expired) return;
    setState(() => _busy = true);
    try {
      await widget.service.declineOffer(widget.orderId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showSnack('Could not decline. Please try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final seed = widget.seedColor;
    final orderId = widget.orderId;
    final buyerName = data['deliveryName'] as String? ?? '';
    final buyerAddress = data['deliveryAddress'] as String? ?? '';
    final fee = (data['shippingFee'] as num?)?.toDouble() ?? 0;
    final shortId = orderId
        .substring(0, orderId.length < 8 ? orderId.length : 8)
        .toUpperCase();

    return AnimatedSize(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: _hidden
          ? SizedBox(width: double.infinity)
          : Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 250),
                opacity: _expired ? 0.55 : 1,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _goldColor.withValues(alpha: 0.55),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: seed.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (_expired ? Colors.grey : _goldColor)
                                    .withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _expired ? 'EXPIRED' : 'NEW REQUEST',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                  color: seed,
                                ),
                              ),
                            ),
                            Text(
                              'Order #$shortId',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Divider(height: 1, color: Colors.grey.shade100),
                        SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: seed.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.place_outlined,
                                size: 14,
                                color: seed,
                              ),
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deliver to',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    buyerName.isEmpty
                                        ? 'No name provided'
                                        : buyerName,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (buyerAddress.isNotEmpty)
                                    Text(
                                      buyerAddress,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (fee > 0) ...[
                          SizedBox(height: 10),
                          Divider(height: 1, color: Colors.grey.shade100),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'You earn',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                formatPeso(fee),
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: seed,
                                ),
                              ),
                            ],
                          ),
                        ],
                        SizedBox(height: 14),
                        AnimatedBuilder(
                          animation: _ctrl,
                          builder: (context, _) {
                            final t = _expired ? 0.0 : _ctrl.value;
                            final totalSecs =
                                DeliveryService.offerWindow.inSeconds;
                            final secsLeft = (t * totalSecs).ceil();
                            final color = _ringColor(t);
                            final urgent = !_expired && t * totalSecs <= 5;
                            final pulse = urgent
                                ? 1 + 0.05 * (1 - ((t * totalSecs) % 1))
                                : 1.0;
                            return Row(
                              children: [
                                Transform.scale(
                                  scale: pulse,
                                  child: SizedBox(
                                    width: 68,
                                    height: 68,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox.expand(
                                          child: CircularProgressIndicator(
                                            value: t,
                                            strokeWidth: 5,
                                            strokeCap: StrokeCap.round,
                                            color: color,
                                            backgroundColor: color.withValues(
                                              alpha: 0.14,
                                            ),
                                          ),
                                        ),
                                        Material(
                                          color: _expired
                                              ? Colors.grey[400]
                                              : seed,
                                          shape: CircleBorder(),
                                          child: InkWell(
                                            customBorder: CircleBorder(),
                                            onTap: (_busy || _expired)
                                                ? null
                                                : _accept,
                                            child: SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: Center(
                                                child: _busy
                                                    ? SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2.5,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                      )
                                                    : Icon(
                                                        Icons.check_rounded,
                                                        color: Colors.white,
                                                        size: 26,
                                                      ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _expired
                                            ? 'Request expired'
                                            : 'Tap to accept',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        _expired
                                            ? 'It may go to another rider.'
                                            : '${secsLeft}s left',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _expired
                                              ? Colors.grey[600]
                                              : color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: (_busy || _expired)
                                      ? null
                                      : _decline,
                                  child: Text(
                                    'Decline',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.w700,
                                      color: (_busy || _expired)
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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
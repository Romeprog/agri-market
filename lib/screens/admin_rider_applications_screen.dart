import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/rider_application.dart';
import '../services/rider_application_service.dart';
import '../widgets/admin_action_button.dart';
import '../widgets/expandable_application_card.dart';
import '../widgets/success_dialog.dart';

class AdminRiderApplicationsTab extends StatefulWidget {
  const AdminRiderApplicationsTab({super.key});

  @override
  State<AdminRiderApplicationsTab> createState() =>
      _AdminRiderApplicationsTabState();
}

class _AdminRiderApplicationsTabState extends State<AdminRiderApplicationsTab> {
  static const Color _seedColor = Color(0xFF1F3D2B);

  String? _openId;

  final Map<String, RiderApplication> _pinned = {};
  final Map<String, int> _pinnedIndex = {};
  final Set<String> _removing = {};

  void _pin(RiderApplication app, int index) {
    _pinned[app.userId] = app;
    _pinnedIndex[app.userId] = index;
  }

  void _unpin(String id) {
    if (!mounted) return;
    setState(() {
      _pinned.remove(id);
      _pinnedIndex.remove(id);
      _removing.remove(id);
    });
  }

  Future<void> _celebrate(RiderApplication app, {required bool approved}) async {
    if (!mounted) return;
    await showSuccessDialog(
      context: context,
      title: approved ? 'Application Approved!' : 'Application Rejected',
      message: approved
          ? '${app.fullName} now has rider access and can start accepting '
                'deliveries.'
          : 'The applicant will see this in their application status '
                'and can apply again.',
      seedColor: approved ? _seedColor : Colors.blueGrey.shade700,
      successColor: approved ? Color(0xFF2E7D4F) : Colors.blueGrey.shade400,
      onDone: () => Navigator.of(context, rootNavigator: true).pop(),
    );
    if (!mounted) return;
    setState(() => _removing.add(app.userId));
    await Future<void>.delayed(Duration(milliseconds: 400));
    _unpin(app.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RiderApplication>>(
      stream: RiderApplicationService.pendingApplications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Could not load applications: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Could not load applications.',
                    style: GoogleFonts.inter(color: Colors.grey[600]),
                  ),
                  SizedBox(height: 10),
                  SelectableText(
                    '${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _seedColor));
        }
        final apps = [...snapshot.data!];
        _pinned.forEach((id, pinnedApp) {
          if (apps.every((a) => a.userId != id)) {
            final at = (_pinnedIndex[id] ?? apps.length)
                .clamp(0, apps.length)
                .toInt();
            apps.insert(at, pinnedApp);
          }
        });
        if (apps.isEmpty) {
          return Center(
            child: Text(
              'No pending applications.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.grey[600]),
            ),
          );
        }
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 24),
          itemCount: apps.length,
          findChildIndexCallback: (key) {
            if (key is! ValueKey<String>) return null;
            final i = apps.indexWhere((a) => a.userId == key.value);
            return i < 0 ? null : i;
          },
          itemBuilder: (context, index) {
            final app = apps[index];
            return _RiderApplicationCard(
              key: ValueKey(app.userId),
              app: app,
              expanded: _openId == app.userId,
              removing: _removing.contains(app.userId),
              onToggle: () => setState(
                () => _openId = _openId == app.userId ? null : app.userId,
              ),
              onPin: () => _pin(app, index),
              onUnpin: () => _unpin(app.userId),
              onResolved: ({required bool approved}) =>
                  _celebrate(app, approved: approved),
            );
          },
        );
      },
    );
  }
}

class _RiderApplicationCard extends StatefulWidget {
  const _RiderApplicationCard({
    super.key,
    required this.app,
    required this.expanded,
    required this.removing,
    required this.onToggle,
    required this.onPin,
    required this.onUnpin,
    required this.onResolved,
  });

  final RiderApplication app;
  final bool expanded;
  final bool removing;
  final VoidCallback onToggle;
  final VoidCallback onPin;
  final VoidCallback onUnpin;
  final void Function({required bool approved}) onResolved;

  @override
  State<_RiderApplicationCard> createState() => _RiderApplicationCardState();
}

class _RiderApplicationCardState extends State<_RiderApplicationCard> {
  static const Color _seedColor = Color(0xFF1F3D2B);

  final _approveController = AdminMorphController();
  final _rejectController = AdminMorphController();

  static String _formatDate(DateTime? d) {
    if (d == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  Widget _detail(String label, String value) {
    if (value.trim().isEmpty) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(fontSize: 12.5, color: Colors.grey[800]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleApprove() async {
    final app = widget.app;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Approve this application?',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${app.fullName} will get rider access immediately.',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: _seedColor),
            child: Text(
              'Approve',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final onResolved = widget.onResolved;
    final onUnpin = widget.onUnpin;
    widget.onPin();
    await _approveController.play();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await RiderApplicationService.approve(app.userId);
      onResolved(approved: true);
    } catch (e) {
      onUnpin();
      _approveController.reset();
      messenger.showSnackBar(SnackBar(content: Text('Could not approve: $e')));
    }
  }

  Future<void> _handleReject() async {
    final app = widget.app;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Reject this application?',
          style: GoogleFonts.fraunces(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          style: GoogleFonts.inter(fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Reason (optional, shown to the applicant)',
            hintStyle: GoogleFonts.inter(fontSize: 13, color: Colors.grey[400]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[700]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
            child: Text(
              'Reject',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final onResolved = widget.onResolved;
    final onUnpin = widget.onUnpin;
    widget.onPin();
    await _rejectController.play();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await RiderApplicationService.reject(
        app.userId,
        reason: reasonController.text.trim(),
      );
      onResolved(approved: false);
    } catch (e) {
      onUnpin();
      _rejectController.reset();
      messenger.showSnackBar(SnackBar(content: Text('Could not reject: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final applied = _formatDate(app.submittedAt);
    final bodyStyle = GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]);

    return ExpandableApplicationCard(
      title: app.fullName,
      subtitle: app.serviceArea,
      hint: applied.isEmpty
          ? 'Tap to review details'
          : 'Applied $applied · Tap to review details',
      expanded: widget.expanded,
      onToggle: widget.onToggle,
      removed: widget.removing,
      children: [
        Text(app.contactNumber, style: bodyStyle),
        Padding(
          padding: EdgeInsets.only(top: 10),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              Chip(
                label: Text(
                  app.vehicleType,
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                backgroundColor: _seedColor.withValues(alpha: 0.08),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
              Chip(
                label: Text(
                  app.vehiclePlateNumber,
                  style: GoogleFonts.inter(fontSize: 11.5),
                ),
                backgroundColor: _seedColor.withValues(alpha: 0.08),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Divider(height: 1),
              SizedBox(height: 6),
              _detail('License no.', app.driverLicenseNumber),
              _detail('Experience', app.yearsOfExperience),
              _detail('Notes', app.additionalNotes),
              _detail('Applied', applied),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(top: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AdminMorphButton(
                label: 'Reject',
                icon: Icons.close_rounded,
                leadingIcon: Icons.highlight_off,
                color: Colors.red[700]!,
                controller: _rejectController,
                onTap: _handleReject,
              ),
              SizedBox(width: 10),
              AdminMorphButton(
                label: 'Approve',
                icon: Icons.check_rounded,
                leadingIcon: Icons.check_circle_outline,
                color: _seedColor,
                filled: true,
                controller: _approveController,
                onTap: _handleApprove,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
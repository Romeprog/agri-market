import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product.dart';
import '../models/report.dart';
import '../services/report_service.dart';
import 'product_detail_screen.dart';

Color _reasonColor(String reason) {
  final r = reason.toLowerCase();
  if (r.contains('prohibit') ||
      r.contains('scam') ||
      r.contains('fraud') ||
      r.contains('fake') ||
      r.contains('counterfeit')) {
    return const Color(0xFFB3261E);
  }
  if (r.contains('mislead') ||
      r.contains('inaccurate') ||
      r.contains('price')) {
    return const Color(0xFFB8860B);
  }
  if (r.contains('spam') || r.contains('duplicate')) {
    return const Color(0xFF1D5D9B);
  }
  return const Color(0xFF1F3D2B);
}

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  static const Color _seedColor = Color(0xFF1F3D2B);
  static const Color _bgColor = Color(0xFFEFF1E4);

  String _statusFilter = 'pending';
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return 'Just now';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    final minute = d.minute.toString().padLeft(2, '0');
    return '${months[d.month - 1]} ${d.day}, ${d.year} · $hour12:$minute $ampm';
  }

  Future<void> _copyId(String id, String label) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$label copied to clipboard',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _seedColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _viewListing(String productId) async {
    final messenger = ScaffoldMessenger.of(context);
    final product = await ReportService.fetchProduct(productId);
    if (!mounted) return;
    if (product == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This listing is no longer available.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w600),
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product, viewOnly: true),
      ),
    );
  }

  Future<void> _resolveReport(
    String reportId, {
    required String productId,
    required String newStatus,
    required bool deleteListing,
    String? note,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (deleteListing && productId.isNotEmpty) {
      try {
        await ReportService.deleteReportedProduct(productId);
      } catch (e) {
        debugPrint('Could not delete listing $productId: $e');
      }
    }

    try {
      await ReportService.resolveReport(
        reportId: reportId,
        resolution: newStatus,
        note: note,
      );
    } catch (e) {
      debugPrint('Could not resolve report $reportId: $e');
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not update this report. Please try again.'),
        ),
      );
      return;
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          newStatus == 'actioned'
              ? 'Listing removed and report resolved.'
              : 'Report dismissed.',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
        backgroundColor: _seedColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _confirmResolve(
    Report report, {
    required bool deleteListing,
  }) async {
    final productName = report.productName.trim().isNotEmpty
        ? report.productName
        : 'this listing';
    final noteController = TextEditingController();

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                deleteListing ? 'Remove this listing?' : 'Dismiss this report?',
                style: GoogleFonts.fraunces(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _seedColor,
                ),
              ),
              SizedBox(height: 4),
              Text(
                deleteListing
                    ? '"$productName" will be permanently removed from the marketplace '
                          'and this report will be marked as actioned.'
                    : 'This report for "$productName" will be closed with no action '
                          'taken on the listing.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 14),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: GoogleFonts.inter(fontSize: 13.5),
                decoration: InputDecoration(
                  hintText: 'Add a resolution note (optional)',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  filled: true,
                  fillColor: _bgColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.all(14),
                ),
              ),
              SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deleteListing
                        ? Colors.red[700]
                        : _seedColor,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: Text(
                    deleteListing ? 'Remove listing' : 'Dismiss report',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _resolveReport(
      report.id,
      productId: report.productId,
      newStatus: deleteListing ? 'actioned' : 'dismissed',
      deleteListing: deleteListing,
      note: noteController.text.trim().isEmpty
          ? null
          : noteController.text.trim(),
    );
  }

  String _emptyMessage() {
    if (_search.trim().isNotEmpty) {
      return 'No reports match "${_search.trim()}".';
    }
    switch (_statusFilter) {
      case 'pending':
        return 'No pending reports right now.';
      case 'actioned':
        return 'No actioned reports yet.';
      case 'dismissed':
        return 'No dismissed reports yet.';
      default:
        return 'No reports yet.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: ReportService.allReports(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            children: [
              SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28),
                    child: Text(
                      'Could not load reports right now.',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  ),
                ),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return Column(
            children: [
              SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: _seedColor),
                ),
              ),
            ],
          );
        }

        final all = snapshot.data!;
        final pendingCount = all
            .where((r) => r.status == ReportStatus.pending)
            .length;
        final actionedCount = all
            .where((r) => r.status == ReportStatus.actioned)
            .length;
        final dismissedCount = all
            .where((r) => r.status == ReportStatus.dismissed)
            .length;

        Iterable<Report> filtered = switch (_statusFilter) {
          'pending' => all.where((r) => r.status == ReportStatus.pending),
          'actioned' => all.where((r) => r.status == ReportStatus.actioned),
          'dismissed' => all.where((r) => r.status == ReportStatus.dismissed),
          _ => all,
        };

        final query = _search.trim().toLowerCase();
        if (query.isNotEmpty) {
          filtered = filtered.where(
            (r) =>
                r.productName.toLowerCase().contains(query) ||
                r.reason.toLowerCase().contains(query) ||
                (r.details ?? '').toLowerCase().contains(query),
          );
        }
        final docs = filtered.toList();

        return Column(
          children: [
            SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: _StatFilterCard(
                      label: 'All',
                      count: all.length,
                      color: _seedColor,
                      selected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StatFilterCard(
                      label: 'Pending',
                      count: pendingCount,
                      color: Color(0xFFB8860B),
                      selected: _statusFilter == 'pending',
                      onTap: () => setState(() => _statusFilter = 'pending'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StatFilterCard(
                      label: 'Actioned',
                      count: actionedCount,
                      color: Color(0xFFB3261E),
                      selected: _statusFilter == 'actioned',
                      onTap: () => setState(() => _statusFilter = 'actioned'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: _StatFilterCard(
                      label: 'Dismissed',
                      count: dismissedCount,
                      color: Colors.grey[600]!,
                      selected: _statusFilter == 'dismissed',
                      onTap: () => setState(() => _statusFilter = 'dismissed'),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _seedColor.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 19, color: Colors.grey[500]),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) => setState(() => _search = v),
                        style: GoogleFonts.inter(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'Search by product or reason',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_search.isNotEmpty)
                      InkWell(
                        onTap: () {
                          _searchController.clear();
                          setState(() => _search = '');
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12),
            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Text(
                          _emptyMessage(),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.fromLTRB(14, 0, 14, 24),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final report = docs[index];
                        return Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: _ReportCard(
                            report: report,
                            seedColor: _seedColor,
                            bgColor: _bgColor,
                            formatDate: _formatDate,
                            onCopyId: _copyId,
                            onViewListing: () => _viewListing(report.productId),
                            onDismiss: report.isResolved
                                ? null
                                : () => _confirmResolve(
                                    report,
                                    deleteListing: false,
                                  ),
                            onRemove: report.isResolved
                                ? null
                                : () => _confirmResolve(
                                    report,
                                    deleteListing: true,
                                  ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _StatFilterCard extends StatelessWidget {
  const _StatFilterCard({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? color : Colors.grey.shade200),
          boxShadow: selected
              ? []
              : [
                  BoxShadow(
                    color: color.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : color,
              ),
            ),
            SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.report,
    required this.seedColor,
    required this.bgColor,
    required this.formatDate,
    required this.onCopyId,
    required this.onViewListing,
    this.onDismiss,
    this.onRemove,
  });

  final Report report;
  final Color seedColor;
  final Color bgColor;
  final String Function(DateTime?) formatDate;
  final void Function(String id, String label) onCopyId;
  final VoidCallback onViewListing;
  final VoidCallback? onDismiss;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = _reasonColor(report.reason);
    final resolved = report.isResolved;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: seedColor.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  report.reason,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              Spacer(),
              if (resolved)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: report.status == ReportStatus.actioned
                        ? Colors.red.withValues(alpha: 0.08)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    report.status == ReportStatus.actioned
                        ? 'Actioned'
                        : 'Dismissed',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: report.status == ReportStatus.actioned
                          ? Colors.red[700]
                          : Colors.grey[700],
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 12),
          FutureBuilder<Product?>(
            future: ReportService.fetchProduct(report.productId),
            builder: (context, snap) {
              final product = snap.data;
              final loading = snap.connectionState == ConnectionState.waiting;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: loading
                        ? Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: seedColor,
                              ),
                            ),
                          )
                        : (product != null && product.image.startsWith('http'))
                        ? Image.network(
                            product.image,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Icon(
                                Icons.category_outlined,
                                color: seedColor.withValues(alpha: 0.5),
                              ),
                            ),
                          )
                        : Center(
                            child: Icon(
                              product == null
                                  ? Icons.remove_circle_outline
                                  : Icons.category_outlined,
                              color: seedColor.withValues(alpha: 0.5),
                            ),
                          ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.productName,
                          style: GoogleFonts.fraunces(
                            fontSize: 15.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Reported ${formatDate(report.createdAt)}',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),

          if (report.reason == 'Other' ||
              (report.details ?? '').trim().isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reporter's explanation",
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    (report.details ?? '').trim().isNotEmpty
                        ? report.details!.trim()
                        : 'No explanation provided.',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontStyle: (report.details ?? '').trim().isNotEmpty
                          ? FontStyle.normal
                          : FontStyle.italic,
                      color: Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 12),
          Divider(height: 1, color: bgColor),
          SizedBox(height: 12),

          _PersonRow(
            label: 'Reporter',
            uid: report.reporterId,
            fallbackName: (report.reporterName ?? '').trim().isNotEmpty
                ? report.reporterName
                : report.reporterEmail,
            seedColor: seedColor,
            onCopy: onCopyId,
          ),
          SizedBox(height: 8),
          _PersonRow(
            label: 'Listing owner',
            uid: report.reportedFarmerId,
            seedColor: seedColor,
            onCopy: onCopyId,
          ),

          if (resolved) ...[
            SizedBox(height: 10),
            Text(
              'Resolved ${formatDate(report.resolvedAt)}',
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey[600]),
            ),
            if ((report.resolutionNote ?? '').trim().isNotEmpty) ...[
              SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  report.resolutionNote!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ],

          SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewListing,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.black87,
                side: BorderSide(color: Colors.grey.shade300),
                padding: EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: Icon(Icons.visibility_outlined, size: 17),
              label: Text(
                'View listing',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),

          if (!resolved) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: seedColor,
                      side: BorderSide(color: seedColor),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Dismiss',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRemove,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Remove listing',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({
    required this.label,
    required this.uid,
    required this.seedColor,
    required this.onCopy,
    this.fallbackName,
  });

  final String label;
  final String uid;
  final String? fallbackName;
  final Color seedColor;
  final void Function(String id, String label) onCopy;

  @override
  Widget build(BuildContext context) {
    final shortId = uid.isEmpty
        ? '—'
        : (uid.length > 14 ? '${uid.substring(0, 14)}…' : uid);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Padding(
            padding: EdgeInsets.only(top: 1),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<String?>(
            future: ReportService.fetchUserName(uid),
            builder: (context, snap) {
              final name = snap.data ?? fallbackName;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name ?? (uid.isEmpty ? '—' : 'Unknown user'),
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  if (name != null)
                    Text(
                      shortId,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (uid.isNotEmpty)
          InkWell(
            onTap: () => onCopy(uid, label),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.content_copy, size: 14, color: seedColor),
            ),
          ),
      ],
    );
  }
}
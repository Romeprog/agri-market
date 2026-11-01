import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class DeliveryProofCard extends StatelessWidget {
  const DeliveryProofCard({
    super.key,
    required this.url,
    this.takenAt,
    this.seedColor = const Color(0xFF1F3D2B),
  });

  final String url;
  final DateTime? takenAt;
  final Color seedColor;

  @override
  Widget build(BuildContext context) {
    final caption = takenAt == null
        ? 'Photo taken by your rider at drop-off'
        : 'Taken ${DateFormat('MMM d, y · h:mm a').format(takenAt!)}';

    return Padding(
      padding: EdgeInsets.only(top: 6, bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: seedColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: seedColor.withValues(alpha: 0.15)),
        ),
        padding: EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.photo_camera_outlined, size: 16, color: seedColor),
                SizedBox(width: 6),
                Text(
                  'Proof of delivery',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: seedColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            GestureDetector(
              onTap: () => showDeliveryProofViewer(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: seedColor,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) => Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            Text(
              caption,
              style: GoogleFonts.inter(fontSize: 11.5, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showDeliveryProofViewer(BuildContext context, String url) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                  errorBuilder: (context, error, stack) => Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(dialogContext).padding.top + 8,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
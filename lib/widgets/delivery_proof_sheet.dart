import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../services/delivery_service.dart';

const _seedColor = Color(0xFF1F3D2B);
const _bg = Color(0xFFEFF1E4);

Future<bool?> showDeliveryProofSheet(
  BuildContext context, {
  required String orderId,
  required DeliveryService service,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeliveryProofSheet(orderId: orderId, service: service),
  );
}

class _DeliveryProofSheet extends StatefulWidget {
  const _DeliveryProofSheet({required this.orderId, required this.service});

  final String orderId;
  final DeliveryService service;

  @override
  State<_DeliveryProofSheet> createState() => _DeliveryProofSheetState();
}

class _DeliveryProofSheetState extends State<_DeliveryProofSheet> {
  final _picker = ImagePicker();
  File? _photo;
  bool _uploading = false;
  String? _error;

  Future<void> _capture() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 75,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (shot == null || !mounted) return;
      setState(() {
        _photo = File(shot.path);
        _error = null;
      });
    } catch (e) {
      debugPrint('Camera failed: $e');
      if (!mounted) return;
      setState(
        () => _error =
            'Could not open the camera. Please allow camera access and try again.',
      );
    }
  }

  Future<void> _confirm() async {
    final photo = _photo;
    if (photo == null || _uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await widget.service.markDelivered(widget.orderId, photo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Delivery proof failed: $e');
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error =
            'Could not send the photo. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final hasPhoto = _photo != null;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: _seedColor.withValues(alpha: 0.2),
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
                      color: _seedColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.photo_camera_outlined, color: _bg),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proof of delivery',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: _seedColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Take a clear photo of the package at the drop-off '
                          'spot. The buyer will see it.',
                          style: textTheme.bodySmall?.copyWith(
                            color: _seedColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _uploading
                        ? null
                        : () => Navigator.of(context).pop(false),
                    icon: Icon(
                      Icons.close_rounded,
                      color: _seedColor.withValues(alpha: 0.5),
                    ),
                    splashRadius: 20,
                  ),
                ],
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: (hasPhoto || _uploading) ? null : _capture,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: 300),
                    child: ClipRRect(
                      key: ValueKey(_photo?.path ?? 'empty'),
                      borderRadius: BorderRadius.circular(18),
                      child: hasPhoto
                          ? Image.file(_photo!, fit: BoxFit.cover)
                          : Container(
                              color: _seedColor.withValues(alpha: 0.06),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_outlined,
                                    size: 40,
                                    color: _seedColor.withValues(alpha: 0.55),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Tap to open the camera',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: _seedColor.withValues(alpha: 0.65),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                SizedBox(height: 10),
                Text(
                  _error!,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: Colors.red[700],
                  ),
                ),
              ],
              SizedBox(height: 16),
              if (!hasPhoto)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _capture,
                    icon: Icon(Icons.photo_camera_outlined),
                    label: Text('Open Camera'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _seedColor,
                      foregroundColor: _bg,
                      shape: StadiumBorder(),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: _uploading ? null : _capture,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _seedColor,
                            side: BorderSide(
                              color: _seedColor.withValues(alpha: 0.4),
                            ),
                            shape: StadiumBorder(),
                          ),
                          child: Text('Retake'),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 48,
                        child: FilledButton(
                          onPressed: _uploading ? null : _confirm,
                          style: FilledButton.styleFrom(
                            backgroundColor: _seedColor,
                            foregroundColor: _bg,
                            disabledBackgroundColor: _seedColor.withValues(
                              alpha: 0.5,
                            ),
                            shape: StadiumBorder(),
                          ),
                          child: _uploading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _bg,
                                  ),
                                )
                              : Text('Confirm Delivery'),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import '../backend/api_service.dart';
import 'toast_service.dart';

class GpsConsentScreen extends StatefulWidget {
  const GpsConsentScreen({Key? key}) : super(key: key);

  @override
  _GpsConsentScreenState createState() => _GpsConsentScreenState();
}

class _GpsConsentScreenState extends State<GpsConsentScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitSignature() async {
    if (_controller.isEmpty) {
      ToastService.error(context, 'Please draw your signature in the box below');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final base64Signature = base64Encode(bytes);
        await ApiService.instance.post('/users/gps-consent', {
          'signature': 'data:image/png;base64,$base64Signature'
        });
        if (mounted) {
          ToastService.success(context, 'Consent Recorded Successfully!');
          Navigator.pop(context, true); // return true to indicate success
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.error(context, 'Failed to save consent: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white70),
          onPressed: () => Navigator.pop(context, false),
          tooltip: 'Cancel',
        ),
        title: const Text(
          'GPS Tracking Consent',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.location_on_outlined, color: Color(0xFF3B82F6), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Worker Location Compliance',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'I consent to GPS tracking during my work hours while clocked in. Location is used for crew dispatch, safety, and travel verification.',
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5, height: 1.35),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Please sign below once to proceed with starting this job.',
                            style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Signature Pad Box with interactive prompt
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF64748B), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Stack(
                      children: [
                        // The actual signature canvas
                        Signature(
                          controller: _controller,
                          backgroundColor: Colors.white,
                        ),

                        // Signature Line guide at the bottom
                        Positioned(
                          bottom: 24,
                          left: 20,
                          right: 20,
                          child: IgnorePointer(
                            child: Row(
                              children: [
                                Text(
                                  '✕ ',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Placeholder watermark when empty
                        if (_controller.isEmpty)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.draw_rounded,
                                      color: Colors.grey.shade400,
                                      size: 38,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Draw your signature here',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '(Use finger or mouse)',
                                      style: TextStyle(
                                        color: Colors.grey.shade400,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _controller.clear(),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Color(0xFF475569)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _submitSignature,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Confirm & Start',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}


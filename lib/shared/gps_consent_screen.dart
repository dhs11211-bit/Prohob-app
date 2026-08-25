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
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitSignature() async {
    if (_controller.isEmpty) {
      ToastService.error(context, 'Please provide a signature');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final base64Signature = base64Encode(bytes);
        await ApiService.instance.post('/users/gps-consent', {
          'signature': 'data:image/png;base64,' + base64Signature
        });
        ToastService.success(context, 'Consent Recorded Successfully!');
        Navigator.pop(context, true); // return true to indicate success
      }
    } catch (e) {
      ToastService.error(context, 'Failed to save consent: $e');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('GPS Tracking Consent',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false, // Force them to sign
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'I consent to GPS tracking during my work hours. I understand my location will be monitored for safety and compliance while clocked in.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Signature(
                  controller: _controller,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => _controller.clear(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: const Text('Clear'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submitSignature,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Submit Signature',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}


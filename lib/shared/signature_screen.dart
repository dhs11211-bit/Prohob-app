import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import '../backend/api_service.dart';
import 'toast_service.dart';

class SignatureScreen extends StatefulWidget {
  final int jobId;

  const SignatureScreen({Key? key, required this.jobId}) : super(key: key);

  @override
  _SignatureScreenState createState() => _SignatureScreenState();
}

class _SignatureScreenState extends State<SignatureScreen> {
  final SignatureController _controller = SignatureController(
    penStrokeWidth: 3,
    penColor: Colors.black,
    exportBackgroundColor: Colors.white,
  );
  
  final TextEditingController _nameController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitSignature() async {
    if (_nameController.text.trim().isEmpty) {
      ToastService.error(context, 'Please provide a printed name');
      return;
    }
    if (_controller.isEmpty) {
      ToastService.error(context, 'Please provide a signature');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bytes = await _controller.toPngBytes();
      if (bytes != null) {
        final base64Signature = base64Encode(bytes);
        await ApiService.instance.completeJobWithSignature(
            widget.jobId, 'data:image/png;base64,' + base64Signature, _nameController.text.trim());
        ToastService.success(context, 'Job Completed Successfully!');
        Navigator.pop(context, true); // return true to indicate success
      }
    } catch (e) {
      ToastService.error(context, 'Failed to save signature');
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Customer Signature',
            style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'By signing below, you acknowledge that all work for this job has been completed to your satisfaction.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Printed Name',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                          style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
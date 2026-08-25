import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import 'dart:convert';
import '../backend/api_service.dart';
import 'toast_service.dart';

class QuoteSignatureScreen extends StatefulWidget {
  final int quoteId;
  final int? selectedOptionId;

  const QuoteSignatureScreen({
    Key? key,
    required this.quoteId,
    this.selectedOptionId,
  }) : super(key: key);

  @override
  _QuoteSignatureScreenState createState() => _QuoteSignatureScreenState();
}

class _QuoteSignatureScreenState extends State<QuoteSignatureScreen> {
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
      ToastService.error(context, 'Please enter your full name');
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
        
        final payload = {
          'signature_data': 'data:image/png;base64,' + base64Signature,
          'signature_name': _nameController.text.trim(),
          'selected_option_id': widget.selectedOptionId,
        };

        await ApiService.instance.request(
          method: 'POST',
          endpoint: '/quotes/${widget.quoteId}/accept',
          body: payload,
        );
        
        ToastService.success(context, 'Estimate Accepted Successfully!');
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
        title: const Text('Sign Estimate', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'By signing below, you accept the estimate and agree to the proposed terms.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Type your full name...',
                hintStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1E293B),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _controller.clear(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _submitSignature,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Confirm & Accept', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

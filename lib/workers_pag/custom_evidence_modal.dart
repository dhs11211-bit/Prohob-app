// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!
import '/shared/toast_service.dart';

import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../backend/api_service.dart';

class CustomEvidenceModal extends StatefulWidget {
  const CustomEvidenceModal({Key? key, this.width, this.height, this.jobId, this.jobTitle})
      : super(key: key);
  final double? width;
  final double? height;
  final int? jobId;
  final String? jobTitle;

  @override
  State<CustomEvidenceModal> createState() => _CustomEvidenceModalState();
}

class _CustomEvidenceModalState extends State<CustomEvidenceModal> {
  final TextEditingController _descController = TextEditingController();

  // 🟢 LA BANDEJA DE FOTOS
  List<Uint8List> _imageBytesList = [];
  bool _isUploading = false;
  bool _isLoadingTasks = true;

  // 🟢 RUTEO INTELIGENTE (SMART ROUTING)
  int? _todayJobId;
  String? _todayJobName;
  List<dynamic> _todayJobs = [];
  String _photoType = 'before';

  // 🟢 PALETA SLATE / NEON
  static const Color bg = Color(0xFF0F172A);
  static const Color card = Color(0xFF1E293B);
  static const Color text = Colors.white;
  static const Color muted = Color(0xFF94A3B8);
  static const Color accentBlue = Color(0xFF3B82F6);
  static const Color neonAction = Color(0xFFD4FF00);
  static const Color accentRed = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    if (widget.jobId != null) {
      _todayJobId = widget.jobId;
      _todayJobName = widget.jobTitle ?? 'Job Evidence';
      _todayJobs = [{'id': widget.jobId, 'title': widget.jobTitle ?? 'Job', 'job_number': '#${widget.jobId}'}];
      _isLoadingTasks = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _takePhoto();
      });
    } else {
      _fetchTodayTasks();
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchTodayTasks() async {
    try {
      final jobs = await ApiService.instance.getTodayJobs();
      if (jobs.isNotEmpty) {
        _todayJobs = jobs;
        
        // Find if there is an active job to auto-select
        dynamic targetJob = jobs.first;
        for (var j in jobs) {
          String s = j['job_status']?.toString().toLowerCase() ?? '';
          if (s == 'active' || s == 'in progress' || s == 'in_progress') {
            targetJob = j;
            break;
          }
        }
        
        _todayJobId = targetJob['id'];
        _todayJobName = targetJob['title'] ?? 'Job Evidence';
        
        // Set default photoType based on job status
        String status = targetJob['job_status']?.toString().toLowerCase() ?? 'pending';
        if (status == 'pending' || status == 'scheduled') {
          _photoType = 'before';
        } else if (status == 'active' || status == 'in progress' || status == 'in_progress') {
          _photoType = 'during';
        } else if (status == 'completed') {
          _photoType = 'after';
        }
        
        if (mounted) {
          _takePhoto();
        }
      } else {
        if (mounted) {
          Navigator.pop(context);
          ToastService.warning(context, 'You have no scheduled jobs today');
        }
      }
    } catch (e) {
      print("Error fetching tasks: $e");
    } finally {
      if (mounted) setState(() => _isLoadingTasks = false);
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (image != null) {
      final bytes = await image.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytesList.add(bytes);
        });
      }
    } else if (_imageBytesList.isEmpty && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _submitEvidence() async {
    if (_imageBytesList.isEmpty) {
      ToastService.error(context, 'Take at least one photo!');
      return;
    }
    if (_todayJobId == null) {
      ToastService.error(context, 'No active job found today.');
      return;
    }

    setState(() => _isUploading = true);

    try {
      int targetJobId = _todayJobId ?? 0;

      List<String> fileNames = [];
      for (int i = 0; i < _imageBytesList.length; i++) {
        fileNames.add('evidence_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
      }

      await ApiService.instance.uploadJobEvidence(
        jobId: targetJobId,
        photoType: _photoType,
        taskName: null,
        description: _descController.text.trim(),
        filesBytes: _imageBytesList,
        fileNames: fileNames,
      );

      if (mounted) {
        ToastService.success(context, 'Evidence submitted successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastService.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.90, // We keep the fixed container but make inner scrollable
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          children: [
            Center(
                child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: muted.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Submit Evidence',
                  style: TextStyle(
                      color: text, fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(
                  icon: const Icon(Icons.close, color: muted),
                  onPressed: () => Navigator.pop(context))
            ]),
            const SizedBox(height: 16),
            
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Evidence Photos',
                        style: TextStyle(
                            color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _imageBytesList.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _imageBytesList.length) {
                            return GestureDetector(
                              onTap: _takePhoto,
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                    color: card,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: accentBlue,
                                        width: 1.5,
                                        style: BorderStyle.solid)),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.camera_alt, color: accentBlue, size: 28),
                                    SizedBox(height: 4),
                                    Text('Add More',
                                        style: TextStyle(
                                            color: accentBlue,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold))
                                  ],
                                ),
                              ),
                            );
                          }

                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16)),
                                child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(_imageBytesList[index],
                                        fit: BoxFit.cover)),
                              ),
                              Positioned(
                                  top: 4,
                                  right: 16,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _imageBytesList.removeAt(index)),
                                    child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 16)),
                                  ))
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_todayJobs.length > 1) ...[
                      const Text('Target Job', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _todayJobId,
                            dropdownColor: card,
                            isExpanded: true,
                            style: const TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.bold),
                            icon: const Icon(Icons.work_outline, color: accentBlue),
                            items: _todayJobs.map((j) {
                              return DropdownMenuItem<int>(
                                value: j['id'] as int,
                                child: Text("${j['job_number'] ?? '#${j['id']}'} - ${j['title'] ?? 'Job'}"),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _todayJobId = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // 🟢 PHOTO TYPE SELECTOR (Moved here, above button)
                    const Text('Photo Type',
                        style: TextStyle(
                            color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10)),
                      child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                        value: _photoType,
                        dropdownColor: card,
                        isExpanded: true,
                        style: const TextStyle(
                            color: text,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        icon: const Icon(Icons.photo_camera, color: accentBlue),
                        items: const [
                          DropdownMenuItem(value: 'before', child: Text('Before Job Photo')),
                          DropdownMenuItem(value: 'during', child: Text('During Job Photo')),
                          DropdownMenuItem(value: 'after', child: Text('After Job Photo')),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _photoType = val);
                        },
                      ))),
                    const SizedBox(height: 24),

                    const Text(
                        'Image Note',
                        style: TextStyle(
                            color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 60, // Fixed height reduced to half
                      child: TextField(
                        controller: _descController,
                        maxLines: null,
                        expands: true, // Let it fill the 120px height
                        style: const TextStyle(color: text),
                        decoration: InputDecoration(
                            hintText: 'Image upload description...',
                            hintStyle: TextStyle(color: muted.withOpacity(0.5)),
                            filled: true,
                            fillColor: card,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🟢 BOTÓN DINÁMICO
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16))),
                        onPressed: _isUploading ||
                                _imageBytesList.isEmpty
                            ? null
                            : _submitEvidence,
                        icon: _isUploading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.upload, color: Colors.white),
                        label: _isUploading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('UPLOAD IMAGE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    letterSpacing: 1.2)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

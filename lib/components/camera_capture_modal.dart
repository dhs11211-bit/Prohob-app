import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../backend/api_service.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class CameraCaptureModal extends StatefulWidget {
  final int? initialJobId;
  final int? initialCustomerId;
  final int? initialInvoiceId;

  const CameraCaptureModal({
    Key? key,
    this.initialJobId,
    this.initialCustomerId,
    this.initialInvoiceId,
  }) : super(key: key);

  @override
  State<CameraCaptureModal> createState() => _CameraCaptureModalState();
}

class _CameraCaptureModalState extends State<CameraCaptureModal> {
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedMedia;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _isUploading = false;

  String _selectedEntityType = 'job';
  int? _selectedEntityId;

  @override
  void initState() {
    super.initState();
    // Default entity logic
    if (widget.initialJobId != null) {
      _selectedEntityType = 'job';
      _selectedEntityId = widget.initialJobId;
    } else if (widget.initialCustomerId != null) {
      _selectedEntityType = 'customer';
      _selectedEntityId = widget.initialCustomerId;
    } else if (widget.initialInvoiceId != null) {
      _selectedEntityType = 'invoice';
      _selectedEntityId = widget.initialInvoiceId;
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, bool isVideo) async {
    final XFile? media = isVideo 
      ? await _picker.pickVideo(source: source)
      : await _picker.pickImage(source: source, imageQuality: 80);
      
    if (media != null) {
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }
      
      setState(() {
        _selectedMedia = media;
        _isVideo = isVideo;
      });
      
      if (isVideo) {
        _videoController = kIsWeb 
          ? VideoPlayerController.networkUrl(Uri.parse(media.path))
          : VideoPlayerController.file(File(media.path));
        
        _videoController!.initialize().then((_) {
            setState(() {});
            _videoController!.setLooping(true);
            _videoController!.play();
          });
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedMedia == null) return;
    
    // In a full implementation, if _selectedEntityId is null because we opened it globally,
    // we would show a searchable dropdown to find a Job/Customer.
    // For this prototype, we'll enforce that we need an ID.
    if (_selectedEntityId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an entity to attach the media to.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final bytes = await _selectedMedia!.readAsBytes();
      
      // We will upload entity image to the selected entity
      await ApiService.instance.uploadEntityImage(
        entityType: _selectedEntityType, 
        entityId: _selectedEntityId!.toString(), 
        fileBytes: bytes, 
        fileName: _selectedMedia!.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Media uploaded successfully!')),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Upload Photo or Video',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              
              if (_selectedMedia == null) ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _pickMedia(ImageSource.camera, false),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Camera'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickMedia(ImageSource.camera, true),
                      icon: const Icon(Icons.videocam),
                      label: const Text('Video'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _pickMedia(ImageSource.gallery, false),
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isVideo && _videoController != null && _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : !_isVideo
                          ? (kIsWeb 
                              ? Image.network(_selectedMedia!.path, height: 200, fit: BoxFit.cover) 
                              : Image.file(File(_selectedMedia!.path), height: 200, fit: BoxFit.cover))
                          : const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                ),
                const SizedBox(height: 20),
                
                DropdownButtonFormField<String>(
                  value: _selectedEntityType,
                  decoration: InputDecoration(
                    labelText: 'Where to save this picture?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  items: [
                    if (widget.initialJobId != null)
                      DropdownMenuItem(value: 'job', child: Text('Current Job')),
                    if (widget.initialCustomerId != null)
                      DropdownMenuItem(value: 'customer', child: Text('Current Customer')),
                    if (widget.initialInvoiceId != null)
                      DropdownMenuItem(value: 'invoice', child: Text('Current Invoice')),
                    // In a global scenario, we could have "Search Jobs", "Search Customers"
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedEntityType = value;
                        if (value == 'job') _selectedEntityId = widget.initialJobId;
                        if (value == 'customer') _selectedEntityId = widget.initialCustomerId;
                        if (value == 'invoice') _selectedEntityId = widget.initialInvoiceId;
                      });
                    }
                  },
                ),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isUploading ? null : _uploadImage,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isUploading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Upload Media'),
                ),
                TextButton(
                  onPressed: _isUploading ? null : () {
                    setState(() {
                      _selectedMedia = null;
                      _videoController?.dispose();
                      _videoController = null;
                    });
                  },
                  child: const Text('Retake / Choose Another'),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}

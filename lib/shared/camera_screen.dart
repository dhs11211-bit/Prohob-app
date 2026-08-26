import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isRecording = false;
  bool _isTakingBurst = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _controller = CameraController(_cameras[0], ResolutionPreset.high);
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takeBurstPhotos() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    setState(() => _isTakingBurst = true);
    for (int i = 0; i < 3; i++) {
      await _controller!.takePicture();
      await Future.delayed(const Duration(milliseconds: 300));
    }
    setState(() => _isTakingBurst = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Burst photos saved locally to queue')));
  }

  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isRecording) {
      final file = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Video saved: ${file.path}')));
    } else {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
      // Auto stop after 30 seconds
      Future.delayed(const Duration(seconds: 30), () {
        if (_isRecording && mounted) _toggleVideoRecording();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'burst',
                  onPressed: _isTakingBurst || _isRecording ? null : _takeBurstPhotos,
                  backgroundColor: _isTakingBurst ? Colors.amber : Colors.white,
                  child: const Icon(Icons.burst_mode, color: Colors.black),
                ),
                FloatingActionButton(
                  heroTag: 'video',
                  onPressed: _isTakingBurst ? null : _toggleVideoRecording,
                  backgroundColor: _isRecording ? Colors.red : Colors.white,
                  child: Icon(_isRecording ? Icons.stop : Icons.videocam, color: Colors.black),
                ),
              ],
            ),
          ),
          Positioned(
            top: 40,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}

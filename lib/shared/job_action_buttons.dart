import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import '../backend/api_service.dart';
import 'toast_service.dart';
import 'signature_screen.dart';
import 'gps_consent_screen.dart';
import '../backend/location_tracking_service.dart';

class JobActionButtons extends StatefulWidget {
  final int jobId;
  final String
      jobStatus; // 'draft', 'scheduled', 'en_route', 'in_progress', 'completed', 'on_hold'
  final Map<String, dynamic>? clockStatus;
  final Future<void> Function() onStateChanged;
  final bool compact; // true = job card, false = full job detail
  final DateTime? scheduledTime;
  final String? mapUrl;

  const JobActionButtons({
    Key? key,
    required this.jobId,
    required this.jobStatus,
    required this.clockStatus,
    required this.onStateChanged,
    this.compact = false,
    this.scheduledTime,
    this.mapUrl,
  }) : super(key: key);

  @override
  _JobActionButtonsState createState() => _JobActionButtonsState();
}

class _JobActionButtonsState extends State<JobActionButtons> {
  bool _isProcessing = false;
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initTimer();
  }

  @override
  void didUpdateWidget(JobActionButtons oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clockStatus != widget.clockStatus ||
        oldWidget.jobId != widget.jobId) {
      _initTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initTimer() {
    _timer?.cancel();
    bool isCurrentJobActive = widget.clockStatus != null &&
        widget.clockStatus!['status'] == 'clocked_in' &&
        widget.clockStatus!['job_id']?.toString() == widget.jobId.toString();

    if (isCurrentJobActive) {
      int serverElapsed = 0;
      if (widget.clockStatus!['elapsed_seconds'] != null) {
        var raw = widget.clockStatus!['elapsed_seconds'];
        if (raw is int) {
          serverElapsed = raw;
        } else if (raw is double) {
          serverElapsed = raw.toInt();
        } else {
          serverElapsed = double.tryParse(raw.toString())?.toInt() ?? 0;
        }
      }

      _elapsedSeconds = serverElapsed;
      int sessionStatus = widget.clockStatus!['session_status'] != null
          ? int.tryParse(widget.clockStatus!['session_status'].toString()) ?? 1
          : 1;

      // If actively working, tick every second
      if (sessionStatus == 1) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _elapsedSeconds++;
            });
          }
        });
      } else if (sessionStatus == 3) {
        // If on break, calculate break duration based on break_started_at
        String? breakStartStr = widget.clockStatus!['break_started_at'];
        if (breakStartStr != null) {
          try {
            DateTime breakStart = DateTime.parse(breakStartStr).toLocal();
            int diff = DateTime.now().difference(breakStart).inSeconds;
            // Absolute value to prevent negative times if timezones are misaligned
            _elapsedSeconds = diff.abs();
          } catch (_) {
            _elapsedSeconds = 0;
          }
          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (mounted) {
              setState(() {
                _elapsedSeconds++;
              });
            }
          });
        }
      }
    }
  }

  String _formatElapsed(int seconds) {
    int h = seconds ~/ 3600;
    int m = (seconds % 3600) ~/ 60;
    int s = seconds % 60;
    String hStr = h.toString().padLeft(2, '0');
    String mStr = m.toString().padLeft(2, '0');
    String sStr = s.toString().padLeft(2, '0');
    return '$hStr:$mStr:$sStr';
  }

  void _showConfirmDialog(
      String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content:
            Text(content, style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6)),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<Position?> _getSafePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await shared.PermissionHelper.requestAllRequiredPermissions();
        permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
          timeLimit: const Duration(seconds: 4));
    } catch (e) {
      return null;
    }
  }

  Future<bool> _handlePhotoProofGate(Map<String, dynamic> settings, String attemptType) async {
    bool requirePhoto = false;
    int photoCount = 1;
    String type = 'before';

    if (attemptType == 'start' && settings['require_photo_before'] == true) {
      requirePhoto = true;
      photoCount = int.tryParse(settings['photo_before_count']?.toString() ?? '1') ?? 1;
      type = 'before';
    } else if (attemptType == 'finish' && settings['require_photo_after'] == true) {
      requirePhoto = true;
      photoCount = int.tryParse(settings['photo_after_count']?.toString() ?? '1') ?? 1;
      type = 'after';
    }

    if (!requirePhoto) return true;

    // Show a dialog that explains they need to take photos
    bool? wantToProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
         backgroundColor: const Color(0xFF1E293B),
         title: const Row(children: [Icon(Icons.camera_alt, color: Colors.blue), SizedBox(width: 8), Text('Photo Proof Required', style: TextStyle(color: Colors.white, fontSize: 18))]),
         content: Text('This job requires $photoCount "$type" photo(s) before you can $attemptType. Please open your camera.', style: const TextStyle(color: Colors.white70)),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.red))),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
             onPressed: () => Navigator.pop(ctx, true), 
             child: const Text('Take Photos', style: TextStyle(color: Colors.white))
           ),
         ]
      )
    );

    if (wantToProceed != true) return false;

    final ImagePicker picker = ImagePicker();
    List<Uint8List> capturedBytes = [];
    List<String> fileNames = [];
    
    for (int i=0; i<photoCount; i++) {
       final XFile? photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
       if (photo == null) {
          ToastService.error(context, 'You must take $photoCount photo(s) to proceed. You cancelled at photo ${i+1}.');
          return false;
       }
       final bytes = await photo.readAsBytes();
       capturedBytes.add(bytes);
       fileNames.add('evidence_${DateTime.now().millisecondsSinceEpoch}_$i.jpg');
    }

    // Upload them to ApiService
    setState(() => _isProcessing = true);
    try {
       await ApiService.instance.uploadJobEvidence(
         jobId: widget.jobId,
         photoType: type,
         taskName: null,
         description: 'Compliance Auto-upload ($type)',
         filesBytes: capturedBytes,
         fileNames: fileNames,
       );
       return true;
    } catch(e) {
       ToastService.error(context, 'Failed to upload photos: $e');
       return false;
    } finally {
       setState(() => _isProcessing = false);
    }
  }

  Future<void> _performAction(Future<void> Function(Position?) action, String attemptType) async {
    setState(() => _isProcessing = true);
    try {
      if (attemptType == 'start' || attemptType == 'drive') {
        final me = await ApiService.instance.getMe();
        if (me['gps_consent_at'] == null) {
          setState(() => _isProcessing = false);
          bool? consented = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GpsConsentScreen()),
          );
          if (consented != true) return;
          setState(() => _isProcessing = true);
        }

        // Task 10.7: Mobile Overlapping Jobs Check
        try {
          final activeJobsResponse = await ApiService.instance.get('/jobs?assigned_to=me&job_status=in_progress');
          if (activeJobsResponse != null && activeJobsResponse['data'] != null) {
             List activeJobs = activeJobsResponse['data'] is List ? activeJobsResponse['data'] : (activeJobsResponse['data']['data'] ?? []);
             if (activeJobs.isNotEmpty) {
                // Technically we should check allow_overlapping_jobs from settings here,
                // but if they have an active job and the backend doesn't block it directly here,
                // we'll fetch the settings or assume it's blocked by default to be safe.
                final locCheck = await ApiService.instance.post('/jobs/${widget.jobId}/check-location', {
                    'lat': 0, 'lng': 0, 'accuracy_m': 0, 'attempt_type': 'start', 'is_mock_location': false
                });
                
                final settings = locCheck?['data']?['settings'] ?? {};
                if (settings['allow_overlapping_jobs'] == false) {
                    setState(() => _isProcessing = false);
                    ToastService.error(context, "Finish your active job (${activeJobs.first['title']}) before starting a new one.");
                    return;
                }
             }
          }
        } catch (e) {
          // ignore
        }
      }

      Position? userPos = await _getSafePosition();

      // Location Verification Gate (Task 10.5)
      if (userPos != null && (attemptType == 'start' || attemptType == 'finish')) {
        try {
          final locCheck = await ApiService.instance.post('/jobs/${widget.jobId}/check-location', {
            'lat': userPos.latitude,
            'lng': userPos.longitude,
            'accuracy_m': userPos.accuracy,
            'attempt_type': attemptType,
            'is_mock_location': userPos.isMocked,
          });

          if (locCheck != null && locCheck['data'] != null) {
            final data = locCheck['data'];
            if (data['allowed'] == false) {
              setState(() => _isProcessing = false);
              
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: const Row(
                      children: [
                        Icon(Icons.location_off, color: Colors.redAccent),
                        SizedBox(width: 10),
                        Text('Location Blocked', style: TextStyle(color: Colors.white, fontSize: 18)),
                      ],
                    ),
                    content: Text(data['message'] ?? 'You are not allowed to clock in from here.', style: const TextStyle(color: Colors.white70)),
                    actions: [
                      if (data['reason'] == 'outside_geofence' && widget.mapUrl != null)
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final url = Uri.parse(widget.mapUrl!);
                            if (await canLaunchUrl(url)) {
                              await launchUrl(url);
                            }
                          },
                          child: const Text('OPEN MAPS', style: TextStyle(color: Color(0xFF10B981))),
                        ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK', style: TextStyle(color: Colors.blue)),
                      )
                    ],
                  )
                );
              }
              return; // Block execution!
            }

            // Photo Proof Gate (Task 10.6)
            if (data['settings'] != null) {
              bool photosDone = await _handlePhotoProofGate(data['settings'], attemptType);
              if (!photosDone) {
                return; // Abort if they didn't complete photos
              }
            }
          }
        } catch (e) {
          print("Location/Photo check warning: $e");
          // Proceed gracefully if backend doesn't support it yet
        }
      }

      await action(userPos);
      if (attemptType == 'start' || attemptType == 'drive') {
        LocationTrackingService.instance.startTracking();
      } else if (attemptType == 'finish') {
        LocationTrackingService.instance.stopTracking();
      }
      await widget.onStateChanged();
    } catch (e) {
      if (mounted) ToastService.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _checkCompletionGate() async {
    setState(() => _isProcessing = true);
    try {
      final res =
          await ApiService.instance.getChecklistCompletionStatus(widget.jobId);
      final resData = res['data'] ?? res; // In case wrapped in successResponse
      final bool canComplete = resData['all_required_done'] ?? resData['can_complete'] ?? false;
      final blockers = resData['blockers'] as List<dynamic>? ?? [];

      setState(() => _isProcessing = false);

      if (!canComplete) {
        // Blocked
        showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.redAccent),
                      SizedBox(width: 10),
                      Text('Completion Blocked',
                          style: TextStyle(color: Colors.white, fontSize: 18)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'You cannot finish this job yet. Please complete the following:',
                          style: TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      if (blockers.isNotEmpty) ...[
                        const Text('Pending Items:',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        ...blockers.map((b) {
                           String issue = b['issue'] == 'missing_required_photo' ? ' (Needs Photo)' : '';
                           return Text('• ' + (b['name'] ?? b['text'] ?? '') + issue, style: const TextStyle(color: Colors.redAccent));
                        }),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK',
                          style: TextStyle(color: Colors.blue)),
                    )
                  ],
                ));
      } else {
        // Unblocked -> Proceed to signature
        final bool? success = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SignatureScreen(jobId: widget.jobId)),
        );
        if (success == true) {
          _performAction((pos) => ApiService.instance
              .clockOut(widget.jobId, pos?.latitude, pos?.longitude), 'finish');
        }
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      ToastService.error(context, 'Failed to verify completion status');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentJobActive = widget.clockStatus != null &&
        widget.clockStatus!['status'] == 'clocked_in' &&
        widget.clockStatus!['job_id']?.toString() == widget.jobId.toString();

    String rawStatus = widget.jobStatus.toLowerCase();
    bool isCompleted = rawStatus == 'completed';
    int sessionStatus =
        isCurrentJobActive ? (widget.clockStatus!['session_status'] ?? 1) : 0;
    bool isOnBreak = sessionStatus == 3 || rawStatus == 'on_hold';
    bool hasClockedIn = isCurrentJobActive;

    if (isCompleted && !hasClockedIn) {
      const Color accentGreen = Color(0xFF10B981);
      return Container(
        width: double.infinity,
        height: 55,
        decoration: BoxDecoration(
          color: accentGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accentGreen.withOpacity(0.4)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
            SizedBox(width: 8),
            Text('SHIFT COMPLETED',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white)),
          ],
        ),
      );
    }

    if (!hasClockedIn) {
      bool isReadyToWork = rawStatus == 'en_route' || rawStatus == 'in_progress';
      
      if (!isReadyToWork) {
        return SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6), // blue for driving
              foregroundColor: Colors.white,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: _isProcessing
                ? null
                : () {
                    _showConfirmDialog('🚗 Start Driving?',
                        'Are you en route to the job location?', () {
                      _performAction((pos) => ApiService.instance
                          .startDriving(widget.jobId, pos?.latitude, pos?.longitude), 'drive');
                    });
                  },
            child: _isProcessing
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car, size: 18),
                      SizedBox(width: 8),
                      Text('START DRIVING',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4FF00), // neon yellow
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isProcessing
              ? null
              : () {
                  _showConfirmDialog('🚨 Start Shift?',
                      'Are you sure you want to Clock In now?', () {
                    _performAction((pos) => ApiService.instance
                        .clockIn(widget.jobId, pos?.latitude, pos?.longitude), 'start');
                  });
                },
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.black)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 18),
                    SizedBox(width: 8),
                    Text('START JOB',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
        ),
      );
    }

    // Active state (In Progress or On Break)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timer Display
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          decoration: BoxDecoration(
            color: isOnBreak
                ? Colors.deepOrange.withOpacity(0.1)
                : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isOnBreak
                    ? Colors.deepOrange.withOpacity(0.3)
                    : Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isOnBreak) ...[
                const Icon(Icons.timer, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(_formatElapsed(_elapsedSeconds),
                    style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'monospace')),
                const SizedBox(width: 8),
                const Icon(Icons.circle,
                    color: Colors.green,
                    size: 8), // Can't easily animate pulse, but good enough
              ] else ...[
                const Icon(Icons.coffee, color: Colors.deepOrange, size: 16),
                const SizedBox(width: 8),
                Text('ON BREAK — ${_formatElapsed(_elapsedSeconds)}',
                    style: const TextStyle(
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ]
            ],
          ),
        ),
        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOnBreak ? Colors.green : Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        _performAction((pos) => ApiService.instance.clockBreak(
                            widget.jobId, pos?.latitude, pos?.longitude), 'break');
                      },
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isOnBreak ? Icons.play_arrow : Icons.pause,
                              size: 18),
                          const SizedBox(width: 4),
                          Text(isOnBreak ? 'RESUME' : 'BREAK',
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444), // red
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        _showConfirmDialog('🛑 Finish Shift?',
                            'Are you sure you want to Finish this shift?', () {
                          _checkCompletionGate();
                        });
                      },
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.stop, size: 18),
                          SizedBox(width: 4),
                          Text('FINISH',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

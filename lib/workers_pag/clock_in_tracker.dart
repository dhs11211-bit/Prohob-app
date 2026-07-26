// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../backend/api_service.dart';
import '../shared/job_detail_screen.dart';
import '../components/contact_list_modal.dart';
import '../components/quick_map_modal.dart';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';


class ClockInTracker extends StatefulWidget {
  const ClockInTracker({Key? key, this.width, this.height}) : super(key: key);
  final double? width;
  final double? height;
  @override
  _ClockInTrackerState createState() => _ClockInTrackerState();
}

class _ClockInTrackerState extends State<ClockInTracker> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentRed = const Color(0xFFEF4444);

  bool _isProcessing = false;
  bool _isShiftExpanded = false;
  Timer? _timer;

  final PageController _pageController = PageController(viewportFraction: 0.95);
  int _currentJobIndex = 0;

  final String _darkMinimalMapStyle = '''
  [
    { "elementType": "geometry", "stylers": [{ "color": "#0F172A" }] },
    { "elementType": "labels.icon", "stylers": [{ "visibility": "off" }] },
    { "elementType": "labels.text.fill", "stylers": [{ "color": "#64748B" }] },
    { "elementType": "labels.text.stroke", "stylers": [{ "visibility": "off" }] },
    { "featureType": "administrative", "elementType": "geometry", "stylers": [{ "color": "#1E293B" }] },
    { "featureType": "poi", "stylers": [{ "visibility": "off" }] },
    { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#1E293B" }] },
    { "featureType": "road", "elementType": "labels.text.fill", "stylers": [{ "color": "#94A3B8" }] },
    { "featureType": "transit", "stylers": [{ "visibility": "off" }] },
    { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#000000" }] }
  ]
  ''';


  List<dynamic> _todayJobs = [];
  bool _isLoadingJobs = true;
  Map<String, dynamic>? _clockStatus;
  
  @override
  void initState() {
    super.initState();
    _fetchData();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _fetchData() async {
    try {
      final jobs = await ApiService.instance.getTodayJobs();
      final status = await ApiService.instance.getClockStatus();
      if (mounted) {
        setState(() {
          _todayJobs = jobs;
          _clockStatus = status;
          _isLoadingJobs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingJobs = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
    }
  }


  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: card,
        title: Text(title, style: TextStyle(color: text)),
        content: Text(content, style: TextStyle(color: muted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
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

  String _getFormattedTime(DateTime time) {
    return DateFormat('hh:mm a').format(time);
  }

  Future<void> _openInAppMap(double? lat, double? lng, String address, String timeLabel) async {
    final tempJobData = {
      'address': address,
      'latitude': lat,
      'longitude': lng,
    };
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return QuickMapModal(
          jobData: tempJobData,
          title: 'Job Location',
        );
      },
    );
  }

  Future<void> _performClockIn(int jobId, double? jobLat, double? jobLng, DateTime? scheduledTime) async {
    _showConfirmDialog('🚨 Start Shift?', 'Are you sure you want to Clock In now?', () async {
      setState(() => _isProcessing = true);
      Position? userPos;
      try {
        userPos = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 4));
      } catch (e) {
        print("GPS Bypass");
      }
      try {
        await ApiService.instance.clockIn(jobId, userPos?.latitude, userPos?.longitude);
        await _fetchData();
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _performClockOut(int jobId, DateTime clockInTime, String clientName) async {
    _showConfirmDialog('🛑 Complete Shift?',
        'Are you sure you want to Complete this shift? This will send it to the Admin for review.',
        () async {
      setState(() => _isProcessing = true);
      Position? userPos;
      try {
        userPos = await Geolocator.getCurrentPosition(
            timeLimit: const Duration(seconds: 4));
      } catch (e) {
        print("GPS Bypass");
      }
      try {
        await ApiService.instance.clockOut(jobId, userPos?.latitude, userPos?.longitude);
        await _fetchData();
        if (mounted) setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  Future<void> _toggleTaskStatus(int jobId, String taskName, Map<String, dynamic> currentStatusMap) async {
    bool isDone = !(currentStatusMap[taskName] == true);
    if (isDone) {
      _showConfirmDialog(
        'Mark Task Completed?',
        'Are you sure you want to mark "$taskName" as completed?',
        () async {
          _executeToggleTask(jobId, taskName, true);
        },
      );
    } else {
      _executeToggleTask(jobId, taskName, false);
    }
  }

  Future<void> _executeToggleTask(int jobId, String taskName, bool isDone) async {
    setState(() => _isProcessing = true);
    try {
      await ApiService.instance.updateChecklist(jobId, taskName, isDone);
      await _fetchData();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error updating task: $e'),
            backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openSwapShiftModal(int jobId) {
    String swapReason = 'Personal Emergency';
    final detailsController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModal) => Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    top: 24),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                  color: muted.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 24),
                      Text('Request Shift Swap',
                          style: TextStyle(
                              color: text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          'A request will be sent to your Admin for approval. You are still responsible for this shift until it is officially reassigned.',
                          style: TextStyle(
                              color: muted, fontSize: 13, height: 1.4)),
                      const SizedBox(height: 24),
                      Text('Reason',
                          style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                  value: swapReason,
                                  dropdownColor: card,
                                  isExpanded: true,
                                  style: TextStyle(color: text, fontSize: 16),
                                  items: [
                                    'Personal Emergency',
                                    'Sick Leave',
                                    'Transportation Issue',
                                    'Other'
                                  ]
                                      .map((s) => DropdownMenuItem(
                                          value: s, child: Text(s)))
                                      .toList(),
                                  onChanged: (v) =>
                                      setModal(() => swapReason = v!)))),
                      const SizedBox(height: 20),
                      Text('Additional Details (Optional)',
                          style: TextStyle(color: muted, fontSize: 12)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: detailsController,
                          maxLines: 3,
                          style: TextStyle(color: text),
                          decoration: InputDecoration(
                              filled: true,
                              fillColor: card,
                              hintText: 'Explain briefly...',
                              hintStyle:
                                  TextStyle(color: muted.withOpacity(0.5)),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none))),
                      const Spacer(),
                      SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16))),
                              onPressed: isSubmitting ? null : () async {
                                setModal(() => isSubmitting = true);
                                try {
                                  await ApiService.instance.submitSwapRequest(jobId, swapReason, detailsController.text.trim());
                                  if (mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Swap request sent to Admin!'), backgroundColor: Colors.green)
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                                    );
                                    setModal(() => isSubmitting = false);
                                  }
                                }
                              },
                              child: isSubmitting
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('SUBMIT REQUEST',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 30)
                    ]))));
  }

  void _deleteSwapRequest(int jobId) {
    _showConfirmDialog('Delete Swap Request?', 'Are you sure you want to delete this shift swap request? This action will remove your request from the system.', () async {
      setState(() => _isProcessing = true);
      try {
        await ApiService.instance.cancelSwapRequest(jobId);
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap request deleted'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  void _cancelSwapRequest(int jobId) {
    _showConfirmDialog('Cancel Swap Request?', 'Are you sure you want to cancel your shift swap request? You will remain assigned to this shift.', () async {
      setState(() => _isProcessing = true);
      try {
        await ApiService.instance.cancelSwapRequest(jobId);
        await _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Swap request cancelled'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    });
  }

  void _openAdminMessage() {
    final TextEditingController adminMsgController = TextEditingController();
    bool isSending = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (c) => StatefulBuilder(
            builder: (ctx, setModal) => Container(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                    left: 24,
                    right: 24,
                    top: 24),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32))),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Message Dispatch',
                          style: TextStyle(
                              color: text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: adminMsgController,
                          maxLines: 3,
                          style: TextStyle(color: text),
                          decoration: InputDecoration(
                              hintText:
                                  'I am running late / I need equipment...',
                              hintStyle: TextStyle(color: muted),
                              filled: true,
                              fillColor: card,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none))),
                      const SizedBox(height: 20),
                      SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: accentBlue,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12))),
                              onPressed: isSending
                                  ? null
                                  : () async {
                                      if (adminMsgController.text
                                          .trim()
                                          .isEmpty) return;
                                      setModal(() => isSending = true);
                                      try {
                                        // TODO: Phase 4 - Connect to Laravel Chat API
                                        await Future.delayed(const Duration(seconds: 1));
                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text('Alert sent!'),
                                                backgroundColor: Colors.green));
                                      } catch (e) {
                                        setModal(() => isSending = false);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor:
                                                    Colors.redAccent));
                                      }
                                    },
                              child: isSending
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2))
                                  : const Text('SEND',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold)))),
                      const SizedBox(height: 30)
                    ]))));
  }

  Widget _statusBadge(String? status) {
    String l = (status ?? 'PENDING').toUpperCase();
    // Map snake_case backend values to display text
    final displayMap = {
      'IN_PROGRESS': 'IN PROGRESS',
      'ON_HOLD': 'ON BREAK',
      'EN_ROUTE': 'EN ROUTE',
    };
    String display = displayMap[l] ?? l;

    Color c = Colors.orange;
    if (l == 'COMPLETED') c = Colors.green.shade700;
    if (l == 'IN_PROGRESS' || l == 'IN PROGRESS') c = neonAction;
    if (l == 'SCHEDULED') c = accentBlue;
    if (l == 'EN_ROUTE' || l == 'EN ROUTE') c = Colors.purpleAccent;
    if (l == 'ON_HOLD' || l == 'ON BREAK') c = Colors.deepOrange;
    if (l == 'DRAFT') c = Colors.grey;

    Color tc = (c == neonAction) ? Colors.black : Colors.white;
    if (l == 'SCHEDULED' || l == 'DRAFT') tc = Colors.white;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        child: Text(display,
            style: TextStyle(
                color: tc, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _subBtn(IconData i, String l) => Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border.all(color: muted.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(i, size: 18, color: text),
        const SizedBox(width: 8),
        Text(l, style: TextStyle(color: text))
      ]));

  DateTime _parseSafeDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is String) return DateTime.parse(val);
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    return DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        height: widget.height ?? MediaQuery.of(context).size.height,
        width: widget.width ?? double.infinity,
        color: bg,
        child: _isLoadingJobs
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Builder(builder: (context) {
                var todayJobs = _todayJobs;
                if (todayJobs.isEmpty) {
                  return Center(
                      child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 32),
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5)
                              ]),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                    color: neonAction.withOpacity(0.1),
                                    shape: BoxShape.circle),
                                child: Icon(Icons.coffee_rounded,
                                    color: neonAction, size: 50)),
                            const SizedBox(height: 24),
                            Text('You\'re all caught up!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: text,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(
                                'No shifts assigned for today. Enjoy your time off or wait for Dispatch to update.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: muted, fontSize: 15, height: 1.5))
                          ])));
                }
                
                if (_currentJobIndex >= todayJobs.length) {
                  _currentJobIndex = 0;
                }


              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        height: _isShiftExpanded 
                            ? (todayJobs.isNotEmpty && _currentJobIndex < todayJobs.length && todayJobs[_currentJobIndex]['swap_request'] != null && todayJobs[_currentJobIndex]['swap_request']['status']?.toString() != '9' ? 420 : 360) 
                            : (todayJobs.isNotEmpty && _currentJobIndex < todayJobs.length && todayJobs[_currentJobIndex]['swap_request'] != null && todayJobs[_currentJobIndex]['swap_request']['status']?.toString() != '9' ? 360 : 280),
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) =>
                              setState(() => _currentJobIndex = index),
                          itemCount: todayJobs.length,
                          itemBuilder: (context, index) {
                            var jobData = todayJobs[index];
                            int jobId = jobData['id'];
                            String clientName =
                                jobData['customer_name'] ?? 'Assigned Shift';
                            String jobTitle = 
                                jobData['title'] ?? jobData['job_type'] ?? '';
                            String displayAddress =
                                jobData['address'] ?? 'No address set';

                            DateTime? scheduledTime =
                                _parseSafeDate(jobData['start_date'] ?? jobData['scheduled_time']);
                            String shiftTimeLabel =
                                DateFormat('hh:mm a').format(scheduledTime);
                            String shiftDateLabel =
                                DateFormat('EEEE, MMM d').format(scheduledTime);

                            double? jobLat;
                            double? jobLng;

                            if (jobData['location'] is Map<String, dynamic>) {
                              jobLat =
                                  double.tryParse((jobData['location'] as Map<String, dynamic>)['latitude']?.toString() ?? '');
                              jobLng =
                                  double.tryParse((jobData['location'] as Map<String, dynamic>)['longitude']?.toString() ?? '');
                            } else if (jobData['lat'] != null &&
                                jobData['lng'] != null) {
                              jobLat =
                                  double.tryParse(jobData['lat'].toString());
                              jobLng =
                                  double.tryParse(jobData['lng'].toString());
                            } else if (jobData['latitude'] != null &&
                                jobData['longitude'] != null) {
                              jobLat = double.tryParse(
                                  jobData['latitude'].toString());
                              jobLng = double.tryParse(
                                  jobData['longitude'].toString());
                            }

                            return Builder(
                                builder: (context) {
                                  // Determine clock status for THIS specific job
                                  // A job is "active" only when _clockStatus points to it
                                  bool isCurrentJobActive = _clockStatus != null &&
                                      _clockStatus!['status'] == 'clocked_in' &&
                                      _clockStatus?['job_id'] == jobId;

                                  // A job is "completed" when its backend status says so
                                  String rawStatus = (jobData['job_status'] ?? '').toString().toLowerCase();
                                  bool isCompleted = rawStatus == 'completed';
                                  bool isOnBreak = rawStatus == 'on_hold';

                                  DateTime? clockInTime = isCurrentJobActive && _clockStatus?['clock_in_time'] != null
                                      ? DateTime.tryParse(_clockStatus!['clock_in_time'])
                                      : null;

                                  bool hasClockedIn = isCurrentJobActive && clockInTime != null;
                                  bool hasClockedOut = isCompleted;

                                  String buttonLabel = 'CLOCK IN';
                                  if (hasClockedOut) {
                                    buttonLabel = '✓ SHIFT COMPLETED';
                                  } else if (isOnBreak) {
                                    buttonLabel = 'ON BREAK — TAP TO RESUME';
                                  } else if (hasClockedIn) {
                                    buttonLabel = 'COMPLETE SHIFT — ${_getFormattedTime(clockInTime!)}';
                                  }

                                  Map<String, dynamic>? swapRequest = jobData['swap_request'] is Map ? jobData['swap_request'] : null;
                                  String swapStatus = 'none';
                                  if (swapRequest != null) {
                                    String rawS = swapRequest['status']?.toString().toLowerCase() ?? '0';
                                    if (rawS == '9' || rawS == 'deleted') {
                                      swapRequest = null;
                                      swapStatus = 'none';
                                    } else if (rawS == '0' || rawS == 'submitted') {
                                      swapStatus = 'submitted';
                                    } else if (rawS == '1' || rawS == 'reviewed') {
                                      swapStatus = 'reviewed';
                                    } else if (rawS == '2' || rawS == 'pending') {
                                      swapStatus = 'pending';
                                    } else if (rawS == '3' || rawS == 'rejected') {
                                      swapStatus = 'rejected';
                                    } else if (rawS == '4' || rawS == 'accepted' || rawS == 'approved') {
                                      swapStatus = 'accepted';
                                    } else {
                                      swapStatus = rawS;
                                    }
                                  }

                                  Color swapColor = Colors.orange;
                                  if (swapStatus == 'accepted') swapColor = Colors.green;
                                  if (swapStatus == 'rejected') swapColor = Colors.red;
                                  if (swapStatus == 'reviewed') swapColor = Colors.blue;

                                  bool isCancelable = swapStatus == 'submitted' || swapStatus == 'pending';

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8.0),
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                          padding: const EdgeInsets.symmetric(
                                               horizontal: 20, vertical: 16),
                                          decoration: BoxDecoration(
                                              color: card,
                                              borderRadius:
                                                  BorderRadius.circular(24),
                                              boxShadow: const [
                                                BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 10)
                                              ]),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                          if (swapRequest != null)
                                            Container(
                                              margin: const EdgeInsets.only(bottom: 16),
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                              decoration: BoxDecoration(
                                                color: swapColor.withOpacity(0.2),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: swapColor.withOpacity(0.5)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    swapStatus == 'accepted' ? Icons.check_circle : (swapStatus == 'rejected' ? Icons.cancel : Icons.pending_actions),
                                                    color: swapColor,
                                                    size: 20
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Swap Request: ${swapStatus.toUpperCase()}',
                                                      style: TextStyle(
                                                        color: swapColor,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13
                                                      )
                                                    )
                                                  ),
                                                  if (isCancelable)
                                                    GestureDetector(
                                                      onTap: () => _deleteSwapRequest(jobId),
                                                      child: const Icon(Icons.delete_outline, color: Colors.orange, size: 20),
                                                    )
                                                ],
                                              )
                                            ),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Text(
                                                                'SCHEDULED SHIFT',
                                                                style: TextStyle(
                                                                    color:
                                                                        accentBlue,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                    letterSpacing:
                                                                        1.2)),
                                                            const SizedBox(
                                                                width: 8),
                                                            Text(
                                                                '• $shiftDateLabel',
                                                                style: TextStyle(
                                                                    color:
                                                                        muted,
                                                                    fontSize:
                                                                        10,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600)),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                            height: 8),
                                                        Text(clientName,
                                                            style: TextStyle(
                                                                color: text,
                                                                fontSize: 20,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis),
                                                        if (jobTitle.isNotEmpty) ...[
                                                          const SizedBox(height: 4),
                                                          Text(jobTitle,
                                                              style: TextStyle(
                                                                  color: muted,
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis),
                                                        ],
                                                        const SizedBox(
                                                            height: 4),
                                                        Row(children: [
                                                          Icon(Icons.schedule,
                                                              color: muted,
                                                              size: 18),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text(shiftTimeLabel,
                                                              style: TextStyle(
                                                                  color: muted,
                                                                  fontSize: 16,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500))
                                                        ])
                                                      ]),
                                                ),
                                                if (hasClockedIn &&
                                                    !hasClockedOut)
                                                  Container(
                                                      width: 12,
                                                      height: 12,
                                                      decoration:
                                                          const BoxDecoration(
                                                              color: Colors
                                                                  .redAccent,
                                                              shape: BoxShape
                                                                  .circle)),
                                                 InkWell(
                                                   onTap: () {
                                                     Navigator.push(
                                                       context,
                                                       MaterialPageRoute(
                                                         builder: (context) => SharedJobDetailScreen(jobId: jobId),
                                                       ),
                                                     );
                                                   },
                                                   borderRadius: BorderRadius.circular(20),
                                                   child: Container(
                                                     padding: const EdgeInsets.all(8),
                                                     decoration: BoxDecoration(
                                                       color: Colors.white.withOpacity(0.08),
                                                       shape: BoxShape.circle,
                                                       border: Border.all(color: Colors.white12),
                                                     ),
                                                     child: const Icon(
                                                       Icons.arrow_forward_ios_rounded,
                                                       color: Colors.white70,
                                                       size: 14,
                                                     ),
                                                   ),
                                                 ),
                                              ]),
                                          const SizedBox(height: 20),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text('Status',
                                                          style: TextStyle(
                                                              color: muted,
                                                              fontSize: 11)),
                                                      const SizedBox(height: 6),
                                                      _statusBadge(jobData['job_status']?.toString())
                                                    ]),
                                                GestureDetector(
                                                  onTap: () => _openInAppMap(
                                                      jobLat,
                                                      jobLng,
                                                      displayAddress,
                                                      shiftTimeLabel),
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 12,
                                                        vertical: 8),
                                                    decoration: BoxDecoration(
                                                        color: Colors.orange
                                                            .withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(12),
                                                        border: Border.all(
                                                            color: Colors.orange
                                                                .withOpacity(
                                                                    0.3))),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.map_outlined,
                                                            color: Colors.orange,
                                                            size: 16),
                                                        const SizedBox(
                                                            width: 6),
                                                        Text(
                                                            displayAddress.length >
                                                                    18
                                                                ? '${displayAddress.substring(0, 18)}...'
                                                                : displayAddress,
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.orange,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 12)),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                              ]),
                                          const Divider(
                                              height: 40,
                                              color: Colors.white10),
                                          Row(children: [
                                            Expanded(
                                                child: SizedBox(
                                                    height: 55,
                                                    child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                            backgroundColor: hasClockedOut
                                                                ? Colors.green.shade700
                                                                : (isOnBreak
                                                                    ? Colors.deepOrange
                                                                    : (hasClockedIn
                                                                        ? accentRed
                                                                        : neonAction)),
                                                            foregroundColor: (hasClockedOut || isOnBreak || hasClockedIn)
                                                                ? Colors.white
                                                                : Colors.black,
                                                            shape: RoundedRectangleBorder(
                                                                borderRadius: BorderRadius.circular(16))),
                                                        // Completed jobs: disable the main button. Clock-in opens fresh.
                                                        onPressed: _isProcessing || hasClockedOut
                                                            ? null
                                                            : (hasClockedIn
                                                                ? () => _performClockOut(
                                                                    jobId,
                                                                    clockInTime!,
                                                                    clientName)
                                                                : () => _performClockIn(
                                                                    jobId, jobLat, jobLng, scheduledTime)),
                                                        child: _isProcessing
                                                            ? const CircularProgressIndicator(color: Colors.white)
                                                            : Row(
                                                                mainAxisAlignment: MainAxisAlignment.center,
                                                                children: [
                                                                  if (hasClockedOut)
                                                                    const Icon(Icons.check_circle_outline, size: 18),
                                                                  if (hasClockedOut) const SizedBox(width: 8),
                                                                  Text(buttonLabel,
                                                                      style: const TextStyle(
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 16)),
                                                                ],
                                                              )))),
                                            const SizedBox(width: 12),
                                            GestureDetector(
                                                onTap: () => setState(() =>
                                                    _isShiftExpanded =
                                                        !_isShiftExpanded),
                                                child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                            16),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white10,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16)),
                                                    child: Icon(
                                                        _isShiftExpanded
                                                            ? Icons.close
                                                            : Icons.more_horiz,
                                                        color: text)))
                                          ]),
                                          if (_isShiftExpanded) ...[
                                            const SizedBox(height: 20),
                                            // If completed, show summary instead of action buttons
                                            if (hasClockedOut)
                                              Container(
                                                padding: const EdgeInsets.all(16),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.shade900.withOpacity(0.3),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: Colors.green.shade700.withOpacity(0.5)),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Icon(Icons.check_circle, color: Colors.green.shade400, size: 20),
                                                        const SizedBox(width: 8),
                                                        Text('Timesheet submitted for Admin review',
                                                            style: TextStyle(color: Colors.green.shade400, fontSize: 13, fontWeight: FontWeight.w600)),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Row(children: [
                                               Expanded(
                                                   child: GestureDetector(
                                                       onTap: () {
                                                         if (swapRequest == null) {
                                                           _openSwapShiftModal(jobId);
                                                         } else if (isCancelable) {
                                                           _cancelSwapRequest(jobId);
                                                         }
                                                       },
                                                       child: _subBtn(
                                                           swapRequest != null ? Icons.info_outline : Icons.swap_calls,
                                                           swapRequest == null 
                                                             ? 'Swap Shift' 
                                                             : (isCancelable ? 'Cancel Swap Request' : 'Swap ${swapStatus.toUpperCase()}')))),
                                               const SizedBox(width: 12),
                                               Expanded(
                                                   child: GestureDetector(
                                                       onTap: () => ContactListModal.show(context),
                                                       child: _subBtn(
                                                           Icons.message,
                                                           'Contact')))
                                             ])
                                          ]
                                        ]))),
                                  );
                                }); // Closes Builder
                          }, // Closes itemBuilder
                        ), // Closes PageView.builder
                      ), // Closes SizedBox
                      if (todayJobs.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(todayJobs.length, (index) {
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                width: _currentJobIndex == index ? 24 : 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: _currentJobIndex == index
                                        ? neonAction
                                        : Colors.white24,
                                    borderRadius: BorderRadius.circular(4)),
                              );
                            }),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 16),
                            Text('TASK CHECKLIST',
                                style: TextStyle(
                                    color: muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2)),
                            const SizedBox(height: 16),
                            Builder(
                                builder: (context) {
                                  var jobData = todayJobs[_currentJobIndex];
                                  int jobId = jobData['id'];
                                  List<dynamic> safeTasks = jobData['checklist'] ?? [];
                                  if (safeTasks.isEmpty)
                                    return Text(
                                        'No tasks assigned for this job.',
                                        style: TextStyle(
                                            color: muted, fontSize: 14));

                                  List<dynamic> sortedTasks = List.from(safeTasks);
                                  sortedTasks.sort((a, b) {
                                    bool aCompleted = a is Map ? a['completed'] == true : false;
                                    bool bCompleted = b is Map ? b['completed'] == true : false;
                                    if (aCompleted == bCompleted) return 0;
                                    return aCompleted ? 1 : -1;
                                  });

                                  bool hasClockedIn = _clockStatus?['job_id'] == jobId;
                                  
                                  Map<String, dynamic> taskStatusMap = {};
                                  Map<String, String?> taskCompletedAtMap = {};
                                  for (var item in safeTasks) {
                                    if (item is Map) {
                                      String? tName = item['name']?.toString() ?? item['title']?.toString() ?? item['text']?.toString();
                                      if (tName != null) {
                                        taskStatusMap[tName] = item['completed'] == true;
                                        taskCompletedAtMap[tName] = item['completed_at']?.toString();
                                      }
                                    } else if (item is String) {
                                      taskStatusMap[item] = false;
                                      taskCompletedAtMap[item] = null;
                                    }
                                  }

                                  return Column(
                                      children: sortedTasks.map((taskItem) {
                                    String taskName = '';
                                    if (taskItem is Map) {
                                      taskName = taskItem['name']?.toString() ?? taskItem['title']?.toString() ?? taskItem['text']?.toString() ?? '';
                                    } else if (taskItem is String) {
                                      taskName = taskItem;
                                    }
                                    if (taskName.isEmpty) return const SizedBox.shrink();

                                    bool isCompleted = taskStatusMap[taskName] == true;
                                    String? completedAt = taskCompletedAtMap[taskName];
                                    String formattedTime = '';
                                    if (isCompleted && completedAt != null && completedAt.isNotEmpty) {
                                      try {
                                        DateTime? dt = DateTime.tryParse(completedAt);
                                        if (dt != null) {
                                          formattedTime = DateFormat('MMM d, h:mm a').format(dt.toLocal());
                                        }
                                      } catch (_) {}
                                    }

                                    Color btnColor = isCompleted
                                        ? accentBlue.withOpacity(0.2)
                                        : card;
                                    Color txtColor =
                                        isCompleted ? accentBlue : muted;
                                    String btnText =
                                        isCompleted ? 'DONE' : 'MARK READY';
                                    IconData btnIcon = isCompleted
                                        ? Icons.check_circle
                                        : Icons.circle_outlined;

                                    return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 12),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                            color: card,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                                color: isCompleted
                                                    ? accentBlue
                                                        .withOpacity(0.3)
                                                    : Colors.transparent)),
                                        child: Row(children: [
                                          Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                  color: bg,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: Icon(Icons.assignment,
                                                  color: isCompleted
                                                      ? accentBlue
                                                      : muted,
                                                  size: 20)),
                                          const SizedBox(width: 16),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(taskName,
                                                        style: TextStyle(
                                                            color: isCompleted
                                                                ? text
                                                                : Colors.white70,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                            fontSize: 15,
                                                            decoration: isCompleted ? TextDecoration.lineThrough : null)),
                                                    if (isCompleted && formattedTime.isNotEmpty) ...[
                                                      const SizedBox(height: 4),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                        decoration: BoxDecoration(
                                                          color: accentBlue.withOpacity(0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Text(
                                                          formattedTime,
                                                          style: TextStyle(
                                                            color: accentBlue,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ])),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                              onTap: () {
                                                if (!hasClockedIn) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(const SnackBar(
                                                          content: Text(
                                                              'You must Clock In first!'),
                                                          backgroundColor:
                                                              Colors.orange));
                                                  return;
                                                }
                                                _toggleTaskStatus(jobId,
                                                    taskName, taskStatusMap);
                                              },
                                              child: AnimatedContainer(
                                                  duration: const Duration(
                                                      milliseconds: 200),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 8),
                                                  decoration: BoxDecoration(
                                                      color: btnColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                          color: isCompleted
                                                              ? Colors
                                                                  .transparent
                                                              : Colors
                                                                  .white10)),
                                                  child: Row(
                                                    children: [
                                                      Icon(btnIcon,
                                                          color: txtColor,
                                                          size: 14),
                                                      const SizedBox(width: 4),
                                                      Text(btnText,
                                                          style: TextStyle(
                                                              color: txtColor,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold))
                                                    ],
                                                  )))
                                        ]));
                                  }).toList());
                                }),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }));
  }
}

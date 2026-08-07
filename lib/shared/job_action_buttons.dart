import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../backend/api_service.dart';
import '../shared/toast_service.dart';

class JobActionButtons extends StatefulWidget {
  final int jobId;
  final String jobStatus; // 'draft', 'scheduled', 'en_route', 'in_progress', 'completed', 'on_hold'
  final Map<String, dynamic>? clockStatus;
  final Future<void> Function() onStateChanged;
  final bool compact; // true = job card, false = full job detail
  final DateTime? scheduledTime;

  const JobActionButtons({
    Key? key,
    required this.jobId,
    required this.jobStatus,
    required this.clockStatus,
    required this.onStateChanged,
    this.compact = false,
    this.scheduledTime,
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
    if (oldWidget.clockStatus != widget.clockStatus || oldWidget.jobId != widget.jobId) {
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
        widget.clockStatus!['job_id'] == widget.jobId;

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
      int sessionStatus = widget.clockStatus!['session_status'] != null ? 
          int.tryParse(widget.clockStatus!['session_status'].toString()) ?? 1 : 1;
      
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

  void _showConfirmDialog(String title, String content, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(content, style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
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
      return await Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 4));
    } catch (e) {
      return null;
    }
  }

  Future<void> _performAction(Future<void> Function(Position?) action) async {
    setState(() => _isProcessing = true);
    try {
      Position? userPos = await _getSafePosition();
      await action(userPos);
      await widget.onStateChanged();
    } catch (e) {
      if (mounted) ToastService.error(context, 'Error: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCurrentJobActive = widget.clockStatus != null &&
        widget.clockStatus!['status'] == 'clocked_in' &&
        widget.clockStatus!['job_id'] == widget.jobId;

    String rawStatus = widget.jobStatus.toLowerCase();
    bool isCompleted = rawStatus == 'completed';
    int sessionStatus = isCurrentJobActive ? (widget.clockStatus!['session_status'] ?? 1) : 0;
    bool isOnBreak = sessionStatus == 3 || rawStatus == 'on_hold';
    bool hasClockedIn = isCurrentJobActive;

    if (isCompleted) {
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
            Text('SHIFT COMPLETED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
          ],
        ),
      );
    }

    if (!hasClockedIn) {
      return SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD4FF00), // neon yellow
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: _isProcessing ? null : () {
            _showConfirmDialog('🚨 Start Shift?', 'Are you sure you want to Clock In now?', () {
              _performAction((pos) => ApiService.instance.clockIn(widget.jobId, pos?.latitude, pos?.longitude));
            });
          },
          child: _isProcessing
              ? const CircularProgressIndicator(color: Colors.black)
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow, size: 18),
                    SizedBox(width: 8),
                    Text('START JOB', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
            color: isOnBreak ? Colors.deepOrange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isOnBreak ? Colors.deepOrange.withOpacity(0.3) : Colors.green.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!isOnBreak) ...[
                const Icon(Icons.timer, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Text(_formatElapsed(_elapsedSeconds), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'monospace')),
                const SizedBox(width: 8),
                const Icon(Icons.circle, color: Colors.green, size: 8), // Can't easily animate pulse, but good enough
              ] else ...[
                const Icon(Icons.coffee, color: Colors.deepOrange, size: 16),
                const SizedBox(width: 8),
                Text('ON BREAK — ${_formatElapsed(_elapsedSeconds)}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : () {
                  _performAction((pos) => ApiService.instance.clockBreak(widget.jobId, pos?.latitude, pos?.longitude));
                },
                child: _isProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isOnBreak ? Icons.play_arrow : Icons.pause, size: 18),
                        const SizedBox(width: 4),
                        Text(isOnBreak ? 'RESUME' : 'BREAK', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing ? null : () {
                  _showConfirmDialog('🛑 Finish Shift?', 'Are you sure you want to Finish this shift?', () {
                    _performAction((pos) => ApiService.instance.clockOut(widget.jobId, pos?.latitude, pos?.longitude));
                  });
                },
                child: _isProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.stop, size: 18),
                        SizedBox(width: 4),
                        Text('FINISH', style: TextStyle(fontWeight: FontWeight.bold)),
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

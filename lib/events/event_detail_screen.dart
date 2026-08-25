import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '../shared/toast_service.dart';
import '../shared/job_media_panel.dart'; // We can reuse media panel
import '../shared/job_notes_section.dart'; // We can reuse notes panel

class EventDetailScreen extends StatefulWidget {
  final int eventId;

  const EventDetailScreen({Key? key, required this.eventId}) : super(key: key);

  @override
  _EventDetailScreenState createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _eventData;
  List<dynamic> _attendees = [];

  // Reused colors
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardColor = const Color(0xFF1E293B);
  final Color accentBlue = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _loadEventDetail();
  }

  Future<void> _loadEventDetail() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.getJob(widget.eventId.toString());
      final attRes = await ApiService.instance.getEventAttendees(widget.eventId);
      setState(() {
        _eventData = res['data'];
        _attendees = attRes['data'] ?? [];
      });
    } catch (e) {
      debugPrint("Error loading event detail: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _respondRSVP(int attendeeId, String status) async {
    try {
      await ApiService.instance.updateEventAttendee(widget.eventId, attendeeId, {'rsvp_status': status});
      ToastService.success(context, 'RSVP updated');
      _loadEventDetail();
    } catch (e) {
      ToastService.error(context, 'Failed to update RSVP');
    }
  }

  Future<void> _duplicateEvent() async {
    try {
      await ApiService.instance.duplicateJob(widget.eventId, {
        'copy_customer': true,
        'copy_notes': true,
        'copy_attachments': true
      });
      ToastService.success(context, 'Event duplicated');
      Navigator.pop(context);
    } catch (e) {
      ToastService.error(context, 'Failed to duplicate event');
    }
  }

  Future<void> _convertEvent(String type) async {
    try {
      await ApiService.instance.convertEvent(widget.eventId, type);
      ToastService.success(context, 'Event converted to $type');
      Navigator.pop(context);
    } catch (e) {
      ToastService.error(context, 'Failed to convert event');
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  IconData _getRsvpIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle;
      case 'declined': return Icons.cancel;
      case 'tentative': return Icons.help;
      default: return Icons.schedule;
    }
  }

  Color _getRsvpColor(String status) {
    switch (status) {
      case 'accepted': return Colors.green;
      case 'declined': return Colors.red;
      case 'tentative': return Colors.orange;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _eventData == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dateStr = _eventData!['start_date'];
    final timeStr = _eventData!['start_time'];
    final address = _eventData!['address'];

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardColor,
        title: const Text('Event Detail'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'duplicate') _duplicateEvent();
              if (val == 'convert_job') _convertEvent('job');
              if (val == 'convert_estimate') _convertEvent('estimate');
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Event')),
              const PopupMenuItem(value: 'convert_job', child: Text('Convert to Job')),
              const PopupMenuItem(value: 'convert_estimate', child: Text('Convert to Estimate')),
            ],
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              _eventData!['title'] ?? 'Event #${_eventData!['job_number']}',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Schedule Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        dateStr != null ? DateFormat('MMMM d, yyyy').format(DateTime.parse(dateStr)) : 'No date',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.access_time, color: Colors.white54, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        timeStr != null ? timeStr.substring(0, 5) : 'Any time',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                  if (address != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on, color: Colors.white54, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "${address['street1'] ?? ''}\n${address['city'] ?? ''}, ${address['state'] ?? ''}",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),

            _buildSectionHeader('AGENDA'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _eventData!['description'] ?? 'No description provided.',
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),

            _buildSectionHeader('ATTENDEES'),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _attendees.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text("No attendees yet.", style: TextStyle(color: Colors.white54)),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attendees.length,
                      separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final att = _attendees[index];
                        final name = att['user'] != null ? att['user']['name'] : (att['external_name'] ?? att['external_email'] ?? 'Unknown');
                        final rsvp = att['rsvp_status'] ?? 'pending';
                        
                        return ListTile(
                          title: Text(name, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(att['role'] ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(rsvp.toUpperCase(), style: TextStyle(color: _getRsvpColor(rsvp), fontSize: 10, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              Icon(_getRsvpIcon(rsvp), color: _getRsvpColor(rsvp), size: 16),
                              
                              // If it's me, allow quick respond
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                                onSelected: (val) => _respondRSVP(att['id'], val),
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'accepted', child: Text('Accept')),
                                  PopupMenuItem(value: 'declined', child: Text('Decline')),
                                  PopupMenuItem(value: 'tentative', child: Text('Tentative')),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),

            _buildSectionHeader('EVENT NOTES'),
            JobNotesSection(jobId: widget.eventId), // Polymorphic reuse!

            _buildSectionHeader('ATTACHMENTS'),
            JobMediaPanel(jobId: widget.eventId), // Polymorphic reuse!

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

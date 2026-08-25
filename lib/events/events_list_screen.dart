import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import 'event_detail_screen.dart';

class EventsListScreen extends StatefulWidget {
  const EventsListScreen({Key? key}) : super(key: key);

  @override
  _EventsListScreenState createState() => _EventsListScreenState();
}

class _EventsListScreenState extends State<EventsListScreen> {
  bool _isLoading = true;
  List<dynamic> _events = [];
  String _activeTab = 'upcoming';

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{};
      if (_activeTab == 'upcoming') {
        params['status[]'] = 'scheduled';
      } else if (_activeTab == 'past') {
        params['status[]'] = 'completed';
      } else if (_activeTab == 'draft') {
        params['status[]'] = 'draft';
      }

      final res = await ApiService.instance.getEvents(params: params);
      setState(() {
        _events = res['data'] ?? [];
      });
    } catch (e) {
      debugPrint("Error loading events: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTab(String label, String value) {
    final isActive = _activeTab == value;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = value);
        _loadEvents();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.blue : Colors.grey.withOpacity(0.5),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.blue : Colors.white70,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Events'),
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTab('Upcoming', 'upcoming'),
                const SizedBox(width: 12),
                _buildTab('Past', 'past'),
                const SizedBox(width: 12),
                _buildTab('Draft', 'draft'),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(
                  child: Text(
                    'No events found',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final ev = _events[index];
                    final title = ev['title'] ?? 'Event #${ev['job_number']}';
                    final dateStr = ev['start_date'];
                    final timeStr = ev['start_time'];
                    
                    DateTime? date;
                    if (dateStr != null) {
                      date = DateTime.tryParse(dateStr);
                    }

                    return Card(
                      color: const Color(0xFF1E293B),
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EventDetailScreen(eventId: ev['id']),
                            ),
                          ).then((_) => _loadEvents());
                        },
                        leading: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                date != null ? DateFormat('MMM').format(date).toUpperCase() : 'TBD',
                                style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                date != null ? DateFormat('d').format(date) : '-',
                                style: const TextStyle(fontSize: 18, color: Colors.blue, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 14, color: Colors.white54),
                              const SizedBox(width: 4),
                              Text(
                                timeStr != null ? timeStr.substring(0, 5) : 'Any time',
                                style: const TextStyle(color: Colors.white54, fontSize: 12),
                              ),
                              const SizedBox(width: 12),
                              if (ev['address'] != null) ...[
                                const Icon(Icons.location_on, size: 14, color: Colors.white54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    ev['address']['street1'] ?? '',
                                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      ),
                    );
                  },
                ),
    );
  }
}

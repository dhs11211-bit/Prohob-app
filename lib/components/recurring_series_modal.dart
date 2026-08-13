import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class RecurringSeriesModal extends StatefulWidget {
  final int parentJobId;

  const RecurringSeriesModal({Key? key, required this.parentJobId}) : super(key: key);

  @override
  State<RecurringSeriesModal> createState() => _RecurringSeriesModalState();
}

class _RecurringSeriesModalState extends State<RecurringSeriesModal> {
  bool _isLoading = true;
  List<dynamic> _instances = [];

  @override
  void initState() {
    super.initState();
    _fetchInstances();
  }

  Future<void> _fetchInstances() async {
    try {
      final token = await ApiService.instance.getToken();
      
      final url = Uri.parse('${ApiService.baseUrl}/jobs?recurring_parent_id=${widget.parentJobId}&per_page=50');
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> items = data['data']['data'] ?? data['data'] ?? [];
        
        // Sort by start_date ascending
        items.sort((a, b) {
          final dateA = DateTime.tryParse(a['start_date'] ?? '') ?? DateTime(2000);
          final dateB = DateTime.tryParse(b['start_date'] ?? '') ?? DateTime(2000);
          return dateA.compareTo(dateB);
        });

        setState(() {
          _instances = items;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load instances');
      }
    } catch (e) {
      print('Error fetching recurring instances: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInstanceCard(dynamic job) {
    String status = (job['job_status'] ?? 'SCHEDULED').toString().toUpperCase();
    Color statusColor = const Color(0xFF3B82F6);
    if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

    DateTime? jobDate = DateTime.tryParse(job['start_date']?.toString() ?? '');
    String dateStr = jobDate != null ? DateFormat('MMM d, yyyy').format(jobDate) : 'No Date';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              "#${job['recurring_instance'] ?? '?'}",
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  job['job_number'] ?? '#${job['id']}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 12, color: Colors.white60),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                  ],
                ),
                if (job['hide_from_calendar'] == true || job['hide_from_calendar'] == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Row(
                      children: [
                        const Icon(Icons.visibility_off, size: 12, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        const Text(
                          "Hidden from Calendar",
                          style: TextStyle(color: Colors.orangeAccent, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recurring Series Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _instances.isEmpty
                    ? const Center(
                        child: Text(
                          'No instances generated yet.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _instances.length,
                        itemBuilder: (context, index) {
                          return _buildInstanceCard(_instances[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

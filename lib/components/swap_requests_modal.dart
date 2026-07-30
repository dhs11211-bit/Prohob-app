import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '/shared/toast_service.dart';

class SwapRequestsModal extends StatefulWidget {
  const SwapRequestsModal({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const SwapRequestsModal(),
    );
  }

  @override
  State<SwapRequestsModal> createState() => _SwapRequestsModalState();
}

class _SwapRequestsModalState extends State<SwapRequestsModal> {
  List<dynamic> _swapRequests = [];
  bool _isLoading = true;

  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _fetchSwapRequests();
  }

  String _normalizeStatus(dynamic statusVal) {
    String s = statusVal?.toString().toLowerCase() ?? '0';
    if (s == '0' || s == 'submitted') return 'SUBMITTED';
    if (s == '1' || s == 'reviewed') return 'REVIEWED';
    if (s == '2' || s == 'pending') return 'PENDING';
    if (s == '3' || s == 'rejected') return 'REJECTED';
    if (s == '4' || s == 'accepted' || s == 'approved') return 'ACCEPTED';
    if (s == '9' || s == 'deleted') return 'DELETED';
    return s.toUpperCase();
  }

  Color _getStatusColor(String normalizedStatus) {
    if (normalizedStatus == 'SUBMITTED' || normalizedStatus == 'PENDING') return Colors.orange;
    if (normalizedStatus == 'REVIEWED') return Colors.blue;
    if (normalizedStatus == 'ACCEPTED' || normalizedStatus == 'APPROVED') return Colors.green;
    if (normalizedStatus == 'REJECTED') return Colors.redAccent;
    return Colors.grey;
  }

  Future<void> _fetchSwapRequests() async {
    try {
      dynamic res;
      try {
        res = await ApiService.instance.get('/jobs/swap-requests');
      } catch (_) {
        try {
          res = await ApiService.instance.get('/swap-requests');
        } catch (_) {
          res = await ApiService.instance.getMyJobs();
        }
      }

      List<dynamic> list = [];
      if (res is Map && res['data'] != null) {
        final d = res['data'];
        if (d is Map && d['data'] != null) {
          list = List<dynamic>.from(d['data']);
        } else if (d is List) {
          list = List<dynamic>.from(d);
        }
      } else if (res is List) {
        list = List<dynamic>.from(res);
      }

      // Filter jobs with swap requests, excluding deleted (status = 9)
      List<dynamic> filtered = [];
      for (var item in list) {
        if (item is Map) {
          Map<String, dynamic>? swapReq = item['swap_request'] is Map
              ? item['swap_request']
              : (item.containsKey('reason') ? item : null);
          
          if (swapReq != null) {
            String st = swapReq['status']?.toString() ?? '';
            if (st != '9' && st.toLowerCase() != 'deleted') {
              filtered.add(item);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _swapRequests = filtered.isNotEmpty ? filtered : list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.swap_calls, color: accentBlue, size: 24),
                const SizedBox(width: 10),
                Text(
                  'My Swap Requests',
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Track all your shift swap requests and status updates',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _swapRequests.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending_actions, color: muted, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              'No swap requests submitted yet.',
                              style: TextStyle(color: muted, fontSize: 15),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _swapRequests.length,
                        itemBuilder: (context, index) {
                          final item = _swapRequests[index] as Map<String, dynamic>;

                          // Determine details based on response payload format
                          Map<String, dynamic>? swapReq = item['swap_request'] is Map
                              ? item['swap_request']
                              : item;

                          String jobTitle = item['title'] ?? item['customer_name'] ?? item['job_title'] ?? 'Shift Swap';
                          String reason = swapReq?['reason'] ?? 'Not specified';
                          String details = swapReq?['details'] ?? '';
                          String status = _normalizeStatus(swapReq?['status']);
                          Color statusColor = _getStatusColor(status);

                          DateTime? schedDate;
                          if (item['scheduled_time'] != null) {
                            schedDate = DateTime.tryParse(item['scheduled_time'].toString());
                          } else if (swapReq?['created_at'] != null) {
                            schedDate = DateTime.tryParse(swapReq!['created_at'].toString());
                          }
                          String dateStr = schedDate != null
                              ? DateFormat('EEE, MMM d, yyyy • hh:mm a').format(schedDate)
                              : '';

                          bool isCancelable = status == 'SUBMITTED' || status == 'PENDING';
                          int jobId = item['id'] is int ? item['id'] : (int.tryParse(item['job_id']?.toString() ?? '') ?? 0);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        jobTitle,
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: statusColor.withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (isCancelable && jobId > 0) ...[
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _confirmDeleteRequest(jobId),
                                            child: const Icon(Icons.delete_outline, color: Colors.orange, size: 20),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                if (dateStr.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    dateStr,
                                    style: TextStyle(color: muted, fontSize: 12),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Text('Reason: ', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.w600)),
                                    Expanded(
                                      child: Text(
                                        reason,
                                        style: TextStyle(color: text, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (details.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    details,
                                    style: TextStyle(color: muted.withOpacity(0.8), fontSize: 12, fontStyle: FontStyle.italic),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRequest(int jobId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        title: Text('Delete Swap Request?', style: TextStyle(color: text)),
        content: Text(
          'Are you sure you want to delete this shift swap request? This action cannot be undone.',
          style: TextStyle(color: muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.cancelSwapRequest(jobId);
                await _fetchSwapRequests();
                if (mounted) {
                  ToastService.success(context, 'Swap request deleted');
                }
              } catch (e) {
                if (mounted) {
                  ToastService.error(context, 'Error: $e');
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

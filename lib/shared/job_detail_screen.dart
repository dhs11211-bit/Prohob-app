import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_service.dart';
import '../components/global_chat_modal.dart';
import '../components/quick_map_modal.dart';
import '../shared/job_action_buttons.dart';
import 'auth_helpers.dart';
import 'job_parser.dart';
import '/shared/toast_service.dart';
import '/workers_pag/custom_evidence_modal.dart';
import '../components/create_invoice_modal.dart';
import '../components/invoice_detail_modal.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '/app_constants.dart';

class SharedJobDetailScreen extends StatefulWidget {
  const SharedJobDetailScreen({
    Key? key,
    required this.jobId,
  }) : super(key: key);

  final int jobId;

  @override
  State<SharedJobDetailScreen> createState() => _SharedJobDetailScreenState();
}

class _SharedJobDetailScreenState extends State<SharedJobDetailScreen> {
  final Color bg = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color accentGreen = const Color(0xFF10B981);
  final Color goldColor = const Color(0xFFF59E0B);
  final Color neonAction = const Color(0xFFD4FF00);

  bool _isLoading = true;
  Map<String, dynamic>? _clockStatus;
  Map<String, dynamic>? _jobData;
  String? _errorMessage;
  bool _showAddTaskInput = false;
  final TextEditingController _taskInputController = TextEditingController();

  @override
  void dispose() {
    _taskInputController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadJobDetail();
    _fetchGoogleMapsKey();
  }

  Future<void> _loadJobDetail() async {
    try {
      final res = await ApiService.instance.get('/jobs/${widget.jobId}');
      Map<String, dynamic>? clockRes;
      try {
        clockRes = await ApiService.instance.getClockStatus();
      } catch (_) {}
      if (mounted) {
        setState(() {
          _jobData = res is Map<String, dynamic> ? (res['data'] ?? res) : res;
          _clockStatus = clockRes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _showQuickMap() {
    if (_jobData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return QuickMapModal(
          jobData: _jobData!,
          title: _jobData!['title'] ?? _jobData!['customer_name'] ?? 'Job Location',
        );
      },
    );
  }

  void _launchCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ToastService.info(context, 'No phone number provided for contact.');
      return;
    }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ToastService.info(context, 'Calling $phone');
    }
  }

  void _showAssignWorkerModal() async {
    final res = await ApiService.instance.get('/admin/workers');
    List<dynamic> workers = [];
    if (res is Map && res.containsKey('data')) {
      workers = res['data'] is List ? res['data'] : [];
    } else if (res is List) {
      workers = res;
    }

    if (workers.isEmpty) {
      if (mounted) ToastService.info(context, "No staff available to assign.");
      return;
    }

    final assignedStaff = _jobData!['assigned_users'] is List ? _jobData!['assigned_users'] as List : [];
    final assignedStaffIds = assignedStaff.map((w) => w['id'].toString()).toSet();
    List<dynamic> availableWorkers = workers.where((w) => !assignedStaffIds.contains(w['id'].toString())).toList();

    Set<String> selectedIds = {};
    Map<String, String> workerRoles = { for (var w in availableWorkers) w['id'].toString() : (w['role_id']?.toString() ?? '3') };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assign Staff", style: TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (availableWorkers.isEmpty)
                    Text("All staff members are already assigned.", style: TextStyle(color: muted)),
                  if (availableWorkers.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableWorkers.length,
                        itemBuilder: (ctx, i) {
                          final w = availableWorkers[i];
                          final wId = w['id'].toString();
                          return CheckboxListTile(
                            title: Text("${w['first_name'] ?? ''} ${w['last_name'] ?? ''}".trim(), style: TextStyle(color: textWhite)),
                            value: selectedIds.contains(wId),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIds.add(wId);
                                } else {
                                  selectedIds.remove(wId);
                                }
                              });
                            },
                            activeColor: accentBlue,
                            checkColor: textWhite,
                            side: const BorderSide(color: Colors.white60),
                          );
                        }
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
                        onPressed: selectedIds.isEmpty ? null : () async {
                          Navigator.pop(ctx);
                          try {
                            for (String id in selectedIds) {
                              await ApiService.instance.post('/job-assignments', {
                                'job_id': widget.jobId.toString(),
                                'user_id': id,
                                'role_id': workerRoles[id],
                              });
                            }
                            if (mounted) {
                              ToastService.success(context, 'Staff member(s) assigned successfully!');
                            }
                          } catch (e) {
                            if (mounted) {
                              ToastService.error(context, 'Failed to assign staff: $e');
                            }
                          }
                          _loadJobDetail();
    _fetchGoogleMapsKey();
                        },
                        child: Text("Save", style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _showAssignTeamModal() async {
    final res = await ApiService.instance.get('/admin/teams');
    List<dynamic> teams = [];
    if (res is Map && res.containsKey('data')) {
      teams = res['data'] is List ? res['data'] : [];
    } else if (res is List) {
      teams = res;
    }

    if (teams.isEmpty) {
      if (mounted) ToastService.info(context, "No teams available to assign.");
      return;
    }

    final assignedTeams = _jobData!['assigned_teams'] is List ? _jobData!['assigned_teams'] as List : [];
    final assignedTeamIds = assignedTeams.map((t) => t['id'].toString()).toSet();
    List<dynamic> availableTeams = teams.where((t) => !assignedTeamIds.contains(t['id'].toString())).toList();

    Set<String> selectedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assign Team", style: TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (availableTeams.isEmpty)
                    Text("All teams are already assigned.", style: TextStyle(color: muted)),
                  if (availableTeams.isNotEmpty)
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: availableTeams.length,
                        itemBuilder: (ctx, i) {
                          final t = availableTeams[i];
                          final tId = t['id'].toString();
                          return CheckboxListTile(
                            title: Text(t['name'] ?? 'Team', style: TextStyle(color: textWhite)),
                            value: selectedIds.contains(tId),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  selectedIds.add(tId);
                                } else {
                                  selectedIds.remove(tId);
                                }
                              });
                            },
                            activeColor: accentBlue,
                            checkColor: textWhite,
                            side: const BorderSide(color: Colors.white60),
                          );
                        }
                      ),
                    ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
                        onPressed: selectedIds.isEmpty ? null : () async {
                          Navigator.pop(ctx);
                          try {
                            for (String id in selectedIds) {
                              await ApiService.instance.post('/job-assignments/assign-team', {
                                'job_id': widget.jobId.toString(),
                                'team_id': id,
                              });
                            }
                            if (mounted) {
                              ToastService.success(context, 'Team assigned successfully!');
                            }
                          } catch (e) {
                            if (mounted) {
                              ToastService.error(context, 'Failed to assign team: $e');
                            }
                          }
                          _loadJobDetail();
    _fetchGoogleMapsKey();
                        },
                        child: Text("Save", style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  void _openCallModal() {
    if (_jobData == null) return;

    List<Map<String, String>> contacts = [];

    // Customer contact
    String custName = _jobData!['customer_name'] ?? 'Customer';
    String? custPhone = _jobData!['customer_phone'] ?? _jobData!['phone'] ?? (_jobData!['customer'] is Map ? _jobData!['customer']['phone'] : null);
    contacts.add({
      'name': custName,
      'role': 'Customer',
      'phone': (custPhone != null && custPhone.isNotEmpty) ? custPhone : 'No Phone',
      'type': 'customer',
      'has_phone': (custPhone != null && custPhone.isNotEmpty) ? 'true' : 'false',
    });

    // Assigned Staff
    if (_jobData!['assigned_users'] is List) {
      for (var u in _jobData!['assigned_users']) {
        String name = u['name'] ?? 'Worker';
        String role = u['role_name'] ?? u['role_slug'] ?? 'Technician';
        String? phone = u['phone'] ?? u['mobile_number'] ?? u['mobile'];
        if (!contacts.any((c) => c['name'] == name)) {
          contacts.add({
            'name': name,
            'role': role,
            'phone': (phone != null && phone.isNotEmpty) ? phone : 'No Phone',
            'type': 'staff',
            'has_phone': (phone != null && phone.isNotEmpty) ? 'true' : 'false',
          });
        }
      }
    }

    // Assigned Teams Members
    if (_jobData!['assigned_teams'] is List) {
      for (var t in _jobData!['assigned_teams']) {
        if (t['members'] is List) {
          for (var m in t['members']) {
            String name = m['name'] ?? 'Worker';
            String role = m['role_name'] ?? m['role_slug'] ?? 'Team Member';
            String? phone = m['phone'] ?? m['mobile_number'] ?? m['mobile'];
            if (!contacts.any((c) => c['name'] == name)) {
              contacts.add({
                'name': name,
                'role': role,
                'phone': (phone != null && phone.isNotEmpty) ? phone : 'No Phone',
                'type': 'team',
                'has_phone': (phone != null && phone.isNotEmpty) ? 'true' : 'false',
              });
            }
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Material(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.phone_in_talk, color: accentGreen, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Select Contact to Call',
                    style: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                  itemBuilder: (c, i) {
                    final item = contacts[i];
                    final isCust = item['type'] == 'customer';
                    final hasPhone = item['has_phone'] == 'true';
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: isCust ? accentBlue.withOpacity(0.2) : accentGreen.withOpacity(0.2),
                          child: Text(
                            item['name']![0].toUpperCase(),
                            style: TextStyle(color: isCust ? accentBlue : accentGreen, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(item['name']!, style: TextStyle(color: textWhite, fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text('${item['role']} • ${item['phone']}', style: TextStyle(color: hasPhone ? muted : muted.withOpacity(0.5), fontSize: 13)),
                        trailing: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: hasPhone ? accentGreen.withOpacity(0.15) : Colors.white12,
                            shape: BoxShape.circle,
                            border: Border.all(color: hasPhone ? accentGreen.withOpacity(0.4) : Colors.white10),
                          ),
                          child: Icon(Icons.phone, color: hasPhone ? accentGreen : muted, size: 20),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (hasPhone) {
                            _launchCall(item['phone']);
                          } else {
                            ToastService.info(context, 'No phone number available for ${item['name']}.');
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _openChat() {
    if (_jobData == null) return;
    final jobTitle = _jobData!['title'] ?? 'Job Chat';
    final jobIdStr = widget.jobId.toString();

    List<String> workerIds = [];
    if (_jobData!['assigned_users'] is List) {
      for (var u in _jobData!['assigned_users']) {
        if (u['id'] != null) workerIds.add(u['id'].toString());
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Material(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Select Chat Option',
                  style: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: accentGreen.withOpacity(0.2),
                      child: Icon(Icons.groups, color: accentGreen),
                    ),
                    title: Text('Job Team Chat', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                    subtitle: Text('Group chat with assigned staff & team members', style: TextStyle(color: muted, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      GlobalChatModal.openGroupChat(
                        context,
                        jobId: jobIdStr,
                        jobName: jobTitle,
                        workerIds: workerIds,
                      );
                    },
                  ),
                ),
                if (_jobData!['customer_id'] != null || _jobData!['customer_name'] != null) ...[
                  const Divider(color: Colors.white10),
                  Material(
                    color: Colors.transparent,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accentBlue.withOpacity(0.2),
                        child: Icon(Icons.person, color: accentBlue),
                      ),
                      title: Text('Customer Chat', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
                      subtitle: Text(_jobData!['customer_name'] ?? 'Direct chat with customer', style: TextStyle(color: muted, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(ctx);
                        final custId = _jobData!['customer_id']?.toString() ?? '1';
                        final custName = _jobData!['customer_name'] ?? 'Customer';
                        GlobalChatModal.openChatWithUser(
                          context,
                          targetUserId: custId,
                          targetName: custName,
                          isCustomer: true,
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: muted,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  int? get _recurringParentId {
    if (_jobData == null) return null;
    final parentId = _jobData!['recurring_parent_id'];
    if (parentId != null && parentId != 0 && parentId != '') {
      return int.tryParse(parentId.toString());
    }
    if (_jobData!['is_template'] == true) {
      return int.tryParse(_jobData!['id'].toString());
    }
    return null;
  }

  Future<bool> _confirmDelete(String title, String content) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(content, style: TextStyle(color: muted, fontSize: 13)),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _confirmCancelJob(bool isRecurringJob) {
    _showActionDialog(
      title: 'Cancel Job',
      content: isRecurringJob
          ? 'Do you want to cancel only this job or the entire series?'
          : 'Are you sure you want to cancel this job?',
      icon: Icons.cancel_outlined,
      color: Colors.orangeAccent,
      actionText: 'Cancel',
      isRecurring: isRecurringJob,
      onSingleAction: () async {
        try {
          await ApiService.instance.cancelJob(widget.jobId);
          if (mounted) {
            ToastService.success(context, 'Job cancelled successfully');
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) ToastService.error(context, 'Failed to cancel job: $e');
        }
      },
      onSeriesAction: () async {
        if (_recurringParentId == null) return;
        try {
          await ApiService.instance.cancelRecurringJob(_recurringParentId!);
          if (mounted) {
            ToastService.success(context, 'Series cancelled successfully');
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) ToastService.error(context, 'Failed to cancel series: $e');
        }
      },
    );
  }

  void _confirmDeleteJob(bool isRecurringJob) {
    _showActionDialog(
      title: 'Delete Job',
      content: isRecurringJob
          ? 'Do you want to delete only this job or the entire series? This action cannot be undone.'
          : 'Are you sure you want to delete this job? This action cannot be undone.',
      icon: Icons.warning_amber_rounded,
      color: Colors.redAccent,
      actionText: 'Delete',
      isRecurring: isRecurringJob,
      onSingleAction: () async {
        try {
          await ApiService.instance.softDeleteJob(widget.jobId);
          if (mounted) {
            ToastService.error(context, 'Job deleted successfully');
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) ToastService.error(context, 'Failed to delete job: $e');
        }
      },
      onSeriesAction: () async {
        if (_recurringParentId == null) return;
        try {
          await ApiService.instance.deleteRecurringJob(_recurringParentId!);
          if (mounted) {
            ToastService.error(context, 'Series deleted successfully');
            Navigator.pop(context, true);
          }
        } catch (e) {
          if (mounted) ToastService.error(context, 'Failed to delete series: $e');
        }
      },
    );
  }

  void _showActionDialog({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required String actionText,
    required bool isRecurring,
    required Future<void> Function() onSingleAction,
    required Future<void> Function() onSeriesAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 10),
            Text(title, style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          content,
          style: TextStyle(color: muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Close', style: TextStyle(color: muted)),
          ),
          if (isRecurring) ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onSingleAction();
              },
              child: Text('Only this job', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onSeriesAction();
              },
              child: Text('Full series', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                onSingleAction();
              },
              child: Text(actionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  void _showSeriesJobsModal(BuildContext context, List<dynamic> seriesJobs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Jobs in this Series', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: seriesJobs.length,
                  itemBuilder: (context, index) {
                    final job = seriesJobs[index];
                    final String jobNum = job['job_number'] ?? 'JOB-${job['id']}';
                    final String title = job['title'] ?? 'Job Details';
                    final String status = (job['job_status'] ?? job['status'] ?? 'SCHEDULED').toString().toUpperCase();
                    
                    DateTime? sTime = JobParser.getStartDate(job);
                    final String dateStr = sTime != null ? DateFormat('MMM d, yyyy').format(sTime) : 'No date';
                    final bool isCurrent = job['id'] == widget.jobId;

                    return ListTile(
                      title: Text('$jobNum - $title', style: TextStyle(color: Colors.white, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text('$dateStr • $status', style: TextStyle(color: isCurrent ? accentBlue : muted, fontSize: 13)),
                      trailing: isCurrent ? Icon(Icons.check_circle, color: accentBlue, size: 20) : const Icon(Icons.chevron_right, color: Colors.white54, size: 20),
                      onTap: () {
                        if (isCurrent) return;
                        Navigator.pop(ctx);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SharedJobDetailScreen(jobId: job['id']),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _fetchAndShowSeriesJobs(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(child: CircularProgressIndicator(color: accentBlue)),
    );

    try {
      final res = await ApiService.instance.get('/jobs/${widget.jobId}/series');
      Navigator.pop(context); // close loader
      
      final List<dynamic> series = (res is Map && res['data'] != null) ? res['data'] : (res is List ? res : []);
      
      if (series.isNotEmpty) {
        _showSeriesJobsModal(context, series);
      } else {
        ToastService.info(context, 'No other jobs in this series found.');
      }
    } catch (e) {
      Navigator.pop(context); // close loader
      ToastService.error(context, 'Failed to fetch series jobs.');
    }
  }

  void _openEditModal() {
    if (_jobData == null) return;
    TextEditingController titleCtrl = TextEditingController(text: _jobData!['title'] ?? '');
    TextEditingController notesCtrl = TextEditingController(text: _jobData!['description'] ?? _jobData!['notes'] ?? '');
    String currentStatus = _jobData!['job_status'] ?? _jobData!['status'] ?? 'scheduled';
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Material(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          clipBehavior: Clip.antiAlias,
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Job Details', style: TextStyle(color: textWhite, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Job Title', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    style: TextStyle(color: textWhite),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Job Status', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(14)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ['draft', 'scheduled', 'en_route', 'in_progress', 'completed'].contains(currentStatus.toLowerCase())
                            ? currentStatus.toLowerCase()
                            : 'scheduled',
                        dropdownColor: cardBg,
                        style: TextStyle(color: textWhite),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: 'draft', child: Text('Draft')),
                          DropdownMenuItem(value: 'scheduled', child: Text('Scheduled')),
                          DropdownMenuItem(value: 'en_route', child: Text('En Route')),
                          DropdownMenuItem(value: 'in_progress', child: Text('In Progress')),
                          DropdownMenuItem(value: 'completed', child: Text('Completed')),
                        ],
                        onChanged: (val) {
                          if (val != null) setModalState(() => currentStatus = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Notes / Description', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    style: TextStyle(color: textWhite),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: isSaving
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                              try {
                                await ApiService.instance.put('/jobs/${widget.jobId}', {
                                  'title': titleCtrl.text.trim(),
                                  'job_status': currentStatus,
                                  'notes': notesCtrl.text.trim(),
                                  'description': notesCtrl.text.trim(),
                                });
                                Navigator.pop(ctx);
                                _loadJobDetail();
    _fetchGoogleMapsKey();
                                ToastService.success(context, 'Job updated successfully');
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ToastService.error(context, 'Failed to update job: $e');
                              }
                            },
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  String? _googleMapsApiKey = AppConstants.fallbackGoogleMapsApiKey;

  Future<void> _fetchGoogleMapsKey() async {
    try {
      final response = await ApiService.instance.get('/settings');
      if (response != null && response['success'] == true) {
        final settings = response['data'] ?? {};
        if (settings.containsKey('google_maps_api_key') && settings['google_maps_api_key'] != null && settings['google_maps_api_key'].toString().trim().isNotEmpty) {
          if (mounted) {
            setState(() {
              _googleMapsApiKey = settings['google_maps_api_key'];
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching maps key: $e');
    }
  }

  void _showEditDescriptionModal() {
    if (_jobData == null) return;
    final ctrl = TextEditingController(text: _jobData!['description'] ?? '');
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          bool isSaving = false;
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Job Description', style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white54),
                        onPressed: () => Navigator.pop(ctx),
                      )
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: ctrl,
                    minLines: 3,
                    maxLines: 5,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter job description...',
                      hintStyle: TextStyle(color: Colors.white30),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      filled: true,
                      fillColor: cardBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: isSaving ? null : () async {
                        setModalState(() => isSaving = true);
                        try {
                          await ApiService.instance.put('/admin/jobs/${widget.jobId}', {
                            'description': ctrl.text,
                          });
                          Navigator.pop(ctx);
                          ToastService.success(context, 'Description updated');
                          _loadJobDetail();
    _fetchGoogleMapsKey();
                        } catch (e) {
                          ToastService.error(context, 'Failed to update description');
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Description', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditLocationModal() {
    if (_jobData == null) return;
    
    final String currentAddress = _jobData!['address']?.toString() ?? _jobData!['service_location']?.toString() ?? '';
    
    final addressCtrl = TextEditingController(text: currentAddress);
    final unitCtrl = TextEditingController(text: _jobData!['unit_number']?.toString() ?? '');
    final gateCtrl = TextEditingController(text: _jobData!['gate_code']?.toString() ?? '');
    final noteCtrl = TextEditingController(text: _jobData!['address_notes']?.toString() ?? '');
    
    bool saveToCustomer = true;
    
    Timer? _debounce;
    List<dynamic> _suggestions = [];
    bool _isSearching = false;
    
    String _city = '';
    String _state = '';
    String _zip = '';
    String _country = '';
    double _lat = double.tryParse(_jobData!['latitude']?.toString() ?? '0') ?? 0.0;
    double _lng = double.tryParse(_jobData!['longitude']?.toString() ?? '0') ?? 0.0;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          
          Future<void> searchPlaces(String query) async {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            if (query.trim().isEmpty) {
              setModalState(() { _suggestions = []; _isSearching = false; });
              return;
            }
            setModalState(() => _isSearching = true);
            try {
              final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
              final response = await http.get(uri);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                setModalState(() {
                  _suggestions = data['predictions'] ?? [];
                  _isSearching = false;
                });
              } else {
                setModalState(() => _isSearching = false);
              }
            } catch (e) {
              setModalState(() => _isSearching = false);
            }
          }

          Future<void> getPlaceDetails(String placeId, String description) async {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            setModalState(() => _isSearching = true);
            try {
              final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
              final response = await http.get(uri);
              if (response.statusCode == 200) {
                final data = jsonDecode(response.body);
                final result = data['result'];
                if (result != null) {
                  addressCtrl.text = description;
                  _lat = result['geometry']['location']['lat'] ?? 0.0;
                  _lng = result['geometry']['location']['lng'] ?? 0.0;
                  
                  final components = result['address_components'] as List<dynamic>?;
                  if (components != null) {
                    _city = ''; _state = ''; _zip = ''; _country = '';
                    for (var c in components) {
                      final types = c['types'] as List<dynamic>;
                      if (types.contains('locality')) _city = c['long_name'];
                      if (types.contains('administrative_area_level_1')) _state = c['short_name'];
                      if (types.contains('postal_code')) _zip = c['long_name'];
                      if (types.contains('country')) _country = c['short_name'];
                    }
                  }
                  setModalState(() { _suggestions = []; });
                }
              }
            } catch (e) {
              debugPrint('Places Details Error: $e');
            } finally {
              setModalState(() => _isSearching = false);
            }
          }

          bool isSaving = false;

          return Container(
            height: MediaQuery.of(ctx).size.height * 0.8,
            decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Edit Location', style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(ctx))
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Address', style: TextStyle(color: muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: addressCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search address...',
                            hintStyle: TextStyle(color: Colors.white30),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            prefixIcon: Icon(Icons.search, color: muted),
                          ),
                          onChanged: (val) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();
                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              searchPlaces(val);
                            });
                          },
                        ),
                        if (_isSearching) const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator())),
                        if (_suggestions.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(8)),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _suggestions.length,
                              itemBuilder: (context, index) {
                                final s = _suggestions[index];
                                return ListTile(
                                  leading: const Icon(Icons.location_on, color: Colors.white54),
                                  title: Text(s['description'], style: const TextStyle(color: Colors.white, fontSize: 13)),
                                  onTap: () => getPlaceDetails(s['place_id'], s['description']),
                                );
                              },
                            ),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Unit / Apt #', style: TextStyle(color: muted, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: unitCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Gate Code', style: TextStyle(color: muted, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: gateCtrl,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      filled: true,
                                      fillColor: cardBg,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text('Address Note', style: TextStyle(color: muted, fontSize: 12)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteCtrl,
                          minLines: 1,
                          maxLines: 3,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            filled: true,
                            fillColor: cardBg,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Checkbox(
                              value: saveToCustomer,
                              onChanged: (val) => setModalState(() => saveToCustomer = val ?? true),
                              fillColor: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? accentBlue : Colors.transparent),
                              side: BorderSide(color: muted),
                            ),
                            Expanded(child: Text('Save to customer profile', style: TextStyle(color: textWhite, fontSize: 14))),
                          ],
                        ),
                        Text('If checked, updates the existing customer address. If unchecked, creates a new address for this job only.', style: TextStyle(color: muted, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: accentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      onPressed: isSaving ? null : () async {
                        if (addressCtrl.text.trim().isEmpty) {
                          ToastService.error(context, 'Address is required');
                          return;
                        }
                        setModalState(() => isSaving = true);
                        try {
                          final payload = {
                            'new_address': {
                              'address1': addressCtrl.text.trim(),
                              'address2': unitCtrl.text.trim(),
                              'city': _city,
                              'state': _state,
                              'zip_code': _zip,
                              'country': _country,
                              'latitude': _lat,
                              'longitude': _lng,
                              'gate_code': gateCtrl.text.trim(),
                              'notes': noteCtrl.text.trim(),
                            },
                            'save_to_customer': saveToCustomer,
                          };
                          await ApiService.instance.put('/admin/jobs/${widget.jobId}', payload);
                          Navigator.pop(ctx);
                          ToastService.success(context, 'Location updated');
                          _loadJobDetail();
    _fetchGoogleMapsKey();
                        } catch (e) {
                          ToastService.error(context, 'Failed to update location');
                        } finally {
                          setModalState(() => isSaving = false);
                        }
                      },
                      child: isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save Location', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    final canViewFinancials = AuthHelpers.hasPermission('VIEW PROFITABILITY') || AuthHelpers.isAdmin;
    final canEditJob = AuthHelpers.hasPermission('EDIT JOBS') || AuthHelpers.isAdmin;
    final canDeleteJob = AuthHelpers.hasPermission('DELETE JOBS') || AuthHelpers.isAdmin;

    String jobNumber = _jobData?['job_number'] ?? '';
    String jobTitle = _jobData?['title'] ?? 'Job Details';
    String displayHeading = jobNumber.isNotEmpty ? '$jobNumber - $jobTitle' : jobTitle;
    String customerName = _jobData?['customer_name'] ?? 'No Customer';
    String customerPhone = _jobData?['customer_phone'] ?? _jobData?['phone'] ?? '';
    String address = _jobData?['address'] ?? 'No address provided.';
    String? unitNumber = _jobData?['unit_number']?.toString();
    String? gateCode = _jobData?['gate_code']?.toString();
    String? addressNotes = _jobData?['address_notes']?.toString();
    String description = _jobData?['description'] ?? _jobData?['notes'] ?? 'No notes provided.';
    bool isRecurring = JobParser.isRecurring(_jobData);
  
    DateTime? scheduledTime = JobParser.getStartDate(_jobData);

    bool isToday = false;
    if (scheduledTime != null) {
      final now = DateTime.now();
      isToday = scheduledTime.year == now.year && scheduledTime.month == now.month && scheduledTime.day == now.day;
    }

    String dateStr = scheduledTime != null
        ? DateFormat('EEEE, MMMM d, yyyy').format(scheduledTime)
        : 'No date set';
    String timeStr = scheduledTime != null
        ? '${DateFormat('h:mm a').format(scheduledTime)} - ${DateFormat('h:mm a').format(scheduledTime.add(const Duration(hours: 2)))}'
        : 'No time set';

    String status = (_jobData?['job_status'] ?? _jobData?['status'] ?? 'SCHEDULED').toString().toUpperCase();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Job Details',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if ((canEditJob || canDeleteJob) && _jobData != null)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              color: cardBg,
              onSelected: (value) {
                if (value == 'edit') {
                  _openEditModal();
                } else if (value == 'cancel') {
                  _confirmCancelJob(isRecurring);
                } else if (value == 'delete') {
                  _confirmDeleteJob(isRecurring);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (canEditJob)
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: const [
                        Icon(Icons.edit_outlined, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Edit Job', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                if (canDeleteJob) // Typically if you can delete, you can cancel
                  PopupMenuItem<String>(
                    value: 'cancel',
                    child: Row(
                      children: const [
                        Icon(Icons.cancel_outlined, color: Colors.orangeAccent),
                        SizedBox(width: 8),
                        Text('Cancel Job', style: TextStyle(color: Colors.orangeAccent)),
                      ],
                    ),
                  ),
                if (canDeleteJob)
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: const [
                        Icon(Icons.delete_outline, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text('Delete Job', style: TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: accentBlue))
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _jobData == null
                  ? const Center(child: Text('Job not found.', style: TextStyle(color: Colors.white70)))
                  : Stack(
                      children: [
                        SingleChildScrollView(
                          padding: EdgeInsets.only(
                              left: 20,
                              right: 20,
                              top: 12,
                              bottom: 120 + MediaQuery.of(context).padding.bottom),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Job Info Header
                              Text(
                                displayHeading,
                                style: TextStyle(color: textWhite, fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                customerName,
                                style: TextStyle(color: muted, fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, color: muted, size: 16),
                                  const SizedBox(width: 8),
                                  Text(dateStr, style: TextStyle(color: textWhite, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(Icons.access_time, color: muted, size: 16),
                                  const SizedBox(width: 8),
                                  Text(timeStr, style: TextStyle(color: textWhite, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Badges Row (Single/Recurring + Status)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      if (isRecurring) {
                                        _fetchAndShowSeriesJobs(context);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: accentBlue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: accentBlue.withOpacity(0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isRecurring ? Icons.repeat : Icons.looks_one,
                                            color: accentBlue,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isRecurring ? 'Recurring Job' : 'Single Job',
                                            style: TextStyle(color: accentBlue, fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: accentBlue, width: 1.5),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: accentBlue, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              if (isToday) ...[
                                JobActionButtons(
                                  jobId: widget.jobId,
                                  jobStatus: status,
                                  clockStatus: _clockStatus,
                                  onStateChanged: _loadJobDetail,
                                  compact: false,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // LOCATION Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('LOCATION'),
                                  if (canEditJob)
                                    IconButton(
                                      icon: Icon(Icons.edit_square, color: accentBlue, size: 20),
                                      onPressed: _showEditLocationModal,
                                    ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, color: accentBlue, size: 24),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: TextStyle(color: textWhite, fontSize: 14, height: 1.3),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(color: Colors.white10, height: 1),
                                    const SizedBox(height: 12),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.door_front_door, color: muted, size: 18),
                                          const SizedBox(width: 10),
                                          Text('Unit / Apt #: ', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                                          Expanded(child: Text((unitNumber != null && unitNumber.trim().isNotEmpty) ? unitNumber : 'N/A', style: TextStyle(color: textWhite, fontSize: 13))),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.vpn_key, color: muted, size: 18),
                                          const SizedBox(width: 10),
                                          Text('Gate Code: ', style: TextStyle(color: muted, fontSize: 13, fontWeight: FontWeight.bold)),
                                          Expanded(child: Text((gateCode != null && gateCode.trim().isNotEmpty) ? gateCode : 'N/A', style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold))),
                                        ],
                                      ),
                                    ),
                                    if (kIsWeb)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Icon(Icons.info_outline, color: goldColor, size: 18),
                                            const SizedBox(width: 10),
                                            Text('Address Note: ', style: TextStyle(color: goldColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                            Expanded(
                                              child: Text(
                                                (addressNotes != null && addressNotes.trim().isNotEmpty) ? addressNotes : 'N/A',
                                                style: TextStyle(color: goldColor, fontSize: 12),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Row(
                                          children: [
                                            Icon(Icons.info_outline, color: goldColor, size: 18),
                                            const SizedBox(width: 10),
                                            Text('Address Note: ', style: TextStyle(color: goldColor, fontSize: 13, fontWeight: FontWeight.bold)),
                                            const SizedBox(width: 4),
                                            GestureDetector(
                                              onTap: () {
                                                showDialog(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    backgroundColor: cardBg,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                                    title: Row(
                                                      children: [
                                                        Icon(Icons.info_outline, color: goldColor),
                                                        const SizedBox(width: 10),
                                                        Text('Address Note', style: TextStyle(color: textWhite, fontSize: 18)),
                                                      ],
                                                    ),
                                                    content: Text((addressNotes != null && addressNotes.trim().isNotEmpty) ? addressNotes : 'No address notes provided.', style: TextStyle(color: textWhite, fontSize: 14)),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () => Navigator.pop(ctx),
                                                        child: Text('Close', style: TextStyle(color: accentBlue)),
                                                      )
                                                    ],
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: goldColor.withOpacity(0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(Icons.priority_high, color: goldColor, size: 16),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              // JOB DESCRIPTION Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('JOB DESCRIPTION'),
                                  if (canEditJob)
                                    IconButton(
                                      icon: Icon(Icons.edit_square, color: accentBlue, size: 20),
                                      onPressed: _showEditDescriptionModal,
                                    ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Text(
                                  description,
                                  style: TextStyle(color: textWhite, fontSize: 14, height: 1.4),
                                ),
                              ),

                              // ITEMS & PRICE BOOK Section
                              _buildSectionHeader('ITEMS & PRICE BOOK'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final items = _jobData!['details'] ?? _jobData!['items'] ?? [];
                                    if (items is List && items.isNotEmpty) {
                                      double totalSum = 0;
                                      return Column(
                                        children: [
                                          ...items.map<Widget>((item) {
                                            final name = item['name'] ?? item['description'] ?? 'Service Item';
                                            final qty = item['quantity'] ?? 1;
                                            final price = double.tryParse(item['price'].toString()) ?? 0.0;
                                            final itemTotal = qty * price;
                                            totalSum += itemTotal;
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 12),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(name, style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                                                        const SizedBox(height: 2),
                                                        Text('$qty × \$${price.toStringAsFixed(2)}', style: TextStyle(color: muted, fontSize: 12)),
                                                      ],
                                                    ),
                                                  ),
                                                  Text('\$${itemTotal.toStringAsFixed(2)}', style: TextStyle(color: accentGreen, fontSize: 14, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                          const Divider(color: Colors.white10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text('TOTAL ITEMS COST', style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold)),
                                              Text('\$${totalSum.toStringAsFixed(2)}', style: TextStyle(color: goldColor, fontSize: 15, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ],
                                      );
                                    }
                                    return Text('No items added yet.', style: TextStyle(color: muted, fontSize: 14));
                                  },
                                ),
                              ),

                              // JOB CHECKLIST Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('JOB CHECKLIST'),
                                  IconButton(
                                    icon: Icon(
                                      _showAddTaskInput ? Icons.close : Icons.add_circle_outline,
                                      color: accentBlue,
                                      size: 22,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _showAddTaskInput = !_showAddTaskInput;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final checklistRaw = _jobData!['checklist'];
                                    List checklist = [];
                                    if (checklistRaw is List) {
                                      checklist = checklistRaw;
                                    }
                                    return StatefulBuilder(
                                      builder: (context, setChecklistState) {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (checklist.isNotEmpty)
                                              ...checklist.map<Widget>((task) {
                                                final taskName = (task is Map)
                                                    ? (task['name'] ?? task['title'] ?? task['task'] ?? 'Task')
                                                    : task.toString();
                                                final isCompleted = (task is Map)
                                                    ? (task['completed'] == true || task['is_completed'] == true || task['status'] == 'completed')
                                                    : false;
                                                String completedTimeString = '';
                                                if (isCompleted && task is Map && task['completed_at'] != null) {
                                                  try {
                                                    final dt = DateTime.parse(task['completed_at'].toString()).toLocal();
                                                    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
                                                    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
                                                    final min = dt.minute.toString().padLeft(2, '0');
                                                    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                                                    completedTimeString = '${months[dt.month - 1]} ${dt.day}, $hour:$min $ampm';
                                                  } catch (_) {}
                                                }
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: InkWell(
                                                          onTap: () async {
                                                            final targetState = !isCompleted;
                                                            final confirm = await showDialog<bool>(
                                                              context: context,
                                                              builder: (ctx) => AlertDialog(
                                                                backgroundColor: cardBg,
                                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                title: Text(
                                                                  targetState ? 'Mark Task Completed?' : 'Mark Task Incomplete?',
                                                                  style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                                                                ),
                                                                content: Text(
                                                                  targetState
                                                                      ? 'Are you sure you want to mark "$taskName" as completed?'
                                                                      : 'Are you sure you want to mark "$taskName" as incomplete?',
                                                                  style: TextStyle(color: muted, fontSize: 13),
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () => Navigator.pop(ctx, false),
                                                                    child: Text('Cancel', style: TextStyle(color: muted)),
                                                                  ),
                                                                  ElevatedButton(
                                                                    style: ElevatedButton.styleFrom(
                                                                      backgroundColor: targetState ? accentGreen : accentBlue,
                                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                    ),
                                                                    onPressed: () => Navigator.pop(ctx, true),
                                                                    child: Text(targetState ? 'Complete' : 'Confirm', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                                  ),
                                                                ],
                                                              ),
                                                            );

                                                            if (confirm != true) return;

                                                            setChecklistState(() {
                                                              if (task is Map) {
                                                                task['completed'] = targetState;
                                                                task['completed_at'] = targetState ? DateTime.now().toIso8601String() : null;
                                                              }
                                                            });
                                                            try {
                                                              await ApiService.instance.updateChecklist(widget.jobId, taskName, targetState);
                                                            } catch (_) {}
                                                          },
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                                                color: isCompleted ? accentGreen : muted,
                                                                size: 22,
                                                              ),
                                                              const SizedBox(width: 12),
                                                              Expanded(
                                                                child: Text(
                                                                  taskName,
                                                                  style: TextStyle(
                                                                    color: isCompleted ? muted : textWhite,
                                                                    fontSize: 14,
                                                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                                                  ),
                                                                ),
                                                              ),
                                                              if (isCompleted && completedTimeString.isNotEmpty)
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                                  decoration: BoxDecoration(
                                                                    color: accentBlue.withOpacity(0.15),
                                                                    borderRadius: BorderRadius.circular(6),
                                                                  ),
                                                                  child: Text(
                                                                    completedTimeString,
                                                                    style: TextStyle(
                                                                      color: accentBlue,
                                                                      fontSize: 10,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 18),
                                                        padding: const EdgeInsets.all(4),
                                                        constraints: const BoxConstraints(),
                                                        onPressed: () async {
                                                          final confirm = await showDialog<bool>(
                                                            context: context,
                                                            builder: (ctx) => AlertDialog(
                                                              backgroundColor: cardBg,
                                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                              title: Text('Remove Checklist Item?', style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                                                              content: Text('Are you sure you want to remove "$taskName"?', style: TextStyle(color: muted, fontSize: 13)),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed: () => Navigator.pop(ctx, false),
                                                                  child: Text('Cancel', style: TextStyle(color: muted)),
                                                                ),
                                                                ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: const Color(0xFFEF4444),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                                  ),
                                                                  onPressed: () => Navigator.pop(ctx, true),
                                                                  child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                                                ),
                                                              ],
                                                            ),
                                                          );

                                                          if (confirm != true) return;

                                                          setChecklistState(() {
                                                            checklist.remove(task);
                                                          });
                                                          try {
                                                            await ApiService.instance.deleteChecklist(widget.jobId, taskName);
                                                            if (mounted) {
                                                              ToastService.success(context, 'Checklist successfully deleted');
                                                            }
                                                          } catch (_) {}
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList()
                                            else
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 4),
                                                child: Text('No checklist items yet.', style: TextStyle(color: muted, fontSize: 14)),
                                              ),
                                            if (_showAddTaskInput) ...[
                                              const SizedBox(height: 12),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller: _taskInputController,
                                                      style: TextStyle(color: textWhite, fontSize: 13),
                                                      decoration: InputDecoration(
                                                        hintText: 'Add a new task...',
                                                        hintStyle: TextStyle(color: muted, fontSize: 13),
                                                        isDense: true,
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                        filled: true,
                                                        fillColor: bg,
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  ElevatedButton(
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: accentBlue,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                                    ),
                                                    onPressed: () async {
                                                      final text = _taskInputController.text.trim();
                                                      if (text.isEmpty) return;
                                                      _taskInputController.clear();
                                                       setChecklistState(() {
                                                         checklist.add({'text': text, 'name': text, 'title': text, 'task': text, 'completed': false});
                                                       });
                                                      setState(() {
                                                        _showAddTaskInput = false;
                                                      });
                                                      ToastService.success(context, 'Checklist task added successfully');
                                                      try {
                                                        await ApiService.instance.updateChecklist(widget.jobId, text, false);
                                                      } catch (_) {}
                                                    },
                                                    child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),

                              // ASSIGNED TEAMS Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('ASSIGNED TEAMS'),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: accentBlue, size: 22),
                                    onPressed: _showAssignTeamModal,
                                  ),
                                ],
                              ),
                              Builder(
                                builder: (context) {
                                  final teams = _jobData!['assigned_teams'];
                                  if (teams is List && teams.isNotEmpty) {
                                    return Column(
                                      children: teams.map<Widget>((t) {
                                        final teamName = t['name'] ?? 'Team';
                                        final teamId = t['id'];
                                        final members = (t['members'] is List) ? (t['members'] as List) : [];
                                        return Container(
                                          width: double.infinity,
                                          margin: const EdgeInsets.only(bottom: 12),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: cardBg,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: accentGreen.withOpacity(0.3)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF10B981),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    teamName.toUpperCase(),
                                                    style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    '• ${members.length} MEMBERS',
                                                    style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                                                  ),
                                                  const Spacer(),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                    onPressed: () async {
                                                      final confirm = await _confirmDelete('Remove Team?', 'Are you sure you want to remove "$teamName"?');
                                                      if (!confirm) return;
                                                      if (teamId == null) return;
                                                      try {
                                                        await ApiService.instance.delete('/job-assignments/team/${widget.jobId}/$teamId');
                                                        if (mounted) {
                                                          ToastService.success(context, 'Team removed successfully!');
                                                        }
                                                      } catch (e) {
                                                        if (mounted) {
                                                          ToastService.error(context, 'Failed to remove team: $e');
                                                        }
                                                      }
                                                      _loadJobDetail();
    _fetchGoogleMapsKey();
                                                    },
                                                  ),
                                                ],
                                              ),
                                              if (members.isNotEmpty) ...[
                                                const SizedBox(height: 12),
                                                const Divider(color: Colors.white10),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 8,
                                                  children: members.map<Widget>((m) {
                                                    final mName = m['name'] ?? 'Worker';
                                                    final mRole = m['role_name'] ?? m['role_slug'] ?? 'Technician';
                                                    final initial = mName.isNotEmpty ? mName[0].toUpperCase() : 'W';
                                                    return Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white.withOpacity(0.05),
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(color: Colors.white10),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          CircleAvatar(
                                                            radius: 12,
                                                            backgroundColor: accentBlue.withOpacity(0.3),
                                                            child: Text(initial, style: TextStyle(color: accentBlue, fontSize: 10, fontWeight: FontWeight.bold)),
                                                          ),
                                                          const SizedBox(width: 8),
                                                          Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Text(mName, style: TextStyle(color: textWhite, fontSize: 12, fontWeight: FontWeight.bold)),
                                                              Text(mRole, style: TextStyle(color: muted, fontSize: 10)),
                                                            ],
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }).toList(),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  }
                                  return Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Text('No team assigned.', style: TextStyle(color: muted, fontSize: 14)),
                                  );
                                },
                              ),

                              // INDIVIDUAL STAFF Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('INDIVIDUAL STAFF'),
                                  IconButton(
                                    icon: Icon(Icons.add_circle_outline, color: accentBlue, size: 22),
                                    onPressed: _showAssignWorkerModal,
                                  ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final assigned = _jobData!['assigned_users'];
                                    List individualStaff = [];
                                    if (assigned is List) {
                                      individualStaff = assigned.where((u) => u['team_id'] == null).toList();
                                    }
                                    if (individualStaff.isNotEmpty) {
                                      return Column(
                                        children: individualStaff.map<Widget>((u) {
                                          final name = u['name'] ?? 'Worker';
                                          final role = u['role_name'] ?? u['role_slug'] ?? 'Technician';
                                          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 20,
                                                  backgroundColor: accentBlue.withOpacity(0.2),
                                                  child: Text(initial, style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                                                ),
                                                const SizedBox(width: 14),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(name, style: TextStyle(color: textWhite, fontSize: 15, fontWeight: FontWeight.bold)),
                                                    Text(role, style: TextStyle(color: muted, fontSize: 12)),
                                                  ],
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                  onPressed: () async {
                                                    final confirm = await _confirmDelete('Remove Staff Member?', 'Are you sure you want to remove "$name"?');
                                                    if (!confirm) return;
                                                    if (u['id'] == null) return;
                                                    try {
                                                      try {
                                                        await ApiService.instance.delete('/job-assignments/${u['assignment_id'] ?? u['id']}');
                                                      } catch (e) {
                                                        await ApiService.instance.post('/admin/jobs/${widget.jobId}/unassign-user', {'user_id': u['id']});
                                                      }
                                                      if (mounted) {
                                                        ToastService.success(context, 'Staff member removed successfully!');
                                                      }
                                                    } catch (e) {
                                                      if (mounted) {
                                                        ToastService.error(context, 'Failed to remove staff member: $e');
                                                      }
                                                    }
                                                    _loadJobDetail();
    _fetchGoogleMapsKey();
                                                  },
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    }
                                    return Text('No individual staff assigned.', style: TextStyle(color: muted, fontSize: 14));
                                  },
                                ),
                              ),

                              // JOB PHOTOS Section (Single unified section)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildSectionHeader('JOB PHOTOS'),
                                  IconButton(
                                    icon: Icon(Icons.add_a_photo_outlined, color: accentBlue, size: 22),
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        useSafeArea: true,
                                        builder: (ctx) => CustomEvidenceModal(
                                          jobId: widget.jobId,
                                          jobTitle: _jobData?['title'] ?? _jobData?['customer_name'] ?? 'Job',
                                        ),
                                      ).then((_) {
                                        // Reload job details to show new photos
                                        _loadJobDetail();
    _fetchGoogleMapsKey();
                                      });
                                    },
                                  ),
                                ],
                              ),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Builder(
                                  builder: (context) {
                                    final before = (_jobData!['before_images'] is List) ? _jobData!['before_images'] as List : [];
                                    final during = (_jobData!['during_images'] is List) ? _jobData!['during_images'] as List : ((_jobData!['images'] is List) ? _jobData!['images'] as List : []);
                                    final after = (_jobData!['after_images'] is List) ? _jobData!['after_images'] as List : [];

                                    final allPhotos = [
                                      ...before.map((img) => {'url': img is Map ? (img['url'] ?? img['path']) : img.toString(), 'type': 'Before'}),
                                      ...during.map((img) => {'url': img is Map ? (img['url'] ?? img['path']) : img.toString(), 'type': 'During'}),
                                      ...after.map((img) => {'url': img is Map ? (img['url'] ?? img['path']) : img.toString(), 'type': 'After'}),
                                    ];

                                    if (allPhotos.isNotEmpty) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          SizedBox(
                                            height: 110,
                                            child: ListView.separated(
                                              scrollDirection: Axis.horizontal,
                                              itemCount: allPhotos.length,
                                              separatorBuilder: (ctx, i) => const SizedBox(width: 12),
                                              itemBuilder: (ctx, index) {
                                                final item = allPhotos[index];
                                                final url = item['url'] ?? '';
                                                final tag = item['type'] ?? 'Photo';
                                                return GestureDetector(
                                                  onTap: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (_) => Dialog(
                                                        backgroundColor: Colors.black,
                                                        insetPadding: const EdgeInsets.all(12),
                                                        child: Stack(
                                                          children: [
                                                            Center(
                                                              child: Image.network(
                                                                url,
                                                                fit: BoxFit.contain,
                                                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white54, size: 60),
                                                              ),
                                                            ),
                                                            Positioned(
                                                              top: 10,
                                                              right: 10,
                                                              child: IconButton(
                                                                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                                                onPressed: () => Navigator.pop(context),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(12),
                                                    child: Stack(
                                                      children: [
                                                        Image.network(
                                                          url,
                                                          width: 110,
                                                          height: 110,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (c, e, s) => Container(
                                                            width: 110,
                                                            height: 110,
                                                            color: Colors.white10,
                                                            child: const Icon(Icons.broken_image, color: Colors.white38),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          bottom: 0,
                                                          left: 0,
                                                          right: 0,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                                                            color: Colors.black54,
                                                            child: Text(
                                                              tag,
                                                              textAlign: TextAlign.center,
                                                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ],
                                      );
                                    }
                                    return Text('No photos uploaded for this job yet.', style: TextStyle(color: muted, fontSize: 14));
                                  },
                                ),
                              ),

                              // FINANCIAL DETAILS Section (Permission guarded)
                              if (canViewFinancials) ...[
                                _buildSectionHeader('FINANCIAL DETAILS'),
                                Builder(builder: (context) {
                                  // Compute totals at runtime from job details (never from DB)
                                  final detailsList = _jobData!['details'] ?? _jobData!['items'] ?? [];
                                  double computedTotal = 0.0;
                                  if (detailsList is List) {
                                    for (var d in detailsList) {
                                      final price = double.tryParse(d['price']?.toString() ?? '0') ?? 0.0;
                                      final qty = int.tryParse(d['quantity']?.toString() ?? '1') ?? 1;
                                      computedTotal += price * qty;
                                    }
                                  }
                                  // Also honour backend-provided value if details not loaded
                                  if (computedTotal == 0.0) {
                                    computedTotal = double.tryParse(
                                      (_jobData!['estimated_value'] ?? _jobData!['total_amount'] ?? '0').toString()
                                    ) ?? 0.0;
                                  }
                                  final totalsContainer = Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: cardBg,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: goldColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Estimated Value:', style: TextStyle(color: muted, fontSize: 14)),
                                            Text('\$${computedTotal.toStringAsFixed(2)}', style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text('Total Amount:', style: TextStyle(color: muted, fontSize: 14)),
                                            Text('\$${computedTotal.toStringAsFixed(2)}', style: TextStyle(color: goldColor, fontSize: 14, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                  
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      totalsContainer,
                                      const SizedBox(height: 16),
                                      if (_jobData!['invoices'] != null && (_jobData!['invoices'] as List).isNotEmpty) ...[
                                        const Text('INVOICES', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                        const SizedBox(height: 8),
                                        ...(_jobData!['invoices'] as List).map((inv) {
                                          String formattedDate = inv['issue_date'] ?? '';
                                          if (formattedDate.isNotEmpty) {
                                            try {
                                              final parsed = DateTime.parse(formattedDate).toLocal();
                                              formattedDate = DateFormat('MMM dd, yyyy').format(parsed);
                                            } catch (e) {
                                              // keep raw string on parse error
                                            }
                                          }
                                          
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: Colors.white10),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              title: Text(inv['invoice_number'] ?? 'Invoice', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                              subtitle: Text('$formattedDate\n\$${inv['total'] ?? '0.00'}', style: TextStyle(color: muted, fontSize: 13)),
                                              trailing: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white10,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                                ),
                                                onPressed: () {
                                                  showInvoiceDetailModal(context, inv);
                                                },
                                                child: const Text('View'),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        const SizedBox(height: 16),
                                      ],
                                      if (AuthHelpers.hasPermission('CREATE INVOICES') || AuthHelpers.isAdmin)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 20),
                                          child: ElevatedButton.icon(
                                            icon: const Icon(Icons.receipt, color: Colors.white),
                                            label: const Text("Create Invoice", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF3B82F6),
                                              minimumSize: const Size(double.infinity, 48),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () {
                                              showCreateInvoiceModal(
                                                context, 
                                                initialJobId: widget.jobId.toString(),
                                                initialCustomerId: _jobData!['customer_id']?.toString() ?? (_jobData!['customer'] is Map ? _jobData!['customer']['id']?.toString() : null),
                                                initialAmount: computedTotal,
                                                onInvoiceCreated: _loadJobDetail,
                                              );
                                            },
                                          ),
                                        ),
                                    ],
                                  );
                                }),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Fixed Bottom Action Dock (CHAT, CALL, MAP)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: EdgeInsets.only(
                              left: 16,
                              right: 16,
                              top: 16,
                              bottom: 16 + MediaQuery.of(context).padding.bottom,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white10),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // CHAT Button
                                Expanded(
                                  child: InkWell(
                                    onTap: _openChat,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: accentGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: accentGreen.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.chat_bubble_outline, color: accentGreen, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'CHAT',
                                            style: TextStyle(color: accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // CALL Button
                                Expanded(
                                  child: InkWell(
                                    onTap: _openCallModal,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: accentGreen.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: accentGreen.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.phone_outlined, color: accentGreen, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'CALL',
                                            style: TextStyle(color: accentGreen, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // MAP Button
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showQuickMap(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: goldColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: goldColor.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.map_outlined, color: goldColor, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'MAP',
                                            style: TextStyle(color: goldColor, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

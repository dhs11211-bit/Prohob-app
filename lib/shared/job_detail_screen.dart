import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_service.dart';
import '../components/global_chat_modal.dart';
import 'auth_helpers.dart';

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
  }

  Future<void> _loadJobDetail() async {
    try {
      final res = await ApiService.instance.get('/jobs/${widget.jobId}');
      if (mounted) {
        setState(() {
          _jobData = res is Map<String, dynamic> ? (res['data'] ?? res) : res;
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

  void _launchDirections(String? address) async {
    if (address == null || address.isEmpty || address == 'No address provided.') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No location address available for this job.')),
      );
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open map.')),
      );
    }
  }

  void _launchCall(String? phone) async {
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No phone number provided for contact.')),
      );
      return;
    }
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Calling $phone')),
      );
    }
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('No phone number available for ${item['name']}.')),
                            );
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

  void _confirmDeleteJob() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text('Delete Job', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this job? This action cannot be undone.',
          style: TextStyle(color: muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiService.instance.delete('/jobs/${widget.jobId}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Job deleted successfully'), backgroundColor: Colors.redAccent),
                  );
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete job: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Job updated successfully'), backgroundColor: Color(0xFF10B981)),
                                );
                              } catch (e) {
                                setModalState(() => isSaving = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to update job: $e'), backgroundColor: Colors.redAccent),
                                );
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
    String description = _jobData?['description'] ?? _jobData?['notes'] ?? 'No notes provided.';
    bool isRecurring = _jobData?['is_recurring'] == true || _jobData?['recurring_pattern'] != null;

    DateTime? scheduledTime;
    if (_jobData?['scheduled_time'] != null) {
      try {
        scheduledTime = DateTime.parse(_jobData!['scheduled_time'].toString()).toLocal();
      } catch (_) {}
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
          if (canEditJob && _jobData != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: _openEditModal,
            ),
          if (canDeleteJob && _jobData != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: _confirmDeleteJob,
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
                          padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 120),
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
                                  Container(
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
                                          isRecurring ? 'Series Job' : 'Single Job',
                                          style: TextStyle(color: accentBlue, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
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

                              // LOCATION Section
                              _buildSectionHeader('LOCATION'),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
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
                              ),

                              // JOB DESCRIPTION Section
                              _buildSectionHeader('JOB DESCRIPTION'),
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
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Checklist task added successfully'),
                                                          backgroundColor: Color(0xFF10B981),
                                                          duration: Duration(seconds: 2),
                                                        ),
                                                      );
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
                              _buildSectionHeader('ASSIGNED TEAMS'),
                              Builder(
                                builder: (context) {
                                  final teams = _jobData!['assigned_teams'];
                                  if (teams is List && teams.isNotEmpty) {
                                    return Column(
                                      children: teams.map<Widget>((t) {
                                        final teamName = t['name'] ?? 'Team';
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
                              _buildSectionHeader('INDIVIDUAL STAFF'),
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
                              _buildSectionHeader('JOB PHOTOS'),
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
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: goldColor.withOpacity(0.3)),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Estimated Value:', style: TextStyle(color: muted, fontSize: 14)),
                                          Text("\$${_jobData!['estimated_value'] ?? '0.00'}", style: TextStyle(color: textWhite, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('Total Amount:', style: TextStyle(color: muted, fontSize: 14)),
                                          Text("\$${_jobData!['total_amount'] ?? '0.00'}", style: TextStyle(color: goldColor, fontSize: 14, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Fixed Bottom Action Dock (CHAT, CALL, MAP)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            margin: const EdgeInsets.all(16),
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
                                    onTap: () => _launchDirections(address),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      decoration: BoxDecoration(
                                        color: accentBlue.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: accentBlue.withOpacity(0.4)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.navigation_outlined, color: accentBlue, size: 18),
                                          const SizedBox(width: 8),
                                          Text(
                                            'MAP',
                                            style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold, fontSize: 13),
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

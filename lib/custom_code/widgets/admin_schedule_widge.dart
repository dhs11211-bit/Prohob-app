// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:table_calendar/table_calendar.dart';
import '/backend/api_service.dart';
import '/components/global_chat_modal.dart';
import '../../auth/laravel_auth_manager.dart';
import '../../backend/api_service.dart';

// =====================================================================
// 🚀 COMPONENTES DEL EDITOR DE FOTOS (PARA EL CHAT INTEGRADO)
// =====================================================================
class DrawingPoint {
  final Offset point;
  final Paint paint;
  DrawingPoint({required this.point, required this.paint});
}

class ImagePainter extends CustomPainter {
  final List<DrawingPoint?> points;
  ImagePainter(this.points);
  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(
            points[i]!.point, points[i + 1]!.point, points[i]!.paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ImageEditorScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const ImageEditorScreen({Key? key, required this.imageBytes})
      : super(key: key);
  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  List<DrawingPoint?> points = [];
  final GlobalKey _globalKey = GlobalKey();

  Future<Uint8List?> _captureEditedImage() async {
    try {
      var boundary = _globalKey.currentContext!.findRenderObject();
      return widget.imageBytes;
    } catch (e) {
      return widget.imageBytes;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Mark Photo", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF10B981)),
              onPressed: () async {
                Navigator.pop(context, widget.imageBytes);
              })
        ],
      ),
      body: Center(child: Image.memory(widget.imageBytes, fit: BoxFit.contain)),
    );
  }
}

/// ===================================================================== 🚀
/// WIDGET PRINCIPAL: CALENDARIO Y SCHEDULE
/// =====================================================================
class AdminScheduleWidge extends StatefulWidget {
  const AdminScheduleWidge({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
  });
  final double? width;
  final double? height;
  final Future Function() onLogout;

  @override
  State<AdminScheduleWidge> createState() => _AdminScheduleWidgeState();
}

class _AdminScheduleWidgeState extends State<AdminScheduleWidge> {
  final LaravelAuthUser? authUser = currentUser as LaravelAuthUser?;
  CalendarFormat _calendarFormat = CalendarFormat.week;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay = DateTime.now();
  String _adminName = "Admin";

  final List<Color> _palette = [
    const Color(0xFFEF4444),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFF06B6D4),
    const Color(0xFFEC4899),
  ];

  List<dynamic> _apiWorkers = [];
  List<dynamic> _apiJobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _fetchWorkers();
    _fetchJobsForDate(_selectedDay ?? DateTime.now());
  }

  Future<void> _fetchWorkers() async {
    try {
      final workers = await ApiService.instance.get('/admin/workers');
      if (mounted) {
        setState(() {
          _apiWorkers = workers;
        });
      }
    } catch (e) {
      debugPrint("Error fetching workers: $e");
    }
  }

  Future<void> _fetchJobsForDate(DateTime date) async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      final jobs = await ApiService.instance.get('/admin/jobs?start_date=$dateStr&end_date=$dateStr');
      if (mounted) {
        setState(() {
          _apiJobs = jobs;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching schedule jobs: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAdminProfile() async {
    if (authUser != null && authUser!.userData != null) {
      if (mounted) {
        setState(() {
          _adminName = '${authUser!.userData!['first_name'] ?? ''} ${authUser!.userData!['last_name'] ?? ''}'.trim().isEmpty ? 'Admin' : '${authUser!.userData!['first_name'] ?? ''} ${authUser!.userData!['last_name'] ?? ''}'.trim();
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning,";
    if (hour < 18) return "Good afternoon,";
    return "Good evening,";
  }

  String _getUserInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : "A";
  }

  bool isSameDayValid(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _generateOccurrences(Map<String, dynamic> data) {
    if (data['scheduled_time'] == null) return [];

    DateTime start;
    if (data['scheduled_time'] is String) {
      start = DateTime.parse(data['scheduled_time']);
    } else {
      return [];
    }

    String freq = data['frequency'] ?? 'One-time';
    String? durationStr = data['duration'];
    List<dynamic> customDays = data['custom_days'] ?? [];

    DateTime limit;
    if (freq == 'One-time') {
      limit = start;
    } else {
      if (durationStr == '1 Month')
        limit = DateTime(start.year, start.month + 1, start.day);
      else if (durationStr == '3 Months')
        limit = DateTime(start.year, start.month + 3, start.day);
      else if (durationStr == '6 Months')
        limit = DateTime(start.year, start.month + 6, start.day);
      else if (durationStr == '1 Year')
        limit = DateTime(start.year + 1, start.month, start.day);
      else
        limit = DateTime(start.year + 2, start.month, start.day);
    }

    List<DateTime> occurrences = [];
    DateTime current = start;
    List<String> weekDayStrs = [
      "",
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun"
    ];

    while (current.isBefore(limit) || isSameDayValid(current, limit)) {
      if (freq == 'One-time' || freq == 'Daily') {
        occurrences.add(current);
      } else if (freq == 'Weekly') {
        occurrences.add(current);
      } else if (freq == 'Bi-weekly') {
        occurrences.add(current);
      } else if (freq == 'Weekends Only') {
        if (current.weekday == 6 || current.weekday == 7)
          occurrences.add(current);
      } else if (freq == 'Custom') {
        if (customDays.contains(weekDayStrs[current.weekday]))
          occurrences.add(current);
      }

      if (freq == 'Weekly')
        current = current.add(const Duration(days: 7));
      else if (freq == 'Bi-weekly')
        current = current.add(const Duration(days: 14));
      else
        current = current.add(const Duration(days: 1));
    }
    return occurrences;
  }

  // =====================================================================
  // 🚀 PERFIL UNIFICADO DEL ADMIN
  // =====================================================================
  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            hintText: label,
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  void _showAdminPersonalInfoModal() {
    TextEditingController firstNameCtrl = TextEditingController(text: _adminName.split(' ').first);
    TextEditingController lastNameCtrl = TextEditingController(text: _adminName.split(' ').length > 1 ? _adminName.split(' ').sublist(1).join(' ') : '');
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setModalState) => Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2A),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32))),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                              child: Container(
                                  width: 40,
                                  height: 5,
                                  decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius:
                                          BorderRadius.circular(10)))),
                          const SizedBox(height: 24),
                          const Text("Personal Information",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          const Text("Email Address (Uneditable)",
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 8),
                          Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(currentUser?.email ?? "No Email",
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 16))),
                          const SizedBox(height: 20),
                          const Text("First Name",
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 8),
                          _buildTextField(
                              controller: firstNameCtrl,
                              label: "First Name",
                              icon: Icons.person),
                          const SizedBox(height: 20),
                          const Text("Last Name",
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 8),
                          _buildTextField(
                              controller: lastNameCtrl,
                              label: "Last Name",
                              icon: Icons.person_outline),
                          const SizedBox(height: 32),
                          SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty)
                                          return;
                                        setModalState(() => isSaving = true);
                                        if (firstNameCtrl.text.trim().isNotEmpty) {
                                          try {
                                            // 1. Update Laravel backend
                                            await ApiService.instance.put('/employee/profile', {
                                              'first_name': firstNameCtrl.text.trim(),
                                              'last_name': lastNameCtrl.text.trim(),
                                            });

                                            if (mounted) {
                                              setState(() =>
                                                  _adminName = '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}');
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(const SnackBar(
                                                      content: Text(
                                                          "Profile updated successfully"),
                                                      backgroundColor:
                                                          Colors.green));
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          "Error updating profile: $e"),
                                                      backgroundColor:
                                                          Colors.redAccent));
                                            }
                                          } finally {
                                            setModalState(() => isSaving = false);
                                          }
                                        }
                                      },
                                child: isSaving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text("Save Changes",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)),
                              ))
                        ])))));
  }

  void _showAdminProfileModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(
                            color: Color(0xFF2A3B5A), shape: BoxShape.circle),
                        child: Center(
                            child: Text(_getUserInitial(_adminName),
                                style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)))),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(_adminName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          Text(currentUser?.email ?? "",
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13))
                        ]))
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading:
                      const Icon(Icons.person_outline, color: Colors.white70),
                  title: const Text("Personal Information",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminPersonalInfoModal();
                  }),
              const SizedBox(height: 16),
              ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout, color: Color(0xFFEF4444)),
                  title: const Text("Sign out",
                      style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white38),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.onLogout();
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startDirectChat(String workerId, String workerName) async {
    await GlobalChatModal.openChatWithUser(
      context,
      targetUserId: workerId,
      targetName: workerName,
      isCustomer: false,
    );
  }

  Future<void> _startJobChat(String jobId, Map<String, dynamic> jobData) async {
    String jobName = "${jobData['client_name'] ?? 'Client'} - ${jobData['job_type'] ?? 'Job'}";
    List<dynamic> workers = jobData['assigned_workers'] ?? [];
    if (workers.isEmpty && jobData['assigned_worker'] != null) {
      workers = [jobData['assigned_worker']];
    }
    List<String> workerIds = workers.map((e) => e.toString()).toList();
    await GlobalChatModal.openGroupChat(
      context,
      jobId: jobId,
      jobName: jobName,
      workerIds: workerIds,
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot dial this number")));
    }
  }

  void _showWorkerHistoryModal(String workerId, String workerName) {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
                color: Color(0xFF0D1B2A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.white24,
                                  borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 24),
                      Text("$workerName's Shifts",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Expanded(
                          child: Center(child: Text("Integration pending...", style: TextStyle(color: Colors.white38))))
                    ]))));
  }

  void _showWorkerProfileModal(
      Map<String, dynamic> workerData, Color workerColor) {
    String workerName = workerData['display_name'] ?? 'Unknown Worker';
    String workerId = workerData['id']?.toString() ?? workerData['uid']?.toString() ?? '';
    String phone = workerData['phone']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                CircleAvatar(
                    radius: 40,
                    backgroundColor: workerColor.withOpacity(0.2),
                    child: Text(workerName[0].toUpperCase(),
                        style: TextStyle(
                            color: workerColor,
                            fontSize: 32,
                            fontWeight: FontWeight.bold))),
                const SizedBox(height: 16),
                Text(workerName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                Text(workerData['email'] ?? 'No email',
                    style:
                        const TextStyle(color: Colors.white60, fontSize: 14)),
                if (phone.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(phone,
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12))),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (phone.isNotEmpty) {
                          _makePhoneCall(phone);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      "No phone number saved for this worker")));
                        }
                      },
                      child: _buildModalActionButton(
                          Icons.phone, "Call", workerColor),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _startDirectChat(workerId, workerName);
                      },
                      child: _buildModalActionButton(
                          Icons.message, "Message", workerColor),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _showWorkerHistoryModal(workerId, workerName);
                      },
                      child: _buildModalActionButton(
                          Icons.history, "History", workerColor),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalActionButton(IconData icon, String label, Color color) {
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24)),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12))
    ]);
  }

  void _deleteJob(String jobId) {
    // Implement API call for deletion
    Navigator.pop(context);
    Navigator.pop(context);
  }

  void _showEditJobModal(String jobId, Map<String, dynamic> jobData) {
    // Edit job via API
  }

  void _showJobDetailsModal(
      String jobId,
      Map<String, dynamic> jobData,
      Map<String, Map<String, dynamic>> allProfiles,
      Map<String, Color> allColors) {
    List<dynamic> assignedWorkers = jobData['assigned_workers'] ?? [];

    String status = (jobData['status'] ?? 'assigned').toString().toUpperCase();
    Color statusColor = const Color(0xFF3B82F6);
    if (status == 'ACTIVE') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2))),
                  ],
                ),
                const SizedBox(height: 24),
                Text(jobData['client_name'] ?? 'Unknown Client',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Text("Assigned Team:",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...assignedWorkers.map<Widget>((wId) {
                  var profile =
                      allProfiles[wId.toString()] ?? {'display_name': 'Unknown Worker'};
                  Color dotColor = allColors[wId.toString()] ?? Colors.white;
                  return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: const Color(0xFF0D1B2A),
                          borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        CircleAvatar(
                            radius: 16,
                            backgroundColor: dotColor.withOpacity(0.2),
                            child: Text(
                                profile['display_name'][0].toUpperCase(),
                                style: TextStyle(
                                    color: dotColor,
                                    fontWeight: FontWeight.bold))),
                        const SizedBox(width: 12),
                        Text(profile['display_name'],
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))
                      ]));
                }).toList(),
                const SizedBox(height: 20),
                Text(
                    (jobData['notes'] == null ||
                            jobData['notes'].toString().isEmpty)
                        ? 'No notes provided.'
                        : jobData['notes'],
                    style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 32),
                if (status == 'COMPLETED')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generating Invoice...')));
                        try {
                          await ApiService.instance.post('/jobs/$jobId/generate-invoice', {});
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Invoice Generated Successfully!')));
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to generate invoice: $e')));
                        }
                      },
                      child: const Text('Generate Invoice', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (status == 'COMPLETED')
                  const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildJobCard(
      Map<String, dynamic> jobData,
      Map<String, Map<String, dynamic>> allProfiles,
      Map<String, Color> allColors) {
    String status = (jobData['job_status'] ?? 'SCHEDULED').toString().toUpperCase();
    Color statusColor = const Color(0xFF3B82F6);
    if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

    List<dynamic> assignedWorkers = jobData['assigned_workers'] ?? [];

    String timeStr = "Time not set";
    if (jobData['scheduled_time'] != null) {
      try {
        DateTime parsedTime = DateTime.parse(jobData['scheduled_time'].toString().trim()).toLocal();
        String startStr = DateFormat.jm().format(parsedTime);
        timeStr = startStr;
        
        if (jobData['end_time'] != null && jobData['end_time'].toString().trim().isNotEmpty) {
           try {
             DateTime endParsed = DateTime.parse("1970-01-01 " + jobData['end_time'].toString().trim());
             String endStr = DateFormat.jm().format(endParsed);
             timeStr = "$startStr - $endStr";
           } catch (e) {}
        }
      } catch (e) {}
    }

    return GestureDetector(
      onTap: () => _showJobDetailsModal(
          jobData['id'].toString(), jobData, allProfiles, allColors),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jobData['title'] ?? 'Job Title',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: Colors.white54),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          jobData['client_name'] ?? 'Unknown Client',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (assignedWorkers.isNotEmpty)
                    Row(
                      children: assignedWorkers.map<Widget>((wId) {
                        var profile = allProfiles[wId.toString()] ??
                            {'display_name': 'Unknown'};
                        Color dotColor = allColors[wId.toString()] ?? Colors.white;
                        return Container(
                          margin: const EdgeInsets.only(right: 8),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: dotColor.withOpacity(0.2),
                            child: Text(
                              profile['display_name'][0].toUpperCase(),
                              style: TextStyle(
                                  color: dotColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.white54),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3))),
                  child: Text(
                    status,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
            : Builder(
                builder: (context) {
                  Map<String, Color> workerColors = {};
                  Map<String, Map<String, dynamic>> workerProfiles = {};
                  
                  for (int i = 0; i < _apiWorkers.length; i++) {
                    var doc = _apiWorkers[i];
                    String uid = doc['id']?.toString() ?? doc['uid']?.toString() ?? '';
                    workerColors[uid] = _palette[i % _palette.length];
                    workerProfiles[uid] = doc as Map<String, dynamic>;
                  }

                  Map<DateTime, List<Map<String, dynamic>>> jobsPerDay = {};
                  List<Map<String, dynamic>> todaysJobs = [];

                  for (var data in _apiJobs) {
                    if (data['start_date'] != null) {
                      try {
                        String timeStr = data['start_date'].toString().trim();
                        DateTime scheduledTime = DateTime.parse(timeStr).toLocal();
                        DateTime normalizedDate = DateTime(
                            scheduledTime.year,
                            scheduledTime.month,
                            scheduledTime.day);
                            
                        jobsPerDay.putIfAbsent(normalizedDate, () => []).add(data);
                        
                        if (isSameDayValid(_selectedDay, normalizedDate)) {
                          todaysJobs.add(data);
                        }
                      } catch (e) {
                        debugPrint("Error parsing job start_date: $e");
                      }
                    } else if (data['scheduled_time'] != null) {
                      try {
                        String timeStr = data['scheduled_time'].toString().trim();
                        DateTime scheduledTime = DateTime.parse(timeStr).toLocal();
                        DateTime normalizedDate = DateTime(
                            scheduledTime.year,
                            scheduledTime.month,
                            scheduledTime.day);
                            
                        jobsPerDay.putIfAbsent(normalizedDate, () => []).add(data);
                        
                        if (isSameDayValid(_selectedDay, normalizedDate)) {
                          todaysJobs.add(data);
                        }
                      } catch (e) {
                        debugPrint("Error parsing job scheduled_time: $e");
                      }
                    }
                  }

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(24)),
                              child: TableCalendar(
                                firstDay: DateTime.utc(2020, 10, 16),
                                lastDay: DateTime.utc(2030, 3, 14),
                                focusedDay: _focusedDay,
                                calendarFormat: _calendarFormat,
                                selectedDayPredicate: (day) =>
                                    isSameDayValid(_selectedDay, day),
                                onDaySelected: (selectedDay, focusedDay) {
                                  if (!isSameDayValid(_selectedDay, selectedDay)) {
                                    setState(() {
                                      _selectedDay = selectedDay;
                                      _focusedDay = focusedDay;
                                    });
                                    _fetchJobsForDate(selectedDay);
                                  }
                                },
                                eventLoader: (day) {
                                  DateTime normalized =
                                      DateTime(day.year, day.month, day.day);
                                  return jobsPerDay[normalized] ?? [];
                                },
                                headerStyle: const HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    titleTextStyle: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold)),
                                calendarStyle: const CalendarStyle(
                                    defaultTextStyle:
                                        TextStyle(color: Colors.white),
                                    selectedDecoration: BoxDecoration(
                                        color: Color(0xFF3B82F6),
                                        shape: BoxShape.circle)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Today's Jobs", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              Expanded(
                                child: todaysJobs.isEmpty 
                                    ? const Center(child: Text("No jobs scheduled for this date.", style: TextStyle(color: Colors.white60)))
                                    : ListView.builder(
                                        itemCount: todaysJobs.length,
                                        itemBuilder: (context, index) => _buildJobCard(todaysJobs[index], workerProfiles, workerColors),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
            ),
      ),
    );
  }
}

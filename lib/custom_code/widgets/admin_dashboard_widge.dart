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
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../../auth/laravel_auth_manager.dart';
import '../../backend/api_service.dart';
import '../../components/global_chat_modal.dart';

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
      RenderRepaintBoundary boundary = _globalKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 2.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
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
            icon: const Icon(Icons.undo, color: Colors.white),
            onPressed: () {
              if (points.isNotEmpty) {
                setState(() => points.removeLast());
              }
            },
          ),
          IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF10B981)),
              onPressed: () async {
                Uint8List? editedBytes = await _captureEditedImage();
                Navigator.pop(context, editedBytes);
              })
        ],
      ),
      body: Center(
        child: RepaintBoundary(
          key: _globalKey,
          child: Stack(
            children: [
              Image.memory(widget.imageBytes, fit: BoxFit.contain),
              Positioned.fill(
                child: GestureDetector(
                  onPanUpdate: (details) {
                    RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    setState(() {
                      points.add(DrawingPoint(
                          point:
                              renderBox.globalToLocal(details.globalPosition),
                          paint: Paint()
                            ..color = Colors.red
                            ..strokeWidth = 4.0
                            ..strokeCap = StrokeCap.round));
                    });
                  },
                  onPanEnd: (details) => setState(() => points.add(null)),
                  child: CustomPaint(
                      painter: ImagePainter(points), size: Size.infinite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================================
// 🚀 WIDGET PRINCIPAL: DASHBOARD CON MULTI-FILTROS
// =====================================================================
class AdminDashboardWidge extends StatefulWidget {
  const AdminDashboardWidge({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;

  @override
  State<AdminDashboardWidge> createState() => _AdminDashboardWidgeState();
}

class _AdminDashboardWidgeState extends State<AdminDashboardWidge> {
  final LaravelAuthUser? authUser = currentUser as LaravelAuthUser?;
  String _adminName = "Admin";
  Map<String, dynamic>? _dashboardMetrics;
  List<dynamic> _allJobs = [];
  Timer? _refreshTimer;
  bool _isLoading = true;

  // 🚀 VARIABLES DE LOS MULTI-FILTROS (SE PUEDEN APILAR)
  String? _filterWorkerId;
  String? _filterWorkerName;
  String? _filterClientName;
  String? _filterStatus;
  bool _showOnlyToday = true; // Por defecto mostramos solo lo de hoy

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    // _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) => _refreshData());
  }

  Future<void> _refreshData() async {
    await _loadAdminProfile();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    if (authUser != null && authUser!.userData != null) {
      if (mounted) {
        setState(() {
          _adminName = authUser!.userData!['name'] ?? 'Admin';
        });
      }
    }
    
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final metrics = await ApiService.instance.get('/admin/dashboard');
      final jobs = await ApiService.instance.get('/admin/jobs?start_date=$dateStr&end_date=$dateStr');
      if (mounted) {
        setState(() {
          _dashboardMetrics = metrics;
          _allJobs = jobs is List ? jobs : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching metrics/jobs: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning,";
    if (hour < 18) return "Good afternoon,";
    return "Good evening,";
  }

  String _getUserInitial() {
    return _adminName.isNotEmpty ? _adminName[0].toUpperCase() : "A";
  }

  // 🚀 CALCULADORA PARA SABER SI EL TRABAJO TOCA "HOY"
  bool isSameDayValid(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _generateOccurrences(Map<String, dynamic> data) {
    if (data['scheduled_time'] == null) return [];
    DateTime start = DateTime.parse(data['scheduled_time'].toString());
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
      if (freq == 'One-time' || freq == 'Daily')
        occurrences.add(current);
      else if (freq == 'Weekly' || freq == 'Bi-weekly')
        occurrences.add(current);
      else if (freq == 'Weekends Only' &&
          (current.weekday == 6 || current.weekday == 7))
        occurrences.add(current);
      else if (freq == 'Custom' &&
          customDays.contains(weekDayStrs[current.weekday]))
        occurrences.add(current);

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
  // 🚀 PERFIL UNIFICADO
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
    TextEditingController nameCtrl = TextEditingController(text: _adminName);
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
                          const Text("Display Name",
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 12)),
                          const SizedBox(height: 8),
                          _buildTextField(
                              controller: nameCtrl,
                              label: "Your Name",
                              icon: Icons.person),
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
                                        if (nameCtrl.text.trim().isEmpty)
                                          return;
                                        setModalState(() => isSaving = true);
                                        try {
                                          await ApiService.instance.put('/employee/profile', {
                                            'name': nameCtrl.text.trim()
                                          });
                                          if (mounted)
                                            setState(() => _adminName =
                                                nameCtrl.text.trim());
                                          Navigator.pop(ctx);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content:
                                                      Text('Profile updated!'),
                                                  backgroundColor:
                                                      Color(0xFF10B981)));
                                        } catch (e) {
                                        } finally {
                                          setModalState(() => isSaving = false);
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

  void _showProfileModal() {
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
                            child: Text(_getUserInitial(),
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
                          Text(authUser?.userData?['email'] ?? "",
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13))
                        ]))
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Material(
                color: Colors.transparent,
                child: ListTile(
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
              ),
              const SizedBox(height: 16),
              Material(
                color: Colors.transparent,
                child: ListTile(
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // 🚀 LÓGICA DE CHAT DEL DASHBOARD
  // =====================================================================
  String _formatChatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp.toDate();
    return DateFormat('hh:mm a').format(date);
  }

  Future<void> _openFileUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error opening URL: $e");
    }
  }

  Future<void> _startJobChat(String jobId, Map<String, dynamic> jobData) async {
    String jobName = "${jobData['client_name']} - ${jobData['job_type']}";
    List<dynamic> workers = jobData['assigned_workers'] ?? [];
    if (workers.isEmpty && jobData['assigned_worker'] != null) {
      workers = [jobData['assigned_worker']];
    }

    List<String> workerIds = workers.map((w) {
      if (w is Map) return w['id'].toString();
      return w.toString();
    }).toList();

    Navigator.pop(context);
    await GlobalChatModal.openGroupChat(
      context,
      jobId: jobId,
      jobName: jobName,
      workerIds: workerIds,
    );
  }

  // =====================================================================
  // 🚀 LÓGICA DE DETALLES DEL TRABAJO
  // =====================================================================
  void _deleteJob(String jobId) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text("Delete Job",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                content: const Text(
                    "Are you sure you want to permanently delete this job? This action cannot be undone.",
                    style: TextStyle(color: Colors.white60)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel",
                          style: TextStyle(color: Colors.white60))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444)),
                      onPressed: () async {
                        await ApiService.instance.delete('/admin/jobs/$jobId');
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text("Job deleted"),
                                backgroundColor: Color(0xFFEF4444)));
                      },
                      child: const Text("Delete",
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  void _showEditJobModal(String jobId, Map<String, dynamic> jobData) {
    TextEditingController notesCtrl =
        TextEditingController(text: jobData['notes'] ?? '');
    DateTime initialDate = DateTime.now();
    if (jobData['scheduled_time'] != null) {
      initialDate = DateTime.parse(jobData['scheduled_time'].toString());
    }

    DateTime tempDate = initialDate;
    TimeOfDay tempTime =
        TimeOfDay(hour: initialDate.hour, minute: initialDate.minute);
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
                          const Text("Quick Edit Job",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 24),
                          const Text("Reschedule",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                              onTap: () async {
                                DateTime? pickedD = await showDatePicker(
                                    context: context,
                                    initialDate: tempDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 365)),
                                    lastDate: DateTime(2030),
                                    builder: (context, child) => Theme(
                                        data: ThemeData.dark().copyWith(
                                            colorScheme: const ColorScheme.dark(
                                                primary: Color(0xFF3B82F6))),
                                        child: child!));
                                if (pickedD != null) {
                                  TimeOfDay? pickedT = await showTimePicker(
                                      context: context,
                                      initialTime: tempTime,
                                      builder: (context, child) => Theme(
                                          data: ThemeData.dark().copyWith(
                                              colorScheme:
                                                  const ColorScheme.dark(
                                                      primary:
                                                          Color(0xFF3B82F6))),
                                          child: child!));
                                  if (pickedT != null) {
                                    setModalState(() {
                                      tempDate = pickedD;
                                      tempTime = pickedT;
                                    });
                                  }
                                }
                              },
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12)),
                                  child: Row(children: [
                                    const Icon(Icons.calendar_month,
                                        color: Color(0xFF3B82F6), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: Text(
                                            "${DateFormat('MMM d, yyyy').format(tempDate)} at ${tempTime.format(context)}",
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16)))
                                  ]))),
                          const SizedBox(height: 24),
                          const Text("Special Instructions / Notes",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12)),
                              child: TextField(
                                controller: notesCtrl,
                                maxLines: 3,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                    hintText: "Add entry codes, warnings...",
                                    hintStyle: TextStyle(color: Colors.white38),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.all(16)),
                              )),
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
                                        setModalState(() => isSaving = true);
                                        try {
                                          DateTime newFullDate = DateTime(
                                              tempDate.year,
                                              tempDate.month,
                                              tempDate.day,
                                              tempTime.hour,
                                              tempTime.minute);
                                          await ApiService.instance.put('/admin/jobs/$jobId', {
                                              'scheduled_time': newFullDate.toIso8601String(),
                                              'notes': notesCtrl.text.trim()
                                            });
                                          Navigator.pop(ctx);
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text('Job updated!'),
                                                  backgroundColor:
                                                      Color(0xFF10B981)));
                                        } catch (e) {
                                        } finally {
                                          setModalState(() => isSaving = false);
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

  void _showJobDetailsModal(String jobId, Map<String, dynamic> jobData) {
    List<dynamic> assignedWorkers = jobData['assigned_workers'] ?? [];
    if (assignedWorkers.isEmpty && jobData['assigned_worker'] != null) {
      assignedWorkers = [jobData['assigned_worker']];
    }

    String leaderId = jobData['team_leader_id'] ??
        (assignedWorkers.isNotEmpty ? assignedWorkers[0] : '');
    String status = (jobData['status'] ?? 'pending').toString().toUpperCase();

    Color statusColor = const Color(0xFF3B82F6);
    if (status == 'ACTIVE') statusColor = const Color(0xFF10B981);
    if (status == 'PENDING') statusColor = const Color(0xFFF59E0B);
    if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);
    if (status == 'CANCELLED') statusColor = Colors.redAccent;

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
                    Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => _deleteJob(jobId),
                          child: const Icon(Icons.delete,
                              color: Color(0xFFEF4444)),
                        ))
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(jobData['client_name'] ?? 'Unknown Client',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(jobData['job_type'] ?? 'Standard Clean',
                              style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showEditJobModal(jobId, jobData),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Row(children: [
                            Icon(Icons.edit, color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text("Edit",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12))
                          ])),
                    )
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.white60, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(jobData['address'] ?? 'No address',
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 14)))
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.access_time_filled,
                        color: Colors.white60, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            jobData['scheduled_time'] != null
                                ? DateFormat('EEEE, MMM d, yyyy • hh:mm a')
                                    .format(
                                        DateTime.parse(jobData['scheduled_time'].toString()).toLocal())
                                : "No Time",
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 14)))
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Assigned Team:",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 10)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Builder(
                    builder: (context) {
                      List users = jobData['assigned_users'] ?? [];
                      if (users.isEmpty) {
                        return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0D1B2A),
                                borderRadius: BorderRadius.circular(12)),
                            child: const Row(children: [
                              Icon(Icons.warning,
                                  color: Colors.orange, size: 20),
                              SizedBox(width: 12),
                              Text("Unassigned - Needs Worker",
                                  style: TextStyle(
                                      color: Colors.orange,
                                      fontWeight: FontWeight.bold))
                            ]));
                      }

                      return Column(
                        children: users.map<Widget>((user) {
                          var profile = user as Map<String, dynamic>;
                          bool isLeader = profile['id'].toString() == leaderId;
                          return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF0D1B2A),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: isLeader
                                          ? const Color(0xFFF59E0B)
                                              .withOpacity(0.5)
                                          : Colors.transparent)),
                              child: Row(children: [
                                CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF3B82F6)
                                        .withOpacity(0.2),
                                    child: Text(
                                        (profile['name'] ?? 'W')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            color: Color(0xFF3B82F6),
                                            fontWeight: FontWeight.bold))),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        profile['name'] ?? 'Worker',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15))),
                                if (isLeader)
                                  const Icon(Icons.star,
                                      color: Color(0xFFF59E0B), size: 20)
                              ]));
                        }).toList(),
                      );
                    }),
                const SizedBox(height: 12),
                SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor:
                                const Color(0xFF3B82F6).withOpacity(0.15),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            side: BorderSide(
                                color:
                                    const Color(0xFF3B82F6).withOpacity(0.3))),
                        icon: const Icon(Icons.chat,
                            color: Color(0xFF3B82F6), size: 18),
                        label: const Text("Open Job Team Chat",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        onPressed: () => _startJobChat(jobId, jobData))),
                if (status == 'PENDING') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                      width: double.infinity,
                      height: 45,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          icon: const Icon(Icons.verified,
                              color: Colors.white, size: 18),
                          label: const Text("Approve & Complete Job",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          onPressed: () async {
                            await ApiService.instance.put('/admin/jobs/$jobId', {'status': 'completed'});
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Job successfully completed!'),
                                    backgroundColor: Color(0xFF10B981)));
                          })),
                ],
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),
                const Text("Special Instructions / Notes:",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                    (jobData['notes'] == null ||
                            jobData['notes'].toString().isEmpty)
                        ? 'No notes provided.'
                        : jobData['notes'],
                    style: const TextStyle(color: Colors.white60)),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 🚀 MENÚS DE LOS MULTI-FILTROS
  // =====================================================================
  void _showWorkerFilterModal() async {
    var workers = await ApiService.instance.get('/admin/workers');
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
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
                    const Text("Select Worker to Filter",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if ((workers as List).isEmpty)
                      const Text("No workers found",
                          style: TextStyle(color: Colors.white38))
                    else
                      Expanded(
                          child: ListView.builder(
                              itemCount: (workers as List).length,
                              itemBuilder: (ctx, i) {
                                var wData = workers[i];
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                      title: Text(
                                          wData['display_name'] ?? 'Worker',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      onTap: () {
                                      setState(() {
                                        _filterWorkerId = workers[i]['id'].toString();
                                        _filterWorkerName =
                                            wData['display_name'] ?? 'Worker';
                                      });
                                      Navigator.pop(context);
                                    }),
                                );
                              }))
                  ],
                ),
              ),
            ));
  }

  void _showClientFilterModal() async {
    var clients = await ApiService.instance.get('/admin/clients');
    if (!mounted) return;
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
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
                    const Text("Select Client to Filter",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if ((clients as List).isEmpty)
                      const Text("No clients found",
                          style: TextStyle(color: Colors.white38))
                    else
                      Expanded(
                          child: ListView.builder(
                              itemCount: (clients as List).length,
                              itemBuilder: (ctx, i) {
                                var cData = clients[i];
                                return Material(
                                  color: Colors.transparent,
                                  child: ListTile(
                                      title: Text(cData['name'] ?? 'Client',
                                          style: const TextStyle(
                                              color: Colors.white)),
                                      onTap: () {
                                      setState(() {
                                        _filterClientName = cData['name'];
                                      });
                                      Navigator.pop(context);
                                    }),
                                );
                              }))
                  ],
                ),
              ),
            ));
  }

  void _showStatusFilterModal() {
    List<String> statuses = [
      'Assigned',
      'Active',
      'Pending',
      'Completed',
      'Cancelled'
    ];
    showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF1E293B),
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
                    const Text("Select Status",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListView.builder(
                        shrinkWrap: true,
                        itemCount: statuses.length,
                        itemBuilder: (ctx, i) {
                          return Material(
                            color: Colors.transparent,
                            child: ListTile(
                                title: Text(statuses[i],
                                    style: const TextStyle(color: Colors.white)),
                                onTap: () {
                                  setState(() {
                                    _filterStatus = statuses[i].toLowerCase();
                                  });
                                  Navigator.pop(context);
                                }),
                          );
                        })
                  ],
                ),
              ),
            ));
  }

  Widget _buildFilterPill(
      String label, bool isActive, VoidCallback onTap, VoidCallback onClear) {
    return GestureDetector(
        onTap: onTap,
        child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFF3B82F6) : const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isActive ? const Color(0xFF3B82F6) : Colors.white10),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label,
                  style: TextStyle(
                      color: isActive ? Colors.white : Colors.white60,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
              if (isActive) ...[
                const SizedBox(width: 6),
                GestureDetector(
                    onTap: onClear,
                    child:
                        const Icon(Icons.close, color: Colors.white, size: 14))
              ]
            ])));
  }

  // =====================================================================
  // 🚀 INTERFAZ PRINCIPAL DEL DASHBOARD
  // =====================================================================
  Widget _buildClickableKPICard(
      {required String title,
      required String value,
      required IconData icon,
      required Color accentColor,
      required String subtitle}) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: accentColor, size: 20)),
                Text(subtitle,
                    style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold))
              ],
            ),
            const SizedBox(height: 16),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(color: Colors.white60, fontSize: 13))
          ],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: const Color(0xFF0D1B2A),
      child: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshData,
          color: const Color(0xFF3B82F6),
          backgroundColor: const Color(0xFF1E293B),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24.0),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getGreeting(),
                          style: const TextStyle(
                              color: Colors.white60, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(_adminName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  GestureDetector(
                    onTap: _showProfileModal,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF3B82F6), width: 2)),
                      child: Center(
                          child: Text(_getUserInitial(),
                              style: const TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Row(
                children: [
                  Expanded(
                      child: _buildClickableKPICard(
                          title: "Monthly Revenue",
                          value: "\$${(_dashboardMetrics?['monthly_revenue'] ?? 0).toStringAsFixed(2)}",
                          icon: Icons.attach_money,
                          accentColor: const Color(0xFF10B981),
                          subtitle: "This Month")),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildClickableKPICard(
                          title: "Active Jobs",
                          value: "${_dashboardMetrics?['active_jobs'] ?? 0}",
                          icon: Icons.work_outline,
                          accentColor: const Color(0xFF3B82F6),
                          subtitle: "Live")),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _buildClickableKPICard(
                          title: "Total Workers",
                          value: "${_dashboardMetrics?['total_workers'] ?? 0}",
                          icon: Icons.people_outline,
                          accentColor: const Color(0xFFF59E0B),
                          subtitle: "Registered")),
                  const SizedBox(width: 16),
                  Expanded(
                      child: _buildClickableKPICard(
                          title: "Pending Estimates",
                          value: "${_dashboardMetrics?['pending_estimates'] ?? 0}",
                          icon: Icons.description_outlined,
                          accentColor: const Color(0xFF8B5CF6),
                          subtitle: "Action req.")),
                ],
              ),
              const SizedBox(height: 40),

              const Text("Operations Log",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // 🚀 PASTILLAS DE MULTI-FILTROS (SE PUEDEN SUMAR)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterPill(
                        _showOnlyToday ? "📅 Today" : "📅 All Dates",
                        _showOnlyToday,
                        () => setState(() => _showOnlyToday = true),
                        () => setState(() => _showOnlyToday = false)),
                    _buildFilterPill(
                        _filterWorkerId != null
                            ? "👷 ${_filterWorkerName!}"
                            : "👷 By Worker",
                        _filterWorkerId != null,
                        _showWorkerFilterModal,
                        () => setState(() {
                              _filterWorkerId = null;
                              _filterWorkerName = null;
                            })),
                    _buildFilterPill(
                        _filterClientName != null
                            ? "🏢 $_filterClientName"
                            : "🏢 By Client",
                        _filterClientName != null,
                        _showClientFilterModal,
                        () => setState(() => _filterClientName = null)),
                    _buildFilterPill(
                        _filterStatus != null
                            ? "📊 ${_filterStatus![0].toUpperCase()}${_filterStatus!.substring(1)}"
                            : "📊 By Status",
                        _filterStatus != null,
                        _showStatusFilterModal,
                        () => setState(() => _filterStatus = null)),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allJobs.isEmpty
                    ? const Center(
                        child: Text("No jobs recorded.",
                            style: TextStyle(color: Colors.white60)))
                    : Builder(builder: (context) {
                        List docs = _allJobs;

                  // 🚀 ALERTA DE PENDIENTES (BANNER)
                  int pendingCount = docs
                      .where((d) =>
                          (d as Map<String, dynamic>)['status'] ==
                          'pending')
                      .length;

                  // 🚀 MOTOR DE FILTRADO EXACTO
                  List<dynamic> filteredDocs =
                      docs.where((doc) {
                    var data = doc as Map<String, dynamic>;
                    String status =
                        (data['status'] ?? 'assigned').toString().toLowerCase();

                    if (_filterStatus != null && status != _filterStatus)
                      return false;
                    if (_filterClientName != null &&
                        data['client_name'] != _filterClientName) return false;
                    if (_filterWorkerId != null) {
                      List users = data['assigned_users'] ?? [];
                      bool hasWorker = users.any((u) => u['id'].toString() == _filterWorkerId);
                      if (!hasWorker) return false;
                    }
                    if (_showOnlyToday) {
                      List<DateTime> dates = _generateOccurrences(data);
                      bool happensToday =
                          dates.any((d) => isSameDayValid(d, DateTime.now()));
                      // Si está PENDING, SIEMPRE lo mostramos porque urge aprobarlo, aunque sea de ayer
                      if (status != 'pending' && !happensToday) return false;
                    }
                    return true;
                  }).toList();

                  // 🚀 ORDENAMIENTO (PENDING HASTA ARRIBA SIEMPRE)
                  filteredDocs.sort((a, b) {
                    var dA = a as Map<String, dynamic>;
                    var dB = b as Map<String, dynamic>;
                    String statA =
                        (dA['status'] ?? '').toString().toLowerCase();
                    String statB =
                        (dB['status'] ?? '').toString().toLowerCase();
                    if (statA == 'pending' && statB != 'pending') return -1;
                    if (statA != 'pending' && statB == 'pending') return 1;
                    return 0;
                  });

                  return Column(
                    children: [
                      if (pendingCount > 0 && _filterStatus != 'pending') ...[
                        GestureDetector(
                            onTap: () => setState(() {
                                  _filterStatus = 'pending';
                                  _showOnlyToday = false;
                                }),
                            child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: const Color(0xFFF59E0B)
                                            .withOpacity(0.5))),
                                child: Row(children: [
                                  const Icon(Icons.warning_amber_rounded,
                                      color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(
                                          "You have $pendingCount job(s) awaiting approval!",
                                          style: const TextStyle(
                                              color: Color(0xFFF59E0B),
                                              fontWeight: FontWeight.bold))),
                                  const Icon(Icons.chevron_right,
                                      color: Color(0xFFF59E0B))
                                ])))
                      ],
                      if (filteredDocs.isEmpty)
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16)),
                            child: const Center(
                                child: Text("No results found for this filter.",
                                    style: TextStyle(color: Colors.white60))))
                      else
                        ...filteredDocs.map((doc) {
                          var data = doc as Map<String, dynamic>;
                          String status = (data['status'] ?? 'assigned').toString().toUpperCase();

                          Color dotColor = const Color(0xFF3B82F6);
                          if (status == 'ACTIVE')
                            dotColor = const Color(0xFF10B981);
                          if (status == 'PENDING')
                            dotColor = const Color(0xFFF59E0B);
                          if (status == 'COMPLETED')
                            dotColor = const Color(0xFF8B5CF6);
                          if (status == 'CANCELLED')
                            dotColor = Colors.redAccent;

                          return GestureDetector(
                            onTap: () => _showJobDetailsModal(data['id'].toString(), data),
                            child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(16)),
                                child: Row(
                                  children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                            color: dotColor,
                                            shape: BoxShape.circle)),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        RichText(
                                            text: TextSpan(
                                                style: const TextStyle(
                                                    fontSize: 14),
                                                children: [
                                              TextSpan(
                                                  text:
                                                      "${data['client_name'] ?? 'Unknown Client'} ",
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              TextSpan(
                                                  text: "($status)",
                                                  style: TextStyle(
                                                      color: dotColor,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 11))
                                            ])),
                                        const SizedBox(height: 4),
                                        Text(
                                            data['address'] ??
                                                'No address provided',
                                            style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis)
                                      ],
                                    )),
                                    const Icon(Icons.chevron_right,
                                        color: Colors.white24, size: 20)
                                  ],
                                )),
                          );
                        }).toList()
                    ],
                  );
                },
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

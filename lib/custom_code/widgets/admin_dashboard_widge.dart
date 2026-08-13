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
import '../../shared/job_detail_screen.dart';
import '../../backend/api_service.dart';
import '../../components/global_chat_modal.dart';
import '/shared/toast_service.dart';
import '../../shared/job_parser.dart';

import '../../shared/image_editor_helper.dart';
import '../../custom_code/widgets/admin_team_widge.dart';
import '../../custom_code/widgets/admin_finances_widge.dart';

// =====================================================================
// 🚀 WIDGET PRINCIPAL: DASHBOARD CON MULTI-FILTROS
// =====================================================================
class AdminDashboardWidge extends StatefulWidget {
  const AdminDashboardWidge({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
    this.onNavigateToFinances,
    this.onNavigateToTeam,
    this.onNavigateToJobs,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;
  final VoidCallback? onNavigateToFinances;
  final VoidCallback? onNavigateToTeam;
  final VoidCallback? onNavigateToJobs;

  @override
  State<AdminDashboardWidge> createState() => _AdminDashboardWidgeState();
}

class _AdminDashboardWidgeState extends State<AdminDashboardWidge> {
  final LaravelAuthUser? authUser = currentUser as LaravelAuthUser?;
  String _adminName = "Admin";
  String _adminFirstName = "";
  String _adminLastName = "";
  Map<String, dynamic>? _dashboardMetrics;
  List<dynamic> _allJobs = [];
  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isModalOpening = false;

  // 🚀 VARIABLES DE LOS MULTI-FILTROS (SE PUEDEN APILAR)
  String? _filterWorkerId;
  String? _filterWorkerName;
  String? _filterCustomerName;
  String? _filterCustomerId;
  String? _filterStatus;
  bool _showOnlyToday = true; // Por defecto mostramos solo lo de hoy
  
  ScrollController _scrollController = ScrollController();
  DateTime _currentStartDate = DateTime.now();
  DateTime _currentEndDate = DateTime.now();
  bool _isFetchingMore = false;
  bool _hasMoreData = true;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _fetchJobs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isFetchingMore && _hasMoreData && !_showOnlyToday) {
      _fetchJobs(isLoadMore: true);
    }
  }

  Future<void> _refreshData() async {
    await _loadAdminProfile();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminProfile() async {
    if (authUser != null && authUser!.userData != null) {
      if (mounted) {
        setState(() {
          _adminFirstName = authUser!.userData!['first_name'] ?? '';
          _adminLastName = authUser!.userData!['last_name'] ?? '';
          _adminName = '$_adminFirstName $_adminLastName'.trim();
          if (_adminName.isEmpty) _adminName = 'Admin';
        });
      }
    }

    try {
      final metrics = await ApiService.instance.get('/admin/dashboard');
      if (mounted) {
        setState(() {
          _dashboardMetrics = metrics;
        });
      }
    } catch (e) {
      debugPrint("Error fetching metrics/jobs: $e");
    }
  }

  Future<void> _fetchJobs({bool isLoadMore = false}) async {
    if (_isFetchingMore || (!isLoadMore && _isLoading && _allJobs.isNotEmpty)) return;
    if (!mounted) return;

    setState(() {
      if (isLoadMore) {
        _isFetchingMore = true;
        _currentStartDate = _currentEndDate.add(const Duration(days: 1));
        _currentEndDate = _currentStartDate.add(const Duration(days: 6));
      } else {
        _isLoading = true;
        _hasMoreData = true;
        _currentStartDate = DateTime.now();
        if (_showOnlyToday) {
          _currentEndDate = DateTime.now();
        } else {
          _currentEndDate = DateTime.now().add(const Duration(days: 6));
        }
      }
    });

    try {
      final startStr = DateFormat('yyyy-MM-dd').format(_currentStartDate);
      final endStr = DateFormat('yyyy-MM-dd').format(_currentEndDate);
      String url = '/admin/jobs?start_date=$startStr&end_date=$endStr';

      if (_filterWorkerId != null) url += '&worker_id=$_filterWorkerId';
      if (_filterCustomerId != null) url += '&customer_id=$_filterCustomerId';
      if (_filterStatus == 'cancelled') {
        url += '&record_status=5';
      } else {
        url += '&record_status=1';
        if (_filterStatus != null && _filterStatus != 'all' && _filterStatus != 'active') {
          String backendJobStatus = _filterStatus!.replaceAll(' ', '_');
          if (backendJobStatus == 'in_route') backendJobStatus = 'en_route';
          url += '&job_status=$backendJobStatus';
        }
      }

      final jobsResponse = await ApiService.instance.get(url);
      
      List fetchedJobs = [];
      if (jobsResponse is Map && jobsResponse.containsKey('data')) {
        fetchedJobs = jobsResponse['data'] as List;
      } else if (jobsResponse is List) {
        fetchedJobs = jobsResponse;
      }

      if (mounted) {
        setState(() {
          if (isLoadMore) {
            _allJobs.addAll(fetchedJobs);
            if (fetchedJobs.isEmpty) _hasMoreData = false;
            _isFetchingMore = false;
          } else {
            _allJobs = fetchedJobs;
            if (fetchedJobs.isEmpty) _hasMoreData = false;
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
      if (mounted) {
        setState(() {
          if (isLoadMore) _isFetchingMore = false;
          else _isLoading = false;
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

  String _getUserInitial() {
    return _adminName.isNotEmpty ? _adminName[0].toUpperCase() : "A";
  }

  // 🚀 CALCULADORA PARA SABER SI EL TRABAJO TOCA "HOY"
  bool isSameDayValid(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<DateTime> _generateOccurrences(Map<String, dynamic> data) {
    DateTime? start = JobParser.getStartDate(data);
    if (start == null) return [];
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
    TextEditingController firstNameCtrl =
        TextEditingController(text: _adminFirstName);
    TextEditingController lastNameCtrl =
        TextEditingController(text: _adminLastName);
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
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
                                        if (firstNameCtrl.text.trim().isEmpty ||
                                            lastNameCtrl.text.trim().isEmpty)
                                          return;
                                        setModalState(() => isSaving = true);
                                        try {
                                          await ApiService.instance.put(
                                              '/employee/profile', {
                                            'first_name':
                                                firstNameCtrl.text.trim(),
                                            'last_name':
                                                lastNameCtrl.text.trim()
                                          });
                                          if (mounted)
                                            setState(() {
                                              _adminFirstName =
                                                  firstNameCtrl.text.trim();
                                              _adminLastName =
                                                  lastNameCtrl.text.trim();
                                              _adminName =
                                                  '$_adminFirstName $_adminLastName'
                                                      .trim();
                                            });
                                          Navigator.pop(ctx);
                                          ToastService.success(context, 'Profile updated!');
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
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      useSafeArea: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
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
                      leading: const Icon(Icons.person_outline,
                          color: Colors.white70),
                      title: const Text("Personal Information",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
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
                      leading:
                          const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      title: const Text("Sign out",
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
                      onTap: () async {
                        Navigator.pop(context);
                        await widget.onLogout();
                      }),
                ),
              ],
            ),
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
    String jobName = "${jobData['customer_name']} - ${jobData['job_type']}";
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
                        ToastService.error(context, 'Job deleted');
                      },
                      child: const Text("Delete",
                          style: TextStyle(color: Colors.white)))
                ]));
  }

  void _showEditJobModal(String jobId, Map<String, dynamic> jobData) {
    TextEditingController notesCtrl =
        TextEditingController(text: jobData['notes'] ?? '');
    DateTime initialDate = JobParser.getStartDate(jobData) ?? DateTime.now();

    DateTime tempDate = initialDate;
    TimeOfDay tempTime =
        TimeOfDay(hour: initialDate.hour, minute: initialDate.minute);
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        useSafeArea: true,
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
                                          await ApiService.instance.put(
                                              '/admin/jobs/$jobId', {
                                            'start_date': DateFormat('yyyy-MM-dd').format(newFullDate),
                                            'start_time': DateFormat('HH:mm:ss').format(newFullDate),
                                            'notes': notesCtrl.text.trim()
                                          });
                                          Navigator.pop(ctx);
                                          Navigator.pop(context);
                                          ToastService.success(context, 'Job updated!');
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

  void _showJobDetailsModal(String jobId, Map<String, dynamic> jobData) async {
    int? parsedId = int.tryParse(jobId);
    if (parsedId != null) {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SharedJobDetailScreen(jobId: parsedId),
        ),
      );
      if (result == true) {
        _refreshData();
      }
      return;
    }
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
      useSafeArea: true,
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
                          Text(jobData['customer_name'] ?? 'Unknown Customer',
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
                            JobParser.getStartDate(jobData) != null
                                ? DateFormat('EEEE, MMM d, yyyy • hh:mm a')
                                    .format(JobParser.getStartDate(jobData)!)
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
                Builder(builder: (context) {
                  List users = jobData['assigned_users'] ?? [];
                  if (users.isEmpty) {
                    return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0D1B2A),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.warning, color: Colors.orange, size: 20),
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
                                      ? const Color(0xFFF59E0B).withOpacity(0.5)
                                      : Colors.transparent)),
                          child: Row(children: [
                            CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    const Color(0xFF3B82F6).withOpacity(0.2),
                                child: Text(
                                    (profile['first_name'] ?? 'W')[0]
                                        .toUpperCase(),
                                    style: const TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontWeight: FontWeight.bold))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(() {
                              final n =
                                  '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'
                                      .trim();
                              return n.isEmpty ? 'Worker' : n;
                            }(),
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
                            await ApiService.instance.put(
                                '/admin/jobs/$jobId', {'status': 'completed'});
                            Navigator.pop(context);
                            ToastService.success(context, 'Job successfully completed!');
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
    if (_isModalOpening) return;
    _isModalOpening = true;
    var apiResponse = await ApiService.instance.get('/admin/workers');
    if (!mounted) {
      _isModalOpening = false;
      return;
    }
    
    var workers = (apiResponse is Map && apiResponse.containsKey('data')) 
        ? apiResponse['data'] 
        : apiResponse;
        
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        useSafeArea: true,
        builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
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
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _filterWorkerId = workers[i]['id'].toString();
                                      _filterWorkerName = wData['display_name'] ?? 'Worker';
                                    });
                                    _fetchJobs();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155).withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.person, color: Color(0xFF3B82F6), size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            wData['display_name'] ?? 'Worker',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.white38),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                      )
                  ],
                ),
              ),
            )));
    _isModalOpening = false;
  }

  void _showCustomerFilterModal() async {
    if (_isModalOpening) return;
    _isModalOpening = true;
    var apiResponse = await ApiService.instance.get('/admin/customers');
    if (!mounted) {
      _isModalOpening = false;
      return;
    }
    
    var clients = (apiResponse is Map && apiResponse.containsKey('data')) 
        ? apiResponse['data'] 
        : apiResponse;
    await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        useSafeArea: true,
        builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                    Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 24),
                    const Text("Select Customer to Filter",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if ((clients as List).isEmpty)
                      const Text("No customers found",
                          style: TextStyle(color: Colors.white38))
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: (clients as List).length,
                          itemBuilder: (ctx, i) {
                                var cData = clients[i];
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _filterCustomerId = cData['id'].toString();
                                      _filterCustomerName =
                                          '${cData['first_name'] ?? ''} ${cData['last_name'] ?? ''}'
                                              .trim();
                                    });
                                    _fetchJobs();
                                    Navigator.pop(context);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF334155).withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.business, color: Color(0xFF10B981), size: 20),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            () {
                                              final n = '${cData['first_name'] ?? ''} ${cData['last_name'] ?? ''}'.trim();
                                              return n.isEmpty ? 'Customer' : n;
                                            }(),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                        const Icon(Icons.chevron_right, color: Colors.white38),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                      )
                  ],
                ),
              ),
            )));
    _isModalOpening = false;
  }

  void _showStatusFilterModal() {
    List<String> statuses = [
      'Draft',
      'Scheduled',
      'In Route',
      'In Progress',
      'Completed',
      'Cancelled'
    ];
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF1E293B),
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        useSafeArea: true,
        builder: (context) => Container(
              height: MediaQuery.of(context).size.height * 0.8,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
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
                      Expanded(
                        child: ListView.builder(
                            itemCount: statuses.length,
                            itemBuilder: (ctx, i) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _filterStatus = statuses[i].toLowerCase();
                                  });
                                  _fetchJobs();
                                  Navigator.pop(context);
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF334155).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.analytics_outlined, color: Color(0xFF8B5CF6), size: 20),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          statuses[i],
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      const Icon(Icons.chevron_right, color: Colors.white38),
                                    ],
                                  ),
                                ),
                              );
                            }),
                      )
                    ],
                  ),
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
      required String subtitle,
      VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: onTap != null ? accentColor.withOpacity(0.3) : Colors.white10)),
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
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(subtitle,
                        style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (onTap != null)
                    Icon(Icons.chevron_right, color: accentColor.withOpacity(0.6), size: 16),
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
          )),
    );
  }

  Widget _buildSplitKPICard({
    required String title1,
    required String value1,
    required String title2,
    required String value2,
    required IconData icon,
    required Color accentColor,
    VoidCallback? onTap1,
    VoidCallback? onTap2,
  }) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accentColor.withOpacity(0.3))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accentColor, size: 20)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: onTap1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value1,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(title1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            ),
                            if (onTap1 != null) ...
                              [const SizedBox(width: 2), const Icon(Icons.chevron_right, color: Colors.white30, size: 12)],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 35,
                  color: Colors.white10,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: onTap2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(value2,
                            style: TextStyle(
                                color: accentColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(title2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
                            ),
                            if (onTap2 != null) ...
                              [const SizedBox(width: 2), Icon(Icons.chevron_right, color: accentColor.withOpacity(0.5), size: 12)],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
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
                  children: [
                    Expanded(
                        child: _buildClickableKPICard(
                            title: "Monthly Revenue",
                            value:
                                "\$${(double.tryParse(_dashboardMetrics?['monthly_revenue']?.toString() ?? '0') ?? 0.0).toStringAsFixed(2)}",
                            icon: Icons.attach_money,
                            accentColor: const Color(0xFF10B981),
                            subtitle: "This Month",
                            onTap: () {
                              if (widget.onNavigateToFinances != null) {
                                widget.onNavigateToFinances!();
                              }
                            })),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildSplitKPICard(
                            title1: "Scheduled",
                            value1: "${_dashboardMetrics?['scheduled_jobs'] ?? 0}",
                            title2: "Live",
                            value2: "${_dashboardMetrics?['live_jobs'] ?? 0}",
                            icon: Icons.work_outline,
                            accentColor: const Color(0xFF3B82F6),
                            onTap1: () {
                              if (widget.onNavigateToJobs != null) {
                                widget.onNavigateToJobs!();
                              }
                            },
                            onTap2: () {
                              if (widget.onNavigateToJobs != null) {
                                widget.onNavigateToJobs!();
                              }
                            })),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildClickableKPICard(
                            title: "Total Workers",
                            value:
                                "${_dashboardMetrics?['total_workers'] ?? 0}",
                            icon: Icons.people_outline,
                            accentColor: const Color(0xFFF59E0B),
                            subtitle: "Registered",
                            onTap: () {
                              if (widget.onNavigateToTeam != null) {
                                widget.onNavigateToTeam!();
                              }
                            })),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _buildClickableKPICard(
                            title: "Pending Estimates",
                            value:
                                "${_dashboardMetrics?['pending_estimates'] ?? 0}",
                            icon: Icons.description_outlined,
                            accentColor: const Color(0xFF8B5CF6),
                            subtitle: "Action req.",
                            onTap: () {
                              if (widget.onNavigateToFinances != null) {
                                widget.onNavigateToFinances!();
                              }
                            })),
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
                          () { setState(() => _showOnlyToday = true); _fetchJobs(); },
                          () { setState(() => _showOnlyToday = false); _fetchJobs(); }),
                      _buildFilterPill(
                          _filterWorkerId != null
                              ? "👷 ${_filterWorkerName!}"
                              : "👷 By Worker",
                          _filterWorkerId != null,
                          _showWorkerFilterModal,
                          () { setState(() {
                                _filterWorkerId = null;
                                _filterWorkerName = null;
                              }); 
                              _fetchJobs();
                          }),
                      _buildFilterPill(
                          _filterCustomerName != null
                              ? "🏢 $_filterCustomerName"
                              : "🏢 By Customer",
                          _filterCustomerName != null,
                          _showCustomerFilterModal,
                          () { setState(() {
                                _filterCustomerName = null;
                                _filterCustomerId = null;
                               });
                               _fetchJobs();
                          }),
                      _buildFilterPill(
                          _filterStatus != null
                              ? "📊 ${_filterStatus![0].toUpperCase()}${_filterStatus!.substring(1)}"
                              : "📊 By Status",
                          _filterStatus != null,
                          _showStatusFilterModal,
                          () { setState(() => _filterStatus = null); _fetchJobs(); }),
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
                        : Builder(
                            builder: (context) {
                              List docs = _allJobs;

                              // 🚀 ALERTA DE PENDIENTES (BANNER)
                              int pendingCount = docs
                                  .where((d) =>
                                      (d as Map<String, dynamic>)['status'] ==
                                      'pending')
                                  .length;

                              // 🚀 MOTOR DE FILTRADO EXACTO (AHORA EN EL BACKEND)
                              List<dynamic> filteredDocs = List.from(docs);

                              // 🚀 ORDENAMIENTO (PENDING HASTA ARRIBA SIEMPRE)
                              filteredDocs.sort((a, b) {
                                var dA = a as Map<String, dynamic>;
                                var dB = b as Map<String, dynamic>;
                                String statA = (dA['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                String statB = (dB['status'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                if (statA == 'pending' && statB != 'pending')
                                  return -1;
                                if (statA != 'pending' && statB == 'pending')
                                  return 1;
                                return 0;
                              });

                              return Column(
                                children: [
                                  if (pendingCount > 0 &&
                                      _filterStatus != 'pending') ...[
                                    GestureDetector(
                                        onTap: () {
                                          setState(() {
                                              _filterStatus = 'pending';
                                              _showOnlyToday = false;
                                          });
                                          _fetchJobs();
                                        },
                                        child: Container(
                                            width: double.infinity,
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFF59E0B)
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                    color:
                                                        const Color(0xFFF59E0B)
                                                            .withOpacity(0.5))),
                                            child: Row(children: [
                                              const Icon(
                                                  Icons.warning_amber_rounded,
                                                  color: Color(0xFFF59E0B)),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Text(
                                                      "You have $pendingCount job(s) awaiting approval!",
                                                      style: const TextStyle(
                                                          color:
                                                              Color(0xFFF59E0B),
                                                          fontWeight: FontWeight
                                                              .bold))),
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
                                            borderRadius:
                                                BorderRadius.circular(16)),
                                        child: const Center(
                                            child: Text(
                                                "No results found for this filter.",
                                                style: TextStyle(
                                                    color: Colors.white60))))
                                  else
                                    ...filteredDocs.map((doc) {
                                      var data = doc as Map<String, dynamic>;
                                      String status =
                                          (data['status'] ?? 'assigned')
                                              .toString()
                                              .toUpperCase();

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
                                        onTap: () => _showJobDetailsModal(
                                            data['id'].toString(), data),
                                        child: Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 12),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius:
                                                    BorderRadius.circular(16)),
                                            child: Row(
                                              children: [
                                                Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: BoxDecoration(
                                                        color: dotColor,
                                                        shape:
                                                            BoxShape.circle)),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                    child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    RichText(
                                                        text: TextSpan(
                                                            style:
                                                                const TextStyle(
                                                                    fontSize:
                                                                        14),
                                                            children: [
                                                          TextSpan(
                                                              text:
                                                                  "${data['customer_name'] ?? 'Unknown Customer'} ",
                                                              style: const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          TextSpan(
                                                              text: "($status)",
                                                              style: TextStyle(
                                                                  color:
                                                                      dotColor,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 11))
                                                        ])),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        data['address'] ??
                                                            'No address provided',
                                                        style: const TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 12),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis)
                                                  ],
                                                )),
                                                const Icon(Icons.chevron_right,
                                                    color: Colors.white24,
                                                    size: 20)
                                              ],
                                            )),
                                      );
                                    }).toList(),
                                  if (_isFetchingMore)
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 20),
                                      child: Center(child: CircularProgressIndicator()),
                                    )
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

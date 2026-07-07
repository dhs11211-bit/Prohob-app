// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../auth/laravel_auth_manager.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../backend/api_service.dart';
import '/components/global_chat_modal.dart';

class CustomSchedule extends StatefulWidget {
  const CustomSchedule({Key? key, this.width, this.height}) : super(key: key);
  final double? width;
  final double? height;
  @override
  State<CustomSchedule> createState() => _CustomScheduleState();
}

class _CustomScheduleState extends State<CustomSchedule> {
  late DateTime _selectedDate;
  String _currentView = 'Week';
  late ScrollController _scrollController;
  late PageController _monthPageController;

  List<dynamic> _allJobs = [];
  bool _isLoadingJobs = true;

  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color holidayPurple = const Color(0xFFA855F7);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentRed = const Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _scrollController = ScrollController(initialScrollOffset: 60 * 65.0);
    _monthPageController = PageController(initialPage: 1200);
    _fetchJobs();
  }

  Future<void> _fetchJobs() async {
    if (mounted) setState(() => _isLoadingJobs = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final jobs = await ApiService.instance.getMyJobs(startDate: dateStr, endDate: dateStr);
      if (mounted) {
        setState(() {
          _allJobs = jobs;
          _isLoadingJobs = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingJobs = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading schedule: $e')));
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _monthPageController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getAllHolidays(int year) {
    List<Map<String, dynamic>> hols = [
      {
        'name': 'New Year\'s Day',
        'date': DateTime(year, 1, 1),
        'icon': Icons.celebration,
        'desc': 'Start of the new year.'
      },
      {
        'name': 'Independence Day',
        'date': DateTime(year, 7, 4),
        'icon': Icons.flag,
        'desc': 'Celebrating Independence.'
      },
      {
        'name': 'Veterans Day',
        'date': DateTime(year, 11, 11),
        'icon': Icons.military_tech,
        'desc': 'Honoring veterans.'
      },
      {
        'name': 'Christmas Day',
        'date': DateTime(year, 12, 25),
        'icon': Icons.park,
        'desc': 'Christmas holiday.'
      },
      {
        'name': 'Juneteenth',
        'date': DateTime(year, 6, 19),
        'icon': Icons.diversity_3,
        'desc': 'Commemorating the end of slavery.'
      },
    ];
    DateTime memorialDay = DateTime(year, 5, 31);
    while (memorialDay.weekday != DateTime.monday) {
      memorialDay = memorialDay.subtract(const Duration(days: 1));
    }
    hols.add({
      'name': 'Memorial Day',
      'date': memorialDay,
      'icon': Icons.local_florist,
      'desc': 'Honoring those who died.'
    });

    DateTime laborDay = DateTime(year, 9, 1);
    while (laborDay.weekday != DateTime.monday) {
      laborDay = laborDay.add(const Duration(days: 1));
    }
    hols.add({
      'name': 'Labor Day',
      'date': laborDay,
      'icon': Icons.engineering,
      'desc': 'Honoring the labor movement.'
    });

    DateTime thanksgiving = DateTime(year, 11, 1);
    while (thanksgiving.weekday != DateTime.thursday) {
      thanksgiving = thanksgiving.add(const Duration(days: 1));
    }
    thanksgiving = thanksgiving.add(const Duration(days: 21));
    hols.add({
      'name': 'Thanksgiving',
      'date': thanksgiving,
      'icon': Icons.restaurant,
      'desc': 'Day of giving thanks.'
    });

    hols.sort((a, b) => a['date'].compareTo(b['date']));
    return hols;
  }

  bool _isHoliday(DateTime date) {
    return _getAllHolidays(date.year)
        .any((h) => h['date'].month == date.month && h['date'].day == date.day);
  }

  List<dynamic> _getJobsForDate(
      List<dynamic> allJobs, DateTime date) {
    return allJobs.where((job) {
      final data = job as Map<String, dynamic>;
      if (data['scheduled_time'] == null) return false;

      DateTime jobDate;
      if (data['scheduled_time'] is String) {
        jobDate = DateTime.parse(data['scheduled_time']).toLocal();
      } else {
        try {
          jobDate = DateTime.parse(data['scheduled_time'].toString()).toLocal();
        } catch (e) {
          return false;
        }
      }

      return jobDate.year == date.year &&
          jobDate.month == date.month &&
          jobDate.day == date.day;
    }).toList();
  }

  Map<String, dynamic>? get _selectedDateHoliday {
    try {
      return _getAllHolidays(_selectedDate.year).firstWhere((h) =>
          h['date'].year == _selectedDate.year &&
          h['date'].month == _selectedDate.month &&
          h['date'].day == _selectedDate.day);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic>? get _nextUpcomingHoliday {
    final target =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final allHols = [
      ..._getAllHolidays(target.year),
      ..._getAllHolidays(target.year + 1)
    ];
    allHols.sort((a, b) => a['date'].compareTo(b['date']));
    try {
      return allHols.firstWhere((h) => h['date'].isAfter(target));
    } catch (e) {
      return null;
    }
  }

  int _daysUntil(DateTime target) {
    final current =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return DateTime(target.year, target.month, target.day)
        .difference(current)
        .inDays;
  }

  Future<void> _launchExternalMaps(
      double? lat, double? lng, String address) async {
    try {
      final String query = (lat != null && lng != null)
          ? '$lat,$lng'
          : Uri.encodeComponent(address);
      final Uri url =
          Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  // Lógica del Chat
  Future<void> _startJobChat(
      String jobId, Map<String, dynamic> jobData, DateTime jobTime) async {
    String clientName = jobData['client_name'] ?? 'Unknown Client';
    String jobName = "$clientName - ${jobData['job_type'] ?? 'Job'}";
    List<dynamic> workers = jobData['assigned_users'] ?? jobData['assigned_workers'] ?? [];

    List<String> workerIds = workers.map((w) {
      if (w is Map) return w['id']?.toString() ?? '';
      return w.toString();
    }).where((id) => id.isNotEmpty).toList();

    await GlobalChatModal.openGroupChat(
      context,
      jobId: jobId,
      jobName: jobName,
      workerIds: workerIds,
    );
  }

  void _openJobDetailsModal(String jobId, Map<String, dynamic> jobData,
      String timeLabel, DateTime jobTime) {
    List<dynamic> tasks = jobData['tasks'] ?? [];
    String clientName =
        jobData['client_name'] ?? jobData['job_type'] ?? 'Scheduled Clean';
    String jobType = jobData['job_type'] ?? 'Cleaning Service';
    String address = jobData['address'] ?? 'No address set';
    String notes = jobData['notes'] ?? 'No special instructions provided.';
    List<dynamic> workers = jobData['assigned_workers'] ?? [];
    String leaderId = jobData['team_leader_id'] ?? '';
    final myUid = currentUser?.uid;

    double? lat = jobData['latitude'] != null
        ? (jobData['latitude'] as num).toDouble()
        : null;
    double? lng = jobData['longitude'] != null
        ? (jobData['longitude'] as num).toDouble()
        : null;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (c) => Container(
            height: MediaQuery.of(context).size.height * 0.90,
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24),
            decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: muted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.access_time_filled,
                              color: neonAction, size: 14),
                          const SizedBox(width: 6),
                          Text(timeLabel,
                              style: TextStyle(
                                  color: neonAction,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                        ]),
                        const SizedBox(height: 12),
                        Text(clientName,
                            style: TextStyle(
                                color: text,
                                fontSize: 26,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(jobType,
                            style: TextStyle(color: muted, fontSize: 14)),
                      ],
                    ),
                  ),
                  Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: accentBlue.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.business_center,
                          color: accentBlue, size: 24)),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LOCATION',
                          style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            Icon(Icons.location_on, color: muted, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(address,
                                    style: TextStyle(
                                        color: text,
                                        fontSize: 15,
                                        height: 1.3))),
                          ],
                        ),
                      ),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1, color: Colors.white10)),
                      Text('SPECIAL INSTRUCTIONS / CODES',
                          style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: card,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.orange.withOpacity(0.3))),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline,
                                color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(notes,
                                    style: TextStyle(
                                        color: text,
                                        fontSize: 14,
                                        height: 1.4))),
                          ],
                        ),
                      ),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1, color: Colors.white10)),
                      Text('TASK CHECKLIST',
                          style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      if (tasks.isEmpty)
                        Text('No specific tasks assigned.',
                            style: TextStyle(color: muted, fontSize: 14))
                      else
                        ...tasks.map((t) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: card,
                                borderRadius: BorderRadius.circular(12)),
                            child: Row(children: [
                              Icon(Icons.check_circle_outline,
                                  color: accentBlue, size: 20),
                              const SizedBox(width: 12),
                              Text(t.toString(),
                                  style: TextStyle(
                                      color: text,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500))
                            ]))),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Divider(height: 1, color: Colors.white10)),
                      Text('ASSIGNED TEAM',
                          style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      if (workers.isEmpty)
                        Text('No workers assigned yet.',
                            style: TextStyle(color: muted))
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: workers.map((workerId) {
                            bool isMe = workerId == myUid;
                            bool isLeader = workerId == leaderId;
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: isMe
                                      ? accentBlue.withOpacity(0.15)
                                      : card,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: isLeader
                                          ? const Color(0xFFF59E0B)
                                          : (isMe
                                              ? accentBlue
                                              : Colors.white10))),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(isLeader ? Icons.star : Icons.person,
                                      color: isLeader
                                          ? const Color(0xFFF59E0B)
                                          : (isMe ? accentBlue : muted),
                                      size: 14),
                                  const SizedBox(width: 6),
                                  Text(isMe ? 'You' : 'Crew Member',
                                      style: TextStyle(
                                          color: isMe ? Colors.white : text,
                                          fontSize: 13,
                                          fontWeight: isMe
                                              ? FontWeight.bold
                                              : FontWeight.normal))
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: card,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                    color: accentBlue.withOpacity(0.5)))),
                        icon:
                            Icon(Icons.navigation, color: accentBlue, size: 18),
                        label: Text('MAPS',
                            style: TextStyle(
                                color: accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        onPressed: () => _launchExternalMaps(lat, lng, address),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 55,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: neonAction,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          icon: const Icon(Icons.chat_bubble,
                              color: Colors.black, size: 18),
                          label: const Text('CHAT',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          onPressed: () {
                            Navigator.pop(context);
                            _startJobChat(jobId, jobData, jobTime);
                          }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30)
            ])));
  }

  // Modales de Time Off
  void _openTimeOffModal() {
    DateTime _pickerMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    DateTime? _startDate;
    DateTime? _endDate;
    String _reason = 'Vacation';
    TextEditingController _notesCtrl = TextEditingController();
    bool _isSubmitting = false;

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (c) => StatefulBuilder(builder: (context, setModal) {
              int daysInMonth =
                  DateTime(_pickerMonth.year, _pickerMonth.month + 1, 0).day;
              int offset =
                  DateTime(_pickerMonth.year, _pickerMonth.month, 1).weekday %
                      7;
              DateTime today = DateTime(DateTime.now().year,
                  DateTime.now().month, DateTime.now().day);

              return Container(
                  height: MediaQuery.of(context).size.height * 0.90,
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 24,
                      right: 24,
                      top: 24),
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                    color: muted.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(10)))),
                        const SizedBox(height: 24),
                        Text('Request Time Off',
                            style: TextStyle(
                                color: text,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),
                        Expanded(
                            child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                              color: card,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: Colors.white10)),
                                          child: Column(children: [
                                            Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons.chevron_left,
                                                          color: text),
                                                      onPressed: () => setModal(
                                                          () => _pickerMonth =
                                                              DateTime(
                                                                  _pickerMonth
                                                                      .year,
                                                                  _pickerMonth
                                                                          .month -
                                                                      1,
                                                                  1))),
                                                  Text(
                                                      DateFormat('MMMM yyyy')
                                                          .format(_pickerMonth),
                                                      style: TextStyle(
                                                          color: text,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                  IconButton(
                                                      icon: Icon(
                                                          Icons.chevron_right,
                                                          color: text),
                                                      onPressed: () => setModal(
                                                          () => _pickerMonth =
                                                              DateTime(
                                                                  _pickerMonth
                                                                      .year,
                                                                  _pickerMonth
                                                                          .month +
                                                                      1,
                                                                  1))),
                                                ]),
                                            const SizedBox(height: 16),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceAround,
                                              children: [
                                                'S',
                                                'M',
                                                'T',
                                                'W',
                                                'T',
                                                'F',
                                                'S'
                                              ]
                                                  .map((day) => SizedBox(
                                                      width: 30,
                                                      child: Center(
                                                          child: Text(day,
                                                              style: TextStyle(
                                                                  color: muted,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)))))
                                                  .toList(),
                                            ),
                                            const SizedBox(height: 12),
                                            GridView.builder(
                                                shrinkWrap: true,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                gridDelegate:
                                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                                        crossAxisCount: 7,
                                                        mainAxisSpacing: 8,
                                                        crossAxisSpacing: 0,
                                                        childAspectRatio: 1.0),
                                                itemCount: daysInMonth + offset,
                                                itemBuilder: (ctx, i) {
                                                  if (i < offset)
                                                    return const SizedBox();
                                                  int day = i - offset + 1;
                                                  DateTime cellDate = DateTime(
                                                      _pickerMonth.year,
                                                      _pickerMonth.month,
                                                      day);
                                                  bool isPast =
                                                      cellDate.isBefore(today);

                                                  bool isStart = _startDate !=
                                                          null &&
                                                      cellDate.isAtSameMomentAs(
                                                          _startDate!);
                                                  bool isEnd = _endDate !=
                                                          null &&
                                                      cellDate.isAtSameMomentAs(
                                                          _endDate!);
                                                  bool inRange = _startDate !=
                                                          null &&
                                                      _endDate != null &&
                                                      cellDate.isAfter(
                                                          _startDate!) &&
                                                      cellDate
                                                          .isBefore(_endDate!);

                                                  Color bgColor =
                                                      Colors.transparent;
                                                  Color txtColor = text;

                                                  if (isPast) {
                                                    txtColor =
                                                        muted.withOpacity(0.3);
                                                  } else if (isStart || isEnd) {
                                                    bgColor = accentBlue;
                                                    txtColor = Colors.white;
                                                  } else if (inRange) {
                                                    bgColor = accentBlue
                                                        .withOpacity(0.2);
                                                    txtColor = accentBlue;
                                                  }

                                                  return GestureDetector(
                                                      onTap: () {
                                                        if (isPast) return;
                                                        setModal(() {
                                                          if (_startDate ==
                                                              null) {
                                                            _startDate =
                                                                cellDate;
                                                          } else if (_endDate ==
                                                              null) {
                                                            if (cellDate.isBefore(
                                                                _startDate!)) {
                                                              _startDate =
                                                                  cellDate;
                                                            } else {
                                                              _endDate =
                                                                  cellDate;
                                                            }
                                                          } else {
                                                            _startDate =
                                                                cellDate;
                                                            _endDate = null;
                                                          }
                                                        });
                                                      },
                                                      child: Container(
                                                          decoration:
                                                              BoxDecoration(
                                                                  color:
                                                                      bgColor,
                                                                  shape:
                                                                      BoxShape
                                                                          .circle),
                                                          child: Center(
                                                              child: Text(
                                                                  '$day',
                                                                  style: TextStyle(
                                                                      color:
                                                                          txtColor,
                                                                      fontWeight: (isStart ||
                                                                              isEnd)
                                                                          ? FontWeight
                                                                              .bold
                                                                          : FontWeight
                                                                              .normal)))));
                                                })
                                          ])),
                                      if (_startDate != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                              top: 16, bottom: 8),
                                          child: Center(
                                            child: Text(
                                              _endDate == null ||
                                                      _startDate == _endDate
                                                  ? 'Selected: ${DateFormat('MMM d, yyyy').format(_startDate!)}'
                                                  : 'Selected: ${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d, yyyy').format(_endDate!)}',
                                              style: TextStyle(
                                                  color: neonAction,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 24),
                                      Text('Reason',
                                          style: TextStyle(
                                              color: muted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16),
                                          decoration: BoxDecoration(
                                              color: card,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: Colors.white10)),
                                          child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                  value: _reason,
                                                  dropdownColor: card,
                                                  isExpanded: true,
                                                  style: TextStyle(
                                                      color: text,
                                                      fontSize: 16),
                                                  items: [
                                                    'Vacation',
                                                    'Sick Leave',
                                                    'Family Emergency',
                                                    'Personal Errand',
                                                    'Other'
                                                  ]
                                                      .map((s) =>
                                                          DropdownMenuItem(
                                                              value: s,
                                                              child: Text(s)))
                                                      .toList(),
                                                  onChanged: (v) => setModal(
                                                      () => _reason = v!)))),
                                      const SizedBox(height: 24),
                                      Text('Additional Notes (Optional)',
                                          style: TextStyle(
                                              color: muted,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 12),
                                      TextField(
                                          controller: _notesCtrl,
                                          maxLines: 3,
                                          style: TextStyle(color: text),
                                          decoration: InputDecoration(
                                              filled: true,
                                              fillColor: card,
                                              hintText:
                                                  'Going out of town, doctor appointment...',
                                              hintStyle: TextStyle(
                                                  color:
                                                      muted.withOpacity(0.5)),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                  borderSide:
                                                      BorderSide.none))),
                                      const SizedBox(height: 40),
                                    ]))),
                        SizedBox(
                            width: double.infinity,
                            height: 55,
                            child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: accentBlue,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16))),
                                onPressed: _isSubmitting
                                    ? null
                                    : () async {
                                        if (_startDate == null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Please select at least one date.'),
                                                  backgroundColor:
                                                      Colors.redAccent));
                                          return;
                                        }
                                        setModal(() => _isSubmitting = true);
                                        try {
                                          final user = currentUser;
                                          if (user != null) {
                                            String typeStr = 'other';
                                            if (_reason == 'Vacation') typeStr = 'vacation';
                                            if (_reason == 'Sick Leave') typeStr = 'sick';
                                            if (_reason == 'Family Emergency' || _reason == 'Personal Errand') typeStr = 'personal';
                                            
                                            await ApiService.instance.post('/time-off', {
                                              'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
                                              'end_date': DateFormat('yyyy-MM-dd').format(_endDate ?? _startDate!),
                                              'reason': _reason + (_notesCtrl.text.trim().isNotEmpty ? ' - ' + _notesCtrl.text.trim() : ''),
                                              'type': typeStr,
                                              'all_day': true,
                                            });
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Time Off request sent to Admin!'),
                                                    backgroundColor:
                                                        Colors.green));
                                          }
                                        } catch (e) {
                                          setModal(() => _isSubmitting = false);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor:
                                                      Colors.redAccent));
                                        }
                                      },
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Text('SUBMIT REQUEST',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)))),
                        const SizedBox(height: 30)
                      ]));
            }));
  }

  void _openAllHolidaysModal() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final allHols = _getAllHolidays(now.year);
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (c) => Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                          color: muted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('US National Holidays',
                      style: TextStyle(
                          color: text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold))),
              const SizedBox(height: 4),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('${DateTime.now().year} Calendar',
                      style: TextStyle(color: muted, fontSize: 14))),
              const SizedBox(height: 20),
              Expanded(
                  child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: allHols.length,
                      itemBuilder: (ctx, i) {
                        var h = allHols[i];
                        bool isPassed = h['date'].isBefore(today);
                        Color itemColor =
                            isPassed ? Colors.grey.shade700 : holidayPurple;
                        Color textColor =
                            isPassed ? Colors.grey.shade600 : text;
                        Color subTextColor =
                            isPassed ? Colors.grey.shade700 : muted;
                        Color iconBg = isPassed
                            ? Colors.transparent
                            : holidayPurple.withOpacity(0.1);
                        Color borderC = isPassed
                            ? Colors.grey.shade800.withOpacity(0.5)
                            : holidayPurple.withOpacity(0.3);
                        return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: isPassed ? Colors.transparent : card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderC)),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                      color: iconBg, shape: BoxShape.circle),
                                  child: Icon(h['icon'],
                                      color: itemColor, size: 24)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(h['name'],
                                        style: TextStyle(
                                            color: textColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(h['desc'],
                                        style: TextStyle(
                                            color: subTextColor, fontSize: 12))
                                  ])),
                              const SizedBox(width: 12),
                              Text(DateFormat('MMM d').format(h['date']),
                                  style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold))
                            ]));
                      }))
            ])));
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ ESCUDO ANTI-CRASH: Si no hay usuario o cargando, espera tranquilo.
    if (_isLoadingJobs) {
      return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? double.infinity,
        color: bg,
        child: Center(
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          CircularProgressIndicator(color: accentBlue),
          const SizedBox(height: 16),
          Text("Loading schedule...", style: TextStyle(color: muted))
        ])),
      );
    }

    String todayString = DateFormat('MMM d').format(DateTime.now());
    var currentHol = _selectedDateHoliday;
    var nextHol = _nextUpcomingHoliday;
    String cardTitle = 'National Holidays';
    String cardSub = 'Tap to view all dates';
    IconData cardIcon = Icons.star;

    if (currentHol != null) {
      cardTitle = currentHol['name'];
      cardSub = "Today is ${currentHol['name']}!";
      cardIcon = currentHol['icon'];
    } else if (nextHol != null) {
      int d = _daysUntil(nextHol['date']);
      cardTitle = 'Next: ${nextHol['name']}';
      cardSub = d == 0 ? 'Today!' : (d == 1 ? 'Tomorrow' : 'In $d days');
      cardIcon = nextHol['icon'];
    }

    List<dynamic> jobsForSelectedDate = _getJobsForDate(_allJobs, _selectedDate);

    return Container(
            color: bg,
            width: widget.width ?? double.infinity,
            height: MediaQuery.of(context).size.height,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              child: Padding(
                padding: const EdgeInsets.only(top: 130, bottom: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Schedule',
                            style: TextStyle(
                                color: text,
                                fontSize: 24,
                                fontWeight: FontWeight.bold))),
                    const SizedBox(height: 20),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _currentView =
                                    _currentView == 'Week' ? 'Month' : 'Week'),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: card,
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    child: Row(children: [
                                      Text(
                                          DateFormat('MMMM yyyy')
                                              .format(_selectedDate),
                                          style: TextStyle(
                                              color: text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 8),
                                      Icon(
                                          _currentView == 'Week'
                                              ? Icons.calendar_view_week
                                              : Icons.calendar_month,
                                          color: muted,
                                          size: 18)
                                    ])),
                              ),
                              GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedDate = DateTime.now();
                                    });
                                    _fetchJobs();
                                    if (_currentView == 'Week')
                                      _scrollController.animateTo(60 * 65.0,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                    if (_currentView == 'Month')
                                      _monthPageController.animateToPage(1200,
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut);
                                  },
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: accentBlue.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color:
                                                  accentBlue.withOpacity(0.3))),
                                      child: Row(children: [
                                        Icon(Icons.today,
                                            color: accentBlue, size: 16),
                                        const SizedBox(width: 6),
                                        Text('Today, $todayString',
                                            style: TextStyle(
                                                color: accentBlue,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold))
                                      ])))
                            ])),
                    const SizedBox(height: 16),
                    AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _currentView == 'Week'
                            ? _buildFluidWeeklyStrip(_allJobs)
                            : _buildFluidMonthGrid(_allJobs)),
                    const SizedBox(height: 32),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  DateFormat('EEEE, MMM d')
                                      .format(_selectedDate),
                                  style: TextStyle(
                                      color: text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              GestureDetector(
                                  onTap: _openTimeOffModal,
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: card,
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Text('+ Request time off',
                                          style: TextStyle(
                                              color: muted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold))))
                            ])),
                    const SizedBox(height: 16),
                    if (jobsForSelectedDate.isNotEmpty)
                      ...jobsForSelectedDate.map((job) {
                        final data = job as Map<String, dynamic>;
                        DateTime jobTime;
                        if (data['scheduled_time'] is String) {
                          jobTime =
                              DateTime.parse(data['scheduled_time']);
                        } else {
                          try {
                            jobTime = DateTime.parse(data['scheduled_time']);
                          } catch (e) {
                            jobTime = DateTime.now();
                          }
                        }
                        String timeStr = "Time not set";
                        if (data['scheduled_time'] != null) {
                          try {
                            DateTime parsedTime = DateTime.parse(data['scheduled_time'].toString().trim()).toLocal();
                            String startStr = DateFormat.jm().format(parsedTime);
                            timeStr = startStr;
                            
                            if (data['start_time'] != null && data['start_time'].toString().trim().isNotEmpty) {
                               try {
                                 DateTime startParsed = DateTime.parse("1970-01-01 " + data['start_time'].toString().trim());
                                 startStr = DateFormat.jm().format(startParsed);
                                 timeStr = startStr;
                               } catch (e) {}
                            }
                            
                            if (data['end_time'] != null && data['end_time'].toString().trim().isNotEmpty) {
                               try {
                                 DateTime endParsed = DateTime.parse("1970-01-01 " + data['end_time'].toString().trim());
                                 String endStr = DateFormat.jm().format(endParsed);
                                 timeStr = "$startStr - $endStr";
                               } catch (e) {}
                            }
                          } catch (e) {}
                        }

                        String status = (data['job_status'] ?? 'SCHEDULED').toString().toUpperCase();
                        Color statusColor = const Color(0xFF3B82F6);
                        if (status == 'ACTIVE' || status == 'IN PROGRESS') statusColor = const Color(0xFF10B981);
                        if (status == 'PENDING' || status == 'DRAFT') statusColor = const Color(0xFFF59E0B);
                        if (status == 'COMPLETED') statusColor = const Color(0xFF8B5CF6);

                        final addr = data['address'] ?? 'No address provided';
                        final clientName = data['client_name'] ??
                            data['job_type'] ??
                            'Scheduled Job';
                        final title = data['title'] ?? 'Job Title';

                        return GestureDetector(
                          onTap: () =>
                              _openJobDetailsModal(data['id'].toString(), data, timeStr, jobTime),
                          child: Container(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: card,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4))
                                  ]),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                Expanded(
                                    flex: 3,
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(title,
                                          style: TextStyle(
                                              color: text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(clientName,
                                          style: TextStyle(
                                              color: text.withOpacity(0.9),
                                              fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(children: [
                                        Icon(Icons.location_on,
                                            color: muted, size: 12),
                                        const SizedBox(width: 4),
                                        Expanded(
                                            child: Text(addr,
                                                style: TextStyle(
                                                    color: muted, fontSize: 12),
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                      ])
                                    ])),
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.access_time, size: 14, color: Colors.white54),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          timeStr,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: statusColor.withOpacity(0.3))),
                                      child: Text(
                                        status,
                                        style: TextStyle(
                                            color: statusColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: bg, shape: BoxShape.circle),
                                    child: Icon(Icons.chevron_right,
                                        color: muted, size: 20))
                              ])),
                        );
                      }).toList()
                    else
                      Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 30),
                          child: Center(
                              child: Text('No shifts scheduled for this day.',
                                  style: TextStyle(color: muted)))),
                    GestureDetector(
                      onTap: _openAllHolidaysModal,
                      child: Container(
                          margin: const EdgeInsets.all(24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: holidayPurple.withOpacity(0.3))),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(children: [
                                  Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                          color: holidayPurple.withOpacity(0.1),
                                          shape: BoxShape.circle),
                                      child: Icon(cardIcon,
                                          color: holidayPurple, size: 24)),
                                  const SizedBox(width: 16),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(cardTitle,
                                            style: TextStyle(
                                                color: text,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        Text(cardSub,
                                            style: TextStyle(
                                                color: muted, fontSize: 12))
                                      ])
                                ]),
                                Icon(Icons.arrow_forward_ios,
                                    color: muted, size: 16)
                              ])),
                    )
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildFluidWeeklyStrip(List<dynamic> allJobs) {
    DateTime baseDate = DateTime.now().subtract(const Duration(days: 60));
    return SizedBox(
        height: 90,
        child: ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 120,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemBuilder: (context, index) {
              DateTime d = baseDate.add(Duration(days: index));
              bool sel = d.day == _selectedDate.day &&
                  d.month == _selectedDate.month &&
                  d.year == _selectedDate.year;
              bool hs = _getJobsForDate(allJobs, d).isNotEmpty;
              bool isHol = _isHoliday(d);
              return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDate = d);
                    _fetchJobs();
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 55,
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                          color: sel ? accentBlue : card,
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(DateFormat('EEE').format(d).toUpperCase(),
                                style: TextStyle(
                                    color: sel ? Colors.white : muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Text('${d.day}',
                                style: TextStyle(
                                    color: sel ? Colors.white : text,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (hs)
                                    CircleAvatar(
                                        radius: 3,
                                        backgroundColor:
                                            sel ? Colors.white : neonAction),
                                  if (hs && isHol) const SizedBox(width: 2),
                                  if (isHol)
                                    CircleAvatar(
                                        radius: 3,
                                        backgroundColor: sel
                                            ? Colors.white70
                                            : holidayPurple)
                                ])
                          ])));
            }));
  }

  Widget _buildFluidMonthGrid(List<dynamic> allJobs) {
    return SizedBox(
        height: 350,
        child: PageView.builder(
            controller: _monthPageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              int offset = index - 1200;
              setState(() => _selectedDate = DateTime(
                  DateTime.now().year, DateTime.now().month + offset, 1));
              _fetchJobs();
            },
            itemBuilder: (context, index) {
              int offset = index - 1200;
              DateTime mDate = DateTime(
                  DateTime.now().year, DateTime.now().month + offset, 1);
              final dIM = DateTime(mDate.year, mDate.month + 1, 0).day;
              final sW = DateTime(mDate.year, mDate.month, 1).weekday % 7;
              return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: card, borderRadius: BorderRadius.circular(20)),
                      child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 7,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8),
                          itemCount: dIM + sW,
                          itemBuilder: (c, i) {
                            if (i < sW) return const SizedBox();
                            int d = i - sW + 1;
                            DateTime cellDate =
                                DateTime(mDate.year, mDate.month, d);
                            bool sel = d == _selectedDate.day &&
                                cellDate.month == _selectedDate.month &&
                                cellDate.year == _selectedDate.year;
                            bool hs =
                                _getJobsForDate(allJobs, cellDate).isNotEmpty;
                            bool isHol = _isHoliday(cellDate);
                            return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedDate = cellDate);
                                    _fetchJobs();
                                  },
                                child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    decoration: BoxDecoration(
                                        color: sel
                                            ? accentBlue
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text('$d',
                                              style: TextStyle(
                                                  color:
                                                      sel ? Colors.white : text,
                                                  fontWeight: sel
                                                      ? FontWeight.bold
                                                      : FontWeight.normal)),
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                if (hs)
                                                  Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 2.0),
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                          color: sel
                                                              ? Colors.white
                                                              : neonAction,
                                                          shape:
                                                              BoxShape.circle)),
                                                if (hs && isHol)
                                                  const SizedBox(width: 2),
                                                if (isHol)
                                                  Container(
                                                      margin:
                                                          const EdgeInsets.only(
                                                              top: 2.0),
                                                      width: 4,
                                                      height: 4,
                                                      decoration: BoxDecoration(
                                                          color: sel
                                                              ? Colors.white70
                                                              : holidayPurple,
                                                          shape:
                                                              BoxShape.circle))
                                              ])
                                        ])));
                          })));
            }));
  }
}

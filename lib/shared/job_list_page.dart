import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';
import 'job_card.dart';
import 'job_detail_screen.dart';
import 'job_parser.dart';

class SharedJobListPage extends StatefulWidget {
  const SharedJobListPage({
    Key? key,
    this.showWorkerFilter = false,
  }) : super(key: key);

  final bool showWorkerFilter;

  @override
  State<SharedJobListPage> createState() => _SharedJobListPageState();
}

class _SharedJobListPageState extends State<SharedJobListPage> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  List<dynamic> _allJobs = [];
  bool _isLoading = true;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  final ScrollController _listScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _listScrollController.addListener(_onScroll);
    _fetchJobs(reset: true);
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_listScrollController.hasClients) return;
    final pos = _listScrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200 && !_isLoadingMore && _hasMore) {
      _fetchJobs(loadMore: true);
    }
  }

  Future<void> _fetchJobs({bool reset = false, bool loadMore = false}) async {
    if (reset) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
      });
    } else if (loadMore) {
      if (!_hasMore || _isLoadingMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay);
      final res = await ApiService.instance.get(
        '/jobs',
        queryParams: {
          'date': dateStr,
          'limit': 15,
          'page': _currentPage,
        },
      );

      final newItems = (res is Map && res['data'] is List)
          ? (res['data'] as List)
          : (res is List ? res : []);

      if (mounted) {
        setState(() {
          if (reset) {
            _allJobs = newItems;
          } else {
            _allJobs.addAll(newItems);
          }
          _hasMore = newItems.length >= 15;
          if (_hasMore) _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<dynamic> _getJobsForDate(List<dynamic> jobs, DateTime date) {
    return jobs.where((job) {
      final data = job as Map<String, dynamic>;
      DateTime? d = JobParser.getStartDate(data);
      if (d == null) return false;
      return d.year == date.year && d.month == date.month && d.day == date.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _fetchJobs(reset: true),
      color: accentBlue,
      child: Container(
        color: bg,
        child: SingleChildScrollView(
          controller: _listScrollController,
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Calendar Card Container (Screenshot 2 Design)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Card Top Row: < | Month Year v | Today | Week / Month | >
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              if (_calendarFormat == CalendarFormat.week) {
                                _focusedDay = _focusedDay.subtract(const Duration(days: 7));
                                _selectedDay = _focusedDay;
                              } else {
                                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1, 1);
                                _selectedDay = _focusedDay;
                              }
                            });
                            _fetchJobs(reset: true);
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDay,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFF3B82F6),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1E293B),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDay = picked;
                                _focusedDay = picked;
                              });
                              _fetchJobs(reset: true);
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                DateFormat('MMMM yyyy').format(_focusedDay),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () {
                                setState(() {
                                  _selectedDay = DateTime.now();
                                  _focusedDay = DateTime.now();
                                });
                                _fetchJobs(reset: true);
                              },
                              child: Text(
                                "Today",
                                style: TextStyle(color: accentBlue, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _calendarFormat = _calendarFormat == CalendarFormat.week
                                      ? CalendarFormat.month
                                      : CalendarFormat.week;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white12,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _calendarFormat == CalendarFormat.week ? 'Month' : 'Week',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            setState(() {
                              if (_calendarFormat == CalendarFormat.week) {
                                _focusedDay = _focusedDay.add(const Duration(days: 7));
                                _selectedDay = _focusedDay;
                              } else {
                                _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1, 1);
                                _selectedDay = _focusedDay;
                              }
                            });
                            _fetchJobs(reset: true);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // TableCalendar Body
                    TableCalendar(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                        _fetchJobs(reset: true);
                      },
                      onPageChanged: (focusedDay) {
                        setState(() {
                          _focusedDay = focusedDay;
                        });
                      },
                      headerVisible: false,
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                        weekendStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      calendarStyle: const CalendarStyle(
                        defaultTextStyle: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                        weekendTextStyle: TextStyle(color: Colors.white70, fontSize: 14),
                        outsideDaysVisible: false,
                        selectedDecoration: BoxDecoration(
                          color: Color(0xFF3B82F6),
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: Color(0x403B82F6),
                          shape: BoxShape.circle,
                        ),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          bool hasJobs = _getJobsForDate(_allJobs, day).isNotEmpty;
                          if (hasJobs) {
                            return Positioned(
                              bottom: 2,
                              child: Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: neonAction,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            );
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Date-Grouped Jobs List
              if (_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: accentBlue)),
                )
              else if (_allJobs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Center(
                    child: Text('No shifts scheduled.', style: TextStyle(color: muted, fontSize: 14)),
                  ),
                )
              else
                ...(() {
                  List<Widget> widgets = [];
                  String? lastDateStr;
                  for (var job in _allJobs) {
                    final data = job as Map<String, dynamic>;
                    DateTime jobTime = JobParser.getStartDate(data) ?? DateTime.now();

                    String currentDateStr = DateFormat('EEEE, MMM d, yyyy').format(jobTime);
                    if (lastDateStr != currentDateStr) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                currentDateStr,
                                style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              if (lastDateStr == null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                    '+ Request time off',
                                    style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                      lastDateStr = currentDateStr;
                    }

                    widgets.add(
                      SharedJobCard(
                        jobData: data,
                        onTap: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => SharedJobDetailScreen(jobId: data['id']),
                            ),
                          );
                          if (result == true) {
                            _fetchJobs(reset: true);
                          }
                        },
                      ),
                    );
                  }

                  if (_isLoadingMore) {
                    widgets.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(child: CircularProgressIndicator(color: accentBlue)),
                      ),
                    );
                  }

                  return widgets;
                })(),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '../shared/index.dart' as shared;
import 'task_detail_screen.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({Key? key}) : super(key: key);

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  // Theme palette
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color cardBorder = const Color(0xFF334155);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color textWhite = Colors.white;
  final Color textMuted = const Color(0xFF94A3B8);
  final Color successGreen = const Color(0xFF10B981);
  final Color urgentRed = const Color(0xFFEF4444);
  final Color warningAmber = const Color(0xFFF59E0B);
  final Color purple = const Color(0xFF8B5CF6);

  bool _isLoading = true;
  List<dynamic> _tasks = [];
  Map<String, dynamic> _stats = {
    'total': 0,
    'my_tasks': 0,
    'due_today': 0,
    'overdue': 0,
    'completed': 0,
    'pending': 0,
  };

  String _scope = 'all'; // 'all' or 'my_tasks'
  String _statusFilter = 'all'; // 'all', 'pending', 'today', 'overdue', 'completed'
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Options cached for creation modal
  List<dynamic> _staffOptions = [];
  List<dynamic> _jobOptions = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchOptions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final res = await ApiService.instance.getTaskOptions();
      final data = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      if (mounted) {
        setState(() {
          _staffOptions = data['staff'] ?? [];
          _jobOptions = data['jobs'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{};
      if (_scope == 'my_tasks') {
        params['filter'] = 'my_tasks';
        params['assigned_to'] = 'me';
      }
      if (_statusFilter == 'today') {
        params['filter'] = 'today';
      } else if (_statusFilter == 'overdue') {
        params['filter'] = 'overdue';
      } else if (_statusFilter == 'completed') {
        params['filter'] = 'completed';
      } else if (_statusFilter == 'pending') {
        params['task_status'] = 'pending';
      }
      if (_searchQuery.trim().isNotEmpty) params['search'] = _searchQuery.trim();

      final tasksFuture = ApiService.instance.getTasks(params: params);
      final statsFuture = ApiService.instance.getTaskStats();

      final results = await Future.wait([tasksFuture, statsFuture]);

      final tasksRes = results[0];
      final statsRes = results[1];

      final tasksList = tasksRes['data'] is List
          ? tasksRes['data'] as List
          : (tasksRes['tasks'] is List ? tasksRes['tasks'] as List : []);
      final statsMap = statsRes['data'] is Map
          ? statsRes['data'] as Map
          : statsRes;

      if (mounted) {
        setState(() {
          _tasks = List.from(tasksList);
          _stats = {
            'total': statsMap['total'] ?? 0,
            'my_tasks': statsMap['my_tasks'] ?? 0,
            'due_today': statsMap['due_today'] ?? 0,
            'overdue': statsMap['overdue'] ?? 0,
            'completed': statsMap['completed'] ?? 0,
            'pending': statsMap['pending'] ?? 0,
          };
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: urgentRed,
            content: Text('Failed to load tasks: $e', style: TextStyle(color: textWhite)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _confirmToggleTaskStatus(Map<String, dynamic> task) async {
    final bool isCurrentlyCompleted = task['task_status'] == 'completed';
    final taskNumber = task['task_number'] ?? 'Task #${task['id']}';
    final title = task['title'] ?? taskNumber;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: (isCurrentlyCompleted ? warningAmber : successGreen).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isCurrentlyCompleted ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
                color: isCurrentlyCompleted ? warningAmber : successGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isCurrentlyCompleted ? 'Mark as Incomplete?' : 'Mark as Completed?',
                style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          isCurrentlyCompleted
              ? 'Are you sure you want to reopen "$title" and mark it as pending?'
              : 'Are you sure you want to mark "$title" as completed?',
          style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyCompleted ? warningAmber : successGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isCurrentlyCompleted ? 'Reopen Task' : 'Mark as Completed',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _toggleTaskStatus(task);
    }
  }

  Future<void> _toggleTaskStatus(Map<String, dynamic> task) async {
    final taskId = task['id'];
    final oldStatus = task['task_status'];
    final newStatus = oldStatus == 'completed' ? 'pending' : 'completed';

    // Optimistic UI update
    setState(() {
      task['task_status'] = newStatus;
    });

    try {
      final res = await ApiService.instance.toggleTask(taskId);
      final updated = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      setState(() {
        final idx = _tasks.indexWhere((t) => t['id'] == taskId);
        if (idx != -1 && updated is Map<String, dynamic>) {
          _tasks[idx] = updated;
        }
      });
      // Refresh stats quietly
      ApiService.instance.getTaskStats().then((sRes) {
        final sMap = sRes['data'] is Map ? sRes['data'] as Map : sRes;
        if (mounted) {
          setState(() {
            _stats = {
              'total': sMap['total'] ?? _stats['total'],
              'my_tasks': sMap['my_tasks'] ?? _stats['my_tasks'],
              'due_today': sMap['due_today'] ?? _stats['due_today'],
              'overdue': sMap['overdue'] ?? _stats['overdue'],
              'completed': sMap['completed'] ?? _stats['completed'],
              'pending': sMap['pending'] ?? _stats['pending'],
            };
          });
        }
      }).catchError((_) {});
    } catch (e) {
      // Revert optimistic update
      setState(() {
        task['task_status'] = oldStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: urgentRed,
            content: Text('Failed to update task: $e', style: TextStyle(color: textWhite)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      floatingActionButton: shared.AuthHelpers.isAdmin
          ? shared.AdminSpeedDial(onTaskCreated: _fetchData)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopAppBar(),
            if (_isSearchVisible) _buildSearchBar(),
            _buildScopeSwitcher(),
            _buildStatusFilterBar(),
            const SizedBox(height: 6),
            Expanded(
              child: RefreshIndicator(
                color: accentBlue,
                backgroundColor: cardBg,
                onRefresh: _fetchData,
                child: _isLoading
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: Center(child: CircularProgressIndicator(color: accentBlue)),
                          ),
                        ],
                      )
                    : _tasks.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            children: [
                              _buildEmptyState(),
                            ],
                          )
                        : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: _tasks.length,
                            itemBuilder: (context, index) {
                              final task = _tasks[index];
                              return _buildTaskCard(task);
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(Icons.arrow_back_rounded, color: textWhite, size: 18),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Tasks',
                      style: TextStyle(
                        color: textWhite,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: accentBlue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${_stats['total']}',
                        style: TextStyle(
                          color: accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _stats['due_today'] > 0
                      ? '${_stats['due_today']} due today • ${_stats['overdue']} overdue'
                      : 'Manage to-dos and checklists',
                  style: TextStyle(
                    color: _stats['overdue'] > 0 ? urgentRed.withValues(alpha: 0.9) : textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(
                _isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                color: _isSearchVisible ? accentBlue : textMuted,
                size: 18,
              ),
              onPressed: () {
                setState(() {
                  _isSearchVisible = !_isSearchVisible;
                  if (!_isSearchVisible) {
                    _searchController.clear();
                    _searchQuery = '';
                    _fetchData();
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentBlue,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: accentBlue.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 19),
              tooltip: 'New Task',
              onPressed: () => _showCreateTaskModal(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cardBorder),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search tasks by title, number, or description...',
            hintStyle: TextStyle(color: textMuted.withOpacity(0.7), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: textMuted, size: 20),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: textMuted, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _searchQuery = '';
                      _fetchData();
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          onSubmitted: (val) {
            _searchQuery = val;
            _fetchData();
          },
        ),
      ),
    );
  }

  Widget _buildScopeSwitcher() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cardBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildScopeItem(
                id: 'all',
                label: 'All Tasks',
                count: _stats['total'] ?? 0,
                icon: Icons.layers_outlined,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: _buildScopeItem(
                id: 'my_tasks',
                label: 'My Tasks',
                count: _stats['my_tasks'] ?? 0,
                icon: Icons.person_outline_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeItem({
    required String id,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _scope == id;
    return GestureDetector(
      onTap: () {
        if (_scope == id) return;
        setState(() => _scope = id);
        _fetchData();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentBlue.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? textWhite : textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? textWhite : textMuted,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : cardBorder.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? textWhite : textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterBar() {
    final filters = [
      {
        'id': 'all',
        'label': 'All',
        'count': _scope == 'my_tasks' ? (_stats['my_tasks'] ?? 0) : (_stats['total'] ?? 0),
        'color': accentBlue,
      },
      {
        'id': 'pending',
        'label': 'New',
        'count': _stats['pending'] ?? 0,
        'color': const Color(0xFF0EA5E9),
      },
      {
        'id': 'today',
        'label': 'Today',
        'count': _stats['due_today'] ?? 0,
        'color': warningAmber,
      },
      {
        'id': 'overdue',
        'label': 'Overdue',
        'count': _stats['overdue'] ?? 0,
        'color': urgentRed,
      },
      {
        'id': 'completed',
        'label': 'Done',
        'count': _stats['completed'] ?? 0,
        'color': successGreen,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        children: filters.map((f) {
          final isSelected = _statusFilter == f['id'];
          final Color color = f['color'] as Color;
          final int count = (f['count'] as int?) ?? 0;
          final String label = f['label'] as String;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: GestureDetector(
                onTap: () {
                  if (_statusFilter == f['id']) return;
                  setState(() => _statusFilter = f['id'] as String);
                  _fetchData();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 34,
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.15) : cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? color : cardBorder,
                      width: 1.0,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.25),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isSelected ? color : color.withValues(alpha: 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected ? textWhite : textMuted,
                                fontSize: 11,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 3),
                              Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected ? color : textMuted.withValues(alpha: 0.8),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
    final bool isCompleted = task['task_status'] == 'completed' || task['task_status'] == 'verified';
    final String priority = (task['priority'] ?? 'normal').toString().toLowerCase();
    final String taskNumber = task['task_number'] ?? 'TK-${task['id']}';
    final String title = task['title'] ?? 'Untitled Task';
    final String? description = task['description'];
    final String? dueDateStr = task['due_date'];

    // Subtasks summary
    final subtasks = (task['subtasks'] as List<dynamic>?) ?? [];
    final int subtaskCount = subtasks.length;
    final int completedSubtasks = subtasks.where((s) => s['task_status'] == 'completed').length;

    // Linked Job
    final job = task['job'] as Map<String, dynamic>?;

    // Billable and Duration
    final bool isBillable = task['billable'] == 1 || task['billable'] == true || task['billable'] == '1';
    final int? durationMinutes = task['estimated_duration_minutes'] != null
        ? int.tryParse(task['estimated_duration_minutes'].toString())
        : null;

    // Assignee
    final assignee = task['assignee'] as Map<String, dynamic>?;
    final String assigneeName = assignee != null
        ? '${assignee['first_name'] ?? ''} ${assignee['last_name'] ?? ''}'.trim()
        : '';

    // Due status determination
    DateTime? dueDate;
    bool isOverdue = false;
    bool isToday = false;
    String dueDateFormatted = '';

    if (dueDateStr != null && dueDateStr.isNotEmpty) {
      try {
        dueDate = DateTime.parse(dueDateStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);

        isToday = dueDay.isAtSameMomentAs(today);
        isOverdue = dueDate.isBefore(now) && !isCompleted;

        if (isToday) {
          dueDateFormatted = 'Today ${DateFormat.jm().format(dueDate)}';
        } else if (dueDay.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
          dueDateFormatted = 'Tomorrow';
        } else {
          dueDateFormatted = DateFormat('MMM d').format(dueDate);
        }
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? urgentRed.withOpacity(0.5) : cardBorder,
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TaskDetailScreen(taskId: task['id']),
              ),
            );
            if (result == true) {
              _fetchData();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Checkbox + Title + Priority
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => _confirmToggleTaskStatus(task),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12, top: 1),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isCompleted ? successGreen : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted ? successGreen : textMuted,
                            width: 2,
                          ),
                        ),
                        child: isCompleted
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              color: isCompleted ? textMuted : textWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          if (description != null && description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              description.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textMuted.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityBadge(priority),
                  ],
                ),
                const SizedBox(height: 12),
                // Divider
                Container(height: 1, color: cardBorder.withOpacity(0.5)),
                const SizedBox(height: 10),
                // Bottom metadata pills
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Task Number
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: accentBlue.withOpacity(0.25)),
                      ),
                      child: Text(
                        taskNumber,
                        style: TextStyle(
                          color: accentBlue,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Due Date Status
                    if (dueDate != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOverdue
                              ? urgentRed.withOpacity(0.12)
                              : isToday
                                  ? warningAmber.withOpacity(0.12)
                                  : cardBorder.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOverdue
                                ? urgentRed.withOpacity(0.4)
                                : isToday
                                    ? warningAmber.withOpacity(0.4)
                                    : cardBorder,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 12,
                              color: isOverdue
                                  ? urgentRed
                                  : isToday
                                      ? warningAmber
                                      : textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dueDateFormatted,
                              style: TextStyle(
                                color: isOverdue
                                    ? urgentRed
                                    : isToday
                                        ? warningAmber
                                        : textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Linked Job
                    if (job != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: purple.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: purple.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.work_outline_rounded, size: 12, color: purple),
                            const SizedBox(width: 4),
                            Text(
                              job['job_number'] ?? 'JOB-${job['id']}',
                              style: TextStyle(
                                color: purple,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Subtasks Ratio
                    if (subtaskCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cardBorder.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_box_outlined, size: 12, color: textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '$completedSubtasks/$subtaskCount',
                              style: TextStyle(
                                color: completedSubtasks == subtaskCount ? successGreen : textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Estimated Duration
                    if (durationMinutes != null && durationMinutes > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cardBorder.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: textMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${durationMinutes}m',
                              style: TextStyle(
                                color: textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Billable Pill
                    if (isBillable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: successGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: successGreen.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.monetization_on_outlined, size: 11, color: successGreen),
                            const SizedBox(width: 3),
                            Text(
                              'Billable',
                              style: TextStyle(
                                color: successGreen,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Assignee
                    if (assigneeName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: accentBlue.withOpacity(0.2),
                            child: Text(
                              assigneeName[0].toUpperCase(),
                              style: TextStyle(color: accentBlue, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            assigneeName,
                            style: TextStyle(color: textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String label;
    IconData? icon;

    switch (priority) {
      case 'urgent':
        color = urgentRed;
        label = 'Urgent';
        icon = Icons.priority_high_rounded;
        break;
      case 'high':
        color = const Color(0xFFF97316);
        label = 'High';
        break;
      case 'normal':
      case 'medium':
        color = accentBlue;
        label = 'Normal';
        break;
      case 'low':
      default:
        color = textMuted;
        label = 'Low';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: cardBorder),
              ),
              child: Icon(Icons.checklist_rounded, size: 36, color: textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              'No tasks found',
              style: TextStyle(
                color: textWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              (_scope == 'all' && _statusFilter == 'all')
                  ? 'Tap "+" at the top to create your first to-do item.'
                  : 'No tasks found for this view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: textMuted, fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showCreateTaskModal(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              label: const Text('Create Task', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // CREATE TASK MODAL
  void _showCreateTaskModal(BuildContext context) {
    CreateTaskBottomSheet.show(
      context,
      onTaskCreated: _fetchData,
      preloadedStaff: _staffOptions,
      preloadedJobs: _jobOptions,
    );
  }
}

class CreateTaskBottomSheet extends StatefulWidget {
  final VoidCallback? onTaskCreated;
  final List<dynamic>? preloadedStaff;
  final List<dynamic>? preloadedJobs;
  final Map<String, dynamic>? initialTask;

  const CreateTaskBottomSheet({
    Key? key,
    this.onTaskCreated,
    this.preloadedStaff,
    this.preloadedJobs,
    this.initialTask,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onTaskCreated,
    List<dynamic>? preloadedStaff,
    List<dynamic>? preloadedJobs,
    Map<String, dynamic>? initialTask,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateTaskBottomSheet(
        onTaskCreated: onTaskCreated,
        preloadedStaff: preloadedStaff,
        preloadedJobs: preloadedJobs,
        initialTask: initialTask,
      ),
    );
  }

  @override
  State<CreateTaskBottomSheet> createState() => _CreateTaskBottomSheetState();
}

class _CreateTaskBottomSheetState extends State<CreateTaskBottomSheet> {
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color cardBorder = const Color(0xFF334155);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color textWhite = Colors.white;
  final Color textMuted = const Color(0xFF94A3B8);
  final Color successGreen = const Color(0xFF10B981);
  final Color urgentRed = const Color(0xFFEF4444);
  final Color warningAmber = const Color(0xFFF59E0B);

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _subtaskInputController = TextEditingController();

  bool _isBillable = false;
  String _priority = 'normal';
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 17, minute: 0);
  int? _selectedAssigneeId;
  int? _selectedJobId;
  final List<String> _initialSubtasks = [];
  bool _isSubmitting = false;

  List<dynamic> _staffOptions = [];
  List<dynamic> _jobOptions = [];

  @override
  void initState() {
    super.initState();
    _staffOptions = widget.preloadedStaff ?? [];
    _jobOptions = widget.preloadedJobs ?? [];
    if (widget.initialTask != null) {
      final t = widget.initialTask!;
      _titleController.text = t['title'] ?? '';
      _descController.text = t['description'] ?? '';
      _priority = t['priority'] ?? 'normal';
      _selectedAssigneeId = t['assigned_to'] as int?;
      _selectedJobId = t['job_id'] as int?;
      _isBillable = t['billable'] == true;
      if (t['estimated_duration_minutes'] != null) {
        _durationController.text = t['estimated_duration_minutes'].toString();
      }
      if (t['due_date'] != null) {
        try {
          final dt = DateTime.parse(t['due_date']);
          _selectedDate = dt;
          _selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        } catch (_) {}
      }
      if (t['subtasks'] != null && t['subtasks'] is List) {
        for (var st in t['subtasks']) {
          if (st is Map && st['title'] != null) {
            _initialSubtasks.add(st['title'].toString());
          } else if (st is String) {
            _initialSubtasks.add(st);
          }
        }
      }
    }
    if (_staffOptions.isEmpty || _jobOptions.isEmpty) {
      _loadOptions();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _durationController.dispose();
    _subtaskInputController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final res = await ApiService.instance.getTaskOptions();
      final data = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      if (mounted) {
        setState(() {
          if (_staffOptions.isEmpty) _staffOptions = data['staff'] ?? [];
          if (_jobOptions.isEmpty) _jobOptions = data['jobs'] ?? [];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 14,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Indicator
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: textMuted.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.initialTask != null ? 'Edit Task' : 'Create New Task',
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Title
            Text('Task Title *', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: TextField(
                controller: _titleController,
                style: TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Inspect HVAC filters before departure',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: bgDark,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accentBlue, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Description
            Text('Description', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            SizedBox(
              height: 40,
              child: TextField(
                controller: _descController,
                style: TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Additional details or instructions...',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: bgDark,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: accentBlue, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Priority Chips
            Text('Priority', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: ['low', 'normal', 'high', 'urgent'].map((p) {
                final isSelected = _priority == p;
                Color pColor = p == 'urgent'
                    ? urgentRed
                    : p == 'high'
                        ? const Color(0xFFF97316)
                        : p == 'normal'
                            ? accentBlue
                            : textMuted;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _priority = p),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      height: 34,
                      decoration: BoxDecoration(
                        color: isSelected ? pColor.withValues(alpha: 0.2) : bgDark,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? pColor : cardBorder,
                          width: 1.0,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        p[0].toUpperCase() + p.substring(1),
                        style: TextStyle(
                          color: isSelected ? textWhite : textMuted,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            // Due Date & Time Pickers
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Due Date', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: accentBlue,
                                    surface: cardBg,
                                    onSurface: textWhite,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => _selectedDate = picked);
                          }
                        },
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: bgDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 16, color: accentBlue),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat('MMM d, yyyy').format(_selectedDate),
                                style: TextStyle(color: textWhite, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Due Time', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.dark(
                                    primary: accentBlue,
                                    surface: cardBg,
                                    onSurface: textWhite,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => _selectedTime = picked);
                          }
                        },
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: bgDark,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: cardBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time_rounded, size: 16, color: warningAmber),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime.format(context),
                                style: TextStyle(color: textWhite, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Duration & Billable
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Duration (mins)', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textWhite, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'e.g. 45',
                            hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                            filled: true,
                            fillColor: bgDark,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: cardBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: accentBlue, width: 1.5),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Billable', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: bgDark,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isBillable ? 'Yes' : 'No',
                              style: TextStyle(
                                color: _isBillable ? successGreen : textMuted,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Transform.scale(
                              scale: 0.75,
                              child: Switch(
                                value: _isBillable,
                                activeThumbColor: successGreen,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                onChanged: (val) => setState(() => _isBillable = val),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Assignee Dropdown
            Text('Assignee', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedAssigneeId,
                  dropdownColor: cardBg,
                  isExpanded: true,
                  isDense: true,
                  hint: Text('Unassigned', style: TextStyle(color: textMuted, fontSize: 13)),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Unassigned', style: TextStyle(color: textMuted, fontSize: 13)),
                    ),
                    ..._staffOptions.map((s) {
                      final name = s['name'] ?? '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
                      return DropdownMenuItem<int?>(
                        value: s['id'] as int,
                        child: Text(name, style: TextStyle(color: textWhite, fontSize: 13)),
                      );
                    }).toList(),
                  ],
                  onChanged: (val) => setState(() => _selectedAssigneeId = val),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Linked Job Dropdown
            Text('Link to Job (Optional)', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: bgDark,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _selectedJobId,
                  dropdownColor: cardBg,
                  isExpanded: true,
                  isDense: true,
                  hint: Text('None (Standalone Task)', style: TextStyle(color: textMuted, fontSize: 13)),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None (Standalone Task)', style: TextStyle(color: textMuted, fontSize: 13)),
                    ),
                    ..._jobOptions.map((j) {
                      final title = '${j['job_number'] ?? '#${j['id']}'} - ${j['title'] ?? 'Job'}';
                      return DropdownMenuItem<int?>(
                        value: j['id'] as int,
                        child: Text(title, style: TextStyle(color: textWhite, fontSize: 13), overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                  ],
                  onChanged: (val) => setState(() => _selectedJobId = val),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Subtasks checklist builder
            Text('Checklist Subtasks (Optional)', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _subtaskInputController,
                      style: TextStyle(color: textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add a subtask item...',
                        hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                        filled: true,
                        fillColor: bgDark,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cardBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: accentBlue, width: 1.5),
                        ),
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          setState(() {
                            _initialSubtasks.add(val.trim());
                            _subtaskInputController.clear();
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentBlue.withValues(alpha: 0.3)),
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.add_rounded, color: accentBlue, size: 20),
                    onPressed: () {
                      if (_subtaskInputController.text.trim().isNotEmpty) {
                        setState(() {
                          _initialSubtasks.add(_subtaskInputController.text.trim());
                          _subtaskInputController.clear();
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (_initialSubtasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._initialSubtasks.asMap().entries.map((entry) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgDark,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: cardBorder.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outline_blank_rounded, size: 16, color: textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(entry.value, style: TextStyle(color: textWhite, fontSize: 13)),
                      ),
                      GestureDetector(
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: cardBorder),
                              ),
                              title: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: urgentRed.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.delete_outline_rounded, color: urgentRed, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Remove Item',
                                    style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              content: Text(
                                'Are you sure you want to remove "${entry.value}" from the checklist?',
                                style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
                              ),
                              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text('Cancel', style: TextStyle(color: textMuted, fontWeight: FontWeight.w600)),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: urgentRed,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Remove', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            setState(() => _initialSubtasks.removeAt(entry.key));
                          }
                        },
                        child: Icon(Icons.close_rounded, size: 16, color: textMuted),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
            const SizedBox(height: 24),
            // Submit button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (_titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: urgentRed,
                              content: Text('Please enter a task title', style: TextStyle(color: textWhite)),
                            ),
                          );
                          return;
                        }

                        setState(() => _isSubmitting = true);

                        try {
                          final fullDueDateTime = DateTime(
                            _selectedDate.year,
                            _selectedDate.month,
                            _selectedDate.day,
                            _selectedTime.hour,
                            _selectedTime.minute,
                          );

                          final payload = <String, dynamic>{
                            'title': _titleController.text.trim(),
                            'description': _descController.text.trim().isNotEmpty
                                ? _descController.text.trim()
                                : null,
                            'priority': _priority,
                            'task_status': 'pending',
                            'due_date': fullDueDateTime.toIso8601String(),
                            'assigned_to': _selectedAssigneeId,
                            'job_id': _selectedJobId,
                            'billable': _isBillable,
                            if (_durationController.text.trim().isNotEmpty && int.tryParse(_durationController.text.trim()) != null)
                              'estimated_duration_minutes': int.parse(_durationController.text.trim()),
                            'subtasks': _initialSubtasks,
                          };

                          if (widget.initialTask != null) {
                            await ApiService.instance.updateTask(widget.initialTask!['id'] as int, payload);
                          } else {
                            await ApiService.instance.createTask(payload);
                          }
                          if (mounted) {
                            Navigator.pop(context);
                            widget.onTaskCreated?.call();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: successGreen,
                                content: Text(
                                  widget.initialTask != null
                                      ? 'Task updated successfully!'
                                      : 'Task created successfully!',
                                  style: TextStyle(color: textWhite),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: urgentRed,
                                content: Text('Failed to save task: $e', style: TextStyle(color: textWhite)),
                              ),
                            );
                          }
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        widget.initialTask != null ? 'Update Task' : 'Create Task',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

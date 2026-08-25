import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import '../custom_code/widgets/index.dart' as custom_widgets;
import 'task_detail_screen.dart';
import 'package:intl/intl.dart';

class TasksListScreen extends StatefulWidget {
  const TasksListScreen({Key? key}) : super(key: key);

  @override
  State<TasksListScreen> createState() => _TasksListScreenState();
}

class _TasksListScreenState extends State<TasksListScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String _activeTab = 'my_tasks';

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);
    try {
      final params = <String, dynamic>{};
      if (_activeTab == 'my_tasks') params['assigned_to'] = 'me';
      if (_activeTab == 'overdue') params['overdue_only'] = 'true';

      final res = await ApiService.instance.getTasks(params: params);
      setState(() {
        _tasks = res['data'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load tasks: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'verified': return Colors.purple;
      case 'in_progress': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.orange;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent': return Colors.red;
      case 'high': return Colors.orange;
      case 'normal': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Tasks', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildFilterTabs(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _tasks.isEmpty
                    ? const Center(child: Text('No tasks found.'))
                    : RefreshIndicator(
                        onRefresh: _fetchTasks,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: simple create task form
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _buildTab('All', 'all'),
          const SizedBox(width: 8),
          _buildTab('My Tasks', 'my_tasks'),
          const SizedBox(width: 8),
          _buildTab('Overdue', 'overdue'),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isActive = _activeTab == value;
    return GestureDetector(
      onTap: () {
        setState(() => _activeTab = value);
        _fetchTasks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1E3A8A) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black87,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(dynamic task) {
    final isOverdue = task['due_date'] != null && 
        DateTime.parse(task['due_date']).isBefore(DateTime.now()) && 
        !['completed', 'verified', 'cancelled'].contains(task['task_status']);
        
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: task['id']),
            ),
          );
          if (result == true) {
            _fetchTasks(); // Refresh if task was updated
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    task['task_number'] ?? 'TK-${task['id']}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(task['priority']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (task['priority'] as String).toUpperCase(),
                          style: TextStyle(
                            color: _getPriorityColor(task['priority']),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(task['task_status']).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          (task['task_status'] as String).replaceAll('_', ' ').toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(task['task_status']),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                task['title'] ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              if (task['job'] != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.business_center, size: 14, color: Colors.blue.shade700),
                    const SizedBox(width: 4),
                    Text(
                      task['job']['title'] ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        task['assignee']?['name'] ?? 'Unassigned',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  if (task['due_date'] != null)
                    Row(
                      children: [
                        Icon(isOverdue ? Icons.warning : Icons.calendar_today, size: 14, color: isOverdue ? Colors.red : Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy').format(DateTime.parse(task['due_date'])),
                          style: TextStyle(fontSize: 13, color: isOverdue ? Colors.red : Colors.grey.shade700, fontWeight: isOverdue ? FontWeight.bold : FontWeight.normal),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

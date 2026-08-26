import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'package:intl/intl.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _task;
  List<dynamic> _comments = [];
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final taskRes = await ApiService.instance.getTask(widget.taskId);
      final commentsRes = await ApiService.instance.getTaskComments(widget.taskId);
      setState(() {
        _task = taskRes['data'];
        _comments = commentsRes['data'] ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load task: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      await ApiService.instance.updateTask(widget.taskId, {'task_status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;
    try {
      await ApiService.instance.addTaskComment(widget.taskId, {
        'content': _commentController.text.trim(),
        'mentions': [], // Simplification for mobile typing
      });
      _commentController.clear();
      _fetchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Task Detail')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(child: Text('Task not found')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(_task!['task_number'] ?? 'TK-${_task!['id']}', style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          PopupMenuButton<String>(
            onSelected: _updateStatus,
            icon: const Icon(Icons.more_vert),
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(value: 'pending', child: Text('Mark Pending')),
              const PopupMenuItem<String>(value: 'in_progress', child: Text('Mark In Progress')),
              const PopupMenuItem<String>(value: 'completed', child: Text('Mark Completed')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 16),
                  _buildSubtasksCard(),
                  const SizedBox(height: 16),
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _task!['title'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: _task!['task_status'],
              items: ['pending', 'in_progress', 'completed', 'cancelled', 'verified']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                  .toList(),
              onChanged: (val) async {
                if (val != null && val != _task!['task_status']) {
                  try {
                    await ApiService.instance.request(
                      method: 'PUT',
                      endpoint: '/tasks/${widget.taskId}',
                      body: {'task_status': val},
                    );
                    setState(() => _task!['task_status'] = val);
                  } catch (e) {
                    debugPrint('Error updating status: $e');
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(_task!['description'] ?? 'No description provided.'),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  _task!['due_date'] != null ? DateFormat('MMM d, yyyy').format(DateTime.parse(_task!['due_date'])) : 'No Due Date',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(_task!['assignee']?['name'] ?? 'Unassigned'),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubtasksCard() {
    final subtasks = _task!['subtasks'] as List<dynamic>? ?? [];
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Subtasks', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (subtasks.isEmpty)
              const Text('No subtasks', style: TextStyle(color: Colors.grey))
            else
              ...subtasks.map((st) => CheckboxListTile(
                title: Text(st['title']),
                value: st['task_status'] == 'completed',
                onChanged: (val) {
                  // In a real app, this would hit updateTask for the subtask
                },
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              )).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        if (_comments.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('No comments yet.', style: TextStyle(color: Colors.grey)),
          )
        else
          ..._comments.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.blue.shade100,
                      child: Text(c['creator']?['name']?[0] ?? 'U', style: TextStyle(color: Colors.blue.shade900)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(c['creator']?['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                Text(
                                  DateFormat('MMM d, h:mm a').format(DateTime.parse(c['created_at'])),
                                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(c['content']),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )).toList(),
      ],
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  hintText: 'Add a comment...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                maxLines: null,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send, color: Color(0xFF1E3A8A)),
              onPressed: _submitComment,
            ),
          ],
        ),
      ),
    );
  }
}

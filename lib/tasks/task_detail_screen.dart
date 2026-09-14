import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../backend/api_service.dart';
import '../shared/job_detail_screen.dart';
import 'tasks_list_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  const TaskDetailScreen({Key? key, required this.taskId}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
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
  Map<String, dynamic>? _task;
  List<dynamic> _subtasks = [];
  List<dynamic> _comments = [];
  List<dynamic> _staffOptions = [];

  bool _wasUpdated = false;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _newSubtaskController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();

  bool _isEditingDetails = false;
  bool _isPostingComment = false;
  bool _isAddingSubtask = false;
  bool _showAddSubtask = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _fetchOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _newSubtaskController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _fetchOptions() async {
    try {
      final res = await ApiService.instance.getTaskOptions();
      final data = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      if (mounted) {
        setState(() {
          _staffOptions = data['staff'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final dynamic taskRes = await ApiService.instance.getTask(widget.taskId);
      final Map<String, dynamic>? taskData = (taskRes is Map && taskRes.containsKey('data') && taskRes['data'] is Map)
          ? Map<String, dynamic>.from(taskRes['data'])
          : (taskRes is Map ? Map<String, dynamic>.from(taskRes) : null);

      if (taskData != null) {
        final commentsRes = await ApiService.instance.getTaskComments(widget.taskId);
        final commentsList = commentsRes['data'] is List
            ? commentsRes['data']
            : (commentsRes is List ? commentsRes : []);

        if (mounted) {
          setState(() {
            _task = Map<String, dynamic>.from(taskData);
            _subtasks = List.from(_task!['subtasks'] ?? []);
            _comments = List.from(commentsList);
            _titleController.text = _task!['title'] ?? '';
            _descController.text = _task!['description'] ?? '';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: urgentRed,
            content: Text('Failed to load task: $e', style: TextStyle(color: textWhite)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateTaskField(Map<String, dynamic> payload) async {
    try {
      final res = await ApiService.instance.updateTask(widget.taskId, payload);
      final updated = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _wasUpdated = true;
      if (mounted && updated is Map<String, dynamic>) {
        setState(() {
          _task = Map<String, dynamic>.from(updated);
          _subtasks = List.from(_task!['subtasks'] ?? []);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: successGreen,
            content: Text('Task updated', style: TextStyle(color: textWhite)),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
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

  Future<bool> _showConfirmationDialog({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = const Color(0xFF3B82F6),
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder),
        ),
        title: Row(
          children: [
            if (icon != null) ...[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: confirmColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: confirmColor, size: 18),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message,
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
              backgroundColor: confirmColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _confirmToggleTaskStatus() async {
    if (_task == null) return;
    final bool isCurrentlyCompleted = _task!['task_status'] == 'completed';
    final taskNumber = _task!['task_number'] ?? 'Task #${widget.taskId}';

    final int incompleteSubtasks = _subtasks.where((s) => s['task_status'] != 'completed').length;
    String warningNote = '';
    if (!isCurrentlyCompleted && incompleteSubtasks > 0) {
      warningNote = '\n\nNote: $incompleteSubtasks checklist item${incompleteSubtasks == 1 ? ' is' : 's are'} still incomplete.';
    }

    final confirmed = await _showConfirmationDialog(
      title: isCurrentlyCompleted ? 'Mark Task as Incomplete?' : 'Mark Task as Completed?',
      message: isCurrentlyCompleted
          ? 'Are you sure you want to reopen $taskNumber and mark it as pending?'
          : 'Are you sure you want to mark $taskNumber as completed?$warningNote',
      confirmLabel: isCurrentlyCompleted ? 'Reopen Task' : 'Mark as Completed',
      confirmColor: isCurrentlyCompleted ? warningAmber : successGreen,
      icon: isCurrentlyCompleted ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
    );

    if (confirmed) {
      _toggleTaskStatus();
    }
  }

  Future<void> _confirmToggleSubtaskStatus(Map<String, dynamic> subtask) async {
    final bool isCurrentlyCompleted = subtask['task_status'] == 'completed';
    final title = subtask['title'] ?? 'this checklist item';
    final confirmed = await _showConfirmationDialog(
      title: isCurrentlyCompleted ? 'Mark as Incomplete?' : 'Mark as Completed?',
      message: isCurrentlyCompleted
          ? 'Are you sure you want to mark "$title" as incomplete?'
          : 'Are you sure you want to mark "$title" as completed?',
      confirmLabel: isCurrentlyCompleted ? 'Mark Incomplete' : 'Mark Completed',
      confirmColor: isCurrentlyCompleted ? warningAmber : successGreen,
      icon: isCurrentlyCompleted ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
    );
    if (confirmed) {
      _toggleSubtaskStatus(subtask);
    }
  }

  Future<void> _confirmDeleteSubtask(Map<String, dynamic> subtask) async {
    final title = subtask['title'] ?? 'this checklist item';
    final confirmed = await _showConfirmationDialog(
      title: 'Delete Checklist Item',
      message: 'Are you sure you want to remove "$title"? This action cannot be undone.',
      confirmLabel: 'Delete',
      confirmColor: urgentRed,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) {
      _deleteSubtask(subtask['id']);
    }
  }

  Future<void> _toggleTaskStatus() async {
    if (_task == null) return;
    try {
      final res = await ApiService.instance.toggleTask(widget.taskId);
      final updated = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _wasUpdated = true;
      if (mounted && updated is Map<String, dynamic>) {
        setState(() {
          _task = Map<String, dynamic>.from(updated);
          _subtasks = List.from(_task!['subtasks'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: urgentRed,
            content: Text('Failed to toggle status: $e', style: TextStyle(color: textWhite)),
          ),
        );
      }
    }
  }

  // SUBTASKS
  Future<void> _addSubtask() async {
    final title = _newSubtaskController.text.trim();
    if (title.isEmpty) return;

    setState(() => _isAddingSubtask = true);
    try {
      final res = await ApiService.instance.addTaskSubtask(widget.taskId, title);
      final newSt = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _wasUpdated = true;
      _newSubtaskController.clear();
      if (mounted && newSt is Map<String, dynamic>) {
        setState(() {
          _subtasks.add(newSt);
          _showAddSubtask = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to add subtask: $e', style: TextStyle(color: textWhite))),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingSubtask = false);
    }
  }

  Future<void> _toggleSubtaskStatus(Map<String, dynamic> subtask) async {
    final int subtaskId = subtask['id'];
    final oldStatus = subtask['task_status'];
    final newStatus = oldStatus == 'completed' ? 'pending' : 'completed';

    // Optimistic
    setState(() {
      subtask['task_status'] = newStatus;
    });

    try {
      await ApiService.instance.updateTaskSubtask(widget.taskId, subtaskId, {'task_status': newStatus});
      _wasUpdated = true;
    } catch (e) {
      setState(() {
        subtask['task_status'] = oldStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to update subtask: $e', style: TextStyle(color: textWhite))),
        );
      }
    }
  }

  Future<void> _deleteSubtask(int subtaskId) async {
    try {
      await ApiService.instance.deleteTaskSubtask(widget.taskId, subtaskId);
      _wasUpdated = true;
      setState(() {
        _subtasks.removeWhere((s) => s['id'] == subtaskId);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to delete subtask: $e', style: TextStyle(color: textWhite))),
        );
      }
    }
  }

  // COMMENTS
  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPostingComment = true);
    try {
      final res = await ApiService.instance.addTaskComment(widget.taskId, {'content': text});
      final newComment = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _commentController.clear();
      _wasUpdated = true;
      if (mounted && newComment is Map<String, dynamic>) {
        setState(() {
          _comments.add(newComment);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to post comment: $e', style: TextStyle(color: textWhite))),
        );
      }
    } finally {
      if (mounted) setState(() => _isPostingComment = false);
    }
  }

  Future<void> _duplicateTask() async {
    try {
      final res = await ApiService.instance.duplicateTask(widget.taskId);
      final newDoc = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _wasUpdated = true;
      if (mounted && newDoc is Map<String, dynamic> && newDoc['id'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: successGreen, content: Text('Task duplicated successfully', style: TextStyle(color: textWhite))),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: newDoc['id'])),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to duplicate task: $e', style: TextStyle(color: textWhite))),
        );
      }
    }
  }

  Future<void> _verifyTask() async {
    try {
      final res = await ApiService.instance.verifyTask(widget.taskId);
      final updated = res.containsKey('data') && res['data'] is Map ? res['data'] : res;
      _wasUpdated = true;
      if (mounted && updated is Map<String, dynamic>) {
        setState(() {
          _task = Map<String, dynamic>.from(updated);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: purple, content: Text('Task verified successfully!', style: TextStyle(color: textWhite))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: urgentRed, content: Text('Failed to verify task: $e', style: TextStyle(color: textWhite))),
        );
      }
    }
  }

  // DELETE TASK
  Future<void> _confirmDeleteTask() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: cardBorder)),
        title: Text('Delete Task?', style: TextStyle(color: textWhite, fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to delete this task? This action cannot be undone.', style: TextStyle(color: textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: urgentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.instance.deleteTask(widget.taskId);
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: urgentRed, content: Text('Failed to delete task: $e', style: TextStyle(color: textWhite))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgDark,
        body: Center(child: CircularProgressIndicator(color: accentBlue)),
      );
    }

    if (_task == null) {
      return Scaffold(
        backgroundColor: bgDark,
        appBar: AppBar(
          backgroundColor: bgDark,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textWhite),
            onPressed: () => Navigator.pop(context, _wasUpdated),
          ),
          title: Text('Task Not Found', style: TextStyle(color: textWhite)),
        ),
        body: Center(
          child: Text('This task does not exist or has been deleted.', style: TextStyle(color: textMuted)),
        ),
      );
    }

    final bool isCompleted = _task!['task_status'] == 'completed' || _task!['task_status'] == 'verified';

    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _wasUpdated);
        return false;
      },
      child: Scaffold(
        backgroundColor: bgDark,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(),
                      const SizedBox(height: 14),
                      _buildMetadataGrid(),
                      const SizedBox(height: 14),
                      _buildSubtasksSection(),
                      const SizedBox(height: 14),
                      _buildCommentsSection(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              _buildBottomActionBar(isCompleted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final taskNumber = _task!['task_number'] ?? 'TK-${_task!['id']}';
    final currentStatus = _task!['task_status'] ?? 'pending';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              shape: BoxShape.circle,
              border: Border.all(color: cardBorder),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textWhite, size: 20),
              onPressed: () => Navigator.pop(context, _wasUpdated),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: accentBlue.withOpacity(0.3)),
            ),
            child: Text(
              taskNumber,
              style: TextStyle(
                color: accentBlue,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Spacer(),
          // Status Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: ['pending', 'in_progress', 'completed', 'cancelled', 'verified'].contains(currentStatus)
                    ? currentStatus
                    : 'pending',
                dropdownColor: cardBg,
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 18),
                items: [
                  DropdownMenuItem(value: 'pending', child: _buildStatusLabel('Pending', warningAmber)),
                  DropdownMenuItem(value: 'in_progress', child: _buildStatusLabel('In Progress', accentBlue)),
                  DropdownMenuItem(value: 'completed', child: _buildStatusLabel('Completed', successGreen)),
                  DropdownMenuItem(value: 'cancelled', child: _buildStatusLabel('Cancelled', urgentRed)),
                  DropdownMenuItem(value: 'verified', child: _buildStatusLabel('Verified', purple)),
                ],
                onChanged: (val) async {
                  if (val != null && val != currentStatus) {
                    if (val == 'completed') {
                      final confirmed = await _showConfirmationDialog(
                        title: 'Mark Task as Completed?',
                        message: 'Are you sure you want to change this task status to Completed?',
                        confirmLabel: 'Mark Completed',
                        confirmColor: successGreen,
                        icon: Icons.check_circle_outline_rounded,
                      );
                      if (!confirmed) return;
                    }
                    _updateTaskField({'task_status': val});
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // More Actions Popup Menu
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cardBorder),
            ),
            child: PopupMenuButton<String>(
              color: cardBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cardBorder)),
              icon: Icon(Icons.more_vert_rounded, color: textWhite, size: 20),
              onSelected: (val) {
                if (val == 'edit') {
                  CreateTaskBottomSheet.show(
                    context,
                    initialTask: _task,
                    onTaskCreated: _fetchData,
                  );
                }
                if (val == 'duplicate') _duplicateTask();
                if (val == 'verify') _verifyTask();
                if (val == 'delete') _confirmDeleteTask();
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_note_rounded, color: accentBlue, size: 18),
                      const SizedBox(width: 10),
                      Text('Edit Task', style: TextStyle(color: textWhite, fontSize: 13)),
                    ],
                  ),
                ),
                if (_task!['task_status'] == 'completed')
                  PopupMenuItem(
                    value: 'verify',
                    child: Row(
                      children: [
                        Icon(Icons.verified_rounded, color: purple, size: 18),
                        const SizedBox(width: 10),
                        Text('Verify Task', style: TextStyle(color: purple, fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, color: textWhite, size: 18),
                      const SizedBox(width: 10),
                      Text('Duplicate Task', style: TextStyle(color: textWhite, fontSize: 13)),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded, color: urgentRed, size: 18),
                      const SizedBox(width: 10),
                      Text('Delete Task', style: TextStyle(color: urgentRed, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLabel(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Task Details', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              GestureDetector(
                onTap: () {
                  if (_isEditingDetails) {
                    _updateTaskField({
                      'title': _titleController.text.trim(),
                      'description': _descController.text.trim(),
                    });
                  }
                  setState(() => _isEditingDetails = !_isEditingDetails);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isEditingDetails ? successGreen.withOpacity(0.15) : accentBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _isEditingDetails ? successGreen : accentBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isEditingDetails ? Icons.check_rounded : Icons.edit_rounded,
                        size: 13,
                        color: _isEditingDetails ? successGreen : accentBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isEditingDetails ? 'Save' : 'Edit',
                        style: TextStyle(
                          color: _isEditingDetails ? successGreen : accentBlue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_isEditingDetails) ...[
            SizedBox(
              height: 40,
              child: TextField(
                controller: _titleController,
                style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Task Title',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: bgDark,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentBlue, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 40,
              child: TextField(
                controller: _descController,
                style: TextStyle(color: textWhite, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Task Description',
                  hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                  filled: true,
                  fillColor: bgDark,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentBlue, width: 1.5)),
                ),
              ),
            ),
          ] else ...[
            Text(
              _task!['title'] ?? 'Untitled Task',
              style: TextStyle(color: textWhite, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _task!['description'] != null && _task!['description'].toString().trim().isNotEmpty
                  ? _task!['description']
                  : 'No description provided.',
              style: TextStyle(color: textMuted, fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataGrid() {
    final String priority = (_task!['priority'] ?? 'normal').toString().toLowerCase();
    final String? dueDateStr = _task!['due_date'];
    DateTime? dueDate;
    if (dueDateStr != null) {
      try {
        dueDate = DateTime.parse(dueDateStr);
      } catch (_) {}
    }

    final job = _task!['job'] as Map<String, dynamic>?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Task Overview', style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 14),
          // Priority Selector Row
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 18, color: textMuted),
              const SizedBox(width: 10),
              Text('Priority:', style: TextStyle(color: textMuted, fontSize: 13)),
              const Spacer(),
              _buildPriorityDropdown(priority),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF334155)),
          // Due Date Picker Row
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 18, color: textMuted),
              const SizedBox(width: 10),
              Text('Due Date:', style: TextStyle(color: textMuted, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final initial = dueDate ?? DateTime.now().add(const Duration(days: 1));
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: initial,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: ColorScheme.dark(primary: accentBlue, surface: cardBg, onSurface: textWhite),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    final time = dueDate != null ? TimeOfDay(hour: dueDate.hour, minute: dueDate.minute) : const TimeOfDay(hour: 17, minute: 0);
                    final full = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                    _updateTaskField({'due_date': full.toIso8601String()});
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dueDate != null ? DateFormat('MMM d, yyyy • h:mm a').format(dueDate) : 'Set Due Date',
                        style: TextStyle(color: textWhite, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.edit_calendar_rounded, size: 14, color: accentBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF334155)),
          // Assignee Row
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 18, color: textMuted),
              const SizedBox(width: 10),
              Text('Assignee:', style: TextStyle(color: textMuted, fontSize: 13)),
              const Spacer(),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _task!['assigned_to'] as int?,
                    dropdownColor: cardBg,
                    isDense: true,
                    hint: Text('Unassigned', style: TextStyle(color: textMuted, fontSize: 12)),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 16),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Unassigned', style: TextStyle(color: textMuted, fontSize: 12)),
                      ),
                      ..._staffOptions.map((s) {
                        final name = s['name'] ?? '${s['first_name'] ?? ''} ${s['last_name'] ?? ''}'.trim();
                        return DropdownMenuItem<int?>(
                          value: s['id'] as int,
                          child: Text(name, style: TextStyle(color: textWhite, fontSize: 12)),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) {
                      _updateTaskField({'assigned_to': val});
                    },
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF334155)),
          // Duration Row
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 18, color: textMuted),
              const SizedBox(width: 10),
              Text('Estimated Duration:', style: TextStyle(color: textMuted, fontSize: 13)),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  final durController = TextEditingController(
                    text: _task!['estimated_duration_minutes']?.toString() ?? '',
                  );
                  final newDur = await showDialog<int?>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: cardBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: cardBorder),
                      ),
                      title: Text('Estimated Duration', style: TextStyle(color: textWhite, fontSize: 16, fontWeight: FontWeight.bold)),
                      content: SizedBox(
                        height: 40,
                        child: TextField(
                          controller: durController,
                          keyboardType: TextInputType.number,
                          style: TextStyle(color: textWhite, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Minutes (e.g. 60)',
                            hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                            suffixText: 'mins',
                            suffixStyle: TextStyle(color: textMuted, fontSize: 12),
                            filled: true,
                            fillColor: bgDark,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: cardBorder)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: accentBlue, width: 1.5)),
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: Text('Cancel', style: TextStyle(color: textMuted)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
                          onPressed: () {
                            final val = int.tryParse(durController.text.trim());
                            Navigator.pop(ctx, val);
                          },
                          child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                  if (newDur != null) {
                    _updateTaskField({'estimated_duration_minutes': newDur});
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _task!['estimated_duration_minutes'] != null
                            ? '${_task!['estimated_duration_minutes']} mins'
                            : 'Set Duration',
                        style: TextStyle(color: textWhite, fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit_rounded, size: 12, color: accentBlue),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24, color: Color(0xFF334155)),
          // Billable Row
          Row(
            children: [
              Icon(Icons.monetization_on_outlined, size: 18, color: _task!['billable'] == true ? successGreen : textMuted),
              const SizedBox(width: 10),
              Text('Billable:', style: TextStyle(color: textMuted, fontSize: 13)),
              const Spacer(),
              Container(
                height: 40,
                alignment: Alignment.centerRight,
                child: Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: _task!['billable'] == true,
                    activeThumbColor: successGreen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      _updateTaskField({'billable': val});
                    },
                  ),
                ),
              ),
            ],
          ),
          if (job != null) ...[
            const Divider(height: 24, color: Color(0xFF334155)),
            // Linked Job Row (Clickable)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SharedJobDetailScreen(jobId: job['id'])),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.work_outline_rounded, size: 18, color: purple),
                  const SizedBox(width: 10),
                  Text('Linked Job:', style: TextStyle(color: textMuted, fontSize: 13)),
                  const Spacer(),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: purple.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${job['job_number'] ?? 'JOB-${job['id']}'} - ${job['title'] ?? ''}',
                          style: TextStyle(color: purple, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.open_in_new_rounded, size: 13, color: purple),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriorityDropdown(String currentPriority) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgDark,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: ['low', 'normal', 'high', 'urgent'].contains(currentPriority) ? currentPriority : 'normal',
          dropdownColor: cardBg,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: textMuted, size: 16),
          items: const [
            DropdownMenuItem(value: 'low', child: Text('Low', style: TextStyle(color: Colors.grey, fontSize: 12))),
            DropdownMenuItem(value: 'normal', child: Text('Normal', style: TextStyle(color: Colors.blue, fontSize: 12))),
            DropdownMenuItem(value: 'high', child: Text('High', style: TextStyle(color: Colors.orange, fontSize: 12))),
            DropdownMenuItem(value: 'urgent', child: Text('Urgent', style: TextStyle(color: Colors.red, fontSize: 12))),
          ],
          onChanged: (val) {
            if (val != null) {
              _updateTaskField({'priority': val});
            }
          },
        ),
      ),
    );
  }

  Widget _buildSubtasksSection() {
    final int total = _subtasks.length;
    final int completed = _subtasks.where((s) => s['task_status'] == 'completed').length;
    final double progress = total > 0 ? (completed / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Subtasks & Checklist ($completed/$total)',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}% Done',
                style: TextStyle(
                  color: progress == 1.0 ? successGreen : accentBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // Plus icon above section to reveal or hide subtask input
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showAddSubtask = !_showAddSubtask;
                  });
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _showAddSubtask ? urgentRed.withValues(alpha: 0.15) : accentBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _showAddSubtask ? urgentRed.withValues(alpha: 0.3) : accentBlue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    _showAddSubtask ? Icons.close_rounded : Icons.add_rounded,
                    size: 16,
                    color: _showAddSubtask ? urgentRed : accentBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: bgDark,
              valueColor: AlwaysStoppedAnimation<Color>(progress == 1.0 ? successGreen : accentBlue),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 14),
          // Subtasks list
          if (_subtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _showAddSubtask
                    ? 'Enter checklist item below.'
                    : 'No subtasks yet. Click + above to add checklist items.',
                style: TextStyle(color: textMuted, fontSize: 13),
              ),
            )
          else
            ..._subtasks.map((st) {
              final bool isDone = st['task_status'] == 'completed';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _confirmToggleSubtaskStatus(st),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isDone ? successGreen : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: isDone ? successGreen : textMuted, width: 1.5),
                        ),
                        child: isDone ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        st['title'] ?? '',
                        style: TextStyle(
                          color: isDone ? textMuted : textWhite,
                          fontSize: 14,
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: textMuted.withOpacity(0.7), size: 16),
                      onPressed: () => _confirmDeleteSubtask(st),
                    ),
                  ],
                ),
              );
            }).toList(),
          // Add subtask inline (visible only when top plus icon is clicked)
          if (_showAddSubtask) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _newSubtaskController,
                      autofocus: true,
                      style: TextStyle(color: textWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Add new subtask...',
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
                      onSubmitted: (_) => _addSubtask(),
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
                    icon: _isAddingSubtask
                        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: accentBlue, strokeWidth: 2))
                        : Icon(Icons.add_rounded, color: accentBlue, size: 20),
                    onPressed: _isAddingSubtask ? null : _addSubtask,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_bubble_outline_rounded, size: 16, color: textMuted),
              const SizedBox(width: 8),
              Text(
                'Activity & Comments (${_comments.length})',
                style: TextStyle(color: textMuted, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_comments.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No comments yet. Post an update or note below.', style: TextStyle(color: textMuted, fontSize: 13)),
            )
          else
            ..._comments.map((c) {
              final creator = c['creator'] as Map<String, dynamic>?;
              final creatorName = creator != null
                  ? '${creator['first_name'] ?? ''} ${creator['last_name'] ?? ''}'.trim()
                  : 'User';
              final createdAt = c['created_at'] != null ? DateTime.tryParse(c['created_at']) : null;
              final timeStr = createdAt != null ? DateFormat('MMM d, h:mm a').format(createdAt) : '';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cardBorder.withOpacity(0.6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: accentBlue.withOpacity(0.2),
                          child: Text(
                            creatorName.isNotEmpty ? creatorName[0].toUpperCase() : 'U',
                            style: TextStyle(color: accentBlue, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          creatorName,
                          style: TextStyle(color: textWhite, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          timeStr,
                          style: TextStyle(color: textMuted.withOpacity(0.7), fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      c['content'] ?? '',
                      style: TextStyle(color: textWhite.withOpacity(0.9), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              );
            }).toList(),
          const SizedBox(height: 8),
          // Comment input
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Write a comment or note...',
                      hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.6), fontSize: 13),
                      filled: true,
                      fillColor: bgDark,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: accentBlue, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _submitComment(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentBlue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: _isPostingComment
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  onPressed: _isPostingComment ? null : _submitComment,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: cardBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isCompleted ? const Color(0xFF475569) : successGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _confirmToggleTaskStatus,
          icon: Icon(
            isCompleted ? Icons.replay_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 20,
          ),
          label: Text(
            isCompleted ? 'Mark as Incomplete' : 'Mark as Completed',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

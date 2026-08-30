import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'toast_service.dart';
import '../app_state.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  @override
  _NotificationPreferencesScreenState createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  bool _pushJobAssigned = true;
  bool _pushJobCompleted = true;
  bool _smsJobAssigned = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final user = await ApiService.instance.getMe();
      if (user['preferences'] != null) {
        final prefs = user['preferences'] as Map<String, dynamic>;
        setState(() {
          _pushJobAssigned = prefs['push_job_assigned'] ?? true;
          _pushJobCompleted = prefs['push_job_completed'] ?? true;
          _smsJobAssigned = prefs['sms_job_assigned'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error loading preferences: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateProfile({
        'preferences': {
          'push_job_assigned': _pushJobAssigned,
          'push_job_completed': _pushJobCompleted,
          'sms_job_assigned': _smsJobAssigned,
        }
      });
      if (mounted) {
        ToastService.success(context, 'Notification preferences saved');
        // Update AppState user if needed
        final updatedUser = await ApiService.instance.getMe();
        // Assuming app_state.dart has a way to update the user, or it's handled by stream
      }
    } catch (e) {
      if (mounted) {
        ToastService.error(context, 'Failed to save preferences');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        title: const Text('Notification Preferences', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Push Notifications (App)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  title: 'New Job Assigned',
                  subtitle: 'Get a push notification when you are assigned a new job.',
                  value: _pushJobAssigned,
                  onChanged: (val) => setState(() => _pushJobAssigned = val),
                  icon: Icons.assignment_ind,
                ),
                _buildSwitchTile(
                  title: 'Job Completed',
                  subtitle: 'Get a push notification when your job is marked complete.',
                  value: _pushJobCompleted,
                  onChanged: (val) => setState(() => _pushJobCompleted = val),
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 32),
                const Text(
                  'SMS Notifications (Text)',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildSwitchTile(
                  title: 'New Job Assigned (SMS)',
                  subtitle: 'Get a text message when you are urgently assigned a new job.',
                  value: _smsJobAssigned,
                  onChanged: (val) => setState(() => _smsJobAssigned = val),
                  icon: Icons.sms,
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isSaving ? null : _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF3B82F6), size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF10B981),
          ),
        ],
      ),
    );
  }
}

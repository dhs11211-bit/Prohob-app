import 'package:intl/intl.dart';

class JobParser {
  /// Strictly determines if a job is recurring or part of a recurring series.
  static bool isRecurring(Map<String, dynamic>? jobData) {
    if (jobData == null) return false;
    
    // Check for parent ID robustly
    final parentIdStr = jobData['recurring_parent_id']?.toString().trim();
    final jobIdStr = jobData['id']?.toString().trim();
    
    bool hasParent = parentIdStr != null && 
                     parentIdStr != '0' && 
                     parentIdStr != '' && 
                     parentIdStr.toLowerCase() != 'null' &&
                     parentIdStr != jobIdStr;
    
    // Helper to robustly check boolean/integer flags
    bool isTruthy(dynamic val) {
      if (val == null) return false;
      final str = val.toString().trim().toLowerCase();
      return str == 'true' || str == '1';
    }

    bool hasPattern = jobData['recurring_pattern'] != null && 
                      jobData['recurring_pattern'].toString().trim().isNotEmpty && 
                      jobData['recurring_pattern'].toString().trim() != '[]' &&
                      jobData['recurring_pattern'].toString().trim() != '{}' &&
                      jobData['recurring_pattern'].toString().trim().toLowerCase() != 'null';

    return hasParent ||
           isTruthy(jobData['is_template']) ||
           isTruthy(jobData['is_recurring']) ||
           hasPattern ||
           isTruthy(jobData['is_recurring_instance']) ||
           isTruthy(jobData['recurring']) ||
           jobData['job_type']?.toString().toLowerCase() == 'recurring';
  }

  /// Strictly extracts the true start date of a job based ONLY on start_date and start_time.
  /// Never falls back to scheduled_time or created_at timestamps.
  static DateTime? getStartDate(Map<String, dynamic>? jobData) {
    if (jobData == null) return null;
    
    // 1. Try to parse actual start_date and start_time
    if (jobData['start_date'] != null) {
      try {
        final dateStr = jobData['start_date'].toString().split('T')[0];
        final timeStr = jobData['start_time']?.toString() ?? '00:00:00';
        return DateTime.parse('${dateStr}T$timeStr').toLocal();
      } catch (_) {}
    }
    
    return null; // Return null explicitly if start_date is missing, do NOT fallback to scheduled_time!
  }
}

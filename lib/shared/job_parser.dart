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
  static DateTime? getStartDate(Map<String, dynamic>? jobData) {
    if (jobData == null) return null;

    // 1. Try to parse actual start_date and start_time
    if (jobData['start_date'] != null) {
      try {
        final rawDate = jobData['start_date'].toString().trim();
        final dateStr = rawDate.split('T')[0].split(' ')[0];
        final timeStr = jobData['start_time']?.toString().trim();
        if (timeStr != null && timeStr.isNotEmpty) {
          return DateTime.parse('${dateStr}T$timeStr').toLocal();
        }
        return DateTime.parse(dateStr).toLocal();
      } catch (_) {}
    }

    return null;
  }

  /// Strictly extracts the true end date of a job based on end_date and end_time.
  static DateTime? getEndDate(Map<String, dynamic>? jobData) {
    if (jobData == null) return null;

    if (jobData['end_date'] != null) {
      try {
        final rawDate = jobData['end_date'].toString().trim();
        final dateStr = rawDate.split('T')[0].split(' ')[0];
        final timeStr = jobData['end_time']?.toString().trim();
        if (timeStr != null && timeStr.isNotEmpty) {
          return DateTime.parse('${dateStr}T$timeStr').toLocal();
        }
        return DateTime.parse(dateStr).toLocal();
      } catch (_) {}
    }

    return null;
  }
}

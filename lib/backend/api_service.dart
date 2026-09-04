import 'dart:convert';
import '../auth/laravel_auth_manager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:http_parser/http_parser.dart';
import 'offline_sync_service.dart';
import 'location_tracking_service.dart';
import '../shared/index.dart' as shared;

class ValidationException implements Exception {
  final Map<String, dynamic> errors;
  ValidationException(this.errors);
  @override
  String toString() => 'Validation Failed';
}

class ApiService {
  static String get baseUrl {
    if (!kReleaseMode) {
      if (kIsWeb) return 'http://localhost:8000/api/mob';
      if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/mob';
      return 'http://localhost:8000/api/mob';
    }

    // Live Production Server
    return 'https://api.serviceprohob.com/api/mob';
  }

  static const _storage = FlutterSecureStorage();

  // Singleton instance
  ApiService._privateConstructor();
  static final ApiService instance = ApiService._privateConstructor();

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> _getToken() async {
    return await getToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final clId = await _storage.read(key: 'active_cl_id');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (clId != null) 'X-CL-ID': clId,
    };
  }

  dynamic _unwrapData(dynamic data) {
    if (data is Map &&
        data['status'] == 'success' &&
        data.containsKey('data')) {
      return data['data'];
    }
    return data;
  }

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> login(String email, String password,
      {int? clId}) async {
    final url = Uri.parse('$baseUrl/auth/login');

    final body = <String, dynamic>{'email': email, 'password': password};
    if (clId != null) body['cl_id'] = clId;

    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    final url = Uri.parse('$baseUrl/auth/logout');
    await http.post(url, headers: await _getHeaders());
  }

  Future<Map<String, dynamic>> getMe() async {
    final url = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data['data']; // Returns user object
    } else {
      throw Exception(data['message'] ?? 'Failed to get user');
    }
  }

  Future<Map<String, dynamic>> getPublicSettings() async {
    final url = Uri.parse('$baseUrl/public/settings');
    final response =
        await http.get(url, headers: {'Accept': 'application/json'});

    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data['data'] ?? {};
    } else {
      throw Exception(data['message'] ?? 'Failed to get public settings');
    }
  }

  // --- Dashboard Endpoints ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final url = Uri.parse('$baseUrl/dashboard');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to load dashboard stats');
    }
  }

  // --- Chat Media Upload ---
  Future<Map<String, dynamic>> uploadChatMedia(
      int chatId, List<int> fileBytes, String fileName) async {
    final url = Uri.parse(baseUrl.replaceAll('/mob', '') + '/conversations/$chatId/media');

    var request = http.MultipartRequest('POST', url);
    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');

    request.headers.addAll({
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    });

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _getMediaType(fileName),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data); // Returns {id, url, filename}
    } else {
      throw Exception(data['message'] ?? 'Failed to upload media');
    }
  }

  // --- Job Endpoints ---
  Future<List<dynamic>> getTodayJobs() async {
    try {
      final url = Uri.parse('$baseUrl/jobs/today');
      final response = await http.get(url, headers: await _getHeaders());

      final data = jsonDecode(response.body);
      if (response.statusCode == 401) {
        LaravelAuthManager.signOut();
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jobsList = _unwrapData(data) as List<dynamic>;
        OfflineSyncService.instance.cacheJobs(jobsList);
        return jobsList;
      } else {
        throw Exception(data['message'] ?? 'Failed to load today jobs');
      }
    } catch (e) {
      return await OfflineSyncService.instance.getCachedJobs();
    }
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final url = Uri.parse('$baseUrl/subscriptions/plans');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data['data'] != null ? data['data'] : data;
    } else {
      throw Exception(data['message'] ?? 'Failed to load subscription plans');
    }
  }

  // Unified Jobs Endpoint
  Future<dynamic> getJobs({
    String? date,
    String? startDate,
    String? endDate,
    String? fromDate,
    String? untilDate,
    int? limit,
    int? page,
    int? customerId,
  }) async {
    final params = <String, dynamic>{};
    if (date != null) params['date'] = date;
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;
    if (fromDate != null) params['from_date'] = fromDate;
    if (untilDate != null) params['until_date'] = untilDate;
    if (limit != null) params['limit'] = limit;
    if (page != null) params['page'] = page;
    if (customerId != null) params['customer_id'] = customerId;

    return await get('/jobs', queryParams: params);
  }

  Future<dynamic> getAdminJobs(
      {String? startDate,
      String? endDate,
      String? fromDate,
      String? untilDate,
      int? limit,
      int? page}) async {
    return await getJobs(
      startDate: startDate,
      endDate: endDate,
      fromDate: fromDate,
      untilDate: untilDate,
      limit: limit,
      page: page,
    );
  }

  Future<dynamic> getMyJobs(
      {String? startDate,
      String? endDate,
      String? fromDate,
      String? untilDate,
      int? limit,
      int? page}) async {
    return await getJobs(
      startDate: startDate,
      endDate: endDate,
      fromDate: fromDate,
      untilDate: untilDate,
      limit: limit,
      page: page,
    );
  }

  Future<void> cancelJob(int jobId) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/cancel');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to cancel job');
    }
  }

  Future<void> softDeleteJob(int jobId) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/soft-delete');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete job');
    }
  }

  Future<void> cancelRecurringJob(int parentId) async {
    final base = baseUrl.replaceAll('/mob', '');
    final url = Uri.parse('$base/recurring-jobs/$parentId/cancel');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to cancel recurring job');
    }
  }

  Future<void> deleteRecurringJob(int parentId) async {
    final base = baseUrl.replaceAll('/mob', '');
    final url = Uri.parse('$base/recurring-jobs/$parentId');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete recurring job');
    }
  }

  Future<void> updateJobStatus(int jobId, String status) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/status');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update status');
    }
  }
  // --- Clock Endpoints ---
  Future<Map<String, dynamic>> getClockStatus([int? jobId]) async {
    // Add timestamp to prevent browser/OS level caching of the GET request
    String urlStr = '$baseUrl/clock/status?_t=${DateTime.now().millisecondsSinceEpoch}';
    if (jobId != null) {
      urlStr += '&job_id=$jobId';
    }
    final url = Uri.parse(urlStr);
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to get clock status');
    }
  }

  Future<Map<String, dynamic>> clockIn(
      int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/clock/in');
    final now = DateTime.now();
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'job_id': jobId,
        'latitude': lat,
        'longitude': lng,
        'start_date': now.toIso8601String().split('T')[0],
        'start_time': now.toIso8601String().substring(11, 16),
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        LocationTrackingService.instance.startTracking();
      } catch (e) {
        print('Could not start GPS tracking: $e');
      }
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to clock in');
    }
  }

  Future<Map<String, dynamic>> startDriving(int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'job_status': 'en_route'
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to start driving');
    }
  }

  Future<Map<String, dynamic>> clockOut(
      int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/clock/out');
    final now = DateTime.now();
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'job_id': jobId,
        'latitude': lat,
        'longitude': lng,
        'end_date': now.toIso8601String().split('T')[0],
        'end_time': now.toIso8601String().substring(11, 16),
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        LocationTrackingService.instance.stopTracking();
      } catch (e) {
        print('Could not stop GPS tracking: $e');
      }
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to clock out');
    }
  }

  Future<Map<String, dynamic>> clockBreak(
      int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/clock/break');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'job_id': jobId,
        'latitude': lat,
        'longitude': lng,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to toggle break');
    }
  }

  Future<Map<String, dynamic>> submitSwapRequest(
      int jobId, String reason, String details) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/swap-request');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({
        'reason': reason,
        'details': details,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to submit swap request');
    }
  }

  Future<void> cancelSwapRequest(int jobId) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/swap-request');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to cancel swap request');
    }
  }


  Future<void> updateChecklist(int jobId, String taskName, bool isDone) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/checklist');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'task_name': taskName, 'is_done': isDone}),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
  }

  Future<Map<String, dynamic>> uploadAttachment(String entityType, int entityId, List<int> fileBytes, String fileName) async {
    String url = baseUrl.replaceAll('/mob', '') + '/attachments';
    final token = await _getToken();

    var request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['entity_type'] = entityType;
    request.fields['entity_id'] = entityId.toString();

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode >= 400) {
      throw Exception('Failed to upload attachment');
    }
    return jsonDecode(response.body);
  }

  Future<dynamic> sendJobAlert(Map<String, dynamic> data) async {
    return await post('/jobs/${data['job_id']}/alert', data);
  }

  // --- Generic Endpoints ---
  Future<Map<String, dynamic>> _request(String method, String endpoint,
      {Map<String, dynamic>? queryParameters, Map<String, dynamic>? body}) async {
    dynamic result;
    switch (method.toUpperCase()) {
      case 'GET':
        result = await get(endpoint, queryParams: queryParameters);
        break;
      case 'POST':
        result = await post(endpoint, body ?? {});
        break;
      case 'PUT':
        result = await put(endpoint, body ?? {});
        break;
      case 'DELETE':
        result = await delete(endpoint);
        break;
      default:
        throw Exception('Method $method not supported');
    }
    if (result is Map<String, dynamic>) return result;
    if (result is List) return {'data': result};
    return {};
  }

  Future<dynamic> get(String endpoint,
      {Map<String, dynamic>? queryParams}) async {
    String urlStr = endpoint.startsWith('http')
        ? endpoint
        : '$baseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}';

    if (queryParams != null && queryParams.isNotEmpty) {
      List<String> parts = [];
      queryParams.forEach((k, v) {
        if (v != null) parts.add('$k=${Uri.encodeComponent(v.toString())}');
      });
      if (parts.isNotEmpty) {
        urlStr += (urlStr.contains('?') ? '&' : '?') + parts.join('&');
      }
    }

    final response = await http.get(
      Uri.parse(urlStr),
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to GET $endpoint');
    }
  }

  Future<dynamic> post(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse(
        '$baseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode == 422 && data['errors'] != null) {
      throw ValidationException(data['errors']);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to POST $endpoint');
    }
  }

  Future<dynamic> put(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse(
        '$baseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode == 422 && data['errors'] != null) {
      throw ValidationException(data['errors']);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to PUT $endpoint');
    }
  }

  Future<dynamic> patch(String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse(
        '$baseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}');
    final response = await http.patch(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(body),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to PATCH $endpoint');
    }
  }

  Future<dynamic> delete(String endpoint) async {
    final url = Uri.parse(
        '$baseUrl${endpoint.startsWith('/') ? endpoint : '/$endpoint'}');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to DELETE $endpoint');
    }
  }
  // --- Phase 5: Jobs Mobile Endpoints ---

  Future<Map<String, dynamic>> getJobMaterials(int jobId) async {
    String url = baseUrl.replaceAll('/mob', '') + '/jobs/$jobId/materials';
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    return jsonDecode(response.body);
  }

  Future<void> updateJobMaterialStatus(int materialId, String status) async {
    String url = baseUrl.replaceAll('/mob', '') + '/job-materials/$materialId';
    final response = await http.put(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
  }

  Future<Map<String, dynamic>> getJobNotes(int jobId) async {
    String url = baseUrl.replaceAll('/mob', '') +
        '/notes?entity_type=job&entity_id=$jobId';
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    return jsonDecode(response.body);
  }

  Future<void> addNote(Map<String, dynamic> payload) async {
    String url = baseUrl.replaceAll('/mob', '') + '/notes';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({
        'entity_type': payload['entity_type'] ?? 'job',
        'entity_id': payload['entity_id'] ?? payload['job_id'],
        'note': payload['note'],
        'visibility': payload['visibility'] ?? 'internal'
      }),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
  }

  Future<void> updateRelationalChecklist(
      int checklistId, Map<String, dynamic> payload) async {
    String url = baseUrl.replaceAll('/mob', '') + '/checklists/$checklistId';
    final response = await http.put(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
  }

  Future<Map<String, dynamic>> getChecklistCompletionStatus(int jobId) async {
    String url = baseUrl.replaceAll('/mob', '') +
        '/jobs/$jobId/checklist-completion-status';
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    return jsonDecode(response.body);
  }

  Future<void> completeJobWithSignature(
      int jobId, String signatureBase64) async {
    String url = baseUrl.replaceAll('/mob', '') + '/jobs/$jobId/complete';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({
        'signature_base64': signatureBase64,
      }),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
  }

  Future<Map<String, dynamic>> getJobAlerts(int jobId) async {
    String url = baseUrl.replaceAll('/mob', '') + '/jobs/$jobId/alerts';
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    return jsonDecode(response.body);
  }

  Future<void> duplicateJob(int jobId) async {
    String url = baseUrl.replaceAll('/mob', '') + '/jobs/$jobId/duplicate';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
    );
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    // Could return newly created Job ID if needed.
  }

  // --- Chat Endpoints ---
  Future<void> deleteConversation(int conversationId) async {
    String url =
        baseUrl.replaceAll('/mob', '') + '/conversations/$conversationId';
    final response =
        await http.delete(Uri.parse(url), headers: await _getHeaders());
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete conversation');
    }
  }

  Future<Map<String, dynamic>> getConversations({String? type}) async {
    String url = baseUrl.replaceAll('/mob', '') + '/conversations';
    if (type != null) {
      url += '?type=$type';
    }
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to GET conversations');
    }
  }

  Future<Map<String, dynamic>> getConversationThread(int conversationId) async {
    String url =
        baseUrl.replaceAll('/mob', '') + '/conversations/$conversationId';
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to GET thread');
    }
  }

  Future<Map<String, dynamic>> sendMessage(int conversationId, String content,
      {String channel = 'in_app',
      List<Map<String, dynamic>>? attachments}) async {
    String url = baseUrl.replaceAll('/mob', '') +
        '/conversations/$conversationId/messages';

    Map<String, dynamic> payload = {
      'content': content,
      'channel': channel,
    };
    if (attachments != null) {
      payload['attachments'] = attachments;
    }

    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to send message');
    }
  }

  Future<void> markConversationAsRead(int conversationId) async {
    String url =
        baseUrl.replaceAll('/mob', '') + '/conversations/$conversationId/read';
    await http.post(Uri.parse(url), headers: await _getHeaders());
  }

  Future<Map<String, dynamic>> createConversation(
      Map<String, dynamic> payload) async {
    String url = baseUrl.replaceAll('/mob', '') + '/conversations';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to create conversation');
    }
  }

  // --- Profile Endpoints ---
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> profileData) async {
    final url = Uri.parse('$baseUrl/employee/profile');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode(profileData),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode == 422 && data['errors'] != null) {
      throw ValidationException(data['errors']);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to update profile');
    }
  }

  Future<Map<String, dynamic>> uploadDocument(
      String docType, List<int> fileBytes, String fileName) async {
    final url = Uri.parse('$baseUrl/employee/profile/document');
    final token = await _getToken();

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['docType'] = docType;

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _getMediaType(fileName),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to upload document');
    }
  }

  Future<Map<String, dynamic>> uploadEntityImage({
    required String entityType,
    required String entityId,
    required List<int> fileBytes,
    required String fileName,
    String imageType = 'gallery',
  }) async {
    final url = Uri.parse('$baseUrl/uploads/image');
    final token = await _getToken();

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['entity_type'] = entityType;
    request.fields['entity_id'] = entityId;
    request.fields['image_type'] = imageType;

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      fileBytes,
      filename: fileName,
      contentType: _getMediaType(fileName),
    ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);

    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to upload image');
    }
  }

  Future<Map<String, dynamic>> uploadJobEvidence({
    required int jobId,
    required String photoType,
    String? taskName,
    String? description,
    required List<List<int>> filesBytes,
    required List<String> fileNames,
  }) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/photos');
    final token = await _getToken();

    var request = http.MultipartRequest('POST', url);
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['photo_type'] = photoType;
    if (taskName != null) request.fields['task_name'] = taskName;
    if (description != null) request.fields['description'] = description;

    for (int i = 0; i < filesBytes.length; i++) {
      request.files.add(http.MultipartFile.fromBytes(
        'files[$i]', // backend expects files.*
        filesBytes[i],
        filename: fileNames[i],
        contentType: _getMediaType(fileNames[i]),
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (e) {
      if (response.body.trim().startsWith('<')) {
        throw Exception(
            "Server Error (${response.statusCode}): The uploaded files may exceed the server's maximum allowed size limit.");
      }
      throw Exception("Invalid response from server: ${response.body}");
    }

    if (response.statusCode == 401) {
      LaravelAuthManager.signOut();
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return _unwrapData(data);
    } else {
      throw Exception(data['message'] ?? 'Failed to upload evidence');
    }
  }

  // ==========================================
  // EVENTS MODULE
  // ==========================================

  Future<Map<String, dynamic>> getEvents({Map<String, dynamic>? params}) async {
    final queryParams = params ?? {};
    queryParams['job_type[]'] = 'event';
    return _request('GET', '/jobs', queryParameters: queryParams);
  }

  Future<Map<String, dynamic>> getEventAttendees(int eventId) async {
    return _request('GET', '/events/$eventId/attendees');
  }

  Future<Map<String, dynamic>> updateEventAttendee(int eventId, int attendeeId, Map<String, dynamic> data) async {
    return _request('PUT', '/events/$eventId/attendees/$attendeeId', body: data);
  }

  Future<Map<String, dynamic>> convertEvent(int eventId, String targetType) async {
    return _request('POST', '/jobs/$eventId/convert', body: {'target_type': targetType});
  }

  // TASKS MODULE
  // ==========================================

  Future<Map<String, dynamic>> getTasks({Map<String, dynamic>? params}) async {
    return _request('GET', '/tasks', queryParameters: params);
  }

  Future<Map<String, dynamic>> getTask(int id) async {
    return _request('GET', '/tasks/$id');
  }

  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    return _request('POST', '/tasks', body: data);
  }

  Future<Map<String, dynamic>> updateTask(int id, Map<String, dynamic> data) async {
    return _request('PUT', '/tasks/$id', body: data);
  }

  Future<Map<String, dynamic>> getTaskComments(int taskId) async {
    return _request('GET', '/tasks/$taskId/comments');
  }

  Future<Map<String, dynamic>> addTaskComment(int taskId, Map<String, dynamic> data) async {
    return _request('POST', '/tasks/$taskId/comments', body: data);
  }


  // ==========================================
  // FILE UPLOAD HELPERS
  // ==========================================
  
  MediaType _getMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'png') return MediaType('image', 'png');
    if (ext == 'gif') return MediaType('image', 'gif');
    if (ext == 'pdf') return MediaType('application', 'pdf');
    if (ext == 'mp4') return MediaType('video', 'mp4');
    if (ext == 'mov' || ext == 'qt') return MediaType('video', 'quicktime');
    return MediaType('image', 'jpeg');
  }

  Future<Map<String, dynamic>> logJobAttempt(int jobId, Map<String, dynamic> payload) async {
    return _request('POST', '/jobs/$jobId/log-attempt', body: payload);
  }
}

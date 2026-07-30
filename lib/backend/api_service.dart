import 'dart:convert';
import '../auth/laravel_auth_manager.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:http_parser/http_parser.dart';

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
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data['data']; // Returns user object
    } else {
      throw Exception(data['message'] ?? 'Failed to get user');
    }
  }

  Future<Map<String, dynamic>> getPublicSettings() async {
    final url = Uri.parse('$baseUrl/public/settings');
    final response = await http.get(url, headers: {'Accept': 'application/json'});

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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to load dashboard stats');
    }
  }

  // --- Chat Media Upload ---
  Future<Map<String, dynamic>> uploadChatMedia(
      int chatId, List<int> fileBytes, String fileName) async {
    final url = Uri.parse('$baseUrl/chat/$chatId/media');

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

    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data; // Returns {id, url, filename}
    } else {
      throw Exception(data['message'] ?? 'Failed to upload media');
    }
  }

  // --- Job Endpoints ---
  Future<List<dynamic>> getTodayJobs() async {
    final url = Uri.parse('$baseUrl/jobs/today');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data; // Returns list of jobs
    } else {
      throw Exception(data['message'] ?? 'Failed to load today jobs');
    }
  }

  Future<List<dynamic>> getSubscriptionPlans() async {
    final url = Uri.parse('$baseUrl/subscriptions/plans');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
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

  Future<void> updateJobStatus(int jobId, String status) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/status');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'status': status}),
    );
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update status');
    }
  }

  Future<void> updateChecklist(int jobId, String taskName, bool isDone) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/checklist');
    final response = await http.put(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'task_name': taskName, 'is_done': isDone}),
    );
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to update checklist');
    }
  }

  Future<void> deleteChecklist(int jobId, String taskName) async {
    final url = Uri.parse('$baseUrl/jobs/$jobId/checklist');
    final response = await http.delete(
      url,
      headers: await _getHeaders(),
      body: jsonEncode({'task_name': taskName}),
    );
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to delete checklist');
    }
  }

  // --- Clock Endpoints ---
  Future<Map<String, dynamic>> getClockStatus() async {
    final url = Uri.parse('$baseUrl/clock/status');
    final response = await http.get(url, headers: await _getHeaders());

    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to get clock status');
    }
  }

  Future<Map<String, dynamic>> clockIn(
      int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/clock/in');
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to clock in');
    }
  }

  Future<Map<String, dynamic>> clockOut(
      int jobId, double? lat, double? lng) async {
    final url = Uri.parse('$baseUrl/clock/out');
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to clock out');
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to cancel swap request');
    }
  }

  // --- Generic Endpoints ---
  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to DELETE $endpoint');
    }
  }

  // --- Chat Endpoints ---
  Future<Map<String, dynamic>> getConversations({String? type}) async {
    String url = baseUrl.replaceAll('/mob', '') + '/conversations';
    if (type != null) {
      url += '?type=$type';
    }
    final response =
        await http.get(Uri.parse(url), headers: await _getHeaders());
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to GET thread');
    }
  }

  Future<Map<String, dynamic>> sendMessage(int conversationId, String content,
      {String channel = 'in_app'}) async {
    String url = baseUrl.replaceAll('/mob', '') +
        '/conversations/$conversationId/messages';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode({
        'content': content,
        'channel': channel,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to send message');
    }
  }

  Future<void> markConversationAsRead(int conversationId) async {
    String url =
        baseUrl.replaceAll('/mob', '') + '/conversations/$conversationId/read';
    await http.post(Uri.parse(url), headers: await _getHeaders());
  }

  Future<Map<String, dynamic>> createConversation(Map<String, dynamic> payload) async {
    String url = baseUrl.replaceAll('/mob', '') + '/conversations';
    final response = await http.post(
      Uri.parse(url),
      headers: await _getHeaders(),
      body: jsonEncode(payload),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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

    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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

    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
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
    final data = jsonDecode(response.body);

    if (response.statusCode == 401) { LaravelAuthManager.signOut(); }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    } else {
      throw Exception(data['message'] ?? 'Failed to upload evidence');
    }
  }

  MediaType _getMediaType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (ext == 'png') return MediaType('image', 'png');
    if (ext == 'gif') return MediaType('image', 'gif');
    if (ext == 'pdf') return MediaType('application', 'pdf');
    if (ext == 'mp4') return MediaType('video', 'mp4');
    if (ext == 'mov' || ext == 'qt') return MediaType('video', 'quicktime');
    return MediaType('image', 'jpeg');
  }
}

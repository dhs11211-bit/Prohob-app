import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._init();
  static Database? _database;

  // In-memory fallback for web platform
  List<dynamic> _webCachedJobs = [];
  final List<Map<String, dynamic>> _webRequestQueue = [];

  OfflineSyncService._init();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    try {
      _database = await _initDB('offline_sync.db');
      return _database!;
    } catch (e) {
      print('OfflineSyncService _initDB error: $e');
      return null;
    }
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE request_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        method TEXT NOT NULL,
        headers TEXT NOT NULL,
        body TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE cached_jobs (
        id INTEGER PRIMARY KEY,
        job_data TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> cacheJobs(List<dynamic> jobs) async {
    if (kIsWeb) {
      _webCachedJobs = List.from(jobs);
      return;
    }
    try {
      final db = await instance.database;
      if (db == null) {
        _webCachedJobs = List.from(jobs);
        return;
      }
      Batch batch = db.batch();
      batch.delete('cached_jobs'); // clear old cache
      for (var job in jobs) {
        batch.insert('cached_jobs', {
          'id': job['id'],
          'job_data': jsonEncode(job),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      await batch.commit(noResult: true);
    } catch (e) {
      print('OfflineSyncService cacheJobs error: $e');
      _webCachedJobs = List.from(jobs);
    }
  }

  Future<List<dynamic>> getCachedJobs() async {
    if (kIsWeb) {
      return _webCachedJobs;
    }
    try {
      final db = await instance.database;
      if (db == null) return _webCachedJobs;
      final List<Map<String, dynamic>> maps = await db.query('cached_jobs');
      return maps.map((m) => jsonDecode(m['job_data'])).toList();
    } catch (e) {
      print('OfflineSyncService getCachedJobs error: $e');
      return _webCachedJobs;
    }
  }

  Future<void> enqueueRequest(String url, String method, Map<String, String> headers, dynamic body) async {
    if (kIsWeb) {
      _webRequestQueue.add({
        'url': url,
        'method': method,
        'headers': jsonEncode(headers),
        'body': body != null ? jsonEncode(body) : null,
        'created_at': DateTime.now().toIso8601String(),
      });
      syncQueue();
      return;
    }
    try {
      final db = await instance.database;
      if (db == null) return;
      await db.insert('request_queue', {
        'url': url,
        'method': method,
        'headers': jsonEncode(headers),
        'body': body != null ? jsonEncode(body) : null,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // Attempt sync immediately if possible
      syncQueue();
    } catch (e) {
      print('OfflineSyncService enqueueRequest error: $e');
    }
  }

  Future<void> syncQueue() async {
    if (kIsWeb) {
      if (_webRequestQueue.isEmpty) return;
      final toProcess = List<Map<String, dynamic>>.from(_webRequestQueue);
      for (var row in toProcess) {
        try {
          final headers = Map<String, String>.from(jsonDecode(row['headers']));
          final url = Uri.parse(row['url']);
          final method = row['method'];
          final body = row['body'];

          http.Response response;
          if (method == 'POST') {
            response = await http.post(url, headers: headers, body: body);
          } else if (method == 'PUT') {
            response = await http.put(url, headers: headers, body: body);
          } else if (method == 'DELETE') {
            response = await http.delete(url, headers: headers);
          } else {
            continue;
          }

          if (response.statusCode >= 200 && response.statusCode < 500) {
            _webRequestQueue.remove(row);
          }
        } catch (e) {
          break;
        }
      }
      return;
    }

    try {
      final db = await instance.database;
      if (db == null) return;
      final List<Map<String, dynamic>> maps = await db.query('request_queue', orderBy: 'created_at ASC');

      for (var row in maps) {
        try {
          final headers = Map<String, String>.from(jsonDecode(row['headers']));
          final url = Uri.parse(row['url']);
          final method = row['method'];
          final body = row['body'];

          http.Response response;
          if (method == 'POST') {
            response = await http.post(url, headers: headers, body: body);
          } else if (method == 'PUT') {
            response = await http.put(url, headers: headers, body: body);
          } else if (method == 'DELETE') {
            response = await http.delete(url, headers: headers);
          } else {
            continue; // Unsupported
          }

          if (response.statusCode >= 200 && response.statusCode < 300) {
            await db.delete('request_queue', where: 'id = ?', whereArgs: [row['id']]);
          } else {
            // If 4xx error, it might never succeed, but we keep it simple here
            if (response.statusCode >= 400 && response.statusCode < 500) {
              await db.delete('request_queue', where: 'id = ?', whereArgs: [row['id']]);
            }
          }
        } catch (e) {
          // Network error, stop syncing
          break;
        }
      }
    } catch (e) {
      print('OfflineSyncService syncQueue error: $e');
    }
  }
}
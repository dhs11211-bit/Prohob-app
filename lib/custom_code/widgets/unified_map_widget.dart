// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import '/components/global_chat_modal.dart';
import 'package:flutter/rendering.dart'; // 🚀 FIX: Librería para el editor de fotos
import 'dart:io'; // 🚀 FIX: Librería para subir archivos
import 'dart:typed_data'; // 🚀 FIX: Librería para procesar imágenes
import '/backend/api_service.dart';
import '../../auth/laravel_auth_manager.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
// =====================================================================
// 🚀 COMPONENTES DEL EDITOR DE FOTOS NATIVO (PARA EL CHAT)
import '../../shared/image_editor_helper.dart';

// =====================================================================
// 🚀 WIDGET PRINCIPAL DE MAPA
// =====================================================================
class UnifiedMapWidget extends StatefulWidget {
  const UnifiedMapWidget({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;

  @override
  State<UnifiedMapWidget> createState() => _UnifiedMapWidgetState();
}

class _UnifiedMapWidgetState extends State<UnifiedMapWidget> {
  static const maps.LatLng _centerCoords = maps.LatLng(41.3286, -74.1847);

  // Removed Firebase currentUser, using global currentUser from laravel_auth_manager.dart
  String _adminName = "Admin";
  String _adminFirstName = "";
  int? _adminId;
  String _adminLastName = "";
  maps.GoogleMapController? _mapController;

  int _selectedFilter = 0;
  double _currentZoom = 13.5;
  double _lastGeneratedZoom = 13.5;

  maps.BitmapDescriptor? _jobIcon;
  maps.BitmapDescriptor? _workerIcon;

  List<dynamic> _allJobs = [];
  List<dynamic> _staffLocations = [];
  bool _isLoading = true;
  bool _isMapCreated = false;
  String? _googleMapsApiKey;
  bool get isWorker {
    if (currentUser == null) return false;
    try {
      final data = (currentUser as dynamic).userData;
      return data?['role'] == 'worker';
    } catch (_) {
      return false;
    }
  }

  Future<void> _fitBounds() async {
    if (_mapController == null || !mounted || !_isMapCreated) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) return _fitBounds();
      return;
    }
    
    double? minLat, maxLat, minLng, maxLng;
    
    void updateBounds(double lat, double lng) {
      if (minLat == null || lat < minLat!) minLat = lat;
      if (maxLat == null || lat > maxLat!) maxLat = lat;
      if (minLng == null || lng < minLng!) minLng = lng;
      if (maxLng == null || lng > maxLng!) maxLng = lng;
    }

    if (_selectedFilter == 0 || _selectedFilter == 1) {
      for (var job in _allJobs) {
        if (job is Map) {
          double? lat = job['latitude'] != null ? double.tryParse(job['latitude'].toString()) : null;
          double? lng = job['longitude'] != null ? double.tryParse(job['longitude'].toString()) : null;
          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            updateBounds(lat, lng);
          }
        }
      }
    }

    if (_selectedFilter == 0 || _selectedFilter == 2) {
      for (var worker in _staffLocations) {
        if (worker is Map) {
          double? lat = worker['latitude'] != null ? double.tryParse(worker['latitude'].toString()) : null;
          double? lng = worker['longitude'] != null ? double.tryParse(worker['longitude'].toString()) : null;
          if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
            updateBounds(lat, lng);
          }
        }
      }
    }

    if (minLat != null && maxLat != null && minLng != null && maxLng != null) {
      if (minLat == maxLat) {
        minLat = minLat! - 0.005;
        maxLat = maxLat! + 0.005;
      }
      if (minLng == maxLng) {
        minLng = minLng! - 0.005;
        maxLng = maxLng! + 0.005;
      }
      
      try {
        maps.LatLngBounds bounds = maps.LatLngBounds(
          southwest: maps.LatLng(minLat!, minLng!),
          northeast: maps.LatLng(maxLat!, maxLng!),
        );
        await _mapController!.animateCamera(maps.CameraUpdate.newLatLngBounds(bounds, 50.0));
      } catch (e) {
        debugPrint("Error animating camera: $e");
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) return _fitBounds();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadCustomMarkers();
    _fetchGoogleMapsKey().then((_) {
      Future.wait([
        _fetchJobs(),
        _fetchStaffLocations(),
      ]).then((_) async {
        await _fitBounds();
        if (mounted && _isLoading) setState(() => _isLoading = false);
      });
    });
  }

  Future<void> _fetchGoogleMapsKey() async {
    try {
      final response = await ApiService.instance.get('/public/settings');
      if (mounted && response is Map && response.containsKey('data')) {
        final settings = response['data'];
        if (settings is Map && settings.containsKey('google_maps_api_key')) {
          _googleMapsApiKey = settings['google_maps_api_key'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching maps key: $e");
    }
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty || address.isEmpty) return null;
    try {
      final url = Uri.parse("https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(address)}&key=$_googleMapsApiKey");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          return {
            'lat': (location['lat'] as num).toDouble(),
            'lng': (location['lng'] as num).toDouble(),
          };
        }
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return null;
  }

  Future<void> _fetchJobs() async {
    try {
      final endpoint = '/jobs/locations';
      final res = await ApiService.instance.get(endpoint);
      List<dynamic> jobs = [];
      if (res is List) {
        jobs = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        jobs = res['data'];
      }

      if (mounted) {
        setState(() {
          _allJobs = jobs;
        });
      }

      bool updated = false;
      for (int i = 0; i < jobs.length; i++) {
        if (jobs[i] is Map<String, dynamic>) {
          var job = jobs[i];
          double? lat = job['latitude'] != null ? double.tryParse(job['latitude'].toString()) : null;
          double? lng = job['longitude'] != null ? double.tryParse(job['longitude'].toString()) : null;
          String address = job['address']?.toString() ?? '';

          if ((lat == null || lng == null || lat == 0.0 || lng == 0.0) && address.isNotEmpty) {
            final coords = await _geocodeAddress(address);
            if (coords != null) {
              jobs[i]['latitude'] = coords['lat'];
              jobs[i]['longitude'] = coords['lng'];
              updated = true;
            }
          }
        }
      }

      if (mounted && updated) {
        setState(() {
          _allJobs = jobs;
        });
      }
    } catch (e) {
      debugPrint("Error fetching jobs: $e");
    }
  }

  Future<void> _fetchStaffLocations() async {
    try {
      final res = await ApiService.instance.get('/staff/locations');
      List<dynamic> locations = [];
      if (res is List) {
        locations = res;
      } else if (res is Map<String, dynamic> && res['data'] is List) {
        locations = res['data'];
      }
      
      if (mounted) {
        setState(() {
          _staffLocations = locations;
        });
      }

      bool updated = false;
      for (int i = 0; i < locations.length; i++) {
        if (locations[i] is Map<String, dynamic>) {
          var worker = locations[i];
          double? lat = worker['latitude'] != null ? double.tryParse(worker['latitude'].toString()) : null;
          double? lng = worker['longitude'] != null ? double.tryParse(worker['longitude'].toString()) : null;
          String address = worker['address']?.toString() ?? '';

          if ((lat == null || lng == null || lat == 0.0 || lng == 0.0) && address.isNotEmpty) {
            final coords = await _geocodeAddress(address);
            if (coords != null) {
              locations[i]['latitude'] = coords['lat'];
              locations[i]['longitude'] = coords['lng'];
              updated = true;
              lat = coords['lat'];
              lng = coords['lng'];
            }
          }
          
          if (_adminId != null && worker['id'].toString() == _adminId.toString() && (lat == null || lng == null)) {
            try {
              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
              if (serviceEnabled) {
                LocationPermission permission = await Geolocator.checkPermission();
                if (permission == LocationPermission.denied) {
                  permission = await Geolocator.requestPermission();
                }
                if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                  locations[i]['latitude'] = position.latitude;
                  locations[i]['longitude'] = position.longitude;
                  updated = true;
                }
              }
            } catch (_) {}
          }
        }
      }

      if (mounted && updated) {
        setState(() {
          _staffLocations = locations;
        });
      }
    } catch (e) {
      debugPrint("Error fetching staff locations: $e");
    }
  }

  Future<void> _loadUserProfile() async {
    if (currentUser != null) {
      try {
        var doc = await ApiService.instance.getMe();
        if (doc != null) {
          if (mounted) {
            setState(() {
              _adminId = doc['id'];
              _adminFirstName = doc['first_name'] ?? '';
              _adminLastName = doc['last_name'] ?? '';
              _adminName = '$_adminFirstName $_adminLastName'.trim();
              if (_adminName.isEmpty) _adminName = isWorker ? 'Worker' : 'Admin';
            });
          }
        }
      } catch (e) {
        // ignore
      }
    }
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<maps.BitmapDescriptor> _createIconFromIconData(IconData iconData, Color color, {double size = 80.0}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint paint = Paint()..color = color;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);
    
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);

    final TextPainter textPainter = TextPainter(textDirection: ui.TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.6,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        (size - textPainter.width) / 2,
        (size - textPainter.height) / 2,
      ),
    );

    final ui.Picture picture = pictureRecorder.endRecording();
    final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return maps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _lastGeneratedZoom = _currentZoom;
      double size = (_currentZoom * 3.5).clamp(24.0, 72.0);

      final jobIcon = await _createIconFromIconData(Icons.location_city, const Color(0xFFFBC02D), size: size);
      final workerIcon = await _createIconFromIconData(Icons.person, const Color(0xFF43A047), size: size);

      if (mounted) {
        setState(() {
          _jobIcon = jobIcon;
          _workerIcon = workerIcon;
        });
      }
    } catch (e) {
      debugPrint("Error cargando marcadores visuales: $e");
      if (mounted) {
        setState(() {
          _jobIcon = maps.BitmapDescriptor.defaultMarkerWithHue(
              maps.BitmapDescriptor.hueYellow);
          _workerIcon = maps.BitmapDescriptor.defaultMarkerWithHue(
              maps.BitmapDescriptor.hueGreen);
        });
      }
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning,";
    if (hour < 18) return "Good afternoon,";
    return "Good evening,";
  }

  String _getUserInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : "A";
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date =
        timestamp is String ? DateTime.parse(timestamp) : DateTime.now();
    DateTime now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  Future<void> _openFileUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error opening URL: $e");
    }
  }

  // =====================================================================
  // 🚀 MOTOR PARA ABRIR CHAT DIRECTO DESDE EL MAPA (REPARADO)
  // =====================================================================
  Future<void> _startDirectChatFromMap(
      String workerId, String workerName) async {
    await GlobalChatModal.openChatWithUser(
      context,
      targetUserId: workerId,
      targetName: workerName,
      isCustomer: false,
      onClose: () => setState(() {}),
    );
  }

  // =====================================================================
  // 🚀 MINI-PERFIL DEL TRABAJADOR PARA MANDAR MENSAJE
  // =====================================================================
  void _showAssignedWorkerOptions(String workerId, String workerName) {
    showDialog(
        context: context,
        builder: (ctx) => Dialog(
            backgroundColor: const Color(0xFF1E293B),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                    child: Text(workerName[0].toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF3B82F6),
                            fontSize: 28,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 16),
                  Text(workerName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text("Assigned Team Member",
                      style: TextStyle(color: Colors.white60, fontSize: 14)),
                  const SizedBox(height: 32),
                  SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.chat, color: Colors.white),
                          label: const Text("Message Worker",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                            _startDirectChatFromMap(workerId, workerName);
                          }))
                ]))));
  }

  // =====================================================================
  // 🚀 POP-UPS CENTRALES (ADIÓS BUG DE GOOGLE MAPS)
  // =====================================================================
  void _showJobDetailsOnMap(Map<String, dynamic> data) {
    String client = data['customer_name'] ?? 'Unknown Customer';
    String type = data['job_type'] ?? 'Standard Clean';
    String address = data['address'] ?? 'No address provided';
    String status = (data['status'] ?? 'pending').toString().toUpperCase();
    List workers = data['assigned_workers'] ?? [];

    Color statusColor =
        status == 'ACTIVE' ? const Color(0xFF10B981) : Colors.orange;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.cleaning_services,
                          color: Color(0xFF3B82F6), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            type,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.location_on, color: Colors.white60),
                  title: Text(
                    address,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                FutureBuilder<List<Map<String, String>>>(
                  future: () async {
                    try {
                      List<Map<String, String>> workerList = [];
                      if (data != null &&
                          data['assigned_users'] != null &&
                          data['assigned_users'] is List) {
                        for (var u in data['assigned_users']) {
                          workerList.add({
                            'id': u['id'].toString(),
                            'name': '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                                    .trim()
                                    .isEmpty
                                ? 'Worker'
                                : '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                                    .trim()
                          });
                        }
                      }
                      return workerList;
                    } catch (e) {
                      print("Error fetching workers for job list: $e");
                      return <Map<String, String>>[];
                    }
                  }(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF3B82F6))),
                      );
                    }

                    List<Map<String, String>> workerDataList =
                        snapshot.data ?? [];

                    if (workerDataList.isEmpty) {
                      return const ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.person_off, color: Colors.white60),
                        title: Text("No workers assigned yet",
                            style:
                                TextStyle(color: Colors.white60, fontSize: 14)),
                      );
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        const Text("ASSIGNED WORKERS",
                            style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ...workerDataList.map((worker) {
                          return GestureDetector(
                            onTap: () {
                              _showAssignedWorkerOptions(
                                  worker['id']!,
                                  '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'
                                      .trim());
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: const Color(0xFF3B82F6)
                                        .withOpacity(0.2),
                                    child: Text(
                                      (worker['first_name'] ?? 'W')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          color: Color(0xFF3B82F6),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'
                                          .trim(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  const Icon(Icons.chat_bubble,
                                      color: Color(0xFF3B82F6), size: 20),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWorkerDetailsOnMap(Map<String, dynamic> data) {
    DateTime? clockInTime;
    if (data['clock_in'] is String) {
      clockInTime = DateTime.parse(data['clock_in']);
    }
    String timeStr = clockInTime != null
        ? DateFormat('hh:mm a').format(clockInTime)
        : 'Unknown Time';
    String workerId = data['worker_id'] ?? '';

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person,
                          color: Color(0xFF10B981), size: 28),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Active Worker",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "Currently on site",
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.access_time_filled,
                      color: Colors.white60),
                  title: Text(
                    "Started at: $timeStr",
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                Builder(
                  builder: (context) {
                    // Temporarily using placeholder for worker name since we disabled Firebase query
                    String workerName = 'Worker';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _startDirectChatFromMap(
                            workerId, workerName); // 🚀 ABRE EL CHAT DIRECTO
                      },
                      child: Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF3B82F6).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.chat,
                                color: Color(0xFF3B82F6), size: 24),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                "Message $workerName",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Colors.white38),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // 🚀 MENÚ DE PERFIL Y EDICIÓN DE DATOS
  // =====================================================================

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  void _showAdminPersonalInfoModal() {
    TextEditingController firstNameCtrl =
        TextEditingController(text: _adminFirstName);
    TextEditingController lastNameCtrl =
        TextEditingController(text: _adminLastName);
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
              return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2A),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                                    width: 40,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius:
                                            BorderRadius.circular(10)))),
                            const SizedBox(height: 24),
                            const Text("Personal Information",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            const Text("Email Address (Uneditable)",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(currentUser?.email ?? "No Email",
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 16)),
                            ),
                            const SizedBox(height: 20),
                            const Text("First Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildTextField(
                                controller: firstNameCtrl,
                                label: "First Name",
                                icon: Icons.person),
                            const SizedBox(height: 20),
                            const Text("Last Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildTextField(
                                controller: lastNameCtrl,
                                label: "Last Name",
                                icon: Icons.person),
                            const SizedBox(height: 32),
                            SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (firstNameCtrl.text
                                                  .trim()
                                                  .isEmpty ||
                                              lastNameCtrl.text.trim().isEmpty)
                                            return;
                                          setModalState(() => isSaving = true);
                                          try {
                                            await ApiService.instance.put(
                                                '/employee/profile', {
                                              'first_name':
                                                  firstNameCtrl.text.trim(),
                                              'last_name':
                                                  lastNameCtrl.text.trim()
                                            });

                                            if (mounted) {
                                              setState(() {
                                                _adminFirstName =
                                                    firstNameCtrl.text.trim();
                                                _adminLastName =
                                                    lastNameCtrl.text.trim();
                                                _adminName =
                                                    '$_adminFirstName $_adminLastName'
                                                        .trim();
                                              });
                                            }
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Profile updated successfully!'),
                                                    backgroundColor:
                                                        Color(0xFF10B981)));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text('Error: $e'),
                                                    backgroundColor:
                                                        Colors.redAccent));
                                          } finally {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        },
                                  child: isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text("Save Changes",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                ))
                          ])));
            }));
  }

  void _showAdminProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                              color: Color(0xFF2A3B5A), shape: BoxShape.circle),
                          child: Center(
                              child: Text(_getUserInitial(_adminName),
                                  style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_adminName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text(currentUser?.email ?? "",
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13))
                          ]))
                    ]),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading:
                        const Icon(Icons.person_outline, color: Colors.white70),
                    title: const Text("Personal Information",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () {
                      Navigator.pop(context);
                      _showAdminPersonalInfoModal();
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      title: const Text("Sign out",
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
                      onTap: () async {
                        Navigator.pop(context);
                        await widget.onLogout();
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Padding(
              padding:
                    const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10)),
                  child: Row(
                    children: [
                      _buildFilterButton("All", 0),
                      _buildFilterButton("Jobs", 1),
                      _buildFilterButton("Team", 2),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Builder(
                      builder: (context) {
                        Set<maps.Marker> mapMarkers = {};

                        // 1. PINTAR TRABAJOS (MALETINES)
                        if (_selectedFilter == 0 || _selectedFilter == 1) {
                          for (var data in _allJobs) {
                            if (data is! Map<String, dynamic>) continue;

                            String status =
                                (data['status'] ?? '').toString().toLowerCase();
                            if (status == 'cancelled') continue;

                            double? lat;
                            double? lng;

                            if (data['latitude'] != null) {
                              lat =
                                  double.tryParse(data['latitude'].toString());
                            }
                            if (data['longitude'] != null) {
                              lng =
                                  double.tryParse(data['longitude'].toString());
                            }

                            if (lat != null &&
                                lng != null &&
                                lat != 0.0 &&
                                lng != 0.0) {
                              mapMarkers.add(
                                maps.Marker(
                                  markerId: maps.MarkerId('job_${data['id']}'),
                                  position: maps.LatLng(lat, lng),
                                  icon: _jobIcon ??
                                      maps.BitmapDescriptor
                                          .defaultMarkerWithHue(
                                              maps.BitmapDescriptor.hueRed),
                                  consumeTapEvents:
                                      true, // 🚀 BLOQUEA LOS CLICS DE GOOGLE MAPS
                                  onTap: () => _showJobDetailsOnMap(data),
                                ),
                              );
                            }
                          }
                        }

                        // 2. PINTAR TRABAJADORES ACTIVOS (PERSONAS)
                        if (_selectedFilter == 0 || _selectedFilter == 2) {
                          for (var worker in _staffLocations) {
                            if (worker is! Map<String, dynamic>) continue;
                            
                            double? lat;
                            double? lng;

                            if (worker['latitude'] != null) {
                              lat = double.tryParse(worker['latitude'].toString());
                            }
                            if (worker['longitude'] != null) {
                              lng = double.tryParse(worker['longitude'].toString());
                            }

                            if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                              mapMarkers.add(
                                maps.Marker(
                                  markerId: maps.MarkerId('worker_${worker['id']}'),
                                  position: maps.LatLng(lat, lng),
                                  icon: _workerIcon ?? maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueAzure),
                                  consumeTapEvents: true,
                                  onTap: () {
                                    final workerId = worker['id'].toString();
                                    final workerName = '${worker['first_name'] ?? ''} ${worker['last_name'] ?? ''}'.trim();
                                    _showAssignedWorkerOptions(workerId, workerName.isEmpty ? 'Worker' : workerName);
                                  },
                                ),
                              );
                            }
                          }
                        }

                        return ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32)),
                          child: maps.GoogleMap(
                            key: const ValueKey('admin_map_google_map'),
                            initialCameraPosition: const maps.CameraPosition(
                                target: _centerCoords, zoom: 13.5),
                            mapToolbarEnabled: false,
                            zoomControlsEnabled: false,
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            onCameraMove: (maps.CameraPosition position) {
                              _currentZoom = position.zoom;
                            },
                            onCameraIdle: () {
                              if ((_currentZoom - _lastGeneratedZoom).abs() > 0.8) {
                                _loadCustomMarkers();
                              }
                            },
                            onMapCreated:
                                (maps.GoogleMapController controller) {
                              _mapController = controller;
                              if (!kIsWeb) {
                                try {
                                  _mapController?.setMapStyle('''
                              [
                                { "elementType": "geometry", "stylers": [{ "color": "#1e293b" }] },
                                { "elementType": "labels.text.fill", "stylers": [{ "color": "#94a3b8" }] },
                                { "elementType": "labels.text.stroke", "stylers": [{ "color": "#0f172a" }] },
                                { "featureType": "administrative.land_parcel", "elementType": "labels", "stylers": [{ "visibility": "off" }] },
                                { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#334155" }] },
                                { "featureType": "road", "elementType": "labels.text.fill", "stylers": [{ "color": "#cbd5e1" }] },
                                { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#0f172a" }] }
                              ]
                            ''');
                                } catch (e) {
                                  debugPrint("Map style error: $e");
                                }
                              }
                              Future.delayed(const Duration(milliseconds: 600), () {
                                if (mounted) {
                                  _isMapCreated = true;
                                }
                              });
                            },
                            markers: mapMarkers,
                          ),
                        );
                      },
                    ),
                  if (_isLoading)
                    Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, int index) {
    bool isSelected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedFilter != index) {
            setState(() {
              _selectedFilter = index;
              _isLoading = true;
            });
            if (index == 0) {
              Future.wait([_fetchJobs(), _fetchStaffLocations()]).then((_) async {
                await _fitBounds();
                if (mounted && _isLoading) setState(() => _isLoading = false);
              });
            } else if (index == 1) {
              _fetchJobs().then((_) async {
                await _fitBounds();
                if (mounted && _isLoading) setState(() => _isLoading = false);
              });
            } else if (index == 2) {
              _fetchStaffLocations().then((_) async {
                await _fitBounds();
                if (mounted && _isLoading) setState(() => _isLoading = false);
              });
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white60,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

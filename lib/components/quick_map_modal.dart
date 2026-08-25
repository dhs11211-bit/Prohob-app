import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '/backend/api_service.dart';
import '/app_constants.dart';
import '/shared/toast_service.dart';

class QuickMapModal extends StatefulWidget {
  final Map<String, dynamic> jobData;
  final String title;

  const QuickMapModal({
    Key? key,
    required this.jobData,
    required this.title,
  }) : super(key: key);

  @override
  State<QuickMapModal> createState() => _QuickMapModalState();
}

class _QuickMapModalState extends State<QuickMapModal> {
  bool _isLoading = true;
  String _address = '';
  double? _latitude;
  double? _longitude;
  String? _googleMapsApiKey = AppConstants.fallbackGoogleMapsApiKey;
  maps.GoogleMapController? _mapController;
  maps.BitmapDescriptor? _jobIcon;

  @override
  void initState() {
    super.initState();
    _address = widget.jobData['address'] ?? 'No address provided';

    if (widget.jobData['latitude'] != null &&
        widget.jobData['longitude'] != null) {
      _latitude = double.tryParse(widget.jobData['latitude'].toString());
      _longitude = double.tryParse(widget.jobData['longitude'].toString());
    }

    _initializeMapData();
  }

  Future<void> _initializeMapData() async {
    await _fetchGoogleMapsKey();
    if (_latitude == null || _longitude == null) {
      await _geocodeAddress();
    }
    await _createCustomIcon();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchGoogleMapsKey() async {
    try {
      final response = await ApiService.instance.get('/public/settings');
      if (mounted && response is Map) {
        final settings = response['data'] ?? response;
        if (settings is Map &&
            settings.containsKey('google_maps_api_key') &&
            settings['google_maps_api_key'] != null &&
            settings['google_maps_api_key'].toString().trim().isNotEmpty) {
          _googleMapsApiKey = settings['google_maps_api_key'];
        }
      }
    } catch (e) {
      debugPrint("Error fetching Google Maps API key: $e");
    }
  }

  Future<void> _geocodeAddress() async {
    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
    if (_address.isEmpty || _address == 'No address provided') return;

    try {
      final encodedQuery = Uri.encodeComponent(_address);
      final url = Uri.parse(
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedQuery&key=$_googleMapsApiKey');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' &&
            data['results'] != null &&
            data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          _latitude = location['lat'];
          _longitude = location['lng'];
        }
      }
    } catch (e) {
      debugPrint("Error geocoding address: $e");
    }
  }

  Future<void> _createCustomIcon() async {
    try {
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      double size = 52.0;
      Color color = const Color(0xFFFBC02D);

      final Paint paint = Paint()..color = color;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, paint);

      final Paint borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      canvas.drawCircle(Offset(size / 2, size / 2), size / 2, borderPaint);

      // Draw House
      final TextPainter housePainter =
          TextPainter(textDirection: ui.TextDirection.ltr);
      housePainter.text = TextSpan(
        text: String.fromCharCode(Icons.home.codePoint),
        style: TextStyle(
          fontSize: size * 0.65,
          fontFamily: Icons.home.fontFamily,
          package: Icons.home.fontPackage,
          color: Colors.white,
        ),
      );
      housePainter.layout();
      housePainter.paint(
        canvas,
        Offset(
          (size - housePainter.width) / 2,
          (size - housePainter.height) / 2,
        ),
      );

      // Draw Wrench
      final TextPainter wrenchPainter =
          TextPainter(textDirection: ui.TextDirection.ltr);
      wrenchPainter.text = TextSpan(
        text: String.fromCharCode(Icons.build.codePoint),
        style: TextStyle(
          fontSize: size * 0.35,
          fontFamily: Icons.build.fontFamily,
          package: Icons.build.fontPackage,
          color: color,
        ),
      );
      wrenchPainter.layout();
      wrenchPainter.paint(
        canvas,
        Offset(
          (size - wrenchPainter.width) / 2,
          (size - wrenchPainter.height) / 2 + (size * 0.05),
        ),
      );

      final ui.Picture picture = pictureRecorder.endRecording();
      final ui.Image image = await picture.toImage(size.toInt(), size.toInt());
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      _jobIcon =
          maps.BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
    } catch (e) {
      debugPrint("Error creating custom icon: $e");
    }
  }

  void _openFullMap() async {
    if (_address.isEmpty || _address == 'No address provided') return;
    final encodedQuery = Uri.encodeComponent(_address);
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encodedQuery');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ToastService.info(context, 'Could not launch Google Maps.');
        }
      }
    } catch (e) {
      if (mounted) {
        ToastService.info(context, 'Error launching Google Maps.');
      }
    }
  }

  void _showStreetViewImage() {
    if (_googleMapsApiKey == null ||
        _googleMapsApiKey!.isEmpty ||
        _latitude == null ||
        _longitude == null) return;
    final imageUrl =
        'https://maps.googleapis.com/maps/api/streetview?size=800x800&location=$_latitude,$_longitude&key=$_googleMapsApiKey';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 300,
                    height: 200,
                    padding: const EdgeInsets.all(20),
                    color: Colors.black87,
                    alignment: Alignment.center,
                    child: const Text(
                      'Street View image not available (or API not enabled).',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(bottom: 24), // Extra padding for safe area
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Map Container
          Container(
            height: 250,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFF1E293B),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : (_latitude != null && _longitude != null)
                    ? Stack(
                        children: [
                          maps.GoogleMap(
                            initialCameraPosition: maps.CameraPosition(
                              target: maps.LatLng(_latitude!, _longitude!),
                              zoom: 15.0,
                            ),
                            markers: {
                              if (_jobIcon != null)
                                maps.Marker(
                                  markerId: const maps.MarkerId('job_location'),
                                  position:
                                      maps.LatLng(_latitude!, _longitude!),
                                  icon: _jobIcon!,
                                ),
                            },
                            onMapCreated: (controller) {
                              _mapController = controller;
                              if (!kIsWeb) {
                                try {
                                  _mapController?.setMapStyle('''
                                [
                                  { "elementType": "geometry", "stylers": [{ "color": "#1e293b" }] },
                                  { "elementType": "labels.text.fill", "stylers": [{ "color": "#94a3b8" }] },
                                  { "elementType": "labels.text.stroke", "stylers": [{ "color": "#0f172a" }] },
                                  { "featureType": "road", "elementType": "geometry", "stylers": [{ "color": "#334155" }] },
                                  { "featureType": "water", "elementType": "geometry", "stylers": [{ "color": "#0f172a" }] }
                                ]
                                ''');
                                } catch (_) {}
                              }
                            },
                            zoomControlsEnabled: true,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                          ),
                          if (_googleMapsApiKey != null &&
                              _googleMapsApiKey!.isNotEmpty)
                            Positioned(
                              left: 12,
                              bottom: 12,
                              child: GestureDetector(
                                onTap: _showStreetViewImage,
                                child: Container(
                                  width: 70,
                                  height: 70,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      )
                                    ],
                                  ),
                                  child: Image.network(
                                    'https://maps.googleapis.com/maps/api/streetview?size=200x200&location=$_latitude,$_longitude&key=$_googleMapsApiKey',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                      color: Colors.grey[800],
                                      child: const Center(
                                          child: Icon(Icons.streetview,
                                              color: Colors.white54, size: 30)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : const Center(
                        child: Text(
                          'Location could not be loaded.',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
          ),

          const SizedBox(height: 16),

          // Address text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.location_on,
                    color: Color(0xFF94A3B8), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _address,
                    style:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Open Full Map Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _openFullMap,
                icon: const Icon(Icons.map_outlined, color: Colors.white),
                label: const Text('Open in Google Maps',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

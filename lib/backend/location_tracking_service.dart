import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';

class LocationTrackingService {
  static final LocationTrackingService instance = LocationTrackingService._internal();

  LocationTrackingService._internal();

  Timer? _timer;
  bool _isTracking = false;

  void startTracking() {
    if (_isTracking) return;
    _isTracking = true;
    
    // Fire immediately once
    _sendLocation();

    // Then every 5 minutes
    _timer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _sendLocation();
    });
  }

  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _isTracking = false;
  }

  Future<void> _sendLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }

      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      await ApiService.instance.post('/users/live-location', {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy_m': pos.accuracy,
        'speed_mps': pos.speed,
        'heading': pos.heading,
        'is_mocked': pos.isMocked,
      });
    } catch (e) {
      print("Background location tracking error: $e");
    }
  }
}

import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';
import 'api_service.dart';
import 'app_state.dart';

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Idle tracking state
  Position? _lastPosition;
  int _idleMinutes = 0;
  final int IDLE_THRESHOLD_MINUTES = 10;
  final double MOVEMENT_THRESHOLD_METERS = 30.0;

  Timer.periodic(const Duration(seconds: 60), (timer) async {
    // 1. Get location
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

    try {
      Position position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 15),
      );

      // Idle logic (Task 10.14 & 10.15)
      if (_lastPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastPosition!.latitude, _lastPosition!.longitude,
          position.latitude, position.longitude
        );

        if (distance < MOVEMENT_THRESHOLD_METERS) {
          _idleMinutes++;
          if (_idleMinutes >= IDLE_THRESHOLD_MINUTES) {
            // Fetch active job to report idle
            try {
              final activeJobsResponse = await ApiService.instance.get('/jobs?assigned_to=me&job_status=in_progress');
              if (activeJobsResponse != null && activeJobsResponse['data'] != null) {
                 List activeJobs = activeJobsResponse['data'] is List ? activeJobsResponse['data'] : (activeJobsResponse['data']['data'] ?? []);
                 if (activeJobs.isNotEmpty) {
                    int jobId = activeJobs.first['id'];
                    // We need the JobTime id, but backend can accept job_id if we update it.
                    // For now, let's just assume we need to call a generic idle endpoint or we know the job_id
                    await ApiService.instance.post('/job-times/$jobId/report-idle', {
                      'idle_minutes': _idleMinutes
                    });
                 }
              }
            } catch(e) {
               // ignore
            }
          }
        } else {
          _idleMinutes = 0;
          _lastPosition = position;
        }
      } else {
        _lastPosition = position;
      }

      // Attempt to batch this breadcrumb
      final payload = {
        'breadcrumbs': [
          {
            'lat': position.latitude,
            'lng': position.longitude,
            'timestamp': DateTime.now().toIso8601String(),
          }
        ]
      };
      
      // POST /gps/breadcrumb
      await ApiService.instance.post('/gps/breadcrumb', payload);
      
    } catch (e) {
      // Ignore errors in background
    }
  });
}

class BackgroundGpsService {
  static Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'gps_tracking',
        initialNotificationTitle: 'GPS Tracking Active',
        initialNotificationContent: 'Tracking location for active job',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: (ServiceInstance service) {
          return true;
        },
      ),
    );
  }

  static void start() {
    FlutterBackgroundService().startService();
  }

  static void stop() {
    FlutterBackgroundService().invoke("stopService");
  }
}

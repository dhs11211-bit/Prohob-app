import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'toast_service.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init(BuildContext context) async {
    // Request permission (mostly for iOS, but good practice)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted permission');
      
      // Get the token and send it to our Laravel backend
      String? token = await _messaging.getToken();
      if (token != null) {
        _sendTokenToBackend(token);
      }

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((newToken) {
        _sendTokenToBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('Got a message whilst in the foreground!');
        if (message.notification != null) {
          ToastService.info(
            context,
            '${message.notification!.title}: ${message.notification!.body}',
          );
        }
      });
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      await ApiService.instance.post('/fcm-token', {'token': token});
      print("FCM Token registered with backend.");
    } catch (e) {
      print("Failed to register FCM token: $e");
    }
  }
}

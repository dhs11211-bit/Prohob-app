import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import '../backend/api_service.dart';
import 'toast_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Handling a background message: ${message.messageId}");
}

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> init(BuildContext context) async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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

      // Handle background notification tap (Deep Linking)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('A new onMessageOpenedApp event was published!');
        _handleDeepLink(context, message);
      });

      // Handle notification tap when app is completely terminated
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleDeepLink(context, initialMessage);
      }
    }
  }

  void _handleDeepLink(BuildContext context, RemoteMessage message) {
    if (message.data.containsKey('route')) {
      final route = message.data['route'];
      print('Deep linking to route: $route');
      context.push(route);
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      String os = 'web';
      if (!kIsWeb) {
        if (Platform.isIOS) {
          os = 'ios';
        } else if (Platform.isAndroid) {
          os = 'android';
        }
      }

      await ApiService.instance.post('/device-tokens', {
        'token': token,
        'platform': os,
      });
      print("Device Token registered with backend ($os).");
    } catch (e) {
      print("Failed to register device token: $e");
    }
  }
}

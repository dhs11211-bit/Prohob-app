import 'dart:async';
import 'dart:convert';
import 'package:dart_pusher_channels/dart_pusher_channels.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import '../app_state.dart';
import 'package:flutter/material.dart';
import '../auth/base_auth_user_provider.dart';
import '../shared/toast_service.dart';

class ReverbService {
  static final ReverbService instance = ReverbService._internal();
  ReverbService._internal();

  PusherChannelsClient? pusher;
  bool isInitialized = false;

  final String _appKey = 'l6diygx4q9lsylsrr1v1';
  
  String get _host {
    if (!kReleaseMode) {
      if (kIsWeb) return 'localhost';
      if (Platform.isAndroid) return '10.0.2.2';
      return 'localhost';
    }
    return 'api.serviceprohob.com';
  }

  int get _port {
    if (!kReleaseMode) return 8080;
    return 443;
  }

  String get _scheme {
    if (!kReleaseMode) return 'ws';
    return 'wss';
  }

  // Listeners
  Function(dynamic)? onMessageReceived;
  Function(dynamic)? onConversationUpdated;

  // Track channels to avoid duplicate subscriptions
  Map<String, PrivateChannel> _subscribedChannels = {};
  Map<String, StreamSubscription> _eventSubscriptions = {};

  Future<void> init() async {
    if (isInitialized) return;
    
    try {
      pusher = PusherChannelsClient.websocket(
        options: PusherChannelsOptions.fromHost(
          scheme: _scheme,
          host: _host,
          port: _port,
          key: _appKey,
        ),
        connectionErrorHandler: (exception, trace, refresh) {
          print("Pusher error: $exception");
          refresh();
        },
      );

      await pusher!.connect();
      isInitialized = true;
    } catch (e) {
      print("ERROR INITIALIZING PUSHER: $e");
    }
  }

  Future<void> subscribeToConversations(int clId) async {
    if (pusher == null) return;
    final channelName = 'private-conversations.$clId';
    if (_subscribedChannels.containsKey(channelName)) return;

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    final authUrl = "${ApiService.baseUrl.replaceAll('/api/mob', '')}/broadcasting/auth";

    final channel = pusher!.privateChannel(
      channelName,
      authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: Uri.parse(authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    _subscribedChannels[channelName] = channel;
    channel.subscribe();
    
    _eventSubscriptions[channelName] = channel.bind('ConversationUpdated').listen((event) {
      if (event.data != null) {
        final data = jsonDecode(event.data.toString());
        
        if (onConversationUpdated != null) {
          onConversationUpdated!(data);
        }

        // Global Toast Notification
        if (data['last_message'] != null) {
          final currentUserId = currentUser?.uid;
          final senderId = data['sender_id']?.toString();

          if (senderId != null && senderId != currentUserId) {
            final messenger = globalMessengerKey.currentState;
            if (messenger != null) {
              ToastService.showWithMessenger(
                messenger,
                "New Message: ${data['last_message']}",
                type: ToastType.info,
              );
            }
          }
        }
      }
    });
  }

  Future<void> subscribeToChat(int conversationId) async {
    if (pusher == null) return;
    final channelName = 'private-conversation.$conversationId';
    if (_subscribedChannels.containsKey(channelName)) return;

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: 'auth_token');
    final authUrl = "${ApiService.baseUrl.replaceAll('/api/mob', '')}/broadcasting/auth";

    final channel = pusher!.privateChannel(
      channelName,
      authorizationDelegate: EndpointAuthorizableChannelTokenAuthorizationDelegate.forPrivateChannel(
        authorizationEndpoint: Uri.parse(authUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ),
    );

    _subscribedChannels[channelName] = channel;
    channel.subscribe();
    
    _eventSubscriptions[channelName] = channel.bind('MessageSent').listen((event) {
      if (onMessageReceived != null && event.data != null) {
        onMessageReceived!(jsonDecode(event.data.toString()));
      }
    });
  }

  Future<void> unsubscribeFromChat(int conversationId) async {
    if (pusher == null) return;
    final channelName = 'private-conversation.$conversationId';
    
    if (_subscribedChannels.containsKey(channelName)) {
      _subscribedChannels[channelName]!.unsubscribe();
      _subscribedChannels.remove(channelName);
    }
    
    if (_eventSubscriptions.containsKey(channelName)) {
      _eventSubscriptions[channelName]!.cancel();
      _eventSubscriptions.remove(channelName);
    }
  }
}

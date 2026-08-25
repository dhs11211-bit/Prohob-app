import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// Task 10.12: Laravel Reverb and dart_pusher_channels have been completely removed.
// This service has been stubbed out to avoid compilation errors until the UI
// is refactored to use Firebase Cloud Messaging natively.

class ReverbService {
  static final ReverbService instance = ReverbService._internal();
  ReverbService._internal();

  bool isInitialized = false;

  // Listeners
  Function(dynamic)? onMessageReceived;
  Function(dynamic)? onConversationUpdated;

  Future<void> init() async {
    isInitialized = true;
  }

  Future<void> subscribeToConversations(int clId) async {
    // Replaced by Firebase FCM in future/current tasks
  }

  Future<void> subscribeToChat(int conversationId) async {
    // Replaced by Firebase FCM in future/current tasks
  }

  Future<void> unsubscribeFromChat(int conversationId) async {
    // Replaced by Firebase FCM in future/current tasks
  }
}

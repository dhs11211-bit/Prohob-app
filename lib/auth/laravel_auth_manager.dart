import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:rxdart/rxdart.dart';
import '../backend/api_service.dart';
import '../shared/auth_helpers.dart' as shared;
import 'base_auth_user_provider.dart';

export 'base_auth_user_provider.dart';

class LaravelAuthUser extends BaseAuthUser {
  LaravelAuthUser(this.userData);
  Map<String, dynamic>? userData;

  @override
  bool get loggedIn => userData != null;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: userData?['id']?.toString(),
        email: userData?['email'],
        displayName:
            '${userData?['first_name'] ?? ''} ${userData?['last_name'] ?? ''}'
                .trim(),
        photoUrl: null,
        phoneNumber: userData?['phone'] ?? userData?['mobile'],
      );

  @override
  bool get emailVerified => true;

  @override
  Future? delete() async {}

  @override
  Future? updateEmail(String email) async {}

  @override
  Future? updatePassword(String newPassword) async {}

  @override
  Future? sendEmailVerification() async {}

  @override
  Future refreshUser() async {
    try {
      userData = await ApiService.instance.getMe();
    } catch (e) {
      userData = null;
    }
  }
}

class LaravelAuthManager {
  static const _storage = FlutterSecureStorage();
  static final BehaviorSubject<BaseAuthUser> _userStreamController =
      BehaviorSubject<BaseAuthUser>();

  // The stream required by main.dart
  static Stream<BaseAuthUser> get userStream => _userStreamController.stream;

  static Future<void> initialize() async {
    final token = await _storage.read(key: 'auth_token');
    Map<String, dynamic>? user;
    if (token != null) {
      try {
        user = await ApiService.instance.getMe();
      } catch (e) {
        await _storage.delete(key: 'auth_token');
      }
    }
    _updateUser(user);
  }

  static Future<dynamic> login(String email, String password,
      {int? clId}) async {
    final response =
        await ApiService.instance.login(email, password, clId: clId);

    if (response['requires_selection'] == true) {
      return response;
    }

    final token = response['access_token'];
    await _storage.write(key: 'auth_token', value: token);

    if (clId != null) {
      await _storage.write(key: 'active_cl_id', value: clId.toString());
    } else {
      final userClId = response['user']['cl_id'];
      if (userClId != null) {
        await _storage.write(key: 'active_cl_id', value: userClId.toString());
      }
    }

    _updateUser(response['user']);
    try {
      await shared.AuthHelpers.fetchMobilePermissions();
    } catch (_) {}
    return response;
  }

  static Future<void> signOut() async {
    try {
      // Try to unregister FCM token before destroying session
      try {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await ApiService.instance.delete('/device-tokens', body: {'token': token});
        }
      } catch (e) {
        // Ignore firebase errors on logout
      }

      await ApiService.instance.logout();
    } catch (e) {
      // Ignore network errors on logout
    }
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'active_cl_id');
    _updateUser(null);
  }

  static void _updateUser(Map<String, dynamic>? userData) {
    final authUser = LaravelAuthUser(userData);
    currentUser = authUser; // Update the global var in base_auth_user_provider
    _userStreamController.add(authUser);
  }
}

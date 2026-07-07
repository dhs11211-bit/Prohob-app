import 'package:flutter/material.dart';
import '/backend/backend.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'flutter_flow/flutter_flow_util.dart';

final GlobalKey<ScaffoldMessengerState> globalMessengerKey = GlobalKey<ScaffoldMessengerState>();

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  int _selectedTab = 0;
  int get selectedTab => _selectedTab;
  set selectedTab(int value) {
    _selectedTab = value;
  }

  bool _isClockedIn = true;
  bool get isClockedIn => _isClockedIn;
  set isClockedIn(bool value) {
    _isClockedIn = value;
  }

  bool _isInitialRoutingDone = false;
  bool get isInitialRoutingDone => _isInitialRoutingDone;
  set isInitialRoutingDone(bool value) {
    _isInitialRoutingDone = value;
  }
}

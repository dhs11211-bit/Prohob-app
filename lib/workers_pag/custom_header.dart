// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '../backend/api_service.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '/auth/laravel_auth_manager.dart';

class CustomHeader extends StatefulWidget {
  const CustomHeader({Key? key, this.width, this.height}) : super(key: key);
  final double? width;
  final double? height;
  @override
  State<CustomHeader> createState() => _CustomHeaderState();
}

class _CustomHeaderState extends State<CustomHeader> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentRed = const Color(0xFFEF4444);

  // Cached user data — fetched ONCE in initState, never on rebuild
  String _userName = 'Worker';
  String _initials = 'W';
  String? _userId;

  final List<String> _hiddenNotifs = [];
  final List<String> _importantNotifs = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await ApiService.instance.getMe();
      if (mounted) {
        setState(() {
          _userName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
          if (_userName.isEmpty) _userName = 'Worker';
          _initials = (user['first_name'] as String? ?? '').isNotEmpty
              ? (user['first_name'] as String).substring(0, 1).toUpperCase()
              : 'W';
          _userId = user['id']?.toString();
        });
      }
    } catch (e) {
      // Keep defaults on error
    }
  }

  String _getGreeting() {
    var hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _handleLogOut() async {
    try {
      await LaravelAuthManager.signOut();
      if (mounted) {
        context.go('/landingPricingFirst');
      }
    } catch (e) {
      print("Error signing out: $e");
    }
  }

  void _openNotificationsModal() {
    // Phase 4: Notifications will be implemented here

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StatefulBuilder(
            builder: (context, setModalState) => Container(
                height: MediaQuery.of(context).size.height * 0.75,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border.all(color: Colors.white10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                          child: Container(
                              width: 40,
                              height: 5,
                              // FIX OPACITY: Color muted al 30%
                              decoration: BoxDecoration(
                                  color: const Color(0x4D94A3B8),
                                  borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 24),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('Notifications',
                                    style: TextStyle(
                                        color: text,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold))),
                            InkWell(
                                onTap: () {
                                  setModalState(() =>
                                      _hiddenNotifs.add('all_cleared_trigger'));
                                  setState(() {});
                                },
                                child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    // FIX OPACITY: Color blue al 10%
                                    decoration: BoxDecoration(
                                        color: const Color(0x1A3B82F6),
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    child: Text('Clear All',
                                        style: TextStyle(
                                            color: accentBlue,
                                            fontWeight: FontWeight.bold))))
                          ]),
                      const SizedBox(height: 20),
                      Expanded(
                          child: _hiddenNotifs.contains('all_cleared_trigger')
                              ? Center(
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined,
                                        color: const Color(0x8094A3B8),
                                        size: 60),
                                    const SizedBox(height: 16),
                                    Text('You\'re all caught up!',
                                        style: TextStyle(
                                            color: text,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('No new notifications.',
                                        style: TextStyle(color: muted)),
                                  ],
                                ))
                              : Center(
                                  child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.notifications_off_outlined,
                                        color: const Color(0x8094A3B8),
                                        size: 60),
                                    const SizedBox(height: 16),
                                    Text('You\'re all caught up!',
                                        style: TextStyle(
                                            color: text,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text('No new notifications.',
                                        style: TextStyle(color: muted)),
                                  ],
                                )),
                          ),
                    ],
                ))));
  }

  @override
  Widget build(BuildContext context) {
    // Uses cached _userName/_initials/_userId — no API call on rebuild
    return _headerUI(_userName, _initials, _userId);
  }

  Widget _headerUI(String name, String initials, String? userId) {
    return Container(
      width: widget.width ?? double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 20),
      // FIX OPACITY: Colores de degradado
      decoration: const BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xF20F172A), Color(0x000F172A)])),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_getGreeting(), style: TextStyle(color: muted, fontSize: 13)),
            Text(name,
                style: TextStyle(
                    color: text, fontSize: 26, fontWeight: FontWeight.bold))
          ]),
          Row(children: [
            GestureDetector(
              onTap: _openNotificationsModal,
              child: Stack(
                children: [
                  Icon(Icons.notifications_none_rounded, color: text, size: 28),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // TU MODAL ORIGINAL LLAMADO DESDE INDEX.DART
            GestureDetector(
                onTap: () => showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (context) =>
                        ProfileMenuModal(onLogOutAction: _handleLogOut)),
                child: Container(
                    width: 45,
                    height: 45,
                    // FIX OPACITY: Color blue al 20%
                    decoration: BoxDecoration(
                        color: const Color(0x333B82F6),
                        shape: BoxShape.circle,
                        border: Border.all(color: accentBlue, width: 2)),
                    child: Center(
                        child: Text(initials,
                            style: TextStyle(
                                color: accentBlue,
                                fontWeight: FontWeight.bold))))),
          ])
        ],
      ),
    );
  }
}

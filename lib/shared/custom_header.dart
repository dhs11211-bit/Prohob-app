import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '/auth/laravel_auth_manager.dart';
import '/backend/api_service.dart';
import 'auth_helpers.dart';
import 'profile_screen.dart';
import '../components/swap_requests_modal.dart';

class SharedCustomHeader extends StatefulWidget {
  const SharedCustomHeader({Key? key}) : super(key: key);

  @override
  State<SharedCustomHeader> createState() => _SharedCustomHeaderState();
}

class _SharedCustomHeaderState extends State<SharedCustomHeader> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color accentRed = const Color(0xFFEF4444);

  String _userName = 'User';
  String _initials = 'U';
  String? _userRole;
  String _companyName = '';

  final List<String> _hiddenNotifs = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final cachedData = AuthHelpers.userData;
    if (cachedData != null) {
      _parseUser(cachedData);
    } else {
      try {
        final user = await ApiService.instance.getMe();
        if (mounted) {
          _parseUser(user);
        }
      } catch (_) {}
    }
  }

  void _parseUser(Map<String, dynamic> user) {
    setState(() {
      String fName = user['first_name'] ?? user['name'] ?? '';
      String lName = user['last_name'] ?? '';
      
      // Combine first name and last name for full display
      _userName = [fName, lName].where((s) => s.isNotEmpty).join(' ').trim();
      if (_userName.isEmpty) _userName = 'User';

      _initials = fName.isNotEmpty
          ? fName[0].toUpperCase()
          : (_userName.isNotEmpty ? _userName[0].toUpperCase() : 'U');

      _userRole = user['role']?['name'] ?? user['role']?['slug'];
      
      // Extract company name if available
      _companyName = user['company']?['name'] ?? 'Unknown Company';
    });
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
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0x4D94A3B8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Notifications',
                      style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      setModalState(() => _hiddenNotifs.add('all_cleared_trigger'));
                      setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0x1A3B82F6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Clear All',
                        style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_off_outlined, color: Color(0x8094A3B8), size: 60),
                      const SizedBox(height: 16),
                      Text(
                        "You're all caught up!",
                        style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text('No new notifications.', style: TextStyle(color: muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.95,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white10),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top drag bar & Back button row
              Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 34,
                backgroundColor: accentBlue.withOpacity(0.2),
                child: Text(
                  _initials,
                  style: TextStyle(color: accentBlue, fontSize: 26, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _userName,
                style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              if (_userRole != null) ...[
                const SizedBox(height: 4),
                Text(
                  _userRole!.toUpperCase(),
                  style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                ),
              ],
              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              const SizedBox(height: 8),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: ListView(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_outline, color: accentBlue, size: 20),
                        ),
                        title: const Text('My Profile', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('Edit personal information & details', style: TextStyle(color: muted, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () {
                          Navigator.pop(context);
                          ProfileScreen.showModal(context, initialTab: ProfileTab.profile);
                        },
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.description_outlined, color: accentBlue, size: 20),
                        ),
                        title: const Text('My Documents', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('Manage Photo ID, SSN, W-9 & Bank forms', style: TextStyle(color: muted, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () {
                          Navigator.pop(context);
                          ProfileScreen.showModal(context, initialTab: ProfileTab.documents);
                        },
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentBlue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.swap_calls, color: accentBlue, size: 20),
                        ),
                        title: const Text('Swap Requests', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        subtitle: Text('View & track shift swap requests', style: TextStyle(color: muted, fontSize: 12)),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                        onTap: () {
                          Navigator.pop(context);
                          SwapRequestsModal.show(context);
                        },
                      ),
                      const SizedBox(height: 6),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accentRed.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.logout, color: accentRed, size: 20),
                        ),
                        title: Text('Log Out', style: TextStyle(color: accentRed, fontSize: 15, fontWeight: FontWeight.bold)),
                        onTap: () {
                          Navigator.pop(context);
                          _handleLogOut();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top > 0
        ? MediaQuery.of(context).padding.top + 8
        : 16.0;

    return Container(
      color: const Color(0xFF0F172A),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(top: topPadding, left: 20, right: 20, bottom: 12),
            child: Row(
              children: [
                // LEFT (Name and Greeting)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(color: text, fontSize: 22, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(_getGreeting(), style: TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                
                // MIDDLE (Company Name Chip)
                if (_companyName.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.business_rounded, size: 14, color: muted),
                        const SizedBox(width: 6),
                        Text(
                          _companyName.length > 10 ? '${_companyName.substring(0, 10)}...' : _companyName,
                          style: TextStyle(color: text, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                // RIGHT (Icons)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: _openNotificationsModal,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: card,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Icon(Icons.notifications_none_rounded, color: text, size: 22),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: _openProfileModal,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accentBlue.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: accentBlue, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                _initials,
                                style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 1.0,
              color: Colors.white10,
            ),
          ),
        ],
      ),
    );
  }
}

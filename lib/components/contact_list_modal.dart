import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import 'global_chat_modal.dart';

class ContactListModal extends StatefulWidget {
  final BuildContext parentContext;
  const ContactListModal({Key? key, required this.parentContext}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (modalCtx) => ContactListModal(parentContext: context),
    );
  }

  @override
  State<ContactListModal> createState() => _ContactListModalState();
}

class _ContactListModalState extends State<ContactListModal> {
  List<dynamic> _staffList = [];
  bool _isLoading = true;

  final Color bg = const Color(0xFF0D1B2A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _fetchStaff();
  }

  Future<void> _fetchStaff() async {
    try {
      dynamic res;
      try {
        res = await ApiService.instance.get('/admin/workers');
      } catch (_) {
        try {
          res = await ApiService.instance.get('/workers');
        } catch (_) {
          res = await ApiService.instance.get('/users');
        }
      }

      List<dynamic> dataList = [];
      if (res is Map && res['data'] != null) {
        final d = res['data'];
        if (d is Map && d['data'] != null) {
          dataList = List<dynamic>.from(d['data']);
        } else if (d is List) {
          dataList = List<dynamic>.from(d);
        }
      } else if (res is List) {
        dataList = List<dynamic>.from(res);
      }

      if (mounted) {
        setState(() {
          _staffList = dataList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openChatWith(String memberId, String memberName) {
    final rootCtx = widget.parentContext;
    Navigator.pop(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootCtx.mounted) {
        GlobalChatModal.openChatWithUser(
          rootCtx,
          targetUserId: memberId,
          targetName: memberName,
          isCustomer: false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.70,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.contact_support_outlined, color: accentBlue, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Contact Staff & Support',
                  style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Select an admin or team member to start a chat',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _staffList.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline, color: muted, size: 48),
                            const SizedBox(height: 12),
                            Text('No contacts found', style: TextStyle(color: muted)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: _staffList.length,
                        itemBuilder: (context, index) {
                          final data = _staffList[index] as Map<String, dynamic>;
                          final memberId = data['id']?.toString() ?? '';
                          final firstName = data['first_name'] ?? '';
                          final lastName = data['last_name'] ?? '';
                          final memberName = (data['display_name'] as String?)?.trim().isNotEmpty == true
                              ? data['display_name'] as String
                              : '$firstName $lastName'.trim().isNotEmpty
                                  ? '$firstName $lastName'.trim()
                                  : (data['name'] ?? 'Staff Member');
                          final role = data['role'] is Map ? (data['role']['name'] ?? '') : (data['role'] ?? data['job_title'] ?? '');
                          final initial = memberName.isNotEmpty ? memberName[0].toUpperCase() : '?';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: accentBlue.withOpacity(0.2),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      color: accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  memberName,
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                subtitle: role.toString().isNotEmpty
                                    ? Text(
                                        role.toString().toUpperCase(),
                                        style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
                                      )
                                    : null,
                                trailing: Icon(Icons.chat_bubble_outline_rounded, color: accentBlue, size: 20),
                                onTap: () => _openChatWith(memberId, memberName),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

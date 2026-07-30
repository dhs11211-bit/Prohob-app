import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';

import '../components/global_chat_modal.dart';
import '/backend/api_service.dart';
import '/backend/reverb_service.dart';
import '/shared/toast_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';

class CustomInbox extends StatefulWidget {
  const CustomInbox({Key? key, this.width, this.height}) : super(key: key);
  final double? width;
  final double? height;
  @override
  State<CustomInbox> createState() => _CustomInboxState();
}

class _CustomInboxState extends State<CustomInbox> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  final List<String> _pinnedChats = [];

  List<dynamic> _conversations = [];
  bool _isLoading = true;

  // Staff list for Direct Message picker
  List<dynamic> _staffMembers = [];
  bool _isLoadingStaff = false;

  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentRed = const Color(0xFFEF4444);

  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    
    // Initialize Reverb
    ReverbService.instance.init().then((_) {
      // Subscribe to real-time updates for the inbox list
      ReverbService.instance.onConversationUpdated = (data) {
        _fetchConversations();
      };
      
      // Fetch user details to subscribe to their specific channel
      ApiService.instance.getMe().then((user) {
        if (mounted && user != null) {
          setState(() {
            _currentUserId = user['id'];
          });
        }
        if (user != null && user['cl_id'] != null) {
          ReverbService.instance.subscribeToConversations(user['cl_id']);
        }
      }).catchError((e) { debugPrint('Error getting user: $e'); return null; });
    });
  }

  Future<void> _fetchConversations() async {
    try {
      final res = await ApiService.instance.getConversations();
      if (mounted) {
        setState(() {
          var resData = res['data'];
          if (resData is Map) {
            _conversations = resData['data'] ?? [];
          } else {
            _conversations = resData ?? [];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching conversations: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showChatOptions(String chatId, String title) {
    bool isPinned = _pinnedChats.contains(chatId);

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: muted.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text(title,
                    style: TextStyle(
                        color: text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(
                      isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                      color: Colors.orange),
                  title: Text(isPinned ? 'Unpin Chat' : 'Pin Chat',
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      isPinned
                          ? _pinnedChats.remove(chatId)
                          : _pinnedChats.add(chatId);
                    });
                  },
                ),
                const SizedBox(height: 20),
              ],
            )));
  }



  Widget _buildChatTile(
      String chatId,
      String title,
      String subtitle,
      String lastMsg,
      String timeStr,
      bool hasUnread,
      bool isPinned,
      bool isGroup) {
    return Dismissible(
        key: Key(chatId),
        direction: DismissDirection.horizontal,
        background: Container(
            color: Colors.orange,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                color: Colors.white)),
        secondaryBackground: Container(
            color: Colors.redAccent,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: const Icon(Icons.delete_forever, color: Colors.white)),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Not hiding chat on server for now
            return false;
          } else {
            setState(() {
              isPinned ? _pinnedChats.remove(chatId) : _pinnedChats.add(chatId);
            });
            return false;
          }
        },
        child: InkWell(
            onLongPress: () => _showChatOptions(chatId, title),
            onTap: () {
              if (_currentUserId != null) {
                GlobalChatModal.show(
                  context,
                  chatId: chatId,
                  title: title,
                  subtitle: subtitle,
                  isGroup: isGroup,
                  currentUserId: _currentUserId!,
                  onClose: () => _fetchConversations(),
                );
              }
            },
            child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                    color:
                        isPinned ? card.withOpacity(0.3) : Colors.transparent,
                    border: Border(
                        bottom:
                            BorderSide(color: Colors.white.withOpacity(0.05)))),
                child: Row(children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: isGroup
                            ? neonAction.withOpacity(0.2)
                            : accentBlue.withOpacity(0.2),
                        child: Text(
                            title.isNotEmpty ? title[0].toUpperCase() : '?',
                            style: TextStyle(
                                color: isGroup ? neonAction : accentBlue,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration:
                              BoxDecoration(color: bg, shape: BoxShape.circle),
                          child: Icon(
                              isGroup ? Icons.groups : Icons.support_agent,
                              color: isGroup ? neonAction : accentBlue,
                              size: 12),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Row(children: [
                          Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: text,
                                    fontSize: 17,
                                    fontWeight: hasUnread
                                        ? FontWeight.bold
                                        : FontWeight.w600)),
                          ),
                          if (isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(Icons.push_pin,
                                color: Colors.orange, size: 14)
                          ]
                        ]),
                        const SizedBox(height: 6),
                        Text(lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: hasUnread ? text : muted,
                                fontSize: 14,
                                fontWeight: hasUnread
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ])),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(timeStr,
                              style: TextStyle(
                                  color: hasUnread ? accentBlue : muted,
                                  fontSize: 12,
                                  fontWeight: hasUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                          const SizedBox(height: 8),
                          if (hasUnread)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: accentBlue,
                                    borderRadius: BorderRadius.circular(10)),
                                child: const Text('NEW',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5)))
                          else
                            const SizedBox(height: 14),
                        ]),
                  )
                ]))));
  }

  Widget _buildUnifiedInboxView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    var docs = _conversations.where((conv) {
      String title = conv['display_name'] ?? conv['name'] ?? conv['customer_name'] ?? 'Chat';
      title = title.replaceAll('Chat with ', '');
      if (_searchQuery.isNotEmpty && !title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    if (docs.isEmpty) {
      return Center(
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: card, shape: BoxShape.circle),
                child: Icon(Icons.forum_outlined,
                    color: accentBlue.withOpacity(0.5), size: 50)),
            const SizedBox(height: 16),
            Text(
                _searchQuery.isEmpty
                    ? 'No active chats'
                    : 'No chats found',
                style: TextStyle(
                    color: text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                _searchQuery.isEmpty
                    ? 'Connect with your company admins.'
                    : 'Try a different search.',
                style: TextStyle(color: muted)),
          ]));
    }

    return ListView.builder(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: docs.length,
        itemBuilder: (context, index) {
          var conv = docs[index];
          String chatId = conv['id'].toString();
          String title = conv['display_name'] ?? conv['name'] ?? conv['customer_name'] ?? 'Chat';
          title = title.replaceAll('Chat with ', '');
          String subtitle = conv['type'] == 'internal' ? 'Staff Chat' : 'Customer Chat';
          
          String lastMsg = conv['last_message']?.toString() ?? '';
          
          String timeStr = '';
          if (conv['last_message_at'] != null) {
            try {
              DateTime dt = DateTime.parse(conv['last_message_at']);
              timeStr = DateFormat('hh:mm a').format(dt.toLocal());
            } catch(e){}
          }
          
          bool hasUnread = (conv['unread_count'] ?? 0) > 0;
          bool isPinned = _pinnedChats.contains(chatId);
          bool isGroup = conv['type'] == 'internal' || conv['type'] == 'group';

          return _buildChatTile(chatId, title, subtitle, lastMsg,
              timeStr, hasUnread, isPinned, isGroup);
        });
  }

  // ─── Fetch staff/workers list ─────────────────────────────────────────
  Future<void> _fetchStaffMembers() async {
    if (_isLoadingStaff) return;
    setState(() => _isLoadingStaff = true);
    try {
      final res = await ApiService.instance.get('/admin/workers');
      if (mounted) {
        List<dynamic> dataList = [];
        if (res is Map && res['data'] != null) {
          final d = res['data'];
          if (d is Map && d['data'] != null) {
            dataList = d['data'];
          } else if (d is List) {
            dataList = d;
          }
        } else if (res is List) {
          dataList = res;
        }
        setState(() {
          _staffMembers = dataList;
          _isLoadingStaff = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff: \$e');
      if (mounted) setState(() => _isLoadingStaff = false);
    }
  }

  // ─── Main "New Chat" option sheet ─────────────────────────────────────
  void _openContactsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Direct Message option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                  ),
                  title: const Text(
                    'Direct Message',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  subtitle: const Text(
                    'Chat 1-on-1 with a staff member or admin',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _openDirectMessagePicker();
                  },
                ),
                const Divider(color: Colors.white10, height: 30),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Staff member picker for Direct Message ───────────────────────────
  void _openDirectMessagePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _StaffPickerSheet(
        onSelected: (memberId, memberName) {
          Navigator.pop(ctx);
          _startDirectMessageWith(memberId, memberName);
        },
      ),
    );
  }


  // ─── Start (or reuse) a 1-on-1 internal conversation ─────────────────
  Future<void> _startDirectMessageWith(String memberId, String memberName) async {
    if (_currentUserId == null) return;

    // Show a brief loading dialog while we look up / create the conversation
    BuildContext? dialogCtx;
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          dialogCtx = ctx;
          return const Center(child: CircularProgressIndicator());
        },
      );
    }

    try {
      // Fetch / create the conversation (network call only — does NOT open modal)
      var me = await ApiService.instance.getMe();
      int currentUserId = me['id'];

      // Look for an existing 1-on-1 internal conversation
      String? foundChatId;
      try {
        var res = await ApiService.instance.getConversations();
        List<dynamic> convs = [];
        final d = res['data'];
        if (d is Map && d['data'] != null) {
          convs = List<dynamic>.from(d['data']);
        } else if (d is List) {
          convs = List<dynamic>.from(d);
        }
        for (var c in convs) {
          if (c['type'] == 'internal' && c['participants'] != null) {
            List<dynamic> parts = c['participants'];
            if (parts.any((p) => p.toString() == memberId)) {
              foundChatId = c['id'].toString();
              break;
            }
          }
        }
      } catch (_) {}

      // Create a new conversation if none found
      if (foundChatId == null) {
        var createRes = await ApiService.instance.createConversation({
          'type': 'internal',
          'name': memberName,
          'participants': [int.parse(memberId)],
        });
        foundChatId = createRes['id']?.toString();
      }

      // Pop the loading dialog BEFORE opening the chat modal
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

      // Now open the chat modal
      if (foundChatId != null && context.mounted) {
        GlobalChatModal.show(
          context,
          chatId: foundChatId!,
          title: memberName,
          subtitle: 'Staff Member',
          isGroup: false,
          currentUserId: currentUserId,
          onClose: _fetchConversations,
        );
      }
    } catch (e) {
      debugPrint('Error opening direct chat: $e');
      // Pop loading dialog on error too
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ToastService.error(context, 'Could not open chat: $e');
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                        color: card, borderRadius: BorderRadius.circular(16)),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      style: TextStyle(color: text),
                      decoration: InputDecoration(
                          icon: Icon(Icons.search, color: muted),
                          hintText: "Search chats...",
                          hintStyle: TextStyle(color: muted),
                          border: InputBorder.none,
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.clear, color: muted),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = "");
                                  })
                              : null),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                    onTap: _openContactsModal,
                    child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                            color: accentBlue,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.edit_square,
                            color: Colors.white, size: 22)))
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _buildUnifiedInboxView(),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Standalone widget for the staff picker so initState fires EXACTLY ONCE
// (avoids infinite API loops that occur when using StatefulBuilder).
// ─────────────────────────────────────────────────────────────────────────────
class _StaffPickerSheet extends StatefulWidget {
  final void Function(String memberId, String memberName) onSelected;
  const _StaffPickerSheet({required this.onSelected});

  @override
  State<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends State<_StaffPickerSheet> {
  List<dynamic> _staff = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStaff(); // called exactly once
  }

  Future<void> _fetchStaff() async {
    try {
      final res = await ApiService.instance.get('/admin/workers');
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
          _staff = dataList;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('_StaffPickerSheet: error fetching staff: \$e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Direct Message',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(
              'Select a staff member or admin',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _staff.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline, color: Colors.white30, size: 48),
                        SizedBox(height: 12),
                        Text(
                          'No staff members found',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: _staff.length,
                    itemBuilder: (_, i) {
                      final data = _staff[i] as Map<String, dynamic>;
                      final memberId   = data['id']?.toString() ?? '';
                      final firstName  = data['first_name'] ?? '';
                      final lastName   = data['last_name']  ?? '';
                      final memberName = (data['display_name'] as String?)?.trim().isNotEmpty == true
                          ? data['display_name'] as String
                          : '$firstName $lastName'.trim().isNotEmpty
                              ? '$firstName $lastName'.trim()
                              : 'Staff Member';
                      final role    = data['role'] ?? data['job_title'] ?? '';
                      final initial = memberName.isNotEmpty ? memberName[0].toUpperCase() : '?';

                      return GestureDetector(
                        onTap: () => widget.onSelected(memberId, memberName),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    const Color(0xFF3B82F6).withOpacity(0.2),
                                child: Text(
                                  initial,
                                  style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      memberName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (role.toString().isNotEmpty)
                                      Text(
                                        role.toString(),
                                        style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white24,
                                size: 16,
                              ),
                            ],
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

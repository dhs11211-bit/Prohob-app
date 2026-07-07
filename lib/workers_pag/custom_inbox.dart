import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';

import '../components/global_chat_modal.dart';
import '/backend/api_service.dart';
import '/backend/reverb_service.dart';
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
      }).catchError((e) => print('Error getting user: $e'));
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

  void _openContactsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: const Center(child: Text('Contact Admin via backend API coming soon', style: TextStyle(color: Colors.white))),
      )
    );
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
          SizedBox(height: MediaQuery.of(context).padding.top + 160), // Push below 150px CustomHeader

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

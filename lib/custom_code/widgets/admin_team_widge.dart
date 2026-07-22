// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import '/backend/api_service.dart';
import '/backend/reverb_service.dart';
import '/components/global_chat_modal.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../../auth/laravel_auth_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';

import '../../shared/image_editor_helper.dart';

// =====================================================================
// 🚀 WIDGET PRINCIPAL DE LA PANTALLA TEAM
// =====================================================================
class AdminTeamWidge extends StatefulWidget {
  const AdminTeamWidge({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
    required this.onChatWithWorker,
    required this.onChatTap,
    this.openCreateWorkerModal = false,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;
  final Future Function(String workerId, String workerName) onChatWithWorker;
  final Future Function(String chatId, String chatName) onChatTap;
  final bool openCreateWorkerModal;

  @override
  State<AdminTeamWidge> createState() => _AdminTeamWidgeState();
}

class _AdminTeamWidgeState extends State<AdminTeamWidge> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BaseAuthUser? _currentUser = currentUser;
  int? _currentUserId;
  String _adminName = "Admin";

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _hourlyRateController = TextEditingController(text: '20');
  bool _isCreatingUser = false;

  String _chatFilter = 'All'; // 'All', 'Unread', 'Groups'
  
  List<dynamic> _allJobs = [];
  bool _isLoadingJobs = true;
  List<dynamic> _allWorkers = [];
  bool _isLoadingWorkers = true;
  List<dynamic> _allChats = [];
  bool _isLoadingChats = true;

  List<Map<String, dynamic>> _availableRoles = [];
  int? _selectedRoleId;
  bool _isLoadingRoles = true;
  Future<void>? _rolesFuture;

  @override
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabSelection);

    _loadAdminProfile();
    _fetchWorkers(); // Initial fetch for the default tab
    _rolesFuture = _fetchRoles();

    if (widget.openCreateWorkerModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddWorkerModal();
      });
    }

    ReverbService.instance.init().then((_) {
      ReverbService.instance.onConversationUpdated = (data) {
        if (_tabController.index == 1) {
          _fetchChats();
        }
      };
      
      ApiService.instance.getMe().then((user) {
        if (mounted && user != null) {
          int? clId = user['cl_id'];
          setState(() {
            _currentUserId = user['id'];
          });
          if (clId != null) {
            ReverbService.instance.subscribeToConversations(clId);
          }
        }
      });
    });
  }

  void _handleTabSelection() {
    if (_tabController.indexIsChanging) return;
    if (_tabController.index == 0) {
      _fetchWorkers();
    } else if (_tabController.index == 1) {
      _fetchChats();
      _fetchJobs();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchChats() async {
    try {
      final res = await ApiService.instance.get('/chat');
      if (mounted) {
        setState(() {
          if (res != null && res['data'] != null) {
            // Check if paginated or direct array
            if (res['data'] is Map && res['data']['data'] != null) {
              _allChats = res['data']['data'];
            } else {
              _allChats = res['data'];
            }
          }
          _isLoadingChats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingChats = false);
      }
      print("Error fetching chats: \$e");
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final res = await ApiService.instance.get('/admin/roles');
      if (res != null && mounted) {
        setState(() {
          List<dynamic> roles = res;
          _availableRoles = roles.map((r) => Map<String, dynamic>.from(r)).toList();
          if (_availableRoles.isNotEmpty) {
            _selectedRoleId = _availableRoles.first['id'];
          }
          _isLoadingRoles = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoles = false;
        });
      }
    }
  }

  Future<void> _fetchJobs() async {
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await ApiService.instance.get('/admin/jobs?start_date=$dateStr&end_date=$dateStr');
      if (mounted) {
        setState(() {
          if (res is List) {
            _allJobs = res;
          } else {
            _allJobs = res['data'] ?? [];
          }
          _isLoadingJobs = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingJobs = false);
    }
  }

  Future<void> _fetchWorkers() async {
    try {
      final res = await ApiService.instance.get('/admin/workers');
      if (mounted) {
        setState(() {
          List dataList = [];
          if (res is List) {
            dataList = res;
          } else {
            dataList = res['data'] ?? [];
          }
          _allWorkers = dataList;
          _isLoadingWorkers = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingWorkers = false);
    }
  }

  Future<void> _loadAdminProfile() async {
    try {
      var user = await ApiService.instance.getMe();
      if (user != null) {
        if (mounted) {
          setState(() {
            _adminName = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim().isEmpty ? "Admin" : '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'.trim();
          });
        }
      }
    } catch (e) {
      print("Error loading admin profile: $e");
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning,";
    if (hour < 18) return "Good afternoon,";
    return "Good evening,";
  }

  String _getUserInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : "A";
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date = timestamp is String ? DateTime.parse(timestamp) : DateTime.now();
    DateTime now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return DateFormat('h:mm a').format(date);
    } else if (now.difference(date).inDays < 7) {
      return DateFormat('EEEE').format(date);
    } else {
      return DateFormat('MMM d').format(date);
    }
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      DateTime date = DateTime.parse(dateStr).toLocal();
      DateTime now = DateTime.now();

      if (date.year == now.year &&
          date.month == now.month &&
          date.day == now.day) {
        return DateFormat('h:mm a').format(date);
      } else if (now.difference(date).inDays < 7) {
        return DateFormat('EEEE').format(date);
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  Future<void> _openFileUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Error opening URL: $e");
    }
  }

  // =====================================================================
  // 🚀 SALA DE CHAT FLOTANTE TIPO WHATSAPP
  // =====================================================================
  void _openChatThreadModal(String chatIdStr, String chatName, bool isGroup,
      String? targetWorkerIdStr, List<dynamic> participants) {
    int chatId = int.tryParse(chatIdStr) ?? 0;
    if (chatId == 0) return;

    TextEditingController msgController = TextEditingController();
    bool isSending = false;
    bool isLoadingMessages = true;
    bool hasInitialized = false;
    List<dynamic> _messages = [];
    String subtitleText = isGroup ? "Group Chat" : "Direct Message";

    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) =>
            StatefulBuilder(builder: (context, setModalState) {

              void _fetchMessages() async {
                try {
                  var res = await ApiService.instance.get('/chat/$chatId/messages');
                  if (res != null && res['data'] != null) {
                    if (res['data'] is Map && res['data']['data'] != null) {
                      _messages = res['data']['data'];
                    } else {
                      _messages = res['data'];
                    }
                    _messages.sort((a, b) {
                      DateTime timeA = DateTime.parse(a['created_at']).toLocal();
                      DateTime timeB = DateTime.parse(b['created_at']).toLocal();
                      return timeB.compareTo(timeA);
                    });
                  }
                } catch (e) {
                  debugPrint("Error fetching messages: $e");
                } finally {
                  if (mounted) {
                    setModalState(() {
                      isLoadingMessages = false;
                    });
                  }
                }
              }

              if (!hasInitialized) {
                hasInitialized = true;
                _fetchMessages();
                ReverbService.instance.subscribeToChat(chatId);
                ReverbService.instance.onMessageReceived = (data) {
                  if (data != null && data['message'] != null) {
                    var msg = data['message'];
                    if (msg['conversation_id'] == chatId) {
                      setModalState(() {
                        // Avoid duplicates if we sent it
                        bool exists = _messages.any((m) => m['id'] == msg['id']);
                        if (!exists) {
                          _messages.insert(0, msg);
                        }
                      });
                    }
                  }
                };
                
                // Mark as read API call
                ApiService.instance.post('/chat/$chatId/read', {}).catchError((e) {
                  debugPrint("Error marking read: $e");
                });
              }

              Future<void> sendImage(ImageSource source) async {
                if (_currentUserId == null) return;
                try {
                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: source,
                    imageQuality: 70,
                  );
                  if (image == null) return;

                  Uint8List imgBytes = await image.readAsBytes();
                  Uint8List? editedBytes = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ImageEditorScreen(imageBytes: imgBytes),
                    ),
                  );
                  if (editedBytes == null) return;

                  setModalState(() => isSending = true);

                  String fileName = '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  
                  var uploadRes = await ApiService.instance.uploadChatMedia(chatId, editedBytes, fileName);
                  if (uploadRes != null && uploadRes['url'] != null) {
                    var msgRes = await ApiService.instance.post('/chat/$chatId/messages', {
                      'content': '📷 Image',
                      'type': 'image',
                      'attachments': [{
                        'url': uploadRes['url'],
                        'filename': uploadRes['filename'],
                      }]
                    });
                    
                    if (msgRes != null && msgRes['status'] == 'success' && msgRes['data'] != null) {
                       setModalState(() {
                         _messages.insert(0, msgRes['data']);
                       });
                    }
                  }

                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setModalState(() => isSending = false);
                  }
                }
              }

              Future<void> sendFile() async {
                if (_currentUserId == null) return;
                try {
                  FilePickerResult? result =
                      await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'doc', 'png', 'jpg', 'jpeg'],
                    withData: true,
                  );
                  if (result == null) return;

                  setModalState(() => isSending = true);

                  String ext =
                      result.files.first.extension?.toLowerCase() ?? 'file';
                  bool isImage =
                      (ext == 'jpg' || ext == 'jpeg' || ext == 'png');
                  String msgType = isImage ? 'image' : 'file';
                  String msgText = isImage ? '📷 Image' : '📄 Document';
                  String fileName =
                      '${_currentUserId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

                  List<int> bytes;
                  if (result.files.first.bytes != null) {
                    bytes = result.files.first.bytes!;
                  } else {
                    File file = File(result.files.first.path!);
                    bytes = await file.readAsBytes();
                  }

                  var uploadRes = await ApiService.instance.uploadChatMedia(chatId, bytes, fileName);
                  if (uploadRes != null && uploadRes['url'] != null) {
                    var msgRes = await ApiService.instance.post('/chat/$chatId/messages', {
                      'content': msgText,
                      'type': msgType,
                      'attachments': [{
                        'url': uploadRes['url'],
                        'filename': uploadRes['filename'],
                      }]
                    });
                    
                    if (msgRes != null && msgRes['status'] == 'success' && msgRes['data'] != null) {
                       setModalState(() {
                         _messages.insert(0, msgRes['data']);
                       });
                    }
                  }

                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Upload failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                } finally {
                  if (mounted) {
                    setModalState(() => isSending = false);
                  }
                }
              }

              void showAttachmentMenu() {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => Container(
                    padding: const EdgeInsets.only(top: 30, bottom: 50),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1E293B),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                sendImage(ImageSource.gallery);
                              },
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Colors.purpleAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.image,
                                    color: Colors.white, size: 30),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Gallery',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                sendFile();
                              },
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                decoration: const BoxDecoration(
                                  color: Colors.blueAccent,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.insert_drive_file,
                                  color: Colors.white,
                                  size: 30,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Document',
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) => Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      children: [
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.05)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isGroup
                                      ? const Color(0xFF10B981)
                                          .withOpacity(0.2)
                                      : const Color(0xFF3B82F6)
                                          .withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isGroup ? Icons.groups : Icons.person,
                                  color: isGroup
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF3B82F6),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      chatName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      subtitleText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white60),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: isLoadingMessages
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF3B82F6)),
                                )
                              : _messages.isEmpty
                                  ? const Center(
                                      child: Text(
                                        "Say hello to start the chat!",
                                        style: TextStyle(
                                            color: Colors.white38),
                                      ),
                                    )
                                  : ListView.builder(
                                      controller: scrollController,
                                      reverse: true,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 20),
                                      itemCount: _messages.length,
                                      itemBuilder: (context, index) {
                                        var data = _messages[index] as Map<String, dynamic>;
                                        bool isMe = data['sender_id'] == _currentUserId;
                                        
                                        String? fileUrl;
                                        if (data['attachments'] != null && (data['attachments'] as List).isNotEmpty) {
                                          fileUrl = data['attachments'][0]['url'];
                                        }
                                        
                                        bool isImageMsg =
                                            data['type'] == 'image' && fileUrl != null;
                                        bool isDocMsg =
                                            data['type'] == 'file' && fileUrl != null;

                                        String senderName = data['sender_name'] ?? 'Worker';
                                        String senderInitial =
                                            senderName.isNotEmpty
                                                ? senderName[0].toUpperCase()
                                                : 'W';

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Row(
                                            mainAxisAlignment: isMe
                                                ? MainAxisAlignment.end
                                                : MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              if (!isMe) ...[
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor:
                                                      const Color(0xFF1E293B),
                                                  child: Text(
                                                    senderInitial,
                                                    style: const TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              Flexible(
                                                child: Container(
                                                  padding: EdgeInsets.all(
                                                      isImageMsg ? 4 : 16),
                                                  decoration: BoxDecoration(
                                                    color: isMe
                                                        ? const Color(
                                                            0xFF3B82F6)
                                                        : const Color(
                                                            0xFF1E293B),
                                                    borderRadius:
                                                        BorderRadius.only(
                                                      topLeft:
                                                          const Radius.circular(
                                                              20),
                                                      topRight:
                                                          const Radius.circular(
                                                              20),
                                                      bottomLeft:
                                                          Radius.circular(
                                                              isMe ? 20 : 4),
                                                      bottomRight:
                                                          Radius.circular(
                                                              isMe ? 4 : 20),
                                                    ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: isMe
                                                        ? CrossAxisAlignment.end
                                                        : CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      if (isGroup && !isMe)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .only(
                                                                  bottom: 4),
                                                          child: Text(
                                                            senderName,
                                                            style:
                                                                const TextStyle(
                                                              color: Color(
                                                                  0xFF10B981),
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      if (isImageMsg)
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _openFileUrl(fileUrl!),
                                                          child: ClipRRect(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        16),
                                                            child:
                                                                Image.network(
                                                              fileUrl!,
                                                              width: 200,
                                                              fit: BoxFit.cover,
                                                            ),
                                                          ),
                                                        )
                                                      else if (isDocMsg)
                                                        GestureDetector(
                                                          onTap: () =>
                                                              _openFileUrl(fileUrl!),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Icon(
                                                                Icons
                                                                    .insert_drive_file,
                                                                color: isMe
                                                                    ? Colors
                                                                        .white
                                                                    : const Color(
                                                                        0xFF10B981),
                                                                size: 24,
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Text(
                                                                'Document Attached',
                                                                style:
                                                                    TextStyle(
                                                                  color: isMe
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .white,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  decoration:
                                                                      TextDecoration
                                                                          .underline,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        )
                                                      else
                                                        Text(
                                                          data['content'] ?? '',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 15,
                                                          ),
                                                        ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsets.only(
                                                          top: 4,
                                                          right: isImageMsg
                                                              ? 8
                                                              : 0,
                                                          bottom: isImageMsg
                                                              ? 4
                                                              : 0,
                                                        ),
                                                        child: Text(
                                                          _formatTimestampLaravel(data['created_at']),
                                                          style: TextStyle(
                                                            color: isMe
                                                                ? Colors.white
                                                                    .withOpacity(
                                                                        0.7)
                                                                : Colors
                                                                    .white38,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            border: Border(
                                top: BorderSide(
                                    color:
                                        Colors.white.withOpacity(0.05))),
                          ),
                          child: isSending
                              ? const Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF3B82F6)))
                              : Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt,
                                          color: Colors.white60),
                                      onPressed: () =>
                                          sendImage(ImageSource.camera),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.attach_file,
                                          color: Colors.white60),
                                      onPressed: showAttachmentMenu,
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0D1B2A),
                                          borderRadius:
                                              BorderRadius.circular(24),
                                          border: Border.all(
                                              color: Colors.white10),
                                        ),
                                        child: TextField(
                                          controller: msgController,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          maxLines: null,
                                          keyboardType:
                                              TextInputType.multiline,
                                          decoration:
                                              const InputDecoration(
                                            hintText: "Message...",
                                            hintStyle: TextStyle(
                                                color: Colors.white38),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () async {
                                        if (msgController.text
                                                .trim()
                                                .isEmpty ||
                                            _currentUserId == null) return;
                                        setModalState(
                                            () => isSending = true);
                                        String text =
                                            msgController.text.trim();
                                        msgController.clear();

                                        try {
                                          var msgRes = await ApiService.instance.post('/chat/$chatId/messages', {
                                            'content': text,
                                            'type': 'text',
                                          });
                                          
                                          if (msgRes != null && msgRes['status'] == 'success' && msgRes['data'] != null) {
                                            setModalState(() {
                                              _messages.insert(0, msgRes['data']);
                                            });
                                          }
                                        } catch (e) {
                                          debugPrint("Error sending text: $e");
                                        } finally {
                                          if (mounted) {
                                            setModalState(
                                                () => isSending = false);
                                          }
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF3B82F6),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.send,
                                            color: Colors.white,
                                            size: 20),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            })).whenComplete(() {
      ReverbService.instance.unsubscribeFromChat(chatId);
      ReverbService.instance.onMessageReceived = null;
    });
  }

  String _formatTimestampLaravel(String? dateStr) {
    if (dateStr == null) return '';
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      String hour = dt.hour > 12 ? (dt.hour - 12).toString() : dt.hour.toString();
      if (hour == '0') hour = '12';
      String minute = dt.minute.toString().padLeft(2, '0');
      String ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $ampm';
    } catch (_) {
      return '';
    }
  }

  // =====================================================================
  // --- MOTOR PARA CREAR CHATS DIRECTOS 1 A 1 ---
  // =====================================================================
  Future<void> _startDirectChat(String workerIdStr, String workerName) async {
    if (_currentUserId == null) return;
    int workerId = int.tryParse(workerIdStr) ?? 0;
    if (workerId == 0) return;

    try {
      String? existingChatId;
      for (var chat in _allChats) {
        List parts = chat['participants'] as List? ?? [];
        if (chat['type'] == 'internal' && parts.contains(workerId)) {
          existingChatId = chat['id']?.toString();
          break;
        }
      }

      if (existingChatId != null) {
        _openChatThreadModal(
            existingChatId, workerName, false, workerIdStr, [_currentUserId, workerId]);
      } else {
        var newChat = await ApiService.instance.post('/conversations', {
          'type': 'internal',
          'participants': [_currentUserId, workerId],
          'name': workerName,
        });
        
        if (newChat != null && newChat['id'] != null) {
            _openChatThreadModal(
                newChat['id'].toString(), workerName, false, workerIdStr, [_currentUserId, workerId]);
            _fetchChats(); // Refresh the list
        }
      }
    } catch (e) {
      debugPrint("Error starting chat: $e");
    }
  }

  // =====================================================================
  // --- CREAR GRUPOS DESDE TRABAJOS ---
  // =====================================================================
  void _showJobGroupCreationModal() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Create Job Group',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Select an active job with 2 or more workers.',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                  child: Builder(
                      builder: (context) {
                        if (_isLoadingJobs) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        var jobs = _allJobs.where((data) {
                          // The API returns assigned_users as an array of user objects
                          List workers = data['assigned_users'] ?? [];
                          return workers.length >= 2;
                        }).toList();

                        if (jobs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No jobs with multiple workers found.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          );
                        }

                        return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: jobs.length,
                            itemBuilder: (ctx, i) {
                              var data = jobs[i];
                              String jobId = data['id'].toString();
                              String jobName =
                                  "${data['customer_name'] ?? data['title']} - ${data['job_type'] ?? ''}";
                              List assignedUsers = data['assigned_users'] as List? ?? [];

                              return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _createGroupFromJob(
                                        jobId, jobName, assignedUsers);
                                  },
                                  child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: Colors.white10),
                                      ),
                                      child: Row(children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.groups,
                                              color: Color(0xFF10B981)),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                jobName,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              Text(
                                                "${assignedUsers.length} Workers assigned",
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 12,
                                                ),
                                              )
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.add_circle,
                                            color: Color(0xFF3B82F6), size: 24)
                                      ])));
                            });
                      }))
            ])));
  }

  void _createGroupFromJob(String jobId, String jobName, List assignedUsers) async {
    List<Map<String, dynamic>> workersInfo = [];
    for (var u in assignedUsers) {
      workersInfo.add({'id': u['id'].toString(), 'name': '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim().isEmpty ? 'Worker' : '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'.trim()});
    }
    List<String> selectedWorkers = workersInfo.map((w) => w['id'] as String).toList();

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: Text(
                      "Group: $jobName",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    content: SizedBox(
                        width: double.maxFinite,
                        height: 250,
                        child: ListView.builder(
                            itemCount: workersInfo.length,
                            itemBuilder: (context, i) {
                              String wId = workersInfo[i]['id'];
                              return CheckboxListTile(
                                  title: Text(
                                    workersInfo[i]['name'],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  value: selectedWorkers.contains(wId),
                                  activeColor: const Color(0xFF3B82F6),
                                  checkColor: Colors.white,
                                  onChanged: (bool? val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedWorkers.add(wId);
                                      } else {
                                        selectedWorkers.remove(wId);
                                      }
                                    });
                                  });
                            })),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.white60)),
                      ),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981)),
                          onPressed: () async {
                            if (selectedWorkers.isEmpty) return;
                            List<dynamic> participants = List.from(selectedWorkers.map((id) => int.tryParse(id)).where((id) => id != null));
                            
                            if (_currentUserId != null && !participants.contains(_currentUserId)) {
                              participants.add(_currentUserId);
                            }

                            try {
                                var newChat = await ApiService.instance.post('/conversations', {
                                    'type': 'group',
                                    'name': jobName,
                                    'job_id': int.tryParse(jobId),
                                    'participants': participants,
                                });
                                
                                Navigator.pop(ctx);
                                
                                if (newChat != null && newChat['id'] != null) {
                                    _openChatThreadModal(
                                        newChat['id'].toString(), jobName, true, null, participants);
                                    _fetchChats(); // Refresh the list
                                }
                            } catch (e) {
                                print("Error creating group: $e");
                            }
                          },
                          child: const Text("Create Group",
                              style: TextStyle(color: Colors.white)))
                    ])));
  }

  void _showNewChatOptions() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                    ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person, color: Color(0xFF3B82F6)),
                        ),
                        title: const Text(
                          "Direct Message",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: const Text(
                          "Chat 1-on-1 with a staff member",
                          style: TextStyle(color: Colors.white60),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showNewDirectChatModal();
                        }),
                    const Divider(color: Colors.white10, height: 30),
                    ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.groups, color: Color(0xFF10B981)),
                        ),
                        title: const Text(
                          "Job Group",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: const Text(
                          "Create a team chat for a job",
                          style: TextStyle(color: Colors.white60),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showJobGroupCreationModal();
                        }),
                    const SizedBox(height: 20),
                  ]),
                ),
              ),
            )));
  }

  void _showNewDirectChatModal() {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
            height: MediaQuery.of(context).size.height * 0.65,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Select a staff member',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                  child: Builder(
                      builder: (context) {
                        if (_isLoadingWorkers) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (_allWorkers.isEmpty) {
                          return const Center(
                            child: Text(
                              'No staff members found.',
                              style: TextStyle(color: Colors.white60),
                            ),
                          );
                        }

                        return ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            itemCount: _allWorkers.length,
                            itemBuilder: (ctx, i) {
                              var data = _allWorkers[i] as Map<String, dynamic>;
                              String workerId = data['id']?.toString() ?? '';
                              String workerName =
                                  data['display_name'] ?? ('${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim().isEmpty ? 'Staff Member' : '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim());

                              return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(context);
                                    _startDirectChat(workerId, workerName);
                                  },
                                  child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: Colors.white10),
                                      ),
                                      child: Row(children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              const Color(0xFF3B82F6)
                                                  .withOpacity(0.2),
                                          child: Text(
                                            workerName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Text(
                                            workerName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chat_bubble_outline,
                                          color: Colors.white38,
                                          size: 20,
                                        )
                                      ])));
                            });
                      }))
            ])));
  }

  // =====================================================================
  // --- FUNCIONES DE PERFIL Y WORKERS ---
  // =====================================================================

  void _showAdminPersonalInfoModal() {
    TextEditingController firstNameCtrl = TextEditingController(text: _adminName.split(' ').first);
    TextEditingController lastNameCtrl = TextEditingController(text: _adminName.split(' ').length > 1 ? _adminName.split(' ').sublist(1).join(' ') : '');
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
              return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2A),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                                    width: 40,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius:
                                            BorderRadius.circular(10)))),
                            const SizedBox(height: 24),
                            const Text("Personal Information",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            const Text("Email Address (Uneditable)",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(_currentUser?.email ?? "No Email",
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 16)),
                            ),
                            const SizedBox(height: 20),
                            const Text("First Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildTextField(
                                controller: firstNameCtrl,
                                label: "First Name",
                                icon: Icons.person),
                            const SizedBox(height: 20),
                            const Text("Last Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildTextField(
                                controller: lastNameCtrl,
                                label: "Last Name",
                                icon: Icons.person_outline),
                            const SizedBox(height: 32),
                            SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty)
                                            return;
                                          setModalState(() => isSaving = true);
                                          try {
                                            await ApiService.instance.put('/employee/profile', {
                                              'first_name': firstNameCtrl.text.trim(),
                                              'last_name': lastNameCtrl.text.trim(),
                                            });
                                            setState(() => _adminName =
                                                '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}');
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Profile updated successfully!'),
                                                    backgroundColor:
                                                        Color(0xFF10B981)));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text('Error: $e'),
                                                    backgroundColor:
                                                        Colors.redAccent));
                                          } finally {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        },
                                  child: isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text("Save Changes",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                ))
                          ])));
            }));
  }

  void _showAdminProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2A3B5A),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _getUserInitial(_adminName),
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _adminName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentUser?.email ?? "",
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.person_outline,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      "Personal Information",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showAdminPersonalInfoModal();
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.logout,
                      color: Color(0xFFEF4444),
                    ),
                    title: const Text(
                      "Sign out",
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: Colors.white38,
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await widget.onLogout();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<String?> _createNewWorker() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      return "Please fill all fields";
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      return "Passwords do not match";
    }

    if (_selectedRoleId == null) {
      return "Please select a role";
    }

    try {
      final res = await ApiService.instance.post('/admin/workers', {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'hourly_rate': double.tryParse(_hourlyRateController.text) ?? 20.0,
        'cost_rate': double.tryParse(_hourlyRateController.text) ?? 20.0,
        'role_id': _selectedRoleId,
      });

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        setState(() {
          _firstNameController.clear();
          _lastNameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _confirmPasswordController.clear();
          _hourlyRateController.text = '20';
        });
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              "Worker added successfully!",
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchWorkers(); // Refresh the list
      }
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  void _showAddWorkerModal() {
    String? _createWorkerError;
    bool _obscurePassword = true;
    bool _obscureConfirmPassword = true;
    bool _isCreatingUserLocal = false;
    bool _isFetchingRolesLocal = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
              if (_isLoadingRoles && !_isFetchingRolesLocal) {
                _isFetchingRolesLocal = true;
                _rolesFuture?.then((_) {
                  if (mounted) {
                    setModalState(() {});
                  }
                });
              }

              return Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 8),
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Add New Staff Member",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white60),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Create an account for your new team member.",
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Stack(
                              children: [
                                AbsorbPointer(
                                  absorbing: _isLoadingRoles,
                                  child: Opacity(
                                    opacity: _isLoadingRoles ? 0.5 : 1.0,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (_createWorkerError != null) ...[
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEF4444)
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: const Color(0xFFEF4444)
                                                      .withOpacity(0.5)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.error_outline,
                                                    color: Color(0xFFEF4444),
                                                    size: 20),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _createWorkerError!,
                                                    style: const TextStyle(
                                                        color: Color(0xFFEF4444),
                                                        fontSize: 14),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                        _buildTextField(
                                          controller: _firstNameController,
                                          label: "First Name",
                                          icon: Icons.person_outline,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _lastNameController,
                                          label: "Last Name",
                                          icon: Icons.person_outline,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _emailController,
                                          label: "Email Address",
                                          icon: Icons.email_outlined,
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: DropdownButtonFormField<int>(
                                            value: _selectedRoleId,
                                            isExpanded: true,
                                            dropdownColor:
                                                const Color(0xFF1E293B),
                                            icon: const Padding(
                                              padding:
                                                  EdgeInsets.only(right: 8.0),
                                              child: Icon(Icons.arrow_drop_down,
                                                  color: Colors.white60),
                                            ),
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(
                                                  Icons.work_outline,
                                                  color: Color(0xFF3B82F6)),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                      vertical: 16),
                                            ),
                                            hint: const Text("Select Role",
                                                style: TextStyle(
                                                    color: Colors.white38)),
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16),
                                            items: _availableRoles.map((role) {
                                              return DropdownMenuItem<int>(
                                                value: role['id'] as int,
                                                child: Text(role['name'] ??
                                                    'Unknown Role'),
                                              );
                                            }).toList(),
                                            onChanged: (int? newValue) {
                                              setModalState(() {
                                                _selectedRoleId = newValue;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _passwordController,
                                          label: "Password",
                                          icon: Icons.lock_outline,
                                          obscure: _obscurePassword,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.white38,
                                            ),
                                            onPressed: () {
                                              setModalState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller:
                                              _confirmPasswordController,
                                          label: "Confirm Password",
                                          icon: Icons.lock_outline,
                                          obscure: _obscureConfirmPassword,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscureConfirmPassword
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                              color: Colors.white38,
                                            ),
                                            onPressed: () {
                                              setModalState(() {
                                                _obscureConfirmPassword =
                                                    !_obscureConfirmPassword;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _hourlyRateController,
                                          label: "Hourly Rate (\$)",
                                          icon: Icons.attach_money,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                        ),
                                        const SizedBox(height: 32),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isLoadingRoles)
                                  const Positioned.fill(
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2A),
                        border: Border(
                          top: BorderSide(color: Colors.white10),
                        ),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isCreatingUserLocal
                              ? null
                              : () async {
                                  setModalState(() {
                                    _isCreatingUserLocal = true;
                                    _createWorkerError = null;
                                  });
                                  String? error = await _createNewWorker();
                                  if (mounted) {
                                    setModalState(() {
                                      _isCreatingUserLocal = false;
                                      _createWorkerError = error;
                                    });
                                    if (error != null) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Failed to create staff member: $error",
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                          backgroundColor: const Color(0xFFEF4444),
                                        ),
                                      );
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isCreatingUserLocal
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Create Worker",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  void _showEditRateDialog(dynamic userId, double currentRate) {
    String idStr = userId?.toString() ?? '';
    TextEditingController rateCtrl =
        TextEditingController(text: currentRate.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Edit Hourly Rate",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: _buildTextField(
            controller: rateCtrl,
            label: "Hourly Rate (\$)",
            icon: Icons.attach_money,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
              ),
              onPressed: () async {
                if (rateCtrl.text.isNotEmpty) {
                  try {
                    double newRate =
                        double.tryParse(rateCtrl.text) ?? currentRate;
                    
                    final messenger = ScaffoldMessenger.of(context);
                    await ApiService.instance.put('/admin/workers/$idStr', {
                      'hourly_rate': newRate,
                      'cost_rate': newRate,
                    });

                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                    _fetchWorkers(); // Refresh the data

                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Hourly Rate updated successfully!",
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  } catch (e) {
                    String errorMsg = e.toString().replaceAll('Exception: ', '');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            "Failed to update hourly rate: $errorMsg",
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: const Color(0xFFEF4444),
                        ),
                      );
                    }
                  }
                }
              },
              child: const Text(
                "Save",
                style: TextStyle(color: Colors.white),
              ),
            )
          ],
        );
      },
    );
  }

  void _showEditWorkerModal(Map<String, dynamic> workerData) {
    String userId = (workerData['uid'] ?? workerData['id'] ?? '').toString();
    String name = workerData['display_name'] ?? workerData['name'] ?? '';
    List<String> nameParts = name.trim().split(' ');
    String defaultFirst = workerData['first_name'] ?? (nameParts.isNotEmpty ? nameParts.first : '');
    String defaultLast = workerData['last_name'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    TextEditingController firstNameCtrl = TextEditingController(text: defaultFirst);
    TextEditingController lastNameCtrl = TextEditingController(text: defaultLast);
    TextEditingController emailCtrl = TextEditingController(text: workerData['email'] ?? '');
    TextEditingController phoneCtrl = TextEditingController(text: workerData['phone'] ?? workerData['mobile'] ?? '');
    TextEditingController addressCtrl = TextEditingController(text: workerData['address'] ?? workerData['address1'] ?? '');
    double currentRate = double.tryParse(workerData['hourly_rate']?.toString() ?? workerData['cost_rate']?.toString() ?? '') ?? 20.0;
    TextEditingController rateCtrl = TextEditingController(text: currentRate.toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Edit Staff Member",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white60),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text("First Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: firstNameCtrl,
                                label: "First Name",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              const Text("Last Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: lastNameCtrl,
                                label: "Last Name",
                                icon: Icons.person_outline,
                              ),
                              const SizedBox(height: 16),
                              const Text("Email Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: emailCtrl,
                                label: "Email Address",
                                icon: Icons.email_outlined,
                              ),
                              const SizedBox(height: 16),
                              const Text("Phone Number",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: phoneCtrl,
                                label: "Phone Number",
                                icon: Icons.phone_outlined,
                              ),
                              const SizedBox(height: 16),
                              const Text("Street Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: addressCtrl,
                                label: "Address",
                                icon: Icons.location_on_outlined,
                              ),
                              const SizedBox(height: 16),
                              const Text("Hourly Rate (\$)",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildTextField(
                                controller: rateCtrl,
                                label: "Hourly Rate (\$)",
                                icon: Icons.attach_money,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D1B2A),
                          border: Border(
                            top: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (firstNameCtrl.text.trim().isNotEmpty &&
                                  lastNameCtrl.text.trim().isNotEmpty) {
                                try {
                                  double newRate =
                                      double.tryParse(rateCtrl.text.trim()) ??
                                          currentRate;
                                  Map<String, dynamic> payload = {
                                    'first_name': firstNameCtrl.text.trim(),
                                    'last_name': lastNameCtrl.text.trim(),
                                    'hourly_rate': newRate,
                                    'cost_rate': newRate,
                                  };
                                  if (emailCtrl.text.trim().isNotEmpty) payload['email'] = emailCtrl.text.trim();
                                  if (phoneCtrl.text.trim().isNotEmpty) {
                                    payload['phone'] = phoneCtrl.text.trim();
                                    payload['mobile'] = phoneCtrl.text.trim();
                                  }
                                  if (addressCtrl.text.trim().isNotEmpty) {
                                    payload['address'] = addressCtrl.text.trim();
                                    payload['address1'] = addressCtrl.text.trim();
                                  }

                                  final messenger = ScaffoldMessenger.of(context);
                                  await ApiService.instance
                                      .put('/admin/workers/$userId', payload);

                                  Navigator.pop(context);
                                  Navigator.of(context).maybePop();
                                  _fetchWorkers();

                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Staff info updated successfully!",
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                } catch (e) {
                                  String errorMsg = e.toString().replaceAll('Exception: ', '');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Failed to update staff info: $errorMsg",
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        backgroundColor: const Color(0xFFEF4444),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            child: const Text(
                              "Save Changes",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showWorkerDetailsModal(Map<String, dynamic> workerData) {
    double hourlyRate = double.tryParse(workerData['hourly_rate']?.toString() ?? workerData['cost_rate']?.toString() ?? '') ?? 16.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor:
                                const Color(0xFF3B82F6).withOpacity(0.2),
                            child: Text(
                              workerData['display_name']?[0]?.toUpperCase() ??
                                  'W',
                              style: const TextStyle(
                                color: Color(0xFF3B82F6),
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  workerData['display_name'] ?? 'No Name',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  workerData['email'] ?? 'No Email',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: const [
                          Icon(Icons.folder_open,
                              color: Colors.white, size: 20),
                          SizedBox(width: 8),
                          Text(
                            "Documents & Payroll",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Compensation",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoField(
                              "Hourly Rate",
                              "\$${hourlyRate.toStringAsFixed(2)} / hr",
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _showEditRateDialog(
                              workerData['uid']?.toString() ?? workerData['id']?.toString() ?? '',
                              hourlyRate,
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Identity & Compliance",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentTile(
                        context,
                        "Photo ID",
                        "Driver's license",
                        Icons.badge_outlined,
                        workerData['photo_id_url']?.toString(),
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentTile(
                        context,
                        "SSN Card",
                        "Copy of SSN",
                        Icons.credit_card_outlined,
                        workerData['ssn_url']?.toString(),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Tax Information",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentTile(
                        context,
                        "W-9 Form",
                        "Tax document",
                        Icons.description_outlined,
                        workerData['w9_url']?.toString(),
                      ),
                      const SizedBox(height: 12),
                      _buildDocumentTile(
                        context,
                        "Direct Deposit",
                        "Bank authorization",
                        Icons.account_balance_outlined,
                        workerData['bank_url']?.toString(),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.person_outline,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                "Personal Info",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showEditWorkerModal(workerData),
                            icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                            label: const Text("Edit Info", style: TextStyle(color: Colors.white, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "BASIC INFORMATION",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        "Full Legal Name",
                        workerData['display_name'] ?? '-',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoField(
                              "Date of Birth",
                              workerData['dob']?.isNotEmpty == true
                                  ? workerData['dob']
                                  : '-',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildInfoField(
                              "Emergency Contact",
                              workerData['emergency_name']?.isNotEmpty == true
                                  ? workerData['emergency_name']
                                  : '-',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "CONTACT & ADDRESS",
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        "Mobile Phone",
                        workerData['phone']?.isNotEmpty == true
                            ? workerData['phone']
                            : '-',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        "Street Address",
                        workerData['address']?.isNotEmpty == true
                            ? workerData['address']
                            : '-',
                      ),
                      const SizedBox(height: 12),
                      _buildInfoField(
                        "City, Zip",
                        workerData['city']?.isNotEmpty == true
                            ? workerData['city']
                            : '-',
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(BuildContext modalContext, String title,
      String subtitle, IconData icon, String? fileUrl) {
    bool isUploaded = fileUrl != null && fileUrl.isNotEmpty;

    return GestureDetector(
      onTap: () async {
        if (isUploaded) {
          try {
            await launchUrl(Uri.parse(fileUrl));
          } catch (e) {
            ScaffoldMessenger.of(modalContext).showSnackBar(
              SnackBar(
                content: Text("Could not open document: $e"),
                backgroundColor: const Color(0xFFEF4444),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(modalContext).showSnackBar(
            const SnackBar(
              content: Text("No document uploaded yet."),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isUploaded
                ? const Color(0xFF10B981).withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF3B82F6), size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isUploaded)
              Column(
                children: const [
                  Icon(
                    Icons.remove_red_eye,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "View",
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            else
              Column(
                children: const [
                  Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.white38,
                    size: 20,
                  ),
                  SizedBox(height: 4),
                  Text(
                    "Missing",
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String label,
      required IconData icon,
      TextInputType? keyboardType,
      bool obscure = false,
      Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  // =================================================================
  // 🚀 ESTRUCTURA PRINCIPAL DE LA PANTALLA CON LOS TABS
  // =================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: SafeArea(
          child: Column(
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF3B82F6),
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white38,
                tabs: const [Tab(text: "Staff Members"), Tab(text: "Chats")],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // --- PESTAÑA 1: DIRECTORIO DE TRABAJADORES ---
                    Stack(
                      children: [
                        RefreshIndicator(
                          onRefresh: _fetchWorkers,
                          color: const Color(0xFF3B82F6),
                          child: Builder(
                            builder: (context) {
                              if (_isLoadingWorkers) {
                                return const Center(
                                  child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                                );
                              }
                              if (_allWorkers.isEmpty) {
                                return ListView(
                                  children: const [
                                    Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(32.0),
                                        child: Text(
                                          "No workers registered yet.",
                                          style: TextStyle(color: Colors.white60),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24.0,
                                  vertical: 8.0,
                                ),
                                itemCount: _allWorkers.length,
                                itemBuilder: (context, index) {
                                  var data = _allWorkers[index];
                                  data['id'] = data['id']?.toString() ?? '';

                                return GestureDetector(
                                  onTap: () => _showWorkerDetailsModal(data),
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.white10),
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundColor:
                                              const Color(0xFF3B82F6)
                                                  .withOpacity(0.2),
                                          child: Text(
                                            data['display_name']?[0]
                                                    ?.toUpperCase() ??
                                                'W',
                                            style: const TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['display_name'] ??
                                                    'Unknown Worker',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                data['email'] ?? '',
                                                style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            "Active",
                                            style: TextStyle(
                                              color: Color(0xFF10B981),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        GestureDetector(
                                          onTap: () => _startDirectChat(
                                            data['id']?.toString() ?? '',
                                            data['display_name'] ?? 'Worker',
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2A3B5A),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.chat_bubble_outline,
                                              color: Color(0xFF3B82F6),
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                        // Removed local addWorker FAB as it is now in the global SpeedDial
                      ],
                    ),

                    // --- PESTAÑA 2: INBOX DE MENSAJES (CHATS) ---
                    Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24.0,
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('All'),
                                    selected: _chatFilter == 'All',
                                    selectedColor: const Color(0xFF3B82F6),
                                    backgroundColor: const Color(0xFF1E293B),
                                    labelStyle: TextStyle(
                                      color: _chatFilter == 'All'
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _chatFilter = 'All');
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Workers'),
                                    selected: _chatFilter == 'Workers',
                                    selectedColor: const Color(0xFF3B82F6),
                                    backgroundColor: const Color(0xFF1E293B),
                                    labelStyle: TextStyle(
                                      color: _chatFilter == 'Workers'
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _chatFilter = 'Workers');
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('Jobs'),
                                    selected: _chatFilter == 'Jobs',
                                    selectedColor: const Color(0xFF3B82F6),
                                    backgroundColor: const Color(0xFF1E293B),
                                    labelStyle: TextStyle(
                                      color: _chatFilter == 'Jobs'
                                          ? Colors.white
                                          : Colors.white60,
                                    ),
                                    onSelected: (val) {
                                      if (val) {
                                        setState(() => _chatFilter = 'Jobs');
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Builder(
                                builder: (context) {
                                  if (_isLoadingChats) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFF3B82F6)),
                                    );
                                  }
                                  if (_allChats.isEmpty) {
                                    return Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: const [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            color: Colors.white24,
                                            size: 64,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            "No messages yet.",
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 18,
                                            ),
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            "Tap the button to start a chat.",
                                            style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  var docs = _allChats.where((data) {
                                    bool isGrp = data['type'] == 'group';
                                    if (_chatFilter == 'Workers') return !isGrp;
                                    if (_chatFilter == 'Jobs') return isGrp;
                                    return true;
                                  }).toList();

                                  if (docs.isEmpty) {
                                    return const Center(
                                      child: Text(
                                        "No chats in this category.",
                                        style: TextStyle(color: Colors.white38),
                                      ),
                                    );
                                  }

                                  return ListView.builder(
                                    padding: const EdgeInsets.only(
                                      left: 24.0,
                                      right: 24.0,
                                      bottom: 100,
                                    ),
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      var data = docs[index];

                                      bool isGroup = data['type'] == 'group';
                                      List parts = data['participants'] ?? [];

                                      String chatName = data['display_name'] ??
                                          ('${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim().isEmpty ? 'Chat' : '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim());
                                          data['customer_name'] ??
                                          data['job_name'] ??
                                          (isGroup
                                              ? 'Group Chat'
                                              : 'Direct Chat');
                                      chatName = chatName.replaceAll('Chat with ', '');
                                      String lastMessage =
                                          data['last_message'] ??
                                              'No messages yet';
                                      String? updatedAtStr = data['last_message_at'];

                                      bool isUnread = (data['unread_count'] ?? 0) > 0;

                                      FontWeight titleWeight = isUnread
                                          ? FontWeight.w900
                                          : FontWeight.bold;
                                      FontWeight msgWeight = isUnread
                                          ? FontWeight.bold
                                          : FontWeight.normal;
                                      Color msgColor = isUnread
                                          ? Colors.white
                                          : Colors.white60;

                                      return Dismissible(
                                        key: Key(data['id'].toString()),
                                        direction: DismissDirection.endToStart,
                                        background: Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 16),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          alignment: Alignment.centerRight,
                                          child: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        onDismissed: (direction) async {
                                          try {
                                            await ApiService.instance.delete('/conversations/${data['id']}');
                                            _fetchChats();
                                          } catch (e) {}
                                        },
                                        child: GestureDetector(
                                          onTap: () {
                                            if (_currentUserId != null) {
                                              GlobalChatModal.show(
                                                context,
                                                chatId: data['id'].toString(),
                                                title: chatName,
                                                subtitle: isGroup ? 'Group Chat' : 'Direct Message',
                                                isGroup: isGroup,
                                                currentUserId: _currentUserId!,
                                                onClose: () => _fetchChats(),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('User profile not loaded yet.')),
                                              );
                                            }
                                          },
                                          child: Container(
                                            margin: const EdgeInsets.only(
                                                bottom: 16),
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E293B),
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                  color: Colors.white10),
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 50,
                                                  height: 50,
                                                  decoration: BoxDecoration(
                                                    color: isGroup
                                                        ? const Color(
                                                                0xFF10B981)
                                                            .withOpacity(0.2)
                                                        : const Color(
                                                                0xFF3B82F6)
                                                            .withOpacity(0.2),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: Icon(
                                                      isGroup
                                                          ? Icons.groups
                                                          : Icons.person,
                                                      color: isGroup
                                                          ? const Color(
                                                              0xFF10B981)
                                                          : const Color(
                                                              0xFF3B82F6),
                                                      size: 24,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              chatName,
                                                              style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    titleWeight,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          Text(
                                                            _formatDateString(
                                                                updatedAtStr),
                                                            style: TextStyle(
                                                              color: isUnread
                                                                  ? const Color(
                                                                      0xFF3B82F6)
                                                                  : Colors
                                                                      .white38,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  msgWeight,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              lastMessage,
                                                              style: TextStyle(
                                                                color: msgColor,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    msgWeight,
                                                              ),
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          if (isUnread)
                                                            Container(
                                                              width: 10,
                                                              height: 10,
                                                              decoration:
                                                                  const BoxDecoration(
                                                                color: Color(
                                                                    0xFF3B82F6),
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                            )
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        Positioned(
                          bottom: 90, // Moved up to avoid overlap with global SpeedDial
                          right: 24,
                          child: FloatingActionButton(
                            heroTag: 'newChat',
                            onPressed: _showNewChatOptions,
                            backgroundColor: const Color(0xFF10B981),
                            child: const Icon(
                              Icons.chat,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

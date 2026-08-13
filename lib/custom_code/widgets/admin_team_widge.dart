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
import 'package:flutter/services.dart';
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
import '../../shared/job_list_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../app_constants.dart';

import '../../shared/image_editor_helper.dart';
import '/shared/toast_service.dart';
import '../../components/searchable_dropdown.dart';

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

  final TextEditingController _addressController = TextEditingController();
  List<dynamic> _placePredictions = [];
  double _lat = 0.0;
  double _lng = 0.0;
  String _address1 = '';
  String _city = '';
  String _state = '';
  String _zipCode = '';
  String _country = '';
  String _address2 = '';
  String _gateCode = '';
  String _notes = '';
  String? _googleMapsApiKey;
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
          _availableRoles = roles.map((r) {
            final m = Map<String, dynamic>.from(r);
            m['id'] = int.tryParse(m['id']?.toString() ?? '0') ?? 0;
            return m;
          }).toList();
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
      final settingsRes = await ApiService.instance.get('/settings');
      if (settingsRes is Map<String, dynamic> && settingsRes.containsKey('data')) {
        final data = settingsRes['data'] as Map<String, dynamic>;
        if (data.containsKey('google_maps_api_key') && 
            data['google_maps_api_key'] != null && 
            data['google_maps_api_key'].toString().trim().isNotEmpty) {
          _googleMapsApiKey = data['google_maps_api_key'].toString();
        }
      }
      if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) {
        _googleMapsApiKey = AppConstants.fallbackGoogleMapsApiKey;
      }
      
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
        useSafeArea: true,
        builder: (context) =>
            StatefulBuilder(builder: (context, setModalState) {

              void _fetchMessages() async {
                try {
                  var res = await ApiService.instance.get('/chat/$chatId/messages');
                  if (res != null && res['data'] != null) {
                    if (res['data'] is Map && res['data']['data'] != null) {
                      _messages = List<dynamic>.from(res['data']['data']);
                    } else {
                      _messages = List<dynamic>.from(res['data'] ?? []);
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
                  if (data != null) {
                    // Message payload is passed directly now because backend uses broadcastWith
                    if (data['conversation_id']?.toString() == chatId.toString()) {
                      setModalState(() {
                        // Avoid duplicates if we sent it
                        bool exists = _messages.any((m) => m['id'] == data['id']);
                        if (!exists) {
                          _messages.insert(0, data);
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
                  ToastService.error(context, 'Upload failed: $e');
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
                  ToastService.error(context, 'Upload failed: $e');
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
                  useSafeArea: true,
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
        useSafeArea: true,
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
        useSafeArea: true,
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
        useSafeArea: true,
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
        useSafeArea: true,
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
                                icon: Icons.person,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))]),
                            const SizedBox(height: 20),
                            const Text("Last Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            _buildTextField(
                                controller: lastNameCtrl,
                                label: "Last Name",
                                icon: Icons.person_outline,
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))]),
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
                                            ToastService.success(context, 'Profile updated successfully!');
                                          } catch (e) {
                                            ToastService.error(context, 'Error: $e');
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
      useSafeArea: true,
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
        'address1': _address1.isNotEmpty ? _address1 : _addressController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _city,
        'state': _state,
        'zip_code': _zipCode,
        'country': _country.isNotEmpty ? _country : 'USA',
        'latitude': _lat != 0.0 ? _lat : null,
        'longitude': _lng != 0.0 ? _lng : null,
        'address2': _address2,
        'gate_code': _gateCode,
        'address_notes': _notes,
        'notes': _notes,
      });

      if (mounted) {
        setState(() {
          _firstNameController.clear();
          _lastNameController.clear();
          _emailController.clear();
          _passwordController.clear();
          _addressController.clear();
          _city = '';
          _state = '';
          _zipCode = '';
          _country = '';
          _address2 = '';
          _gateCode = '';
          _notes = '';
          _lat = 0.0;
          _lng = 0.0;
          _confirmPasswordController.clear();
          _hourlyRateController.text = '20';
        });
        Navigator.pop(context);
        ToastService.success(context, 'Worker added successfully!');
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
      useSafeArea: true,
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

              Future<void> searchPlaces(String query) async {
                if (query.isEmpty) {
                  setModalState(() => _placePredictions = []);
                  return;
                }
                try {
                  if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                  final uri = Uri.parse(
                      "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                  final response = await http.get(uri);
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'OK') {
                      setModalState(() => _placePredictions =
                          List<dynamic>.from(data['predictions'] ?? []));
                    }
                  }
                } catch (e) {
                  debugPrint("Error Autocomplete: $e");
                }
              }

              Future<void> getPlaceDetails(String placeId) async {
                try {
                  if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                  final uri = Uri.parse(
                      "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                  final response = await http.get(uri);
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'OK') {
                      var location = data['result']['geometry']['location'];
                      var components = data['result']['address_components'] as List<dynamic>?;
                      
                      String pStreetNumber = '';
                      String pRoute = '';
                      String pCity = '';
                      String pState = '';
                      String pPostal = '';
                      String pCountry = '';
                      
                      if (components != null) {
                        for (var c in components) {
                          List<dynamic> types = c['types'] ?? [];
                          if (types.contains('street_number')) pStreetNumber = c['long_name'];
                          if (types.contains('route')) pRoute = c['long_name'];
                          if (types.contains('locality')) pCity = c['long_name'];
                          if (types.contains('administrative_area_level_1')) pState = c['short_name'];
                          if (types.contains('postal_code')) pPostal = c['long_name'];
                          if (types.contains('country')) pCountry = c['long_name'];
                        }
                      }

                      String pAddress1 = pStreetNumber.isNotEmpty ? "$pStreetNumber $pRoute".trim() : pRoute;

                      setModalState(() {
                        _lat = location['lat'];
                        _lng = location['lng'];
                        _address1 = pAddress1;
                        _city = pCity;
                        _state = pState;
                        _zipCode = pPostal;
                        _country = pCountry;
                      });
                    }
                  }
                } catch (e) {
                  debugPrint("Error Details: $e");
                }
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
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))],
                                        ),
                                        const SizedBox(height: 16),
                                        _buildTextField(
                                          controller: _lastNameController,
                                          label: "Last Name",
                                          icon: Icons.person_outline,
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))],
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
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: TextField(
                                            controller: _addressController,
                                            style: const TextStyle(color: Colors.white, fontSize: 16),
                                            onChanged: (val) => searchPlaces(val),
                                            decoration: const InputDecoration(
                                              prefixIcon: Icon(Icons.location_on, color: Color(0xFF3B82F6)),
                                              labelText: "Staff Address",
                                              labelStyle: TextStyle(color: Colors.white38),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                            ),
                                          ),
                                        ),
                                        if (_placePredictions.isNotEmpty)
                                          Container(
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1E293B),
                                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: _placePredictions.map<Widget>((p) => ListTile(
                                                title: Text(p['description']?.toString() ?? '',
                                                    style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                onTap: () async {
                                                  String pId = p['place_id']?.toString() ?? '';
                                                  setModalState(() {
                                                    _addressController.text = p['description']?.toString() ?? '';
                                                    _placePredictions.clear();
                                                  });
                                                  await getPlaceDetails(pId);
                                                },
                                              )).toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: TextField(
                                                  onChanged: (val) => _address2 = val,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: const InputDecoration(
                                                    hintText: "Unit / Apartment #",
                                                    hintStyle: TextStyle(color: Colors.white38),
                                                    prefixIcon: Icon(Icons.apartment_outlined, color: Color(0xFF3B82F6)),
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1E293B),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: TextField(
                                                  onChanged: (val) => _gateCode = val,
                                                  style: const TextStyle(color: Colors.white),
                                                  decoration: const InputDecoration(
                                                    hintText: "Gate / Door / Lock Code",
                                                    hintStyle: TextStyle(color: Colors.white38),
                                                    prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF3B82F6)),
                                                    border: InputBorder.none,
                                                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: TextField(
                                            onChanged: (val) => _notes = val,
                                            style: const TextStyle(color: Colors.white),
                                            maxLines: 3,
                                            minLines: 1,
                                            decoration: const InputDecoration(
                                              hintText: "Notes / Key Notes",
                                              hintStyle: TextStyle(color: Colors.white38),
                                              prefixIcon: Icon(Icons.notes_outlined, color: Color(0xFF3B82F6)),
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 16),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        SearchableDropdown(
                                          value: _selectedRoleId?.toString(),
                                          hint: "Select Role",
                                          prefixIcon: const Icon(Icons.work_outline, color: Color(0xFF3B82F6), size: 20),
                                          items: _availableRoles.map((role) {
                                            return {
                                              'value': role['id'].toString(),
                                              'label': role['name']?.toString() ?? 'Unknown Role'
                                            };
                                          }).toList(),
                                          onChanged: (val) {
                                            setModalState(() {
                                              _selectedRoleId = int.tryParse(val ?? '');
                                            });
                                          },
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
                                      ToastService.error(context, 'Failed to create staff member: $error');
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
                    
                    await ApiService.instance.put('/admin/workers/$idStr', {
                      'hourly_rate': newRate,
                      'cost_rate': newRate,
                    });

                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                    _fetchWorkers(); // Refresh the data

                    ToastService.success(context, 'Hourly Rate updated successfully!');
                  } catch (e) {
                    String errorMsg = e.toString().replaceAll('Exception: ', '');
                    if (mounted) {
                      ToastService.error(context, 'Failed to update hourly rate: $errorMsg');
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
    
    int? currentRoleId;
    if (workerData['role_id'] != null) {
      currentRoleId = int.tryParse(workerData['role_id'].toString());
    } else if (workerData['role'] is Map && workerData['role']['id'] != null) {
      currentRoleId = int.tryParse(workerData['role']['id'].toString());
    }
    String currentRoleSlug = '';
    if (workerData['role_slug'] != null) {
      currentRoleSlug = workerData['role_slug'].toString().toLowerCase();
    } else if (workerData['role'] is Map && workerData['role']['slug'] != null) {
      currentRoleSlug = workerData['role']['slug'].toString().toLowerCase();
    } else if (workerData['role'] is String) {
      currentRoleSlug = workerData['role'].toString().toLowerCase();
    }
    bool isAdmin = currentRoleSlug == 'admin' || currentRoleSlug == 'super-admin';

    TextEditingController firstNameCtrl = TextEditingController(text: defaultFirst);
    TextEditingController lastNameCtrl = TextEditingController(text: defaultLast);
    TextEditingController emailCtrl = TextEditingController(text: workerData['email'] ?? '');
    TextEditingController phoneCtrl = TextEditingController(text: workerData['phone'] ?? workerData['mobile'] ?? '');
    Map<String, dynamic> addrData = {};
    if (workerData['primary_address'] is Map) {
      addrData = workerData['primary_address'] as Map<String, dynamic>;
    } else if (workerData['addresses'] is List && (workerData['addresses'] as List).isNotEmpty) {
      addrData = (workerData['addresses'] as List)[0] as Map<String, dynamic>;
    }

    TextEditingController addressCtrl = TextEditingController(text: workerData['address'] ?? workerData['address1'] ?? addrData['address1'] ?? addrData['address'] ?? '');
    
    final unitCtrl = TextEditingController(text: workerData['address2']?.toString() ?? addrData['address2']?.toString() ?? '');
    final gateCtrl = TextEditingController(text: workerData['gate_code']?.toString() ?? addrData['gate_code']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: workerData['address_notes']?.toString() ?? workerData['notes']?.toString() ?? addrData['address_notes']?.toString() ?? addrData['notes']?.toString() ?? '');

    double currentRate = double.tryParse(workerData['hourly_rate']?.toString() ?? workerData['cost_rate']?.toString() ?? '') ?? 20.0;
    TextEditingController rateCtrl = TextEditingController(text: currentRate.toStringAsFixed(2));

    List<dynamic> placePredictions = [];
    String address1 = '';
    double lat = double.tryParse(workerData['latitude']?.toString() ?? addrData['latitude']?.toString() ?? '0') ?? 0.0;
    double lng = double.tryParse(workerData['longitude']?.toString() ?? addrData['longitude']?.toString() ?? '0') ?? 0.0;
    String city = workerData['city'] ?? addrData['city'] ?? '';
    String stateStr = workerData['state'] ?? addrData['state'] ?? '';
    String zipCode = workerData['zip_code'] ?? addrData['zip_code'] ?? '';
    String country = workerData['country'] ?? addrData['country'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (BuildContext context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {

                Future<void> searchPlaces(String query) async {
                  if (query.isEmpty) {
                    setModalState(() => placePredictions = []);
                    return;
                  }
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        setModalState(() => placePredictions =
                            List<dynamic>.from(data['predictions'] ?? []));
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Autocomplete: $e");
                  }
                }

                Future<void> getPlaceDetails(String placeId) async {
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        var location = data['result']['geometry']['location'];
                        var components = data['result']['address_components'] as List<dynamic>?;
                        
                        String pStreetNumber = '';
                        String pRoute = '';
                        String pCity = '';
                        String pState = '';
                        String pPostal = '';
                        String pCountry = '';
                        
                        if (components != null) {
                          for (var c in components) {
                            List<dynamic> types = c['types'] ?? [];
                            if (types.contains('street_number')) pStreetNumber = c['long_name'];
                            if (types.contains('route')) pRoute = c['long_name'];
                            if (types.contains('locality')) pCity = c['long_name'];
                            if (types.contains('administrative_area_level_1')) pState = c['short_name'];
                            if (types.contains('postal_code')) pPostal = c['long_name'];
                            if (types.contains('country')) pCountry = c['long_name'];
                          }
                        }

                        String pAddress1 = pStreetNumber.isNotEmpty ? "$pStreetNumber $pRoute".trim() : pRoute;

                        setModalState(() {
                          lat = location['lat'];
                          lng = location['lng'];
                          address1 = pAddress1;
                          city = pCity;
                          stateStr = pState;
                          zipCode = pPostal;
                          country = pCountry;
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Details: $e");
                  }
                }

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
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))],
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
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9 ]'))],
                              ),
                              const SizedBox(height: 16),
                              const Text("Role",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  width: double.infinity,
                                  child: const Text("Admin (Cannot be changed)", style: TextStyle(color: Colors.white38, fontSize: 16)),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: DropdownButtonFormField<int>(
                                    value: currentRoleId,
                                    isExpanded: true,
                                    dropdownColor: const Color(0xFF1E293B),
                                    icon: const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.arrow_drop_down, color: Colors.white38)),
                                    decoration: const InputDecoration(
                                      prefixIcon: Icon(Icons.badge_outlined, color: Colors.white38),
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                    items: _availableRoles.map((role) {
                                      return DropdownMenuItem<int>(
                                        value: role['id'] as int,
                                        child: Text(role['name'] ?? 'Unknown Role'),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setModalState(() {
                                        currentRoleId = val;
                                      });
                                    },
                                  ),
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
                                keyboardType: TextInputType.phone,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              ),
                              const SizedBox(height: 16),
                              const Text("Street Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: addressCtrl,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  onChanged: (val) => searchPlaces(val),
                                  decoration: const InputDecoration(
                                    prefixIcon: Icon(Icons.location_on_outlined, color: Colors.white38),
                                    labelText: "Address",
                                    labelStyle: TextStyle(color: Colors.white38),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  ),
                                ),
                              ),
                              if (placePredictions.isNotEmpty)
                                Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1E293B),
                                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: placePredictions.map<Widget>((p) => ListTile(
                                      title: Text(p['description']?.toString() ?? '',
                                          style: const TextStyle(color: Colors.white, fontSize: 13)),
                                      onTap: () async {
                                        String pId = p['place_id']?.toString() ?? '';
                                        setModalState(() {
                                          addressCtrl.text = p['description']?.toString() ?? '';
                                          placePredictions.clear();
                                        });
                                        await getPlaceDetails(pId);
                                      },
                                    )).toList(),
                                  ),
                                ),
                              const SizedBox(height: 16),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Unit / Apartment #",
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: unitCtrl,
                                          label: "Unit / Apartment #",
                                          icon: Icons.apartment_outlined,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text("Gate / Door / Lock Code",
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        _buildTextField(
                                          controller: gateCtrl,
                                          label: "Gate / Door / Lock Code",
                                          icon: Icons.lock_outline,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text("Notes / Key Notes",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TextField(
                                  controller: notesCtrl,
                                  style: const TextStyle(color: Colors.white),
                                  maxLines: 3,
                                  minLines: 1,
                                  decoration: const InputDecoration(
                                    hintText: "Notes / Key Notes",
                                    hintStyle: TextStyle(color: Colors.white38),
                                    prefixIcon: Icon(Icons.notes_outlined, color: Color(0xFF3B82F6)),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
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
                                    payload['address1'] = address1.isNotEmpty ? address1 : addressCtrl.text.trim();
                                    payload['city'] = city;
                                    payload['state'] = stateStr;
                                    payload['zip_code'] = zipCode;
                                    payload['country'] = country.isNotEmpty ? country : 'USA';
                                    if (lat != 0.0) payload['latitude'] = lat;
                                    if (lng != 0.0) payload['longitude'] = lng;
                                  }
                                  
                                  payload['address2'] = unitCtrl.text.trim();
                                  payload['gate_code'] = gateCtrl.text.trim();
                                  payload['address_notes'] = notesCtrl.text.trim();
                                  payload['notes'] = notesCtrl.text.trim();
                                  
                                  if (!isAdmin && currentRoleId != null) {
                                    payload['role_id'] = currentRoleId;
                                  }

                                  await ApiService.instance
                                      .put('/admin/workers/$userId', payload);

                                  Navigator.pop(context);
                                  Navigator.of(context).maybePop();
                                  _fetchWorkers();

                                  ToastService.success(context, 'Staff info updated successfully!');
                                } catch (e) {
                                  String errorMsg = e.toString().replaceAll('Exception: ', '');
                                  if (mounted) {
                                    ToastService.error(context, 'Failed to update staff info: $errorMsg');
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
    String userId = (workerData['uid'] ?? workerData['id'] ?? '').toString();
    String name = workerData['display_name'] ?? workerData['name'] ?? '';
    List<String> nameParts = name.trim().split(' ');
    String defaultFirst = workerData['first_name'] ?? (nameParts.isNotEmpty ? nameParts.first : '');
    String defaultLast = workerData['last_name'] ?? (nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '');

    TextEditingController firstNameCtrl = TextEditingController(text: defaultFirst);
    TextEditingController lastNameCtrl = TextEditingController(text: defaultLast);
    TextEditingController emailCtrl = TextEditingController(text: workerData['email'] ?? '');
    TextEditingController phoneCtrl = TextEditingController(text: workerData['phone'] ?? workerData['mobile'] ?? '');

    Map<String, dynamic> addrData = {};
    if (workerData['primary_address'] is Map) {
      addrData = workerData['primary_address'] as Map<String, dynamic>;
    } else if (workerData['addresses'] is List && (workerData['addresses'] as List).isNotEmpty) {
      addrData = (workerData['addresses'] as List)[0] as Map<String, dynamic>;
    }

    TextEditingController addressCtrl = TextEditingController(text: workerData['address'] ?? workerData['address1'] ?? addrData['address1'] ?? addrData['address'] ?? '');
    final unitCtrl = TextEditingController(text: workerData['address2']?.toString() ?? addrData['address2']?.toString() ?? '');
    final gateCtrl = TextEditingController(text: workerData['gate_code']?.toString() ?? addrData['gate_code']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: workerData['address_notes']?.toString() ?? workerData['notes']?.toString() ?? addrData['address_notes']?.toString() ?? addrData['notes']?.toString() ?? '');

    double currentRate = double.tryParse(workerData['hourly_rate']?.toString() ?? workerData['cost_rate']?.toString() ?? '') ?? 20.0;
    TextEditingController rateCtrl = TextEditingController(text: currentRate.toStringAsFixed(2));

    bool isSavingBasic = false;
    bool isSavingDocs = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (modalContext) {
        return DefaultTabController(
          length: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            height: MediaQuery.of(modalContext).size.height * 0.9,
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
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(0xFF3B82F6).withOpacity(0.2),
                        child: Text(
                          workerData['display_name']?[0]?.toUpperCase() ?? 'W',
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
                ),
                const SizedBox(height: 16),
                const TabBar(
                  indicatorColor: Color(0xFF3B82F6),
                  labelColor: Color(0xFF3B82F6),
                  unselectedLabelColor: Colors.white60,
                  tabs: [
                    Tab(text: "Basic Info"),
                    Tab(text: "Documents"),
                    Tab(text: "Jobs History"),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      // TAB 1: BASIC INFO
                      StatefulBuilder(
                        builder: (context, setTabState) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTextField(controller: firstNameCtrl, label: "First Name", icon: Icons.person_outline),
                                const SizedBox(height: 16),
                                _buildTextField(controller: lastNameCtrl, label: "Last Name", icon: Icons.person_outline),
                                const SizedBox(height: 16),
                                _buildTextField(controller: emailCtrl, label: "Email Address", icon: Icons.email_outlined),
                                const SizedBox(height: 16),
                                _buildTextField(controller: phoneCtrl, label: "Mobile Phone", icon: Icons.phone_outlined),
                                const SizedBox(height: 16),
                                _buildTextField(controller: addressCtrl, label: "Street Address", icon: Icons.location_on_outlined),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(child: _buildTextField(controller: unitCtrl, label: "Unit / Apt", icon: Icons.apartment_outlined)),
                                    const SizedBox(width: 16),
                                    Expanded(child: _buildTextField(controller: gateCtrl, label: "Gate Code", icon: Icons.lock_outline)),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                _buildTextField(controller: notesCtrl, label: "Notes", icon: Icons.notes_outlined),
                                const SizedBox(height: 16),
                                _buildTextField(controller: rateCtrl, label: "Hourly Rate (\$)", icon: Icons.attach_money),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isSavingBasic ? null : () async {
                                      setTabState(() => isSavingBasic = true);
                                      try {
                                        double newRate = double.tryParse(rateCtrl.text) ?? currentRate;
                                        Map<String, dynamic> payload = {
                                          'phone': phoneCtrl.text,
                                          'address': addressCtrl.text,
                                          'address2': unitCtrl.text,
                                          'gate_code': gateCtrl.text,
                                          'notes': notesCtrl.text,
                                          'hourly_rate': newRate,
                                          'cost_rate': newRate,
                                        };
                                        if (firstNameCtrl.text.trim().isNotEmpty && firstNameCtrl.text.trim() != workerData['first_name']) {
                                          payload['first_name'] = firstNameCtrl.text.trim();
                                        }
                                        if (lastNameCtrl.text.trim().isNotEmpty && lastNameCtrl.text.trim() != workerData['last_name']) {
                                          payload['last_name'] = lastNameCtrl.text.trim();
                                        }
                                        if (emailCtrl.text.trim().isNotEmpty && emailCtrl.text.trim() != workerData['email']) {
                                          payload['email'] = emailCtrl.text.trim();
                                        }
                                        await ApiService.instance.put('/admin/workers/$userId', payload);
                                        ToastService.success(context, 'Basic info updated!');
                                        _fetchWorkers();
                                      } catch (e) {
                                        ToastService.error(context, 'Failed to update basic info');
                                      } finally {
                                        if (mounted) setTabState(() => isSavingBasic = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: isSavingBasic
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Save Basic Info", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      // TAB 2: DOCUMENTS
                      StatefulBuilder(
                        builder: (context, setTabState) {
                          return SingleChildScrollView(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDocumentTile(modalContext, "Photo ID", "Driver's license", Icons.badge_outlined, workerData['photo_id_url']?.toString()),
                                const SizedBox(height: 12),
                                _buildDocumentTile(modalContext, "SSN Card", "Copy of SSN", Icons.credit_card_outlined, workerData['ssn_url']?.toString()),
                                const SizedBox(height: 12),
                                _buildDocumentTile(modalContext, "W-9 Form", "Tax document", Icons.description_outlined, workerData['w9_url']?.toString()),
                                const SizedBox(height: 12),
                                _buildDocumentTile(modalContext, "Direct Deposit", "Bank authorization", Icons.account_balance_outlined, workerData['bank_url']?.toString()),
                                const SizedBox(height: 32),
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: isSavingDocs ? null : () async {
                                      setTabState(() => isSavingDocs = true);
                                      try {
                                        await ApiService.instance.put('/admin/workers/$userId', {});
                                        ToastService.success(context, 'Documents & Payroll updated!');
                                        _fetchWorkers();
                                      } catch (e) {
                                        ToastService.error(context, 'Failed to update documents');
                                      } finally {
                                        if (mounted) setTabState(() => isSavingDocs = false);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    child: isSavingDocs
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Save Documents", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                      // TAB 3: JOBS HISTORY
                      SharedJobListPage(
                        staffId: int.tryParse(userId.toString()),
                        hideCalendar: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            ToastService.error(modalContext, 'Could not open document: $e');
          }
        } else {
          ToastService.warning(modalContext, 'No document uploaded yet.');
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
      Widget? suffixIcon,
      String? errorText,
      List<TextInputFormatter>? inputFormatters}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: errorText != null ? Colors.red : Colors.transparent),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white38),
          errorText: errorText,
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
                                              ToastService.info(context, 'User profile not loaded yet.');
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

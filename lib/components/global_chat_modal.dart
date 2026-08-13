import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../backend/api_service.dart';
import '../backend/reverb_service.dart';
import '/shared/toast_service.dart';

class GlobalChatModal {
  static Future<void> openChatWithUser(
    BuildContext context, {
    required String targetUserId,
    required String targetName,
    required bool isCustomer,
    VoidCallback? onClose,
  }) async {
    try {
      var me = await ApiService.instance.getMe();
      int currentUserId = me['id'];

      // 1. Fetch all conversations
      var res = await ApiService.instance.getConversations();
      // The index endpoint returns a paginated response: {data: {data: [...]}}
      List<dynamic> convs = [];
      final d = res['data'];
      if (d is Map && d['data'] != null) {
        convs = List<dynamic>.from(d['data']);
      } else if (d is List) {
        convs = List<dynamic>.from(d);
      }

      String? foundChatId;

      // 2. Look for existing conversation
      for (var c in convs) {
        if (isCustomer) {
          if (c['type'] == 'customer' &&
              c['customer_id'].toString() == targetUserId) {
            foundChatId = c['id'].toString();
            break;
          }
        } else {
          if (c['type'] == 'internal' && c['participants'] != null) {
            List<dynamic> parts = c['participants'];
            // participants is stored as a plain array of integer IDs
            bool hasTarget = parts.any((p) => p.toString() == targetUserId);
            if (hasTarget) {
              foundChatId = c['id'].toString();
              break;
            }
          }
        }
      }

      // 3. Create if not found
      if (foundChatId == null) {
        Map<String, dynamic> payload = {
          'type': isCustomer ? 'customer' : 'internal',
          'name': targetName,
        };
        if (isCustomer) {
          payload['customer_id'] = int.parse(targetUserId);
        } else {
          payload['participants'] = [int.parse(targetUserId)];
        }

        var createRes =
            await ApiService.instance.createConversation(payload);
        foundChatId = createRes['id'].toString();
      }

      // 4. Open modal
      if (context.mounted) {
        show(
          context,
          chatId: foundChatId,
          title: targetName,
          subtitle: isCustomer ? 'Customer' : 'Staff Member',
          isGroup: false,
          currentUserId: currentUserId,
          onClose: onClose,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.error(context, 'Failed to open chat: $e');
      }
    }
  }

  static Future<void> openGroupChat(
    BuildContext context, {
    required String jobId,
    required String jobName,
    required List<String> workerIds,
    VoidCallback? onClose,
  }) async {
    try {
      var me = await ApiService.instance.getMe();
      int currentUserId = me['id'];

      // We assume jobs have a chat_group_id saved on them if it already exists.
      // But if we don't know it, we create one.
      Map<String, dynamic> payload = {
        'type': 'group',
        'name': jobName,
        'job_id': int.tryParse(jobId),
        'participants': workerIds.map((id) => int.parse(id)).toList(),
      };

      var createRes = await ApiService.instance.createConversation(payload);
      String chatId = createRes['id'].toString();

      if (context.mounted) {
        show(
          context,
          chatId: chatId,
          title: jobName,
          subtitle: 'Job Group Chat',
          isGroup: true,
          currentUserId: currentUserId,
          onClose: onClose,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ToastService.error(context, 'Failed to open group chat: $e');
      }
    }
  }

  static void show(
    BuildContext context, {
    required String chatId,
    required String title,
    required String subtitle,
    required bool isGroup,
    required int currentUserId,
    VoidCallback? onClose,
  }) {
    // Styling colors matching custom_inbox.dart
    const Color bg = Color(0xFF0D1B2A);
    const Color card = Color(0xFF1E293B);
    const Color text = Colors.white;
    const Color muted = Colors.white60;
    const Color accentBlue = Color(0xFF3B82F6);
    const Color neonAction = Color(0xFF00FFCC);
    const Color accentRed = Color(0xFFEF4444);

    // Mark as read in background
    ApiService.instance
        .markConversationAsRead(int.parse(chatId))
        .catchError((e) {});

    bool isSearchingChat = false;
    String inChatSearchQuery = "";

    List<dynamic> _messages = [];
    bool _isLoadingMessages = true;
    final TextEditingController _msgController = TextEditingController();

    bool isModalOpen = true;

    // Attachment state
    bool _isUploadingAttachment = false;
    FilePickerResult? _pickedAttachment;
    String? _attachmentType; // 'image' or 'file'

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          if (_isLoadingMessages && _messages.isEmpty) {
            ApiService.instance
                .getConversationThread(int.parse(chatId))
                .then((res) {
              if (isModalOpen) {
                setModalState(() {
                  var dataBlock = res['data'];
                  if (dataBlock is Map) {
                    _messages = List<dynamic>.from(dataBlock['data'] ?? []);
                  } else if (dataBlock is List) {
                    _messages = List<dynamic>.from(dataBlock);
                  } else {
                    _messages = [];
                  }

                  _messages.sort((a, b) {
                    try {
                      DateTime timeA = DateTime.parse(a['created_at']);
                      DateTime timeB = DateTime.parse(b['created_at']);
                      return timeB.compareTo(timeA); // Descending
                    } catch (e) {
                      return 0;
                    }
                  });
                  _isLoadingMessages = false;
                });
              }
            }).catchError((e) {
              if (isModalOpen) setModalState(() => _isLoadingMessages = false);
            });
          }

          ReverbService.instance.subscribeToChat(int.parse(chatId));
          ReverbService.instance.onMessageReceived = (data) {
            if (isModalOpen && data['conversation_id']?.toString() == chatId) {
              setModalState(() {
                int existingIndex =
                    _messages.indexWhere((m) => m['id'] == data['id']);
                if (existingIndex == -1) {
                  int tempIndex = _messages.indexWhere((m) =>
                      m['id'] != null &&
                      m['id'].toString().startsWith('temp_') &&
                      m['content'] == data['content']);
                  if (tempIndex != -1) {
                    _messages[tempIndex] = data;
                  } else {
                    _messages.insert(0, data);
                  }
                }
              });
            }
          };

          return Container(
            height: MediaQuery.of(context).size.height * 0.95,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
                color: bg,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(32))),
              child: Column(
                children: [
                  Center(
                      child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: 50,
                          height: 5,
                          decoration: BoxDecoration(
                              color: muted.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(10)))),
                  Container(
                      padding: const EdgeInsets.only(
                          top: 8, bottom: 16, left: 24, right: 16),
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Colors.white.withOpacity(0.05)))),
                      child: Row(children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: isGroup
                                  ? neonAction.withOpacity(0.2)
                                  : accentBlue.withOpacity(0.2),
                              child: Text(
                                  title.isNotEmpty
                                      ? title[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                      color: isGroup ? neonAction : accentBlue,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: bg, shape: BoxShape.circle),
                                child: Icon(
                                    isGroup
                                        ? Icons.groups
                                        : Icons.support_agent,
                                    color: isGroup ? neonAction : accentBlue,
                                    size: 10),
                              ),
                            )
                          ],
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                            child: isSearchingChat
                                ? TextField(
                                    autofocus: true,
                                    style: const TextStyle(
                                        color: text, fontSize: 16),
                                    decoration: const InputDecoration(
                                        hintText: "Search in this chat...",
                                        hintStyle: TextStyle(
                                            color: muted, fontSize: 14),
                                        border: InputBorder.none),
                                    onChanged: (v) => setModalState(
                                        () => inChatSearchQuery = v),
                                  )
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                        Text(title,
                                            style: const TextStyle(
                                                color: text,
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold)),
                                        Text(subtitle,
                                            style: const TextStyle(
                                                color: muted, fontSize: 12))
                                      ])),
                        IconButton(
                            icon: Icon(
                                isSearchingChat ? Icons.close : Icons.search,
                                color: isSearchingChat ? accentRed : muted),
                            onPressed: () {
                              setModalState(() {
                                isSearchingChat = !isSearchingChat;
                                inChatSearchQuery = "";
                              });
                            })
                      ])),
                  Expanded(
                      child: _isLoadingMessages
                          ? const Center(child: CircularProgressIndicator())
                          : Builder(builder: (context) {
                              var filteredDocs = _messages.where((m) {
                                if (inChatSearchQuery.isEmpty) return true;
                                String textMsg = m['content'] ?? '';
                                return textMsg
                                    .toLowerCase()
                                    .contains(inChatSearchQuery.toLowerCase());
                              }).toList();

                              if (filteredDocs.isEmpty) {
                                return Center(
                                    child: Text(
                                        inChatSearchQuery.isNotEmpty
                                            ? 'No messages found.'
                                            : 'Start the conversation!',
                                        style: const TextStyle(color: muted)));
                              }

                              return ListView.builder(
                                  reverse: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 20),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    var data = filteredDocs[index];
                                    bool isMe =
                                        data['sender_id'] == currentUserId;

                                    DateTime? time;
                                    try {
                                      time = DateTime.parse(data['created_at'])
                                          .toLocal();
                                    } catch (e) {}

                                    String timeStr = time != null
                                        ? DateFormat('hh:mm a').format(time)
                                        : '';

                                    return Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 16),
                                        child: Row(
                                            mainAxisAlignment: isMe
                                                ? MainAxisAlignment.end
                                                : MainAxisAlignment.start,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Flexible(
                                                  child: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              16),
                                                      decoration: BoxDecoration(
                                                          color: isMe
                                                              ? accentBlue
                                                              : card,
                                                          borderRadius: BorderRadius.only(
                                                              topLeft: const Radius
                                                                  .circular(20),
                                                              topRight:
                                                                  const Radius.circular(
                                                                      20),
                                                              bottomLeft: isMe
                                                                  ? const Radius.circular(
                                                                      20)
                                                                  : const Radius
                                                                      .circular(
                                                                      4),
                                                              bottomRight: isMe
                                                                  ? const Radius.circular(4)
                                                                  : const Radius.circular(20))),
                                                      child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                                                        if (isGroup &&
                                                            !isMe) ...[
                                                          Text(
                                                              data['sender_name'] ??
                                                                  "Team Member",
                                                              style: const TextStyle(
                                                                  color:
                                                                      neonAction,
                                                                  fontSize: 10,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                          const SizedBox(
                                                              height: 4),
                                                        ],
                                                        if (data['attachments'] != null && (data['attachments'] as List).isNotEmpty) ...[
                                                          Builder(
                                                            builder: (context) {
                                                              var attachment = data['attachments'][0];
                                                              bool isImage = attachment['type'] == 'image';
                                                              return GestureDetector(
                                                                onTap: () async {
                                                                  if (isImage) {
                                                                    showDialog(
                                                                      context: context,
                                                                      builder: (context) => Dialog(
                                                                        backgroundColor: Colors.transparent,
                                                                        insetPadding: EdgeInsets.zero,
                                                                        child: Stack(
                                                                          fit: StackFit.expand,
                                                                          children: [
                                                                            GestureDetector(
                                                                              onTap: () => Navigator.of(context).pop(),
                                                                              child: InteractiveViewer(
                                                                                panEnabled: true,
                                                                                minScale: 0.5,
                                                                                maxScale: 4.0,
                                                                                child: Image.network(attachment['url'], fit: BoxFit.contain),
                                                                              ),
                                                                            ),
                                                                            Positioned(
                                                                              top: 40,
                                                                              right: 20,
                                                                              child: IconButton(
                                                                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                                                                onPressed: () => Navigator.of(context).pop(),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                      ),
                                                                    );
                                                                  } else {
                                                                    Uri url = Uri.parse(attachment['url']);
                                                                    if (await canLaunchUrl(url)) {
                                                                      await launchUrl(url, mode: LaunchMode.externalApplication);
                                                                    }
                                                                  }
                                                                },
                                                                child: Container(
                                                                  margin: const EdgeInsets.only(bottom: 8),
                                                                  constraints: isImage 
                                                                    ? BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5, maxHeight: 150)
                                                                    : const BoxConstraints(maxHeight: 200),
                                                                  decoration: BoxDecoration(
                                                                    borderRadius: BorderRadius.circular(8),
                                                                  ),
                                                                  clipBehavior: Clip.hardEdge,
                                                                  child: isImage 
                                                                    ? Image.network(attachment['url'], fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                                                                    : Container(
                                                                        padding: const EdgeInsets.all(12),
                                                                        decoration: BoxDecoration(
                                                                          color: Colors.white.withOpacity(isMe ? 0.2 : 1),
                                                                          borderRadius: BorderRadius.circular(8),
                                                                          border: Border.all(color: Colors.grey.withOpacity(0.3))
                                                                        ),
                                                                        child: Row(
                                                                          mainAxisSize: MainAxisSize.min,
                                                                          children: [
                                                                            Icon(Icons.insert_drive_file, color: isMe ? Colors.white : Colors.black54),
                                                                            const SizedBox(width: 8),
                                                                            Flexible(
                                                                              child: Text(
                                                                                attachment['filename'] ?? 'Attachment',
                                                                                style: TextStyle(color: isMe ? Colors.white : text),
                                                                                overflow: TextOverflow.ellipsis,
                                                                              ),
                                                                            )
                                                                          ],
                                                                        )
                                                                      )
                                                                ),
                                                              );
                                                            }
                                                          )
                                                        ],
                                                        if (data['content'] != null && data['content'].toString().trim().isNotEmpty && (data['attachments'] == null || (data['attachments'] as List).isEmpty || data['content'] != data['attachments'][0]['filename']))
                                                          LinkifiedText(
                                                              text: data['content'] ?? '',
                                                              style: TextStyle(
                                                                  color: isMe ? Colors.white : text,
                                                                  fontSize: 15)),
                                                        Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6),
                                                            child: Text(timeStr,
                                                                style: TextStyle(
                                                                    color: isMe
                                                                        ? Colors
                                                                            .white70
                                                                        : muted,
                                                                    fontSize:
                                                                        10)))
                                                      ])))
                                            ]));
                                  });
                            })),
                  Container(
                    padding: const EdgeInsets.only(
                        left: 4, right: 8, top: 12, bottom: 20),
                    decoration: BoxDecoration(
                        color: bg,
                        border: Border(
                            top: BorderSide(
                                color: Colors.white.withOpacity(0.05)))),
                    child: Column(
                      children: [
                        if (_pickedAttachment != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white.withOpacity(0.1))
                            ),
                            child: Row(
                              children: [
                                Icon(_attachmentType == 'image' ? Icons.image : Icons.insert_drive_file, color: accentBlue),
                                const SizedBox(width: 8),
                                Expanded(child: Text(_pickedAttachment!.files.first.name, style: const TextStyle(color: text), overflow: TextOverflow.ellipsis)),
                                IconButton(
                                  icon: const Icon(Icons.close, color: accentRed, size: 18),
                                  onPressed: () => setModalState(() { _pickedAttachment = null; })
                                )
                              ],
                            )
                          ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file, color: muted),
                              onPressed: () async {
                                FilePickerResult? result = await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'pdf', 'doc', 'docx', 'xls', 'xlsx', 'csv', 'txt'],
                                  allowCompression: true,
                                  withData: true,
                                );
                                if (result != null) {
                                  setModalState(() {
                                    _pickedAttachment = result;
                                    String ext = result.files.first.extension?.toLowerCase() ?? '';
                                    _attachmentType = ['jpg', 'jpeg', 'png', 'gif'].contains(ext) ? 'image' : 'file';
                                  });
                                }
                              }
                            ),
                            Expanded(
                                child: Container(
                                    padding:
                                        const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                        color: card,
                                        borderRadius: BorderRadius.circular(24),
                                        border: Border.all(
                                            color: Colors.white.withOpacity(0.1))),
                                    child: TextField(
                                        controller: _msgController,
                                        style: const TextStyle(color: text),
                                        maxLines: null,
                                        keyboardType: TextInputType.multiline,
                                        decoration: const InputDecoration(
                                            hintText: 'Message...',
                                            hintStyle: TextStyle(
                                                color: muted, fontSize: 14),
                                            border: InputBorder.none)))),
                            _isUploadingAttachment 
                                ? const Padding(padding: EdgeInsets.all(12.0), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: accentBlue)))
                                : IconButton(
                                icon: const Icon(Icons.send,
                                    color: accentBlue, size: 24),
                                onPressed: () async {
                                  if (_msgController.text.trim().isEmpty && _pickedAttachment == null) return;
                                  var textMsg = _msgController.text.trim();
                                  
                                  List<Map<String, dynamic>>? attachmentsPayload;

                                  if (_pickedAttachment != null) {
                                    setModalState(() { _isUploadingAttachment = true; });
                                    try {
                                      List<int> bytes = _pickedAttachment!.files.first.bytes ?? await File(_pickedAttachment!.files.first.path!).readAsBytes();
                                      String fileName = _pickedAttachment!.files.first.name;
                                      
                                      var uploadedData = await ApiService.instance.uploadChatMedia(int.parse(chatId), bytes, fileName);
                                      attachmentsPayload = [{
                                        'id': uploadedData['id'],
                                        'url': uploadedData['url'],
                                        'filename': uploadedData['filename'],
                                        'type': uploadedData['type'] ?? _attachmentType,
                                      }];
                                      
                                      _pickedAttachment = null;
                                    } catch (e) {
                                      ToastService.error(context, 'Failed to upload attachment');
                                      setModalState(() { _isUploadingAttachment = false; });
                                      return;
                                    }
                                  }

                                  if (textMsg.isEmpty && attachmentsPayload != null && attachmentsPayload.isNotEmpty) {
                                    textMsg = attachmentsPayload[0]['filename'] ?? 'Attachment';
                                  }

                                  _msgController.clear();
                                  setModalState(() { _isUploadingAttachment = false; });

                                  // Optimistic update
                                  setModalState(() {
                                    _messages.insert(0, {
                                      'id':
                                          'temp_${DateTime.now().millisecondsSinceEpoch}',
                                      'content': textMsg,
                                      'sender_id': currentUserId,
                                      'direction': 'inbound',
                                      'created_at':
                                          DateTime.now().toUtc().toIso8601String(),
                                      'attachments': attachmentsPayload,
                                    });
                                  });

                                  ApiService.instance
                                      .sendMessage(int.parse(chatId), textMsg, attachments: attachmentsPayload)
                                      .catchError((e) {
                                    ToastService.error(context, 'Failed to send: $e');
                                  });
                                }), // IconButton
                          ], // Row children
                        ),
                      ],
                    ), // Column
                  ), // Container
                ], // Column children
              ), // Column
            ); // Container
        });
      },
    ).whenComplete(() {
      isModalOpen = false;
      ReverbService.instance.unsubscribeFromChat(int.parse(chatId));
      ReverbService.instance.onMessageReceived = null;
      if (onClose != null) {
        onClose();
      }
    });
  }
}

class LinkifiedText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const LinkifiedText({Key? key, required this.text, required this.style}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Combined regex: URLs first (supporting optional http/www), then phone numbers
    final RegExp linkRegex = RegExp(
      r'((?:https?://)?(?:www\.)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(?:/[^\s]*)?)|(\+?\d[\d\s\-\.\(\)]{4,18}\d)',
      caseSensitive: false,
    );

    List<TextSpan> spans = [];
    text.splitMapJoin(
      linkRegex,
      onMatch: (Match match) {
        final matched = match[0]!;
        final isUrl = match.group(1) != null;

        spans.add(
          TextSpan(
            text: matched,
            style: style.copyWith(
              decoration: TextDecoration.underline,
              decorationColor: isUrl ? Colors.lightBlueAccent : null,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                Uri url;
                if (isUrl) {
                  final urlStr = matched.toLowerCase().startsWith('http') ? matched : 'https://$matched';
                  url = Uri.parse(urlStr);
                } else {
                  url = Uri.parse('tel:${matched.replaceAll(RegExp(r'[^\d+]'), '')}');
                }
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
          ),
        );
        return '';
      },
      onNonMatch: (String nonMatch) {
        spans.add(TextSpan(text: nonMatch, style: style));
        return '';
      },
    );

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}

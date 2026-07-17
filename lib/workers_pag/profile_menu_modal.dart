// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/widgets/index.dart';
import '/auth/base_auth_user_provider.dart';
import '/auth/laravel_auth_manager.dart';
import '/backend/api_service.dart';
import 'package:file_picker/file_picker.dart';

class ProfileMenuModal extends StatefulWidget {
  const ProfileMenuModal({
    Key? key,
    this.width,
    this.height,
    this.onLogOutAction,
  }) : super(key: key);

  final double? width;
  final double? height;
  final Future Function()? onLogOutAction;

  @override
  _ProfileMenuModalState createState() => _ProfileMenuModalState();
}

class _ProfileMenuModalState extends State<ProfileMenuModal> {
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardDark = const Color(0xFF1E293B);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color textLight = Colors.white;
  final Color textMuted = const Color(0xFF94A3B8);

  final PageController _pageController = PageController();

  String _currentName = "Worker Name";
  String _currentEmail = "worker@email.com";
  bool _isSaving = false;

  final Map<String, TextEditingController> _ctrls = {
    'first_name': TextEditingController(),
    'last_name': TextEditingController(),
    'dob': TextEditingController(),
    'phone': TextEditingController(),
    'address': TextEditingController(),
    'city': TextEditingController(),
    'routing': TextEditingController(),
    'account': TextEditingController(),
  };

  Map<String, String> _docUrls = {
    'Photo ID': '',
    'SSN Card': '',
    'W-9 Form': '',
    'Direct Deposit Form': '',
  };
  String? _uploadingDoc;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = currentUser as LaravelAuthUser?;
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentEmail = user.email ?? "";
          _currentName = '${user.userData?['first_name'] ?? ''} ${user.userData?['last_name'] ?? ''}'.trim();
          if (_currentName.isEmpty) _currentName = 'Worker';
          _ctrls['first_name']?.text = user.userData?['first_name'] ?? '';
          _ctrls['last_name']?.text = user.userData?['last_name'] ?? '';
          _ctrls['phone']?.text = user.userData?['phone'] ?? "";
          _ctrls['dob']?.text = user.userData?['dob'] ?? "";
          _ctrls['address']?.text = user.userData?['address'] ?? "";
          _ctrls['city']?.text = user.userData?['city'] ?? "";

          _docUrls['Photo ID'] = user.userData?['photo_id_url'] ?? '';
          _docUrls['SSN Card'] = user.userData?['ssn_url'] ?? '';
          _docUrls['W-9 Form'] = user.userData?['w9_url'] ?? '';
          _docUrls['Direct Deposit Form'] = user.userData?['bank_form_url'] ?? '';
        });
      }
    }
  }

  Future<dynamic>? _myRequestsFuture;

  void _fetchMyRequests() {
    setState(() {
      _myRequestsFuture = ApiService.instance.get('/jobs/my-requests');
    });
  }

  void _navTo(int index) {
    if (index == 3) {
      _fetchMyRequests();
    }
    _pageController.animateToPage(index,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  Future<void> _performLogOut() async {
    if (widget.onLogOutAction != null) {
      Navigator.pop(context);
      await widget.onLogOutAction!();
    } else {
      await LaravelAuthManager.signOut();
      if (mounted)
        Navigator.pop(context); // IMPORTANTE: Cerrar el modal después de salir
    }
  }

  void _deleteDocument(String docName, String firestoreField) async {
    // For MVP, just wipe it locally and prompt them to upload a new one.
    setState(() {
      _docUrls[docName] = "";
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$docName removed. You can upload a new one.'),
        backgroundColor: Colors.redAccent));
  }

  void _uploadDocument(String docName, String firestoreField) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'jpeg'],
      withData: true,
    );

    if (result == null) return;

    setState(() => _uploadingDoc = docName);

    try {
      final fileBytes = result.files.first.bytes;
      final fileName = result.files.first.name;

      if (fileBytes == null) return;

      final res = await ApiService.instance.uploadDocument(docName, fileBytes, fileName);
      final downloadUrl = res['data']['url'];

      // Refresh the global user state with the updated profile
      await LaravelAuthManager.initialize();

      setState(() {
        _docUrls[docName] = downloadUrl;
        _uploadingDoc = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$docName updated successfully!'),
          backgroundColor: Colors.green));
    } catch (e) {
      setState(() => _uploadingDoc = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ApiService.instance.updateProfile({
        'first_name': _ctrls['first_name']!.text,
        'last_name': _ctrls['last_name']!.text,
        'dob': _ctrls['dob']!.text,
        'phone': _ctrls['phone']!.text,
        'address': _ctrls['address']!.text,
        'city': _ctrls['city']!.text,
      });

      // Refresh the global user state with the updated profile
      await LaravelAuthManager.initialize();

      setState(() {
        _isSaving = false;
        _currentName = '${_ctrls['first_name']!.text} ${_ctrls['last_name']!.text}'.trim();
        if (_currentName.isEmpty) _currentName = 'Worker';
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated!'), backgroundColor: Colors.green));
      _navTo(0);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        width: widget.width ?? double.infinity,
        height: widget.height ?? MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
            color: bgDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: Colors.white10)),
        child: PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [_buildMainMenu(), _buildDocs(), _buildPersonalInfo(), _buildMyRequests()]));
  }

  Widget _buildMainMenu() {
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Center(
              child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                      color: cardDark,
                      borderRadius: BorderRadius.circular(10)))),
          const SizedBox(height: 30),
          Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardDark, borderRadius: BorderRadius.circular(24)),
              child: Row(children: [
                Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: accentBlue.withOpacity(0.2),
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text(
                            _currentName.isNotEmpty
                                ? _currentName[0].toUpperCase()
                                : 'W',
                            style: TextStyle(
                                color: accentBlue,
                                fontWeight: FontWeight.bold,
                                fontSize: 24)))),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_currentName,
                          style: TextStyle(
                              color: textLight,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text(_currentEmail,
                          style: TextStyle(color: textMuted, fontSize: 13))
                    ]))
              ])),
          const SizedBox(height: 30),
          Expanded(
              child: ListView(children: [
            _menuItem(Icons.contact_page, 'My Documents', () => _navTo(1)),
            _menuItem(Icons.person, 'Personal Information', () => _navTo(2)),
            _menuItem(Icons.list_alt, 'My Job Requests', () => _navTo(3)),
            const SizedBox(height: 24),
            _menuItem(Icons.logout, 'Sign out', _performLogOut,
                isDestructive: true)
          ]))
        ]));
  }

  Widget _buildDocs() {
    return _pageWrapper('My Documents', [
      Text('Identity & Compliance',
          style: TextStyle(
              color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _docCard(Icons.badge, 'Photo ID', 'Driver\'s license', 'photo_id_url'),
      _docCard(Icons.credit_card, 'SSN Card', 'Copy of SSN', 'ssn_url'),
      const SizedBox(height: 24),
      Text('Tax & Payroll',
          style: TextStyle(
              color: textMuted, fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      _docCard(Icons.description, 'W-9 Form', 'Tax document', 'w9_url'),
      _docCard(Icons.account_balance, 'Direct Deposit Form',
          'Bank authorization', 'bank_form_url'),
    ]);
  }

  Widget _docCard(
      IconData icon, String title, String subtitle, String firestoreField) {
    bool isUploaded = _docUrls[title] != null && _docUrls[title] != '';
    bool isUploading = _uploadingDoc == title;
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: cardDark,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isUploaded
                    ? Colors.green.withOpacity(0.3)
                    : Colors.white10)),
        child: Column(children: [
          Row(children: [
            Icon(icon, color: accentBlue, size: 28),
            const SizedBox(width: 16),
            Expanded(
                child: InkWell(
                    onTap: () => _uploadDocument(title, firestoreField),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: TextStyle(
                                  color: textLight,
                                  fontWeight: FontWeight.bold)),
                          Text(subtitle,
                              style: TextStyle(color: textMuted, fontSize: 12))
                        ]))),
            if (!isUploading)
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (isUploaded) ...[
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 22),
                    const SizedBox(height: 4),
                    Text("Reviewing",
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold))
                  ]),
                  const SizedBox(width: 16),
                  GestureDetector(
                      onTap: () => _deleteDocument(title, firestoreField),
                      child: const Icon(Icons.delete_outline,
                          color: Colors.redAccent, size: 26)),
                ] else ...[
                  GestureDetector(
                      onTap: () => _uploadDocument(title, firestoreField),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.cloud_upload, color: textMuted, size: 22),
                        const SizedBox(height: 4),
                        Text("Upload",
                            style: TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.bold))
                      ])),
                ]
              ]),
          ]),
          if (isUploading) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(color: accentBlue, backgroundColor: bgDark)
          ]
        ]));
  }

  Widget _buildPersonalInfo() {
    return _pageWrapper('Personal Info', [
      Row(children: [
        Expanded(child: _inputField('First Name', _ctrls['first_name']!)),
        const SizedBox(width: 12),
        Expanded(child: _inputField('Last Name', _ctrls['last_name']!)),
      ]),
      Row(children: [
        Expanded(child: _dateInputField('Date of Birth', _ctrls['dob']!)),
        const SizedBox(width: 12),
        Expanded(child: _inputField('Mobile Phone', _ctrls['phone']!))
      ]),
      _inputField('Street Address', _ctrls['address']!),
      _inputField('City, Zip Code', _ctrls['city']!),
      const SizedBox(height: 24),
      SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16))),
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('UPDATE',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 40),
    ]);
  }

  Widget _dateInputField(String label, TextEditingController controller) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
            controller: controller,
            readOnly: true,
            onTap: () async {
              DateTime? picked = await showDatePicker(
                context: context,
                initialDate: DateTime(2000),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                if (!mounted) return;
                controller.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
              }
            },
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: textMuted, fontSize: 13),
                filled: true,
                fillColor: cardDark,
                suffixIcon: Icon(Icons.calendar_today, color: textMuted, size: 20),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none))));
  }

  Widget _inputField(String label, TextEditingController controller) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
            controller: controller,
            style: TextStyle(color: textLight),
            decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: textMuted, fontSize: 13),
                filled: true,
                fillColor: cardDark,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none))));
  }

  Widget _pageWrapper(String title, List<Widget> children) {
    return Column(children: [
      Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: textLight),
                onPressed: () => _navTo(0)),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: textLight,
                    fontSize: 22,
                    fontWeight: FontWeight.bold))
          ])),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: children))
    ]);
  }

  Widget _menuItem(IconData icon, String title, VoidCallback onTap,
      {bool isDestructive = false}) {
    return InkWell(
        onTap: onTap,
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(children: [
              Icon(icon, color: isDestructive ? Colors.redAccent : textMuted),
              const SizedBox(width: 16),
              Text(title,
                  style: TextStyle(
                      color: isDestructive ? Colors.redAccent : textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              const Spacer(),
              Icon(Icons.chevron_right, color: textMuted)
            ])));
  }

  Widget _buildMyRequests() {
    return _pageWrapper('My Requests', [
      FutureBuilder<dynamic>(
        future: _myRequestsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || (snapshot.data as List).isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: Text('No requests found.', style: TextStyle(color: Colors.white60)),
              )
            );
          }

          List requests = snapshot.data as List;
          return Column(
            children: requests.map((req) {
              int statusCode = int.tryParse(req['status'].toString()) ?? 0;
              bool isPending = (statusCode == 0 || statusCode == 1 || statusCode == 2);
              
              String statusText;
              Color statusColor;
              switch (statusCode) {
                case 0: statusText = 'SUBMITTED'; statusColor = Colors.orange; break;
                case 1: statusText = 'REVIEWED'; statusColor = Colors.blue; break;
                case 2: statusText = 'PENDING'; statusColor = Colors.orange; break;
                case 3: statusText = 'REJECTED'; statusColor = Colors.red; break;
                case 4: statusText = 'ACCEPTED'; statusColor = Colors.green; break;
                default: statusText = 'UNKNOWN'; statusColor = Colors.grey; break;
              }
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardDark,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${req['request_type'].toString().toUpperCase()}',
                          style: TextStyle(color: textLight, fontWeight: FontWeight.bold),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (req['job'] != null)
                      Text('Job: ${req['job']['title'] ?? 'Unknown Job'}', style: TextStyle(color: textMuted, fontSize: 13)),
                    if (req['reason'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Reason: ${req['reason']}', style: TextStyle(color: textMuted, fontSize: 13)),
                      ),
                    if (req['created_at'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text('Submitted on: ${DateFormat('MMM d, yyyy h:mm a').format(DateTime.parse(req['created_at'].toString()).toLocal())}', style: TextStyle(color: textMuted, fontSize: 12, fontStyle: FontStyle.italic)),
                      ),
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                backgroundColor: cardDark,
                                title: const Text('Cancel Request', style: TextStyle(color: Colors.white)),
                                content: const Text('Are you sure you want to cancel this request?', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('No', style: TextStyle(color: Colors.white54)),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('Yes', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );

                            if (confirm != true) return;

                            try {
                              if (req['request_type'] == 'swap') {
                                await ApiService.instance.delete('/jobs/${req['job_id']}/swap-request');
                              }
                              _fetchMyRequests();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request cancelled'), backgroundColor: Colors.green));
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to cancel request'), backgroundColor: Colors.red));
                            }
                          },
                          child: const Text('Cancel Request', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ]
                  ],
                ),
              );
            }).toList(),
          );
        },
      )
    ]);
  }
}

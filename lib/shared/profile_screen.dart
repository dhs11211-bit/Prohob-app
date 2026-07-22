import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import '../backend/api_service.dart';

enum ProfileTab { profile, documents }

class ProfileScreen extends StatefulWidget {
  final ProfileTab initialTab;

  const ProfileScreen({
    Key? key,
    this.initialTab = ProfileTab.profile,
  }) : super(key: key);

  static Future<void> showModal(BuildContext context, {ProfileTab initialTab = ProfileTab.profile}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ProfileScreen(initialTab: initialTab),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileTab _activeTab;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String _userEmail = '';
  String _userRole = 'User';
  String _userName = '';
  bool _isLoading = true;
  bool _isSaving = false;
  String? _uploadingDocType;

  final Map<String, String?> _documents = {
    'Photo ID': null,
    'SSN Card': null,
    'W-9 Form': null,
    'Direct Deposit Form': null,
  };

  // Ultra-Premium Dark Theme Palette
  final Color bgDark = const Color(0xFF0F172A);
  final Color cardBg = const Color(0xFF1E293B);
  final Color cardBgHover = const Color(0xFF26334D);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color accentGreen = const Color(0xFF10B981);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab;
    _loadUserProfile();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'User';
      final role = prefs.getString('user_role') ?? 'User';
      final email = prefs.getString('user_email') ?? '';

      _userName = name;
      _userRole = role;
      _userEmail = email;

      final nameParts = name.trim().split(' ');
      if (nameParts.isNotEmpty) {
        _firstNameController.text = nameParts.first;
        if (nameParts.length > 1) {
          _lastNameController.text = nameParts.sublist(1).join(' ');
        }
      }

      // Fetch latest profile details & documents from backend via ApiService.getMe() or /mob/auth/me
      try {
        final userData = await ApiService.instance.getMe();
        if (userData != null) {
          final fn = userData['first_name'];
          final ln = userData['last_name'];
          final fullName = userData['name'] ?? '$fn $ln'.trim();

          if (fn != null && fn.toString().isNotEmpty) {
            _firstNameController.text = fn;
          }
          if (ln != null && ln.toString().isNotEmpty) {
            _lastNameController.text = ln;
          }

          if ((_firstNameController.text.isEmpty && _lastNameController.text.isEmpty) && fullName.isNotEmpty) {
            final parts = fullName.split(' ');
            _firstNameController.text = parts.first;
            if (parts.length > 1) {
              _lastNameController.text = parts.sublist(1).join(' ');
            }
          }

          if (userData['phone'] != null) _phoneController.text = userData['phone'].toString();
          if (userData['address'] != null) _addressController.text = userData['address'].toString();
          if (userData['city'] != null) _cityController.text = userData['city'].toString();
          if (userData['email'] != null) _userEmail = userData['email'].toString();

          if (userData['role'] != null) {
            if (userData['role'] is Map) {
              _userRole = userData['role']['name'] ?? userData['role']['slug'] ?? 'User';
            } else {
              _userRole = userData['role'].toString();
            }
          }

          _userName = fullName.isNotEmpty ? fullName : name;

          // Document URLs
          _documents['Photo ID'] = userData['photo_id_url'];
          _documents['SSN Card'] = userData['ssn_url'];
          _documents['W-9 Form'] = userData['w9_url'];
          _documents['Direct Deposit Form'] = userData['bank_form_url'];
        }
      } catch (err) {
        debugPrint('Error fetching user profile via API: $err');
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final payload = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
      };

      final updatedRes = await ApiService.instance.updateProfile(payload);
      final updatedUser = updatedRes['data'] ?? updatedRes;

      final newName = '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'.trim();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', newName);

      if (mounted) {
        setState(() {
          _userName = newName;
          if (updatedUser != null && updatedUser is Map) {
            if (updatedUser['phone'] != null) _phoneController.text = updatedUser['phone'].toString();
            if (updatedUser['address'] != null) _addressController.text = updatedUser['address'].toString();
            if (updatedUser['city'] != null) _cityController.text = updatedUser['city'].toString();
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully!'),
            backgroundColor: accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadDocument(String docType) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.bytes == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file bytes.')),
          );
        }
        return;
      }

      setState(() => _uploadingDocType = docType);

      final response = await ApiService.instance.uploadDocument(
        docType,
        file.bytes!,
        file.name,
      );

      final url = response['data']?['url'] ?? response['url'];
      if (url != null) {
        setState(() {
          _documents[docType] = url;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$docType uploaded successfully!'),
            backgroundColor: accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingDocType = null);
    }
  }

  String _getInitials() {
    final fn = _firstNameController.text.trim();
    final ln = _lastNameController.text.trim();
    if (fn.isNotEmpty && ln.isNotEmpty) {
      return '${fn[0]}${ln[0]}'.toUpperCase();
    } else if (_userName.isNotEmpty) {
      return _userName[0].toUpperCase();
    }
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final targetHeight = mediaQuery.size.height * 0.95;

    return Material(
      color: bgDark,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: targetHeight,
        padding: EdgeInsets.only(
          bottom: mediaQuery.viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        child: Column(
          children: [
            // Handle bar
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
            const SizedBox(height: 12),

            // Top Header Bar with Navigation
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Text(
                    _activeTab == ProfileTab.profile ? 'My Profile' : 'My Documents',
                    style: TextStyle(
                      color: textWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Toggle Tab Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _activeTab = _activeTab == ProfileTab.profile
                          ? ProfileTab.documents
                          : ProfileTab.profile;
                    });
                  },
                  child: Text(
                    _activeTab == ProfileTab.profile ? 'Documents' : 'Profile',
                    style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentBlue))
                  : _activeTab == ProfileTab.profile
                      ? _buildProfileForm()
                      : _buildDocumentsView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Avatar Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: accentBlue.withOpacity(0.2),
                    child: Text(
                      _getInitials(),
                      style: TextStyle(
                        color: accentBlue,
                        fontSize: 22,
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
                          '${_firstNameController.text} ${_lastNameController.text}'.trim().isEmpty
                              ? _userName
                              : '${_firstNameController.text} ${_lastNameController.text}',
                          style: TextStyle(
                            color: textWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentBlue.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _userRole.toUpperCase(),
                                style: TextStyle(
                                  color: accentBlue,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _userEmail,
                                style: TextStyle(color: muted, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Form Inputs
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'First Name',
                    controller: _firstNameController,
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    label: 'Last Name',
                    controller: _lastNameController,
                    icon: Icons.person_outline,
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _buildTextField(
              label: 'Phone Number',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    label: 'Street Address',
                    controller: _addressController,
                    icon: Icons.location_on_outlined,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    label: 'City',
                    controller: _cityController,
                    icon: Icons.location_city_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSaving ? null : _saveProfile,
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Profile Changes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section 1: Identity & Compliance
          Text(
            'Identity & Compliance',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildDocumentCard(
            title: 'Photo ID',
            subtitle: "Driver's license",
            icon: Icons.badge_outlined,
            docType: 'Photo ID',
          ),
          const SizedBox(height: 12),

          _buildDocumentCard(
            title: 'SSN Card',
            subtitle: 'Copy of SSN',
            icon: Icons.credit_card_outlined,
            docType: 'SSN Card',
          ),
          const SizedBox(height: 24),

          // Section 2: Tax & Payroll
          Text(
            'Tax & Payroll',
            style: TextStyle(
              color: muted,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          _buildDocumentCard(
            title: 'W-9 Form',
            subtitle: 'Tax document',
            icon: Icons.description_outlined,
            docType: 'W-9 Form',
          ),
          const SizedBox(height: 12),

          _buildDocumentCard(
            title: 'Direct Deposit Form',
            subtitle: 'Bank authorization',
            icon: Icons.account_balance_outlined,
            docType: 'Direct Deposit Form',
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDocumentCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required String docType,
  }) {
    final bool isUploading = _uploadingDocType == docType;
    final bool hasDoc = _documents[docType] != null && _documents[docType]!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasDoc ? accentGreen.withOpacity(0.3) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentBlue, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: isUploading ? null : () => _uploadDocument(docType),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: isUploading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accentBlue),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          hasDoc ? Icons.check_circle_outline : Icons.cloud_upload_outlined,
                          color: hasDoc ? accentGreen : muted,
                          size: 20,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasDoc ? 'Uploaded' : 'Upload',
                          style: TextStyle(
                            color: hasDoc ? accentGreen : muted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: muted, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: TextStyle(color: textWhite, fontSize: 14),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: accentBlue, size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb
import '../backend/api_service.dart';
import '../shared/signature_screen.dart';
import 'package:go_router/go_router.dart';

class OnboardingWizardScreen extends StatefulWidget {
  final int userId;
  final String token;

  const OnboardingWizardScreen({Key? key, required this.userId, required this.token}) : super(key: key);

  @override
  _OnboardingWizardScreenState createState() => _OnboardingWizardScreenState();
}

class _OnboardingWizardScreenState extends State<OnboardingWizardScreen> {
  int _currentStep = 0;
  bool _isLoading = false;

  String get apiUrl => ApiService.baseUrl.replaceAll('/mob', '');

  // --- Controllers for Step 1 ---
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // --- Controllers & State for Step 2 ---
  String _selectedIdType = 'Driver License';
  final List<String> _idTypes = ['Driver License', 'Passport', 'State ID', 'Other'];
  XFile? _idFrontImage;
  XFile? _idBackImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(bool isFront) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          if (isFront) {
            _idFrontImage = image;
          } else {
            _idBackImage = image;
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    }
  }

  // --- Controllers & State for Step 3 ---
  String _workerType = 'contractor'; // 'contractor' or 'employee'
  FilePickerResult? _w9File;
  String? _w9SignatureData;
  final _ssnController = TextEditingController();

  Future<void> _pickW9File() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() => _w9File = result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick W-9 file: $e')));
    }
  }

  Future<void> _captureW9Signature() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );
    if (result != null && result is String) {
      setState(() => _w9SignatureData = result);
    }
  }

  Future<void> _downloadW9() async {
    final url = Uri.parse('https://www.irs.gov/pub/irs-pdf/fw9.pdf');
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch W-9 link')));
    }
  }

  // --- Controllers & State for Step 4 ---
  String _filingStatus = 'Single';
  final List<String> _filingStatuses = ['Single', 'Married', 'Married but withhold at Single rate'];
  final _allowancesController = TextEditingController();
  final _additionalWithholdingController = TextEditingController();
  bool _isExempt = false;
  FilePickerResult? _w4File;
  String? _w4SignatureData;

  Future<void> _pickW4File() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() => _w4File = result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick W-4 file: $e')));
    }
  }

  Future<void> _captureW4Signature() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );
    if (result != null && result is String) {
      setState(() => _w4SignatureData = result);
    }
  }

  Future<void> _downloadW4() async {
    final url = Uri.parse('https://www.irs.gov/pub/irs-pdf/fw4.pdf');
    if (!await launchUrl(url)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not launch W-4 link')));
    }
  }

  // --- Controllers & State for Step 5 ---
  int _yearsExperience = 0;
  String _experienceLevel = 'Entry';
  final List<String> _experienceLevels = ['Entry', 'Intermediate', 'Senior', 'Expert'];
  final List<String> _selectedTransportation = [];
  final List<String> _transportationOptions = ['Own Car', 'Public Transit', 'Company Van', 'Bicycle', 'None'];
  final List<String> _selectedLanguages = [];
  final List<String> _languageOptions = ['English', 'Spanish', 'French', 'Mandarin', 'Arabic', 'Other'];
  final _bioController = TextEditingController();
  
  FilePickerResult? _coiFile;
  DateTime? _coiExpiryDate;

  Future<void> _pickCoiFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() => _coiFile = result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick COI file: $e')));
    }
  }

  Future<void> _pickCoiExpiryDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (pickedDate != null) {
      setState(() => _coiExpiryDate = pickedDate);
    }
  }

  // --- Controllers & State for Step 6 ---
  final Map<String, Map<String, dynamic>> _availability = {
    'monday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'tuesday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'wednesday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'thursday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'friday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'saturday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
    'sunday': {'available': false, 'start': const TimeOfDay(hour: 9, minute: 0), 'end': const TimeOfDay(hour: 17, minute: 0)},
  };
  
  String _formatTimeOfDay(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _copyMondaySchedule() {
    setState(() {
      final mon = _availability['monday']!;
      final days = ['tuesday', 'wednesday', 'thursday', 'friday']; // typically copy to weekdays
      for (var day in days) {
        _availability[day] = {
          'available': mon['available'],
          'start': mon['start'],
          'end': mon['end'],
        };
      }
    });
  }

  // --- Controllers & State for Step 7 ---
  String _serviceType = 'radius'; // 'radius' or 'zip_codes'
  final _homeAddressController = TextEditingController();
  double _maxTravelDistance = 25.0;
  final List<String> _serviceZipCodes = [];
  final _zipCodeController = TextEditingController();

  void _addZipCode() {
    final zip = _zipCodeController.text.trim();
    if (zip.isNotEmpty && !_serviceZipCodes.contains(zip)) {
      setState(() {
        _serviceZipCodes.add(zip);
        _zipCodeController.clear();
      });
    }
  }

  // --- Controllers & State for Step 8 ---
  bool _tosAccepted = false;
  bool _tosScrolledToBottom = false;
  bool _fcraAccepted = false;
  bool _fcraScrolledToBottom = false;
  bool _privacyAccepted = false;
  bool _privacyScrolledToBottom = false;
  String? _agreementsSignatureData;

  Future<void> _captureAgreementsSignature() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignatureScreen()),
    );
    if (result != null && result is String) {
      setState(() => _agreementsSignatureData = result);
    }
  }

  Widget _buildAgreementBox(String title, String text, bool isScrolled, bool isAccepted, Function(bool) onScrolled, Function(bool?) onAccepted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 8),
        Container(
          height: 150,
          decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(4)),
          child: NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification scrollInfo) {
              if (!isScrolled && scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 20) {
                onScrolled(true);
              }
              return false;
            },
            child: SingleChildScrollView(
              padding: EdgeInsets.all(8),
              child: Text(text),
            ),
          ),
        ),
        CheckboxListTile(
          title: Text('I have read and agree to the $title'),
          value: isAccepted,
          onChanged: isScrolled ? onAccepted : null,
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          subtitle: isScrolled ? null : Text('Please scroll to the bottom to accept', style: TextStyle(color: Colors.red, fontSize: 12)),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  // --- Controllers & State for Step 9 ---
  String _paymentMethod = 'direct_deposit'; // 'direct_deposit', 'check', 'debit_card'
  final _bankNameController = TextEditingController();
  String _accountType = 'checking'; // 'checking', 'savings'
  final _routingNumberController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _confirmAccountNumberController = TextEditingController();
  FilePickerResult? _bankFormFile;

  Future<void> _pickBankFormFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (result != null) {
        setState(() => _bankFormFile = result);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to pick bank form: $e')));
    }
  }

  // --- Future steps can have their controllers here ---
  
  Future<void> _saveStepProgress(String sectionName, Map<String, dynamic> data) async {
    setState(() => _isLoading = true);
    
    data['completed_section'] = sectionName;
    
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/users/${widget.userId}/onboarding-progress'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$sectionName saved!')));
        if (_currentStep < 9) {
          setState(() => _currentStep += 1);
        } else {
          // Final step submission logic
          _submitFinal();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save progress')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> _submitFinal() async {
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/users/${widget.userId}/onboarding-progress'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode({'submit_for_review': true}),
      );

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Profile Under Review'),
            content: Text('Your profile has been submitted and is currently under review by an admin. You will be notified once approved.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  context.pushReplacementNamed('WorkDashboard'); // Go to dashboard
                },
                child: Text('OK'),
              ),
            ],
          )
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submission failed. Please check your connection and try again.'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Complete Your Profile'),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator()) 
        : Stepper(
            type: StepperType.vertical,
            currentStep: _currentStep,
            onStepContinue: () async {
              // Switch statement to handle save logic for each step
              switch (_currentStep) {
                case 0:
                  if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty || _dobController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please fill out all personal information fields.')));
                    return;
                  }
                  _saveStepProgress('step_1_personal', {
                    'first_name': _firstNameController.text,
                    'last_name': _lastNameController.text,
                    'phone': _phoneController.text,
                    'dob': _dobController.text,
                  });
                  break;
                case 1:
                  if (_idFrontImage == null || _idBackImage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload both front and back of your ID.')));
                    return;
                  }
                  setState(() => _isLoading = true);
                  try {
                    final frontBytes = await _idFrontImage!.readAsBytes();
                    final frontRes = await ApiService.instance.uploadAttachment('user', widget.userId, frontBytes, _idFrontImage!.name);
                    
                    final backBytes = await _idBackImage!.readAsBytes();
                    final backRes = await ApiService.instance.uploadAttachment('user', widget.userId, backBytes, _idBackImage!.name);
                    
                    _saveStepProgress('step_2_identity', {
                      'id_type': _selectedIdType,
                      'id_front_url': frontRes['url'] ?? '',
                      'id_back_url': backRes['url'] ?? '',
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload ID: $e')));
                  }
                  break;
                case 2:
                  if (_workerType == 'contractor') {
                    if (_ssnController.text.isEmpty || _w9File == null || _w9SignatureData == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please provide SSN, upload W-9, and provide signature.')));
                      return;
                    }
                    setState(() => _isLoading = true);
                    try {
                      final fileBytes = _w9File!.files.single.bytes ?? await File(_w9File!.files.single.path!).readAsBytes();
                      final w9Res = await ApiService.instance.uploadAttachment('user', widget.userId, fileBytes, _w9File!.files.single.name);
                      
                      _saveStepProgress('step_3_tax', {
                        'worker_type': _workerType,
                        'w9_url': w9Res['url'] ?? '',
                        'ssn': _ssnController.text,
                        'signature_data': _w9SignatureData,
                      });
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload W-9: $e')));
                    }
                  } else {
                    _saveStepProgress('step_3_tax', {
                      'worker_type': _workerType,
                    });
                  }
                  break;
                case 3:
                  if (_workerType == 'employee') {
                    if (_w4File == null || _w4SignatureData == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload your completed W-4 and provide a signature.')));
                      return;
                    }
                    setState(() => _isLoading = true);
                    try {
                      final fileBytes = _w4File!.files.single.bytes ?? await File(_w4File!.files.single.path!).readAsBytes();
                      final w4Res = await ApiService.instance.uploadAttachment('user', widget.userId, fileBytes, _w4File!.files.single.name);
                      
                      _saveStepProgress('step_4_w2', {
                        'filing_status': _filingStatus,
                        'allowances': _allowancesController.text,
                        'additional_withholding': _additionalWithholdingController.text,
                        'exempt': _isExempt,
                        'w4_url': w4Res['url'] ?? '',
                        'signature_data': _w4SignatureData,
                      });
                    } catch (e) {
                      setState(() => _isLoading = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload W-4: $e')));
                    }
                  } else {
                    _saveStepProgress('step_4_w2', {
                      'skipped': true,
                    });
                  }
                  break;
                case 4:
                  if (_workerType == 'contractor') {
                    if (_coiFile == null || _coiExpiryDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please upload your COI and set an expiry date.')));
                      return;
                    }
                  }
                  setState(() => _isLoading = true);
                  try {
                    String? coiUrl;
                    if (_workerType == 'contractor' && _coiFile != null) {
                      final fileBytes = _coiFile!.files.single.bytes ?? await File(_coiFile!.files.single.path!).readAsBytes();
                      final coiRes = await ApiService.instance.uploadAttachment('user', widget.userId, fileBytes, _coiFile!.files.single.name);
                      coiUrl = coiRes['url'];
                    }
                    
                    _saveStepProgress('step_5_work', {
                      'years_experience': _yearsExperience,
                      'experience_level': _experienceLevel,
                      'transportation': _selectedTransportation,
                      'languages': _selectedLanguages,
                      'bio': _bioController.text,
                      if (_workerType == 'contractor') 'coi_url': coiUrl ?? '',
                      if (_workerType == 'contractor') 'coi_expiry': _coiExpiryDate?.toIso8601String(),
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
                  }
                  break;
                case 5:
                  final availData = {};
                  _availability.forEach((day, data) {
                    availData[day] = {
                      'available': data['available'],
                      'start': _formatTimeOfDay(data['start']),
                      'end': _formatTimeOfDay(data['end']),
                    };
                  });
                  
                  // Also POST to the specific availability endpoint if it exists
                  try {
                    http.post(
                      Uri.parse('$apiUrl/users/${widget.userId}/availability'),
                      headers: {'Authorization': 'Bearer ${widget.token}', 'Content-Type': 'application/json'},
                      body: json.encode({'availability': availData}),
                    );
                  } catch (e) {
                    // Ignore errors here if the endpoint isn't fully ready, _saveStepProgress will handle the main save
                  }

                  _saveStepProgress('step_6_availability', {
                    'availability': availData,
                  });
                  break;
                case 6:
                  if (_serviceType == 'radius' && _homeAddressController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your home address for the radius calculation.')));
                    return;
                  }
                  if (_serviceType == 'zip_codes' && _serviceZipCodes.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add at least one ZIP code.')));
                    return;
                  }
                  
                  _saveStepProgress('step_7_service_areas', {
                    'service_type': _serviceType,
                    'home_address': _homeAddressController.text,
                    'max_travel_distance': _maxTravelDistance,
                    'service_zip_codes': _serviceZipCodes,
                  });
                  break;
                case 7:
                  if (!_tosAccepted || !_fcraAccepted || !_privacyAccepted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('All agreements must be read and accepted.')));
                    return;
                  }
                  if (_agreementsSignatureData == null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please provide your digital signature.')));
                    return;
                  }
                  
                  _saveStepProgress('step_8_agreements', {
                    'tos_accepted': true,
                    'tos_accepted_at': DateTime.now().toIso8601String(),
                    'fcra_accepted': true,
                    'fcra_accepted_at': DateTime.now().toIso8601String(),
                    'privacy_accepted': true,
                    'privacy_accepted_at': DateTime.now().toIso8601String(),
                    'signature_data': _agreementsSignatureData,
                  });
                  break;
                case 8:
                  if (_paymentMethod == 'direct_deposit') {
                    if (_bankNameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter your Bank Name.')));
                      return;
                    }
                    if (_routingNumberController.text.length != 9) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Routing number must be exactly 9 digits.')));
                      return;
                    }
                    if (_accountNumberController.text.isEmpty || _accountNumberController.text != _confirmAccountNumberController.text) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account numbers do not match or are empty.')));
                      return;
                    }
                  }
                  
                  setState(() => _isLoading = true);
                  try {
                    String? formUrl;
                    if (_paymentMethod == 'direct_deposit' && _bankFormFile != null) {
                      final fileBytes = _bankFormFile!.files.single.bytes ?? await File(_bankFormFile!.files.single.path!).readAsBytes();
                      final formRes = await ApiService.instance.uploadAttachment('user', widget.userId, fileBytes, _bankFormFile!.files.single.name);
                      formUrl = formRes['url'];
                    }
                    
                    _saveStepProgress('step_9_payment', {
                      'payment_method': _paymentMethod,
                      if (_paymentMethod == 'direct_deposit') ...{
                        'bank_name': _bankNameController.text,
                        'account_type': _accountType,
                        'routing_number': _routingNumberController.text,
                        'account_number': _accountNumberController.text,
                        'bank_form_url': formUrl ?? '',
                      }
                    });
                  } catch (e) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save payment info: $e')));
                  }
                  break;
                case 9:
                  _saveStepProgress('step_10_final', {});
                  break;
              }
            },
            onStepCancel: () {
              if (_currentStep > 0) {
                setState(() => _currentStep -= 1);
              }
            },
            steps: [
              Step(
                title: Text('1. Personal Information'),
                content: Column(
                  children: [
                    TextFormField(controller: _firstNameController, decoration: InputDecoration(labelText: 'Legal First Name')),
                    TextFormField(controller: _lastNameController, decoration: InputDecoration(labelText: 'Legal Last Name')),
                    TextFormField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone Number')),
                    TextFormField(controller: _dobController, decoration: InputDecoration(labelText: 'Date of Birth (YYYY-MM-DD)')),
                  ],
                ),
                isActive: _currentStep >= 0,
              ),
              Step(
                title: Text('2. Identity Verification'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedIdType,
                      items: _idTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (val) => setState(() => _selectedIdType = val!),
                      decoration: InputDecoration(labelText: 'ID Type'),
                    ),
                    SizedBox(height: 16),
                    Text('Front of ID', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickImage(true),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: _idFrontImage == null 
                          ? Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 40)) 
                          : kIsWeb 
                              ? Image.network(_idFrontImage!.path, fit: BoxFit.contain) 
                              : Image.file(File(_idFrontImage!.path), fit: BoxFit.contain),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text('Back of ID', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    InkWell(
                      onTap: () => _pickImage(false),
                      child: Container(
                        height: 120,
                        width: double.infinity,
                        color: Colors.grey[200],
                        child: _idBackImage == null 
                          ? Center(child: Icon(Icons.add_a_photo, color: Colors.grey, size: 40)) 
                          : kIsWeb 
                              ? Image.network(_idBackImage!.path, fit: BoxFit.contain) 
                              : Image.file(File(_idBackImage!.path), fit: BoxFit.contain),
                      ),
                    ),
                  ],
                ),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: Text('3. Tax Information (1099)'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Radio<String>(
                          value: 'contractor',
                          groupValue: _workerType,
                          onChanged: (val) => setState(() => _workerType = val!),
                        ),
                        Text('I am a 1099 Contractor'),
                      ],
                    ),
                    Row(
                      children: [
                        Radio<String>(
                          value: 'employee',
                          groupValue: _workerType,
                          onChanged: (val) => setState(() => _workerType = val!),
                        ),
                        Text('I am a W-2 Employee'),
                      ],
                    ),
                    if (_workerType == 'employee') 
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Text('W-4 info will be collected in the next step.', style: TextStyle(color: Colors.blue)),
                      ),
                    if (_workerType == 'contractor') ...[
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _ssnController,
                        decoration: InputDecoration(
                          labelText: 'Social Security Number (SSN)',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        keyboardType: TextInputType.number,
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.download),
                          label: Text('Download Blank W-9'),
                          onPressed: _downloadW9,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text(_w9File == null ? 'Upload Completed W-9' : 'W-9 File Selected ✓'),
                          onPressed: _pickW9File,
                          style: _w9File != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                        ),
                      ),
                      SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.draw),
                          label: Text(_w9SignatureData == null ? 'Draw Digital Signature' : 'Signature Captured ✓'),
                          onPressed: _captureW9Signature,
                          style: _w9SignatureData != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                        ),
                      ),
                    ],
                  ],
                ),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: Text('4. Tax Forms (W-2 only)'),
                content: _workerType == 'contractor'
                    ? Text('Not applicable — W-4 is for W-2 employees only. Tap Continue to skip.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            value: _filingStatus,
                            items: _filingStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _filingStatus = val!),
                            decoration: InputDecoration(labelText: 'Filing Status', border: OutlineInputBorder()),
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _allowancesController,
                            decoration: InputDecoration(labelText: 'Total number of allowances', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _additionalWithholdingController,
                            decoration: InputDecoration(labelText: 'Additional withholding (\$) (Optional)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                          SizedBox(height: 8),
                          CheckboxListTile(
                            title: Text('I claim exemption from withholding'),
                            value: _isExempt,
                            onChanged: (val) => setState(() => _isExempt = val ?? false),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                          SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.download),
                              label: Text('Download Blank W-4'),
                              onPressed: _downloadW4,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.upload_file),
                              label: Text(_w4File == null ? 'Upload Completed W-4' : 'W-4 File Selected ✓'),
                              onPressed: _pickW4File,
                              style: _w4File != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                            ),
                          ),
                          SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.draw),
                              label: Text(_w4SignatureData == null ? 'Draw Digital Signature' : 'Signature Captured ✓'),
                              onPressed: _captureW4Signature,
                              style: _w4SignatureData != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                            ),
                          ),
                        ],
                      ),
                isActive: _currentStep >= 3,
              ),
              Step(
                title: Text('5. Work Profile & Insurance'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Years of Experience: ${_yearsExperience == 20 ? '20+' : _yearsExperience}', style: TextStyle(fontWeight: FontWeight.bold)),
                    Slider(
                      value: _yearsExperience.toDouble(),
                      min: 0,
                      max: 20,
                      divisions: 20,
                      label: _yearsExperience == 20 ? '20+' : _yearsExperience.toString(),
                      onChanged: (val) => setState(() => _yearsExperience = val.toInt()),
                    ),
                    SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _experienceLevel,
                      items: _experienceLevels.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (val) => setState(() => _experienceLevel = val!),
                      decoration: InputDecoration(labelText: 'Experience Level', border: OutlineInputBorder()),
                    ),
                    SizedBox(height: 16),
                    Text('Transportation (Select all that apply)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: _transportationOptions.map((opt) {
                        final isSelected = _selectedTransportation.contains(opt);
                        return FilterChip(
                          label: Text(opt),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) _selectedTransportation.add(opt);
                              else _selectedTransportation.remove(opt);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    Text('Languages Spoken', style: TextStyle(fontWeight: FontWeight.bold)),
                    Wrap(
                      spacing: 8.0,
                      children: _languageOptions.map((opt) {
                        final isSelected = _selectedLanguages.contains(opt);
                        return FilterChip(
                          label: Text(opt),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) _selectedLanguages.add(opt);
                              else _selectedLanguages.remove(opt);
                            });
                          },
                        );
                      }).toList(),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _bioController,
                      decoration: InputDecoration(labelText: 'Professional Bio', border: OutlineInputBorder()),
                      maxLines: 4,
                      maxLength: 500,
                    ),
                    if (_workerType == 'contractor') ...[
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Text('Business Insurance (COI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text(_coiFile == null ? 'Upload COI PDF/Image' : 'COI File Selected ✓'),
                          onPressed: _pickCoiFile,
                          style: _coiFile != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                        ),
                      ),
                      SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(_coiExpiryDate == null ? 'Select COI Expiry Date' : 'Expiry: ${_coiExpiryDate!.toString().split(' ')[0]}'),
                        trailing: Icon(Icons.calendar_today),
                        onTap: _pickCoiExpiryDate,
                      ),
                    ],
                  ],
                ),
                isActive: _currentStep >= 4,
              ),
              Step(
                title: Text('6. Availability'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Select your typical weekly availability:', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    ..._availability.keys.map((day) {
                      final data = _availability[day]!;
                      final isAvailable = data['available'] as bool;
                      final start = data['start'] as TimeOfDay;
                      final end = data['end'] as TimeOfDay;
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 4),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(day.toUpperCase(), style: TextStyle(fontWeight: FontWeight.bold)),
                                  Switch(
                                    value: isAvailable,
                                    onChanged: (val) => setState(() => data['available'] = val),
                                  ),
                                ],
                              ),
                              if (isAvailable) 
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final t = await showTimePicker(context: context, initialTime: start);
                                          if (t != null) setState(() => data['start'] = t);
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(labelText: 'Start', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                          child: Text(start.format(context)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final t = await showTimePicker(context: context, initialTime: end);
                                          if (t != null) setState(() => data['end'] = t);
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(labelText: 'End', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                                          child: Text(end.format(context)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.copy),
                        label: Text('Copy Monday to Tue-Fri'),
                        onPressed: _copyMondaySchedule,
                      ),
                    ),
                  ],
                ),
                isActive: _currentStep >= 5,
              ),
              Step(
                title: Text('7. Service Areas'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How do you define your service area?', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: Text('Service radius from home'),
                      value: 'radius',
                      groupValue: _serviceType,
                      onChanged: (val) => setState(() => _serviceType = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Specific ZIP codes'),
                      value: 'zip_codes',
                      groupValue: _serviceType,
                      onChanged: (val) => setState(() => _serviceType = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_serviceType == 'radius') ...[
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _homeAddressController,
                        decoration: InputDecoration(labelText: 'Home Base Address', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 16),
                      Text('Max Travel Distance: ${_maxTravelDistance.toInt()} miles', style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: _maxTravelDistance,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_maxTravelDistance.toInt()} miles',
                        onChanged: (val) => setState(() => _maxTravelDistance = val),
                      ),
                    ],
                    if (_serviceType == 'zip_codes') ...[
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _zipCodeController,
                              decoration: InputDecoration(labelText: 'Enter ZIP code', border: OutlineInputBorder()),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addZipCode,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Text('Add'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Wrap(
                        spacing: 8.0,
                        children: _serviceZipCodes.map((zip) {
                          return Chip(
                            label: Text(zip),
                            onDeleted: () => setState(() => _serviceZipCodes.remove(zip)),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
                isActive: _currentStep >= 6,
              ),
              Step(
                title: Text('8. Agreements & Background Check'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildAgreementBox(
                      'Terms of Service',
                      'By using this platform, you agree to abide by our standard operating procedures, maintain professionalism, and uphold quality standards. You understand that you are operating as an independent contractor or employee depending on your previous selection. This document contains standard arbitration clauses, liability limitations, and intellectual property agreements. \n\n(This is a placeholder for the full legal text. Please scroll to the bottom to accept.)\n\n\n\n\n\n\n\n\n\n\n[End of Document]',
                      _tosScrolledToBottom,
                      _tosAccepted,
                      (val) => setState(() => _tosScrolledToBottom = val),
                      (val) => setState(() => _tosAccepted = val ?? false),
                    ),
                    _buildAgreementBox(
                      'FCRA Background Check Authorization',
                      'By agreeing to this document, you authorize us to procure a consumer report and/or investigative consumer report on you for employment or contract purposes. This may include criminal history, driving records, and other relevant information as permitted by the Fair Credit Reporting Act (FCRA). \n\n(This is a placeholder for the full legal text. Please scroll to the bottom to accept.)\n\n\n\n\n\n\n\n\n\n\n[End of Document]',
                      _fcraScrolledToBottom,
                      _fcraAccepted,
                      (val) => setState(() => _fcraScrolledToBottom = val),
                      (val) => setState(() => _fcraAccepted = val ?? false),
                    ),
                    _buildAgreementBox(
                      'Privacy Policy',
                      'We collect your personal information to facilitate your work, process payments, and ensure platform safety. We do not sell your data to third parties. For a full breakdown of how we store, encrypt, and handle your data, please read the entire policy. \n\n(This is a placeholder for the full legal text. Please scroll to the bottom to accept.)\n\n\n\n\n\n\n\n\n\n\n[End of Document]',
                      _privacyScrolledToBottom,
                      _privacyAccepted,
                      (val) => setState(() => _privacyScrolledToBottom = val),
                      (val) => setState(() => _privacyAccepted = val ?? false),
                    ),
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.draw),
                        label: Text(_agreementsSignatureData == null ? 'Draw Digital Signature' : 'Agreements Signed ✓'),
                        onPressed: _captureAgreementsSignature,
                        style: _agreementsSignatureData != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                      ),
                    ),
                  ],
                ),
                isActive: _currentStep >= 7,
              ),
              Step(
                title: Text('9. Payment Setup'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How would you like to be paid?', style: TextStyle(fontWeight: FontWeight.bold)),
                    RadioListTile<String>(
                      title: Text('Direct Deposit'),
                      value: 'direct_deposit',
                      groupValue: _paymentMethod,
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Paper Check'),
                      value: 'check',
                      groupValue: _paymentMethod,
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    RadioListTile<String>(
                      title: Text('Prepaid Debit Card'),
                      value: 'debit_card',
                      groupValue: _paymentMethod,
                      onChanged: (val) => setState(() => _paymentMethod = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_paymentMethod == 'direct_deposit') ...[
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _bankNameController,
                        decoration: InputDecoration(labelText: 'Bank Name', border: OutlineInputBorder()),
                      ),
                      SizedBox(height: 16),
                      Text('Account Type', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Checking'),
                              value: 'checking',
                              groupValue: _accountType,
                              onChanged: (val) => setState(() => _accountType = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<String>(
                              title: Text('Savings'),
                              value: 'savings',
                              groupValue: _accountType,
                              onChanged: (val) => setState(() => _accountType = val!),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _routingNumberController,
                        decoration: InputDecoration(labelText: '9-Digit Routing Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        maxLength: 9,
                      ),
                      SizedBox(height: 8),
                      TextFormField(
                        controller: _accountNumberController,
                        decoration: InputDecoration(labelText: 'Account Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmAccountNumberController,
                        decoration: InputDecoration(labelText: 'Confirm Account Number', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                        obscureText: true,
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text(_bankFormFile == null ? 'Upload Voided Check / Bank Letter' : 'Bank Document Selected ✓'),
                          onPressed: _pickBankFormFile,
                          style: _bankFormFile != null ? ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white) : null,
                        ),
                      ),
                    ],
                    if (_paymentMethod == 'check') ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(Icons.local_post_office, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(child: Text('Paper checks will be mailed to your home address on file.')),
                          ],
                        ),
                      ),
                    ],
                    if (_paymentMethod == 'debit_card') ...[
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        color: Colors.blue.shade50,
                        child: Row(
                          children: [
                            Icon(Icons.credit_card, color: Colors.blue),
                            SizedBox(width: 8),
                            Expanded(child: Text('You will receive instructions to activate your prepaid debit card via email upon approval.')),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                    Text('🔒 Your banking information is encrypted and stored securely.', style: TextStyle(color: Colors.grey.shade700, fontSize: 13, fontStyle: FontStyle.italic)),
                  ],
                ),
                isActive: _currentStep >= 8,
              ),
              Step(
                title: Text('10. Final Submission'),
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 40),
                          SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              'You have completed all the required steps!\n\nTap Continue to submit your profile for administrator review. We will notify you once you are approved to start receiving jobs.',
                              style: TextStyle(fontSize: 14, color: Colors.green.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                isActive: _currentStep >= 9,
              ),
            ],
          ),
    );
  }
}

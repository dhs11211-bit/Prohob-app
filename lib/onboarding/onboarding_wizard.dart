import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  final String apiUrl = 'http://localhost:8000/api';

  // --- Controllers for Step 1 ---
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _phoneController = TextEditingController();
  
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
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          )
        );
      }
    } catch (e) {}
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
            onStepContinue: () {
              // Switch statement to handle save logic for each step
              switch (_currentStep) {
                case 0:
                  _saveStepProgress('step_1_personal', {
                    'first_name': _firstNameController.text,
                    'last_name': _lastNameController.text,
                    'phone': _phoneController.text,
                    'dob': _dobController.text,
                  });
                  break;
                case 1:
                  _saveStepProgress('step_2_identity', {});
                  break;
                case 2:
                  _saveStepProgress('step_3_tax', {});
                  break;
                case 3:
                  _saveStepProgress('step_4_w2', {});
                  break;
                case 4:
                  _saveStepProgress('step_5_work', {});
                  break;
                case 5:
                  _saveStepProgress('step_6_availability', {});
                  break;
                case 6:
                  _saveStepProgress('step_7_service_areas', {});
                  break;
                case 7:
                  _saveStepProgress('step_8_agreements', {});
                  break;
                case 8:
                  _saveStepProgress('step_9_payment', {});
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
                content: Text('Upload Government ID (Photo UI placeholder)'),
                isActive: _currentStep >= 1,
              ),
              Step(
                title: Text('3. Tax Information (1099)'),
                content: Text('W-9 Upload & Digital Signature (Placeholder)'),
                isActive: _currentStep >= 2,
              ),
              Step(
                title: Text('4. Tax Forms (W-2 only)'),
                content: Text('W-4 filling & Digital Signature (Placeholder)'),
                isActive: _currentStep >= 3,
              ),
              Step(
                title: Text('5. Work Profile & Insurance'),
                content: Text('Experience, Transportation, Languages, and Business Insurance (COI) Upload for 1099s (Placeholder)'),
                isActive: _currentStep >= 4,
              ),
              Step(
                title: Text('6. Availability'),
                content: Text('Schedule configuration (Placeholder)'),
                isActive: _currentStep >= 5,
              ),
              Step(
                title: Text('7. Service Areas'),
                content: Text('Zip codes / Distance setup (Placeholder)'),
                isActive: _currentStep >= 6,
              ),
              Step(
                title: Text('8. Agreements & Background Check'),
                content: Text('Contractor/Employee Agreements & FCRA Background Check Authorization Digital Signatures (Placeholder)'),
                isActive: _currentStep >= 7,
              ),
              Step(
                title: Text('9. Payment Setup'),
                content: Text('Bank Details or Instant Payout Debit Card (Placeholder)'),
                isActive: _currentStep >= 8,
              ),
              Step(
                title: Text('10. Final Submission'),
                content: Text('Review your data and submit for admin approval.'),
                isActive: _currentStep >= 9,
              ),
            ],
          ),
    );
  }
}

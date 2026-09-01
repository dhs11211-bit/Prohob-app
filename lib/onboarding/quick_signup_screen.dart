import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'onboarding_wizard.dart';
import '../backend/api_service.dart';

class QuickSignupScreen extends StatefulWidget {
  const QuickSignupScreen({Key? key}) : super(key: key);

  static String routeName = 'QuickSignup';
  static String routePath = '/quickSignup';

  @override
  _QuickSignupScreenState createState() => _QuickSignupScreenState();
}

class _QuickSignupScreenState extends State<QuickSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  TextEditingController _firstNameController = TextEditingController();
  TextEditingController _lastNameController = TextEditingController();
  TextEditingController _phoneController = TextEditingController();
  TextEditingController _emailController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _companyCodeController = TextEditingController();
  TextEditingController _otpController = TextEditingController();
  
  String _workerType = '1099_contractor';
  bool _otpSent = false;
  bool _isLoading = false;

  String get apiUrl => ApiService.baseUrl.replaceAll('/mob', '');

  Future<void> sendOtp() async {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please enter phone number')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/auth/worker/send-otp'),
        body: {'phone': _phoneController.text},
      );
      if (response.statusCode == 200) {
        setState(() => _otpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('OTP sent (Use 123456 for testing)')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send OTP')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  Future<void> submitSignup() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/auth/worker/quick-signup'),
        body: {
          'first_name': _firstNameController.text,
          'last_name': _lastNameController.text,
          'email': _emailController.text,
          'phone': _phoneController.text,
          'password': _passwordController.text,
          'company_code': _companyCodeController.text,
          'otp': _otpController.text,
          'user_type': _workerType,
        },
      );
      
      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Account created! Please sign in.')));
        Navigator.pop(context);
      } else {
        final error = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: ${error['message'] ?? 'Unknown error'}')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Quick Signup'),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _companyCodeController,
                  decoration: InputDecoration(labelText: 'Company Invite Code'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _firstNameController,
                  decoration: InputDecoration(labelText: 'First Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _lastNameController,
                  decoration: InputDecoration(labelText: 'Last Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(labelText: 'Password'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _workerType,
                  decoration: InputDecoration(labelText: 'Worker Type'),
                  items: [
                    DropdownMenuItem(value: '1099_contractor', child: Text('1099 Independent Contractor')),
                    DropdownMenuItem(value: 'w2_employee', child: Text('W-2 Employee')),
                  ],
                  onChanged: (val) => setState(() => _workerType = val!),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(labelText: 'Mobile Number'),
                        validator: (v) => v!.isEmpty ? 'Required' : null,
                        enabled: !_otpSent,
                      ),
                    ),
                    SizedBox(width: 8),
                    if (!_otpSent)
                      ElevatedButton(
                        onPressed: _isLoading ? null : sendOtp,
                        child: _isLoading ? CircularProgressIndicator() : Text('Send OTP'),
                      )
                  ],
                ),
                if (_otpSent) ...[
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _otpController,
                    decoration: InputDecoration(labelText: 'Enter OTP'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : submitSignup,
                    child: Text('Create Account'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

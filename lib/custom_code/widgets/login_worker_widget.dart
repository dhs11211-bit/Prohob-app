// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

// Set your widget name, define your parameter, and then add the
// boilerplate code using the green button on the right!
import 'dart:ui';
import '../../auth/laravel_auth_manager.dart';

class LoginWorkerWidget extends StatefulWidget {
  const LoginWorkerWidget({
    super.key,
    this.width,
    this.height,
    required this.onLoginSuccess,
    required this.onBackTap, // Nuevo parámetro para regresar
  });

  final double? width;
  final double? height;
  final Future Function() onLoginSuccess;
  final Future Function() onBackTap;

  @override
  State<LoginWorkerWidget> createState() => _LoginWorkerWidgetState();
}

class _LoginWorkerWidgetState extends State<LoginWorkerWidget> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _errorMessage = '';

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = "Please fill in all fields.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await LaravelAuthManager.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (result != null && result['requires_selection'] == true) {
        final List<dynamic> companies = result['companies'];
        if (mounted) setState(() => _isLoading = false);
        final selectedClId = await _showCompanySelectionDialog(companies);

        if (selectedClId != null) {
          setState(() {
            _isLoading = true;
          });
          await LaravelAuthManager.login(
            _emailController.text.trim(),
            _passwordController.text.trim(),
            clId: selectedClId,
          );
          await widget.onLoginSuccess();
        } else {
          return;
        }
      } else {
        await widget.onLoginSuccess();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int?> _showCompanySelectionDialog(List<dynamic> companies) {
    return showDialog<int>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A), // Slate 900
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withOpacity(0.1), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.business_rounded,
                          color: Color(0xFF3B82F6), size: 24),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Select Company",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 4),
                          Text("Choose a workspace to continue",
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // List of Companies
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: companies.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final company = companies[index];
                      final String companyName =
                          company['company_name'] ?? 'Unknown Company';
                      final String initial = companyName.isNotEmpty
                          ? companyName.substring(0, 1).toUpperCase()
                          : 'U';

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).pop(company['cl_id'] as int);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  companyName,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: Colors.white38, size: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Cancel",
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: const Color(0xFF0D1B2A), // Background Dark Mode
      child: SafeArea(
        child: Stack(
          children: [
            // --- FORMULARIO CENTRAL ---
            Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Welcome to",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 16)),
                      const Text("Field Handle",
                          style: TextStyle(
                              color: Color(0xFF3B82F6),
                              fontSize: 44,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 40),

                      const Text("Email Address",
                          style:
                              TextStyle(color: Colors.white60, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildTextField(
                          controller: _emailController,
                          hint: "worker@fieldhandle.com",
                          icon: Icons.email_outlined),
                      const SizedBox(height: 24),

                      const Text("Password",
                          style:
                              TextStyle(color: Colors.white60, fontSize: 14)),
                      const SizedBox(height: 8),
                      _buildTextField(
                        controller: _passwordController,
                        hint: "••••••••",
                        icon: Icons.lock_outline,
                        isPassword: true,
                        suffixIcon: IconButton(
                          icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Colors.white38),
                          onPressed: () => setState(
                              () => _isPasswordVisible = !_isPasswordVisible),
                        ),
                      ),

                      if (_errorMessage.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_errorMessage,
                                style: const TextStyle(
                                    color: Color(0xFFEF4444), fontSize: 14))),

                      const SizedBox(height: 40),

                      // Botón de Iniciar Sesión
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text("Sign In",
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- BOTÓN DE ATRÁS (ESQUINA SUPERIOR IZQUIERDA) ---
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white, size: 24),
                onPressed: () async {
                  await widget.onBackTap();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
      {required TextEditingController controller,
      required String hint,
      required IconData icon,
      bool isPassword = false,
      Widget? suffixIcon}) {
    return Container(
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12)),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !_isPasswordVisible,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
            suffixIcon: suffixIcon,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 18)),
      ),
    );
  }
}

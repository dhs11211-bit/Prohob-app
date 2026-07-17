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
      await LaravelAuthManager.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await widget.onLoginSuccess();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

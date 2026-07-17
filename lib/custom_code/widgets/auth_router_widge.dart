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
import '../../auth/laravel_auth_manager.dart';

class AuthRouterWidge extends StatefulWidget {
  const AuthRouterWidge({
    super.key,
    this.width,
    this.height,
    required this.onAdminRoute,
    required this.onWorkerRoute,
  });

  final double? width;
  final double? height;
  final Future Function() onAdminRoute;
  final Future Function() onWorkerRoute;

  @override
  State<AuthRouterWidge> createState() => _AuthRouterWidgeState();
}

class _AuthRouterWidgeState extends State<AuthRouterWidge> {
  @override
  void initState() {
    super.initState();
    // Esperamos a que la UI dibuje el primer frame para no romper FlutterFlow al navegar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _routeUser();
    });
  }

  Future<void> _routeUser() async {
    final user = currentUser as LaravelAuthUser?;

    if (user == null || user.userData == null) {
      if (mounted) {
        // Redirigir al landing o login si no hay sesión para no quedarse trabado
        context.goNamed('LandingPricingFirst');
      }
      return;
    }
    try {
      String role = user.userData!['role']?['slug'] ??
          'technician'; // Por defecto worker/technician

      if (role == 'admin') {
        await widget.onAdminRoute();
      } else {
        await widget.onWorkerRoute();
      }
    } catch (e) {
      debugPrint("Error en ruteo: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      color: const Color(0xFF0D1B2A),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF3B82F6),
            ),
            SizedBox(height: 24),
            Text(
              "Loading Field Handle...",
              style: TextStyle(
                color: Colors.white60,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/widgets/index.dart'; // 🟢 ESTO IMPORTA TU NUEVO WIDGET
import '/backend/api_service.dart';

class CustomNavBar extends StatefulWidget {
  const CustomNavBar({
    Key? key,
    this.width,
    this.height,
    this.currentIndex = 0,
    this.onHome,
    this.onSchedule,
    this.onWallet,
    this.onInbox,
  }) : super(key: key);

  final double? width;
  final double? height;
  final int currentIndex;
  final Future Function()? onHome;
  final Future Function()? onSchedule;
  final Future Function()? onWallet;
  final Future Function()? onInbox;

  @override
  _CustomNavBarState createState() => _CustomNavBarState();
}

class _CustomNavBarState extends State<CustomNavBar> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);

  // 🟢 LA ORDEN DIRECTA PARA ABRIR EL MODAL INTELIGENTE
  void _openEvidenceFlow() async {
    try {
      final jobs = await ApiService.instance.getTodayJobs();
      if (jobs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You have no scheduled jobs today', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              backgroundColor: Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }
      if (mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const CustomEvidenceModal(),
        );
      }
    } catch (e) {
      print("Error opening evidence flow: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? double.infinity,
      height: 90,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            width: double.infinity,
            height: 65,
            decoration: BoxDecoration(color: card, boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, -2))
            ]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  _navItem(Icons.home_filled, 0, widget.onHome),
                  _navItem(Icons.calendar_month, 1, widget.onSchedule)
                ]),
                Row(children: [
                  _navItem(Icons.account_balance_wallet, 2, widget.onWallet),
                  _navItem(Icons.chat_bubble, 3, widget.onInbox)
                ]),
              ],
            ),
          ),

          // EL BOTÓN AMARILLO GIGANTE
          Positioned(
            top: 0,
            child: GestureDetector(
              onTap: _openEvidenceFlow, // 🟢 AQUÍ CONECTAMOS EL GATILLO
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                    color: neonAction,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: neonAction.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.black, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, int index, Future Function()? action) {
    bool sel = widget.currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (!sel && action != null) action();
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 80) / 4,
        alignment: Alignment.center,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: sel ? accentBlue.withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(16)),
          child:
              Icon(icon, color: sel ? accentBlue : muted, size: sel ? 26 : 24),
        ),
      ),
    );
  }
}

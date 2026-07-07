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

class LandingPricingWidget extends StatefulWidget {
  const LandingPricingWidget({
    super.key,
    this.width,
    this.height,
    required this.onSignInTap,
    required this.onSelectPlan,
  });

  final double? width;
  final double? height;
  final Future Function() onSignInTap;
  final Future Function(String planName) onSelectPlan;

  @override
  State<LandingPricingWidget> createState() => _LandingPricingWidgetState();
}

class _LandingPricingWidgetState extends State<LandingPricingWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width ?? double.infinity,
      height: widget.height ?? double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A), // Dark Navy Background
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "FIELD HANDLE",
                    style: TextStyle(
                      color: Color(0xFF3B82F6),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      // Este botón dispara la acción que configurarás en FlutterFlow
                      await widget.onSignInTap();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("SIGN IN"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- HERO SECTION ---
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Text(
                    "The Software That Powers\nYour Service Business", // CAMBIO AQUÍ: Universal
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Choose the plan that fits your growth and start optimizing your field operations today.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // --- PRICING CARDS ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  _buildPricingCard(
                    title: "STARTER",
                    price: "\$49",
                    description:
                        "Best for solo independent contractors starting their journey.",
                    features: [
                      "1 Active User",
                      "Automatic Invoicing",
                      "Client Database",
                      "Support"
                    ],
                  ),
                  _buildPricingCard(
                    title: "PROFESSIONAL",
                    price: "\$129",
                    description:
                        "Perfect for growing teams of cleaners and supervisors.",
                    isPopular: true,
                    features: [
                      "Up to 5 Users",
                      "Live GPS Tracking",
                      "Review Automation",
                      "Advanced Analytics"
                    ],
                  ),
                  _buildPricingCard(
                    title: "ENTERPRISE",
                    price: "\$249",
                    description:
                        "Custom solutions for large agencies and commercial giants.",
                    features: [
                      "Unlimited Users",
                      "Predictive AI Logic",
                      "Dedicated Manager",
                      "Full API Access"
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 80),

            const Text(
              "Trusted by 1,000+ service companies worldwide", // CAMBIO AQUÍ
              style: TextStyle(color: Colors.white24, fontSize: 14),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String description,
    required List<String> features,
    bool isPopular = false,
  }) {
    return Container(
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Card color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? const Color(0xFF3B82F6) : Colors.white10,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPopular)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text("MOST POPULAR",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          Text(title,
              style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(price,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.bold)),
              const Padding(
                padding: EdgeInsets.only(bottom: 8, left: 4),
                child: Text("/mo",
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(description,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 14, height: 1.4)),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 24),
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 12),
                    Text(f,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              )),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                await widget.onSelectPlan(title);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isPopular ? const Color(0xFF3B82F6) : Colors.white,
                foregroundColor: isPopular ? Colors.white : Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("START FREE TRIAL",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

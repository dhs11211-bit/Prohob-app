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
import '/backend/api_service.dart';

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
  List<dynamic> _plans = [];
  String _platformName = "FIELD HANDLE";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final plansFuture = ApiService.instance.getSubscriptionPlans();
      final settingsFuture = ApiService.instance.getPublicSettings();

      final results = await Future.wait([plansFuture, settingsFuture]);
      final plans = results[0] as List<dynamic>;
      final settings = results[1] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _plans = plans;
          if (settings['platform_name'] != null &&
              settings['platform_name'].toString().isNotEmpty) {
            _platformName = settings['platform_name'].toString().toUpperCase();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      print('Error fetching data: $e');
    }
  }

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
                  Text(
                    _platformName,
                    style: const TextStyle(
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
                    "Powering Your\nService Business",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
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
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child:
                          CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _plans.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(40),
                          child: Text('No plans available',
                              style: TextStyle(color: Colors.white)))
                      : Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: _plans.map((plan) {
                            return _buildPricingCard(
                                context: context,
                                plan: plan as Map<String, dynamic>);
                          }).toList(),
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
    required BuildContext context,
    required Map<String, dynamic> plan,
  }) {
    final title = plan['name']?.toString() ?? 'PLAN';
    final price =
        plan['price_monthly'] != null ? '\$${plan['price_monthly']}' : '\$0';
    final description = plan['description']?.toString() ?? '';
    final isPopular = plan['is_popular'] == true ||
        plan['is_popular'] == 1 ||
        plan['is_popular'] == '1';
    final planId = plan['id'];

    final trialDays = plan['trial_days'] is num
        ? (plan['trial_days'] as num).toInt()
        : int.tryParse(plan['trial_days']?.toString() ?? '0');
    final yearlyDiscount = plan['yearly_discount_percentage'] is num
        ? (plan['yearly_discount_percentage'] as num)
        : num.tryParse(plan['yearly_discount_percentage']?.toString() ?? '0');

    List<String> features = [];
    if (plan['features'] != null) {
      if (plan['features'] is String) {
        features = plan['features'].split(',');
      } else if (plan['features'] is List) {
        features = List<String>.from(plan['features'].map((e) => e.toString()));
      }
    }

    return Container(
      width: MediaQuery.of(context).size.width > 400
          ? 380
          : MediaQuery.of(context).size.width - 32,
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
          if (trialDays != null && trialDays > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF10B981)), // Green
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0xFF10B981).withOpacity(0.1),
                ),
                child: Text("$trialDays Days Free Trial",
                    style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          if (yearlyDiscount != null && yearlyDiscount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text("Save $yearlyDiscount% with yearly billing",
                  style: const TextStyle(
                      color: Color(0xFFF59E0B), // Amber
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
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
                final url = 'https://serviceprohob.com/register?plan=$planId';
                await launchURL(url);
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

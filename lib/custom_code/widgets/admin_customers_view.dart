// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:ui';
import '../../backend/api_service.dart';
import '/app_constants.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class AdminCustomersView extends StatefulWidget {
  const AdminCustomersView({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
    this.openCreateJobModal = false,
    this.openCreateCustomerModal = false,
    this.onJobCreated,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;
  final bool openCreateJobModal;
  final bool openCreateCustomerModal;
  final VoidCallback? onJobCreated;

  @override
  State<AdminCustomersView> createState() => _AdminCustomersViewState();
}

class _AdminCustomersViewState extends State<AdminCustomersView> {
  String _adminName = "Admin";
  bool _isLoadingCustomers = true;
  List<dynamic> _customersList = [];
  Timer? _refreshTimer;
  String? _googleMapsApiKey = AppConstants.fallbackGoogleMapsApiKey;

  List<String> _jobTypes = ["Job", "Estimate", "Appointment", "Event"];
  List<String> _availableTasks = ["Dusting", "Vacuuming", "Mopping", "Windows"];

  final List<String> _frequencies = [
    "One-time",
    "Daily",
    "Weekly",
    "Bi-weekly",
    "Weekends Only",
    "Custom"
  ];

  final List<String> _durations = [
    "Ongoing (No end date)",
    "1 Month",
    "3 Months",
    "6 Months",
    "1 Year"
  ];

  @override
  void initState() {
    super.initState();
    _adminName = "Admin";
    _fetchGoogleMapsKey();
    _fetchCustomers();
    // _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
    //   _fetchCustomers();
    // });

    if (widget.openCreateCustomerModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showAddCustomerModal();
      });
    }
    if (widget.openCreateJobModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showCreateJobModal();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchGoogleMapsKey() async {
    try {
      final settings = await ApiService.instance.get('/settings');
      if (mounted &&
          settings is Map &&
          settings.containsKey('data') &&
          settings['data'] is Map &&
          settings['data'].containsKey('google_maps_api_key') &&
          settings['data']['google_maps_api_key'] != null &&
          settings['data']['google_maps_api_key'].toString().trim().isNotEmpty) {
        _googleMapsApiKey = settings['data']['google_maps_api_key'];
      }
    } catch (e) {
      debugPrint("Error fetching maps key: $e");
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await ApiService.instance.get('/admin/customers');
      if (mounted) {
        setState(() {
          // Check if paginated or raw list
          dynamic dataObj =
              res is Map && res.containsKey('data') ? res['data'] : res;
          if (dataObj is Map && dataObj.containsKey('data')) {
            _customersList = dataObj['data'];
          } else if (dataObj is List) {
            _customersList = dataObj;
          } else {
            _customersList = [];
          }
          _isLoadingCustomers = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching customers: $e");
      if (mounted) setState(() => _isLoadingCustomers = false);
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good morning,";
    if (hour < 18) return "Good afternoon,";
    return "Good evening,";
  }

  String _getUserInitial(String name) {
    return name.isNotEmpty ? name[0].toUpperCase() : "A";
  }

  // --- COMPONENTES UI REUTILIZABLES ---
  Widget _buildInfoField(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500))
      ]),
    );
  }

  Widget _buildSimpleTextField(TextEditingController ctrl, String hint,
      {bool isAddress = false, Function(String)? onChanged}) {
    return Container(
      height: 41,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10)),
      child: Center(
        child: TextField(
          controller: ctrl,
          onChanged: onChanged,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
            prefixIconConstraints: isAddress
                ? const BoxConstraints(minWidth: 36, minHeight: 0)
                : null,
            prefixIcon: isAddress
                ? const Icon(Icons.location_on,
                    color: Color(0xFF3B82F6), size: 20)
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  // =====================================================================
  // 🚀 MENÚ DE PERFIL UNIFICADO (IGUAL AL TEAM Y AL MAPA)
  // =====================================================================
  void _showAdminPersonalInfoModal() {
    TextEditingController firstNameCtrl =
        TextEditingController(text: _adminName.split(' ').first);
    TextEditingController lastNameCtrl = TextEditingController(
        text: _adminName.split(' ').length > 1
            ? _adminName.split(' ').sublist(1).join(' ')
            : '');
    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(builder: (context, setModalState) {
              return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0D1B2A),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(32)),
                      ),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                                child: Container(
                                    width: 40,
                                    height: 5,
                                    decoration: BoxDecoration(
                                        color: Colors.white24,
                                        borderRadius:
                                            BorderRadius.circular(10)))),
                            const SizedBox(height: 24),
                            const Text("Personal Information",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 24),
                            const Text("Email Address (Uneditable)",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text("No Email",
                                  style: const TextStyle(
                                      color: Colors.white60, fontSize: 16)),
                            ),
                            const SizedBox(height: 20),
                            const Text("First Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: firstNameCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "First Name",
                                  hintStyle: TextStyle(color: Colors.white38),
                                  prefixIcon: Icon(Icons.person,
                                      color: Color(0xFF3B82F6)),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text("Last Name",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: TextField(
                                controller: lastNameCtrl,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: "Last Name",
                                  hintStyle: TextStyle(color: Colors.white38),
                                  prefixIcon: Icon(Icons.person_outline,
                                      color: Color(0xFF3B82F6)),
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12))),
                                  onPressed: isSaving
                                      ? null
                                      : () async {
                                          if (firstNameCtrl.text
                                                  .trim()
                                                  .isEmpty ||
                                              lastNameCtrl.text.trim().isEmpty)
                                            return;
                                          setModalState(() => isSaving = true);
                                          try {
                                            await ApiService.instance
                                                .put('/auth/profile', {
                                              'first_name':
                                                  firstNameCtrl.text.trim(),
                                              'last_name':
                                                  lastNameCtrl.text.trim(),
                                            });

                                            if (mounted)
                                              setState(() => _adminName =
                                                  '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}');
                                            Navigator.pop(ctx);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(const SnackBar(
                                                    content: Text(
                                                        'Profile updated successfully!'),
                                                    backgroundColor:
                                                        Color(0xFF10B981)));
                                          } catch (e) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content: Text('Error: $e'),
                                                    backgroundColor:
                                                        Colors.redAccent));
                                          } finally {
                                            setModalState(
                                                () => isSaving = false);
                                          }
                                        },
                                  child: isSaving
                                      ? const CircularProgressIndicator(
                                          color: Colors.white)
                                      : const Text("Save Changes",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold)),
                                ))
                          ])));
            }));
  }

  void _showAdminProfileModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                              color: Color(0xFF2A3B5A), shape: BoxShape.circle),
                          child: Center(
                              child: Text(_getUserInitial(_adminName),
                                  style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(_adminName,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text("Admin",
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13))
                          ]))
                    ]),
                  ),
                  const SizedBox(height: 24),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.person_outline,
                          color: Colors.white70),
                      title: const Text("Personal Information",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
                      onTap: () {
                        Navigator.pop(context);
                        _showAdminPersonalInfoModal();
                      }),
                  const SizedBox(height: 16),
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading:
                          const Icon(Icons.logout, color: Color(0xFFEF4444)),
                      title: const Text("Sign out",
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 16,
                              fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.white38),
                      onTap: () async {
                        Navigator.pop(context);
                        await widget.onLogout();
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =====================================================================
  // 🚀 CREAR, EDITAR Y BORRAR CLIENTES (SOFT DELETE INCORPORADO)
  // =====================================================================
  void _showAddCustomerModal(
      {Function(String customerId, String name, double lat, double lng)?
          onCustomerCreated}) {
    TextEditingController firstNameCtrl = TextEditingController();
    TextEditingController lastNameCtrl = TextEditingController();
    TextEditingController phoneCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController addressCtrl = TextEditingController();

    List<dynamic> placePredictions = [];
    String address1 = '';
    double lat = 0.0;
    double lng = 0.0;
    String city = '';
    String state = '';
    String zipCode = '';
    String country = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                Future<void> searchPlaces(String query) async {
                  if (query.isEmpty) {
                    setModalState(() => placePredictions = []);
                    return;
                  }
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        setModalState(() => placePredictions =
                            List<dynamic>.from(data['predictions'] ?? []));
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Autocomplete: $e");
                  }
                }

                Future<void> getPlaceDetails(String placeId) async {
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        var location = data['result']['geometry']['location'];
                        var components = data['result']['address_components'] as List<dynamic>?;
                        
                        String pStreetNumber = '';
                        String pRoute = '';
                        String pCity = '';
                        String pState = '';
                        String pPostal = '';
                        String pCountry = '';
                        
                        if (components != null) {
                          for (var c in components) {
                            List<dynamic> types = c['types'] ?? [];
                            if (types.contains('street_number')) pStreetNumber = c['long_name'];
                            if (types.contains('route')) pRoute = c['long_name'];
                            if (types.contains('locality')) pCity = c['long_name'];
                            if (types.contains('administrative_area_level_1')) pState = c['short_name'];
                            if (types.contains('postal_code')) pPostal = c['long_name'];
                            if (types.contains('country')) pCountry = c['long_name'];
                          }
                        }

                        String pAddress1 = pStreetNumber.isNotEmpty ? "$pStreetNumber $pRoute".trim() : pRoute;

                        setModalState(() {
                          lat = location['lat'];
                          lng = location['lng'];
                          address1 = pAddress1;
                          city = pCity;
                          state = pState;
                          zipCode = pPostal;
                          country = pCountry;
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Details: $e");
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Add New Customer",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white60),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text("First Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(firstNameCtrl, "First Name"),
                              const SizedBox(height: 16),
                              const Text("Last Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(lastNameCtrl, "Last Name"),
                              const SizedBox(height: 16),
                              const Text("Phone Number",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(phoneCtrl, "Phone Number"),
                              const SizedBox(height: 16),
                              const Text("Email Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(emailCtrl, "Email Address"),
                              const SizedBox(height: 16),
                              const Text("Service Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(
                                  addressCtrl, "Start typing address...",
                                  isAddress: true, onChanged: (val) {
                                if (val.length > 3) {
                                  searchPlaces(val);
                                } else {
                                  setModalState(() => placePredictions = []);
                                }
                              }),
                              if (placePredictions.isNotEmpty)
                                Material(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: placePredictions
                                        .map<Widget>((p) => ListTile(
                                              title: Text(
                                                  p['description']?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13)),
                                              onTap: () async {
                                                String pId =
                                                    p['place_id']?.toString() ?? '';
                                                setModalState(() {
                                                  addressCtrl.text =
                                                      p['description']
                                                              ?.toString() ??
                                                          '';
                                                  placePredictions.clear();
                                                });
                                                await getPlaceDetails(pId);
                                              },
                                            ))
                                        .toList(),
                                  ),
                                ),
                              if (lat != 0.0) ...[
                                const SizedBox(height: 12),
                                const Row(children: [
                                  Icon(Icons.gps_fixed,
                                      color: Color(0xFF10B981), size: 14),
                                  SizedBox(width: 6),
                                  Text("Address Confirmed",
                                      style: TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ]),
                              ],
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D1B2A),
                          border: Border(
                            top: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (firstNameCtrl.text.trim().isNotEmpty &&
                                  lastNameCtrl.text.trim().isNotEmpty) {
                                try {
                                  Map<String, dynamic> payload = {
                                    'first_name': firstNameCtrl.text.trim(),
                                    'last_name': lastNameCtrl.text.trim(),
                                  };
                                  if (phoneCtrl.text.trim().isNotEmpty) payload['phone'] = phoneCtrl.text.trim();
                                  if (emailCtrl.text.trim().isNotEmpty) payload['email'] = emailCtrl.text.trim();
                                  if (addressCtrl.text.trim().isNotEmpty) {
                                    payload['address'] = addressCtrl.text.trim();
                                    payload['address1'] = address1.isNotEmpty ? address1 : addressCtrl.text.trim();
                                    if (city.isNotEmpty) payload['city'] = city;
                                    if (state.isNotEmpty) payload['state'] = state;
                                    if (zipCode.isNotEmpty) payload['zip_code'] = zipCode;
                                    if (country.isNotEmpty) payload['country'] = country;
                                  }
                                  if (lat != 0.0) payload['lat'] = lat;
                                  if (lng != 0.0) payload['lng'] = lng;

                                  final messenger = ScaffoldMessenger.of(context);
                                  var newDoc = await ApiService.instance
                                      .post('/customers', payload);
                                  if (onCustomerCreated != null) {
                                    onCustomerCreated(
                                        newDoc['id'].toString(),
                                        '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}',
                                        lat,
                                        lng);
                                  } else {
                                    _fetchCustomers();
                                  }
                                  Navigator.pop(context);
                                  messenger.showSnackBar(const SnackBar(
                                      content: Text(
                                          "Customer created successfully!",
                                          style: TextStyle(
                                              color: Colors.white)),
                                      backgroundColor: Color(0xFF10B981)));
                                } catch (e) {
                                  String errorMsg = e.toString().replaceAll('Exception: ', '');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                            content: Text(
                                                "Failed to create customer: $errorMsg",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            backgroundColor: const Color(0xFFEF4444)));
                                  }
                                }
                              }
                            },
                            child: const Text(
                              "Create Customer",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void _showEditCustomerDialog(dynamic arg1, [Map<String, dynamic>? arg2]) {
    Map<String, dynamic> customerData = (arg2 != null) ? arg2 : (arg1 is Map<String, dynamic> ? arg1 : {});
    String customerId = (customerData['id'] ?? arg1).toString();
    TextEditingController firstNameCtrl = TextEditingController(
        text: customerData['first_name'] ??
            customerData['name']?.split(' ').first ??
            '');
    TextEditingController lastNameCtrl = TextEditingController(
        text: customerData['last_name'] ??
            (customerData['name'] != null && customerData['name'].contains(' ')
                ? customerData['name'].split(' ').sublist(1).join(' ')
                : ''));
    TextEditingController phoneCtrl =
        TextEditingController(text: customerData['phone']);
    TextEditingController emailCtrl =
        TextEditingController(text: customerData['email']);
    TextEditingController addressCtrl = TextEditingController(
        text: customerData['address1'] ??
            (customerData['primary_address'] != null
                ? customerData['primary_address']['address1']
                : ''));

    List<dynamic> placePredictions = [];
    String address1 = addressCtrl.text;
    double lat = customerData['lat'] != null
        ? (customerData['lat'] as num).toDouble()
        : 0.0;
    double lng = customerData['lng'] != null
        ? (customerData['lng'] as num).toDouble()
        : 0.0;
    String city = customerData['city'] ?? '';
    String state = customerData['state'] ?? '';
    String zipCode = customerData['zip_code'] ?? '';
    String country = customerData['country'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.95,
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
                Future<void> searchPlaces(String query) async {
                  if (query.isEmpty) {
                    setModalState(() => placePredictions = []);
                    return;
                  }
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        setModalState(() => placePredictions =
                            List<dynamic>.from(data['predictions'] ?? []));
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Autocomplete: $e");
                  }
                }

                Future<void> getPlaceDetails(String placeId) async {
                  try {
                    if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                    final uri = Uri.parse(
                        "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                    final response = await http.get(uri);
                    if (response.statusCode == 200) {
                      final data = jsonDecode(response.body);
                      if (data['status'] == 'OK') {
                        var location = data['result']['geometry']['location'];
                        var components = data['result']['address_components'] as List<dynamic>?;
                        
                        String pStreetNumber = '';
                        String pRoute = '';
                        String pCity = '';
                        String pState = '';
                        String pPostal = '';
                        String pCountry = '';
                        
                        if (components != null) {
                          for (var c in components) {
                            List<dynamic> types = c['types'] ?? [];
                            if (types.contains('street_number')) pStreetNumber = c['long_name'];
                            if (types.contains('route')) pRoute = c['long_name'];
                            if (types.contains('locality')) pCity = c['long_name'];
                            if (types.contains('administrative_area_level_1')) pState = c['short_name'];
                            if (types.contains('postal_code')) pPostal = c['long_name'];
                            if (types.contains('country')) pCountry = c['long_name'];
                          }
                        }

                        String pAddress1 = pStreetNumber.isNotEmpty ? "$pStreetNumber $pRoute".trim() : pRoute;

                        setModalState(() {
                          lat = location['lat'];
                          lng = location['lng'];
                          address1 = pAddress1;
                          city = pCity;
                          state = pState;
                          zipCode = pPostal;
                          country = pCountry;
                        });
                      }
                    }
                  } catch (e) {
                    debugPrint("Error Details: $e");
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Edit Customer Info",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close,
                                  color: Colors.white60),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 12),
                              const Text("First Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(firstNameCtrl, "First Name"),
                              const SizedBox(height: 16),
                              const Text("Last Name",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(lastNameCtrl, "Last Name"),
                              const SizedBox(height: 16),
                              const Text("Phone Number",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(phoneCtrl, "Phone Number"),
                              const SizedBox(height: 16),
                              const Text("Email Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(emailCtrl, "Email Address"),
                              const SizedBox(height: 16),
                              const Text("Service Address",
                                  style: TextStyle(
                                      color: Colors.white60,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _buildSimpleTextField(
                                  addressCtrl, "Start typing address...",
                                  isAddress: true, onChanged: (val) {
                                if (val.length > 3) {
                                  searchPlaces(val);
                                } else {
                                  setModalState(() => placePredictions = []);
                                }
                              }),
                              if (placePredictions.isNotEmpty)
                                Material(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12)),
                                  clipBehavior: Clip.hardEdge,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: placePredictions
                                        .map<Widget>((p) => ListTile(
                                              title: Text(
                                                  p['description']?.toString() ??
                                                      '',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13)),
                                              onTap: () async {
                                                String pId =
                                                    p['place_id']?.toString() ?? '';
                                                setModalState(() {
                                                  addressCtrl.text =
                                                      p['description']
                                                              ?.toString() ??
                                                          '';
                                                  placePredictions.clear();
                                                });
                                                await getPlaceDetails(pId);
                                              },
                                            ))
                                        .toList(),
                                  ),
                                ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0D1B2A),
                          border: Border(
                            top: BorderSide(color: Colors.white10),
                          ),
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              if (firstNameCtrl.text.trim().isNotEmpty &&
                                  lastNameCtrl.text.trim().isNotEmpty) {
                                try {
                                  Map<String, dynamic> payload = {
                                    'first_name': firstNameCtrl.text.trim(),
                                    'last_name': lastNameCtrl.text.trim(),
                                  };
                                  if (phoneCtrl.text.trim().isNotEmpty) payload['phone'] = phoneCtrl.text.trim();
                                  if (emailCtrl.text.trim().isNotEmpty) payload['email'] = emailCtrl.text.trim();
                                  if (addressCtrl.text.trim().isNotEmpty) {
                                    payload['address'] = addressCtrl.text.trim();
                                    payload['address1'] = address1.isNotEmpty ? address1 : addressCtrl.text.trim();
                                    if (city.isNotEmpty) payload['city'] = city;
                                    if (state.isNotEmpty) payload['state'] = state;
                                    if (zipCode.isNotEmpty) payload['zip_code'] = zipCode;
                                    if (country.isNotEmpty) payload['country'] = country;
                                  }
                                  if (lat != 0.0) payload['lat'] = lat;
                                  if (lng != 0.0) payload['lng'] = lng;

                                  final messenger = ScaffoldMessenger.of(context);
                                  await ApiService.instance
                                      .put('/customers/$customerId', payload);
                                  Navigator.pop(context);
                                  Navigator.of(context).maybePop();
                                  _fetchCustomers();
                                  messenger.showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Customer updated successfully!",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                          backgroundColor: Color(0xFF10B981)));
                                } catch (e) {
                                  String errorMsg = e.toString().replaceAll('Exception: ', '');
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Failed to update customer: $errorMsg",
                                                style: const TextStyle(
                                                    color: Colors.white)),
                                            backgroundColor: const Color(0xFFEF4444)));
                                  }
                                }
                              }
                            },
                            child: const Text(
                              "Save Changes",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // 🚀 NUEVA FUNCIÓN: BORRADO SEGURO DE CLIENTE
  void _showDeleteCustomerDialog(String customerId, String customerName) {
    TextEditingController confirmCtrl = TextEditingController();
    bool isDeleting = false;

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
                  backgroundColor: const Color(0xFF1E293B),
                  title: const Text("Delete Customer",
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("You are about to delete $customerName.",
                          style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 12),
                      const Text(
                          "This will remove the customer from your directory, but their historical jobs and chats will be preserved for your records.",
                          style:
                              TextStyle(color: Colors.white60, fontSize: 13)),
                      const SizedBox(height: 24),
                      const Text("Type 'DELETE' to confirm:",
                          style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirmCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: "DELETE",
                          hintStyle: TextStyle(color: Colors.white24),
                          enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.white24)),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.redAccent)),
                        ),
                        onChanged: (val) =>
                            setDialogState(() {}), // Para refrescar el botón
                      )
                    ],
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text("Cancel",
                            style: TextStyle(color: Colors.white60))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent),
                      onPressed: (confirmCtrl.text == 'DELETE' && !isDeleting)
                          ? () async {
                              setDialogState(() => isDeleting = true);
                              try {
                                await ApiService.instance
                                    .delete('/customers/$customerId');
                                _fetchCustomers();
                                if (mounted) {
                                  Navigator.pop(
                                      ctx); // Cierra modal de confirmación
                                  Navigator.pop(
                                      context); // Cierra modal de detalles del customere
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Customer deleted from directory."),
                                          backgroundColor: Colors.green));
                                }
                              } catch (e) {
                                setDialogState(() => isDeleting = false);
                              }
                            }
                          : null,
                      child: isDeleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text("Delete Permanently",
                              style: TextStyle(color: Colors.white)),
                    )
                  ],
                )));
  }

  void _showJobHistoryModal(String customerId, String customerName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(24),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 24),
                  Text("$customerName's History",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: FutureBuilder<dynamic>(
                      future: ApiService.instance
                          .get('/admin/jobs?customer_id=$customerId'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        List<dynamic> jobsList = snapshot.data ?? [];
                        if (jobsList.isEmpty) {
                          return const Center(
                              child: Text("No jobs found for this customer.",
                                  style: TextStyle(color: Colors.white38)));
                        }

                        return ListView.builder(
                          itemCount: jobsList.length,
                          itemBuilder: (context, index) {
                            var job = jobsList[index] as Map<String, dynamic>;
                            DateTime date = job['scheduled_time'] != null
                                ? DateTime.parse(job['scheduled_time'])
                                : DateTime.now();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(16)),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF10B981)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(job['job_type'] ?? 'Standard',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold)),
                                        Text(
                                            DateFormat('MMM d, yyyy - hh:mm a')
                                                .format(date),
                                            style: const TextStyle(
                                                color: Colors.white60,
                                                fontSize: 12))
                                      ])),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCustomerDetailsModal(String id, Map<String, dynamic> customerData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(2))),
                      Align(
                          alignment: Alignment.centerRight,
                          child: GestureDetector(
                            onTap: () => _showDeleteCustomerDialog(
                                id,
                                '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'
                                        .trim()
                                        .isEmpty
                                    ? 'Customer'
                                    : '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'
                                        .trim()),
                            child: const Icon(Icons.person_remove,
                                color: Colors.redAccent),
                          ))
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              const Color(0xFF3B82F6).withOpacity(0.2),
                          child: const Icon(Icons.business,
                              color: Color(0xFF3B82F6), size: 28)),
                      const SizedBox(width: 16),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'
                                        .trim()
                                        .isEmpty
                                    ? 'No Name'
                                    : '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'
                                        .trim(),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold)),
                            const Text("Customer Profile",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 14))
                          ])),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildInfoField(
                      "Phone Number",
                      customerData['phone']?.isNotEmpty == true
                          ? customerData['phone']
                          : '-'),
                  const SizedBox(height: 12),
                  _buildInfoField(
                      "Email Address",
                      customerData['email']?.isNotEmpty == true
                          ? customerData['email']
                          : '-'),
                  const SizedBox(height: 12),
                  _buildInfoField(
                      "Primary Address",
                      customerData['address']?.isNotEmpty == true
                          ? customerData['address']
                          : '-'),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () =>
                                  _showEditCustomerDialog(id, customerData),
                              icon: const Icon(Icons.edit,
                                  color: Colors.white, size: 16),
                              label: const Text("Edit Info",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16)))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: ElevatedButton.icon(
                              onPressed: () => _showJobHistoryModal(
                                  id,
                                  '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'
                                      .trim()),
                              icon: const Icon(Icons.history,
                                  color: Colors.white, size: 16),
                              label: const Text("Job History",
                                  style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16)))),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- MOTOR MAESTRO DE CREACIÓN DE TRABAJOS ---
  void _showCreateJobModal() {
    Future<dynamic>? workersFuture = ApiService.instance.get('/admin/workers');
    Future<dynamic>? teamsFuture = ApiService.instance.get('/admin/teams');
    Future<dynamic>? customersFuture =
        ApiService.instance.get('/admin/customers');
    Future<dynamic>? itemsFuture = ApiService.instance.get('/items');

    TextEditingController jobTitleCtrl = TextEditingController();
    TextEditingController notesCtrl = TextEditingController();
    TextEditingController addressCtrl = TextEditingController();

    // Quick Add Item Controllers
    TextEditingController newItemNameCtrl = TextEditingController();
    TextEditingController newItemPriceCtrl = TextEditingController();
    TextEditingController newItemQtyCtrl = TextEditingController();

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedStartTime = TimeOfDay.now();
    TimeOfDay? selectedEndTime = TimeOfDay(
        hour: (TimeOfDay.now().hour + 2) % 24, minute: TimeOfDay.now().minute);

    String? selectedJobType = "Job";
    bool isRecurring = false;
    String recFrequency = 'weekly';
    TextEditingController recIntervalCtrl = TextEditingController(text: '1');
    List<int> recDaysOfWeek = [];
    String recEndType = 'never';
    TextEditingController recOccurrencesCtrl = TextEditingController();
    DateTime? recEndDate;
    bool recSkipWeekends = false;
    bool recAutoNotify = false;

    List<String> selectedWorkerIds = [];
    List<String> selectedTeamIds = [];

    String? selectedCustomerId;
    String? selectedCustomerName;
    
    List<dynamic> customerAddressesList = [];
    String? selectedAddressId;
    bool showNewAddressForm = false;
    bool saveToCustomerProfile = true;
    Map<String, dynamic>? newAddressData;

    // Items state
    List<Map<String, dynamic>> availableItems = [];
    List<Map<String, dynamic>> selectedItems = [];
    bool isAddingNewItem = false;

    String? selectedTeamLeaderId;
    List<dynamic> placePredictions = [];
    bool isSaving = false;

    String address1 = '';
    double latitude = 0.0;
    double longitude = 0.0;
    String city = '';
    String state = '';
    String postalCode = '';
    String country = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Material(
          color: const Color(0xFF0D1B2A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.90,
            child: StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
              Future<void> searchPlaces(String query) async {
                if (query.isEmpty) {
                  setModalState(() => placePredictions = []);
                  return;
                }
                try {
                  if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty)
                    return;
                  final uri = Uri.parse(
                      "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                  final response = await http.get(uri);
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'OK') {
                      setModalState(() => placePredictions =
                          List<dynamic>.from(data['predictions'] ?? []));
                    } else {
                      setModalState(() => placePredictions = [{'description': 'API Error: ${data['status']}'}]);
                    }
                  } else {
                    setModalState(() => placePredictions = [{'description': 'HTTP Error: ${response.statusCode}'}]);
                  }
                } catch (e) {
                  debugPrint("Cloud Function Error (Autocomplete): $e");
                  setModalState(() => placePredictions = [{'description': 'Exception: $e'}]);
                }
              }

              Future<void> getPlaceDetails(String placeId) async {
                try {
                  if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty)
                    return;
                  final uri = Uri.parse(
                      "https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                  final response = await http.get(uri);
                  if (response.statusCode == 200) {
                    final data = jsonDecode(response.body);
                    if (data['status'] == 'OK') {
                      var location = data['result']['geometry']['location'];
                      var components = data['result']['address_components'] as List<dynamic>?;
                      
                      String pStreetNumber = '';
                      String pRoute = '';
                      String pCity = '';
                      String pState = '';
                      String pPostal = '';
                      String pCountry = '';
                      
                      if (components != null) {
                        for (var c in components) {
                          List<dynamic> types = c['types'] ?? [];
                          if (types.contains('street_number')) pStreetNumber = c['long_name'];
                          if (types.contains('route')) pRoute = c['long_name'];
                          if (types.contains('locality')) pCity = c['long_name'];
                          if (types.contains('administrative_area_level_1')) pState = c['short_name'];
                          if (types.contains('postal_code')) pPostal = c['long_name'];
                          if (types.contains('country')) pCountry = c['long_name'];
                        }
                      }

                      String pAddress1 = pStreetNumber.isNotEmpty ? "$pStreetNumber $pRoute".trim() : pRoute;

                      setModalState(() {
                        latitude = location['lat'];
                        longitude = location['lng'];
                        address1 = pAddress1;
                        city = pCity;
                        state = pState;
                        postalCode = pPostal;
                        country = pCountry;
                      });
                    }
                  }
                } catch (e) {
                  debugPrint("Cloud Function Error (Details): $e");
                }
              }

              void showAssignmentDialog(
                  List<dynamic> workers, List<dynamic> teams) {
                showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return StatefulBuilder(
                          builder: (context, setDialogState) {
                        return AlertDialog(
                          backgroundColor: const Color(0xFF1E293B),
                          title: const Text("Assign Teams & Staff",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold)),
                          content: SizedBox(
                            width: double.maxFinite,
                            height: 400,
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (teams.isNotEmpty) ...[
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text("Teams",
                                          style: TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ),
                                    ...teams.map((doc) {
                                      var data = doc as Map<String, dynamic>;
                                      String docId = data['id'].toString();
                                      bool isSelected =
                                          selectedTeamIds.contains(docId);
                                      return CheckboxListTile(
                                        title: Text(data['name'] ?? 'Team',
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        subtitle: data['member_count'] != null
                                            ? Text(
                                                "${data['member_count']} members",
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12))
                                            : null,
                                        value: isSelected,
                                        activeColor: const Color(0xFF3B82F6),
                                        checkColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white60),
                                        onChanged: (bool? val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedTeamIds.add(docId);
                                            } else {
                                              selectedTeamIds.remove(docId);
                                            }
                                          });
                                          setModalState(() {});
                                        },
                                      );
                                    }).toList(),
                                    const Divider(color: Colors.white10),
                                  ],
                                  if (workers.isNotEmpty) ...[
                                    const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 8.0),
                                      child: Text("Individual Staff",
                                          style: TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14)),
                                    ),
                                    ...workers.map((doc) {
                                      var data = doc as Map<String, dynamic>;
                                      String docId = data['id'].toString();
                                      bool isSelected =
                                          selectedWorkerIds.contains(docId);
                                      return CheckboxListTile(
                                        title: Text(
                                            data['display_name'] ??
                                                data['name'] ??
                                                'Worker',
                                            style: const TextStyle(
                                                color: Colors.white)),
                                        value: isSelected,
                                        activeColor: const Color(0xFF3B82F6),
                                        checkColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white60),
                                        onChanged: (bool? val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedWorkerIds.add(docId);
                                            } else {
                                              selectedWorkerIds.remove(docId);
                                              if (selectedTeamLeaderId ==
                                                  docId) {
                                                selectedTeamLeaderId = null;
                                              }
                                            }
                                          });
                                          setModalState(() {});
                                        },
                                      );
                                    }).toList(),
                                  ]
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6)),
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text("Done",
                                  style: TextStyle(color: Colors.white)),
                            )
                          ],
                        );
                      });
                    });
              }

              return Padding(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Column(
                  children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 8),
                        child: Center(
                            child: Container(
                                width: 40,
                                height: 4,
                                decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(2))))),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Assign Job",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold)),
                              IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.white60),
                                  onPressed: () => Navigator.pop(context))
                            ])),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Job Title",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            _buildSimpleTextField(
                                jobTitleCtrl, "Enter job title..."),
                            const SizedBox(height: 16),
                            const Text("Select Customer",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            FutureBuilder<dynamic>(
                              future: customersFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    height: 41,
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF3B82F6)),
                                      ),
                                    ),
                                  );
                                }

                                var customers = snapshot.data is Map &&
                                        snapshot.data.containsKey('data')
                                    ? snapshot.data['data']
                                    : (snapshot.data is List
                                        ? snapshot.data
                                        : []);

                                List<dynamic> customersList =
                                    List.from(customers);

                                List<DropdownMenuItem<String>> customerItems =
                                    customersList.map((customer) {
                                  return DropdownMenuItem<String>(
                                      value: customer['id'].toString(),
                                      child: Text(
                                          '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'
                                                  .trim()
                                                  .isEmpty
                                              ? 'Unknown'
                                              : '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'
                                                  .trim(),
                                          style: const TextStyle(
                                              color: Colors.white)));
                                }).toList();

                                return Container(
                                  height: 41,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E293B),
                                      value: selectedCustomerId,
                                      hint: const Text("Choose a customer...",
                                          style:
                                              TextStyle(color: Colors.white38)),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Color(0xFF3B82F6)),
                                      items: customerItems,
                                      onChanged: (val) {
                                        if (val != null) {
                                          var selectedDoc =
                                              customersList.firstWhere((d) =>
                                                  d['id'].toString() == val);

                                          setModalState(() {
                                            selectedCustomerId = val;
                                            selectedCustomerName =
                                                '${selectedDoc['first_name'] ?? ''} ${selectedDoc['last_name'] ?? ''}'
                                                    .trim();
                                            customerAddressesList = selectedDoc['addresses'] != null
                                                ? List.from(selectedDoc['addresses'])
                                                : [];
                                            selectedAddressId = null;
                                            showNewAddressForm = false;
                                            newAddressData = null;
                                            addressCtrl.clear();
                                            latitude = 0.0;
                                            longitude = 0.0;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Service Address",
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                if (selectedCustomerId != null && !showNewAddressForm)
                                  TextButton.icon(
                                    onPressed: () {
                                      setModalState(() {
                                        showNewAddressForm = true;
                                        selectedAddressId = null;
                                        newAddressData = null;
                                        addressCtrl.clear();
                                        latitude = 0.0;
                                        longitude = 0.0;
                                      });
                                    },
                                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF3B82F6)),
                                    label: const Text("Quick Add Location",
                                        style: TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Addresses List
                            if (selectedCustomerId == null)
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: const Text("Please select a customer first.", style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                              )
                            else if (!showNewAddressForm) ...[
                              if (customerAddressesList.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(vertical: 20),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: const Text("No stored addresses found.", style: TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
                                )
                              else
                                ...customerAddressesList.map((addr) {
                                  bool isSelected = selectedAddressId == addr['id'].toString();
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        selectedAddressId = addr['id'].toString();
                                        showNewAddressForm = false;
                                        newAddressData = null;
                                        addressCtrl.text = addr['address1'] ?? '';
                                        latitude = double.tryParse(addr['latitude']?.toString() ?? '0') ?? 0.0;
                                        longitude = double.tryParse(addr['longitude']?.toString() ?? '0') ?? 0.0;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF3B82F6).withOpacity(0.2) : const Color(0xFF1E293B),
                                        border: Border.all(color: isSelected ? const Color(0xFF3B82F6) : Colors.white10),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                            color: isSelected ? const Color(0xFF3B82F6) : Colors.white60,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              addr['address1'] ?? 'Unknown Address',
                                              style: const TextStyle(color: Colors.white, fontSize: 13),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ],

                            // New Address Form
                            if (selectedCustomerId != null && showNewAddressForm) ...[
                              Container(
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10)),
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 41,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Center(
                                          child: TextField(
                                            controller: addressCtrl,
                                            onChanged: (val) {
                                              if (val.length > 3) {
                                                searchPlaces(val);
                                              } else {
                                                setModalState(() => placePredictions = []);
                                              }
                                            },
                                            textAlignVertical: TextAlignVertical.center,
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                            decoration: const InputDecoration(
                                                hintText: "Start typing address...",
                                                hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                                                prefixIconConstraints: BoxConstraints(minWidth: 36, minHeight: 0),
                                                prefixIcon: Icon(Icons.location_on, color: Color(0xFF3B82F6), size: 20),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding: EdgeInsets.zero),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (placePredictions.isNotEmpty)
                                      Material(
                                        color: const Color(0xFF0D1B2A),
                                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                                        clipBehavior: Clip.hardEdge,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: placePredictions
                                              .map<Widget>((p) => ListTile(
                                                    title: Text(p['description']?.toString() ?? '',
                                                        style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                    onTap: () async {
                                                      String pId = p['place_id']?.toString() ?? '';
                                                      setModalState(() {
                                                        addressCtrl.text = p['description']?.toString() ?? '';
                                                        placePredictions.clear();
                                                      });
                                                      await getPlaceDetails(pId);
                                                      
                                                      setModalState(() {
                                                          newAddressData = {
                                                            'address1': address1.isNotEmpty ? address1 : addressCtrl.text,
                                                            'city': city,
                                                            'state': state,
                                                            'zip_code': postalCode,
                                                            'country': country,
                                                            'latitude': latitude,
                                                            'longitude': longitude,
                                                          };
                                                      });
                                                    },
                                                  ))
                                              .toList(),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                              if (latitude != 0.0) ...[
                                const SizedBox(height: 8),
                                const Row(children: [
                                  Icon(Icons.gps_fixed, color: Color(0xFF10B981), size: 14),
                                  SizedBox(width: 6),
                                  Text("Address Confirmed",
                                      style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
                                ]),
                                if (selectedCustomerId != null)
                                  Row(
                                    children: [
                                      Checkbox(
                                        value: saveToCustomerProfile,
                                        activeColor: const Color(0xFF3B82F6),
                                        checkColor: Colors.white,
                                        side: const BorderSide(color: Colors.white60),
                                        onChanged: (val) {
                                          setModalState(() => saveToCustomerProfile = val ?? true);
                                        },
                                      ),
                                      const Text("Save to customer profile", style: TextStyle(color: Colors.white60, fontSize: 13)),
                                    ],
                                  ),
                              ],
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    setModalState(() {
                                      showNewAddressForm = false;
                                      newAddressData = null;
                                      selectedAddressId = null;
                                      addressCtrl.clear();
                                      latitude = 0.0;
                                      longitude = 0.0;
                                    });
                                  },
                                  child: const Text("Cancel & Back to List", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            const Text("Job Type",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                              height: 41,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10)),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: const Color(0xFF1E293B),
                                  value: selectedJobType,
                                  hint: const Text("Select or add new...",
                                      style: TextStyle(color: Colors.white38)),
                                  icon: const Icon(Icons.keyboard_arrow_down,
                                      color: Color(0xFF3B82F6)),
                                  items: _jobTypes
                                      .map((type) => DropdownMenuItem(
                                          value: type,
                                          child: Text(type,
                                              style: const TextStyle(
                                                  color: Colors.white))))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(
                                          () => selectedJobType = val);
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Items",
                                    style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold)),
                                if (!isAddingNewItem)
                                  GestureDetector(
                                    onTap: () => setModalState(() {
                                      isAddingNewItem = true;
                                      newItemPriceCtrl.text = "0";
                                    }),
                                    child: const Row(children: [
                                      Icon(Icons.add_circle,
                                          color: Color(0xFF3B82F6), size: 16),
                                      SizedBox(width: 4),
                                      Text("Add quick item",
                                          style: TextStyle(
                                              color: Color(0xFF3B82F6),
                                              fontSize: 13))
                                    ]),
                                  )
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (isAddingNewItem)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: _buildSimpleTextField(
                                              newItemNameCtrl, "Item Name"),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          flex: 1,
                                          child: _buildSimpleTextField(
                                              newItemPriceCtrl, "Price",
                                              isAddress: false),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () => setModalState(
                                              () => isAddingNewItem = false),
                                          child: const Text("Cancel",
                                              style: TextStyle(
                                                  color: Colors.white60)),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFF3B82F6)),
                                          onPressed: () {
                                            if (newItemNameCtrl.text.isEmpty)
                                              return;
                                            setModalState(() {
                                              selectedItems.add({
                                                'description':
                                                    newItemNameCtrl.text.trim(),
                                                'price': double.tryParse(
                                                        newItemPriceCtrl
                                                            .text) ??
                                                    0.0,
                                                'quantity': 1,
                                                'save_to_items': false,
                                              });
                                              isAddingNewItem = false;
                                              newItemNameCtrl.clear();
                                              newItemPriceCtrl.clear();
                                            });
                                          },
                                          child: const Text("Add",
                                              style: TextStyle(
                                                  color: Colors.white)),
                                        )
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            FutureBuilder<dynamic>(
                              future: itemsFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData)
                                  return const SizedBox.shrink();
                                var itemsList = [];
                                if (snapshot.data is Map &&
                                    snapshot.data['data'] != null) {
                                  itemsList = snapshot.data['data'];
                                } else if (snapshot.data is List) {
                                  itemsList = snapshot.data;
                                }
                                return Container(
                                  height: 41,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E293B),
                                      hint: const Text("Select item...",
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 13)),
                                      icon: const Icon(
                                          Icons.keyboard_arrow_down,
                                          color: Color(0xFF3B82F6)),
                                      items: itemsList
                                          .map<DropdownMenuItem<String>>(
                                              (item) {
                                        double price = double.tryParse(
                                                item['price']?.toString() ??
                                                    "0") ??
                                            0.0;
                                        return DropdownMenuItem<String>(
                                          value: item['id'].toString(),
                                          child: Text(
                                              "${item['name'] ?? ''} - \$${price.toStringAsFixed(2)}",
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          var selected = itemsList.firstWhere(
                                              (i) => i['id'].toString() == val);
                                          setModalState(() {
                                            selectedItems.add({
                                              'item_id': selected['id'],
                                              'description': selected['name'],
                                              'price': selected['price'] ?? 0.0,
                                              'quantity': 1,
                                            });
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (selectedItems.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Column(
                                  children: selectedItems
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    int idx = entry.key;
                                    var item = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                              child: Text(
                                                  item['description'] ?? '',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13))),
                                          Text(
                                              "\$${item['price']} x ${item['quantity']}",
                                              style: const TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13)),
                                          const SizedBox(width: 12),
                                          GestureDetector(
                                            onTap: () => setModalState(() =>
                                                selectedItems.removeAt(idx)),
                                            child: const Icon(Icons.close,
                                                color: Colors.redAccent,
                                                size: 18),
                                          )
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Job Date",
                                          style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          DateTime? pickedDate = await showDatePicker(
                                              context: context,
                                              initialDate: selectedDate,
                                              firstDate: DateTime.now(),
                                              lastDate: DateTime(2030),
                                              builder: (context, child) => Theme(
                                                  data: ThemeData.dark().copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .dark(
                                                              primary: Color(
                                                                  0xFF3B82F6))),
                                                  child: child!));
                                          if (pickedDate != null) {
                                            setModalState(() =>
                                                selectedDate = pickedDate);
                                          }
                                        },
                                        child: Container(
                                            height: 41,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Row(children: [
                                              const Icon(Icons.calendar_month,
                                                  color: Color(0xFF3B82F6),
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                      DateFormat('MMM d')
                                                          .format(selectedDate),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13))),
                                            ])),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("Start Time",
                                          style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          TimeOfDay? pickedTime = await showTimePicker(
                                              context: context,
                                              initialTime: selectedStartTime,
                                              builder: (context, child) => Theme(
                                                  data: ThemeData.dark().copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .dark(
                                                              primary: Color(
                                                                  0xFF3B82F6))),
                                                  child: child!));
                                          if (pickedTime != null) {
                                            setModalState(() {
                                              selectedStartTime = pickedTime;
                                              selectedEndTime = TimeOfDay(
                                                  hour: (pickedTime.hour + 2) %
                                                      24,
                                                  minute: pickedTime.minute);
                                            });
                                          }
                                        },
                                        child: Container(
                                            height: 41,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Row(children: [
                                              const Icon(Icons.access_time,
                                                  color: Color(0xFF3B82F6),
                                                  size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                      selectedStartTime
                                                          .format(context),
                                                      style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 13))),
                                            ])),
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text("End Time",
                                          style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      GestureDetector(
                                        onTap: () async {
                                          TimeOfDay? pickedTime = await showTimePicker(
                                              context: context,
                                              initialTime: selectedEndTime ??
                                                  selectedStartTime,
                                              builder: (context, child) => Theme(
                                                  data: ThemeData.dark().copyWith(
                                                      colorScheme:
                                                          const ColorScheme
                                                              .dark(
                                                              primary: Color(
                                                                  0xFF3B82F6))),
                                                  child: child!));
                                          if (pickedTime != null) {
                                            setModalState(() =>
                                                selectedEndTime = pickedTime);
                                          }
                                        },
                                        child: Container(
                                            height: 41,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Row(children: [
                                              const Icon(Icons.access_time,
                                                  color: Colors.grey, size: 20),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                  child: Text(
                                                      selectedEndTime?.format(
                                                              context) ??
                                                          "--:--",
                                                      style: TextStyle(
                                                          color:
                                                              selectedEndTime !=
                                                                      null
                                                                  ? Colors.white
                                                                  : Colors
                                                                      .white38,
                                                          fontSize: 13))),
                                            ])),
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const SizedBox(height: 20),
                            const Text("Assign Team",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            FutureBuilder<List<dynamic>>(
                              future: Future.wait([
                                workersFuture ?? Future.value([]),
                                teamsFuture ?? Future.value([])
                              ]),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                var workersResponse = snapshot.data![0];
                                var teamsResponse = snapshot.data![1];
                                var workers = workersResponse is Map &&
                                        workersResponse.containsKey('data')
                                    ? workersResponse['data']
                                    : (workersResponse is List
                                        ? workersResponse
                                        : []);
                                var teams = teamsResponse is Map &&
                                        teamsResponse.containsKey('data')
                                    ? teamsResponse['data']
                                    : (teamsResponse is List
                                        ? teamsResponse
                                        : []);

                                int totalSelections = selectedWorkerIds.length +
                                    selectedTeamIds.length;
                                String selectionText =
                                    "Tap to assign staff & teams...";
                                if (totalSelections > 0) {
                                  List<String> parts = [];
                                  if (selectedTeamIds.isNotEmpty) {
                                    parts.add(
                                        "${selectedTeamIds.length} team(s)");
                                  }
                                  if (selectedWorkerIds.isNotEmpty) {
                                    parts.add(
                                        "${selectedWorkerIds.length} staff member(s)");
                                  }
                                  selectionText =
                                      "${parts.join(' & ')} selected";
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    InkWell(
                                        onTap: () => showAssignmentDialog(
                                            workers, teams),
                                        child: Container(
                                            height: 41,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFF1E293B),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                border: Border.all(
                                                    color: Colors.white10)),
                                            child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(selectionText,
                                                      style: TextStyle(
                                                          color:
                                                              totalSelections == 0
                                                                  ? Colors
                                                                      .white38
                                                                  : Colors
                                                                      .white,
                                                          fontSize: 13)),
                                                  const Icon(Icons.group_add,
                                                      color: Color(0xFF3B82F6))
                                                ]))),
                                    if (selectedWorkerIds.length > 1) ...[
                                      const SizedBox(height: 16),
                                      const Text("Select Team Leader",
                                          style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 8),
                                      Container(
                                        height: 41,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            border: Border.all(
                                                color: const Color(0xFFF59E0B)
                                                    .withOpacity(0.5))),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            isExpanded: true,
                                            dropdownColor:
                                                const Color(0xFF1E293B),
                                            value: selectedTeamLeaderId,
                                            hint: const Text("Choose leader...",
                                                style: TextStyle(
                                                    color: Colors.white38,
                                                    fontSize: 13)),
                                            icon: const Icon(Icons.star,
                                                color: Color(0xFFF59E0B)),
                                            items: workers
                                                .where((w) =>
                                                    selectedWorkerIds.contains(
                                                        w['id'].toString()))
                                                .map<DropdownMenuItem<String>>(
                                                    (doc) {
                                              var data =
                                                  doc as Map<String, dynamic>;
                                              return DropdownMenuItem<String>(
                                                  value: data['id'].toString(),
                                                  child: Text(
                                                      "${data['display_name']} (Leader)",
                                                      style: const TextStyle(
                                                          color:
                                                              Color(0xFFF59E0B),
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 13)));
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setModalState(() =>
                                                    selectedTeamLeaderId = val);
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ]
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 20),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text("Make this a recurring series",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                              value: isRecurring,
                              activeColor: const Color(0xFF3B82F6),
                              onChanged: (val) {
                                setModalState(() => isRecurring = val);
                              },
                            ),
                            if (isRecurring) ...[
                              Material(
                                  color: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side:
                                        const BorderSide(color: Colors.white10),
                                  ),
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    const Text("Repeats",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    const SizedBox(height: 4),
                                                    Container(
                                                        height: 41,
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 12),
                                                        decoration: BoxDecoration(
                                                            color: const Color(
                                                                0xFF0F172A),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8)),
                                                        child:
                                                            DropdownButtonHideUnderline(
                                                                child:
                                                                    DropdownButton<
                                                                        String>(
                                                          isExpanded: true,
                                                          dropdownColor:
                                                              const Color(
                                                                  0xFF0F172A),
                                                          value: recFrequency,
                                                          items: [
                                                            'daily',
                                                            'weekly',
                                                            'monthly',
                                                            'yearly'
                                                          ]
                                                              .map((f) => DropdownMenuItem(
                                                                  value: f,
                                                                  child: Text(
                                                                      f[0].toUpperCase() +
                                                                          f.substring(
                                                                              1),
                                                                      style: const TextStyle(
                                                                          color: Colors
                                                                              .white,
                                                                          fontSize:
                                                                              13))))
                                                              .toList(),
                                                          onChanged: (val) {
                                                            if (val != null)
                                                              setModalState(() =>
                                                                  recFrequency =
                                                                      val);
                                                          },
                                                        )))
                                                  ])),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                  child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                    const Text("Every",
                                                        style: TextStyle(
                                                            color:
                                                                Colors.white60,
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                    const SizedBox(height: 4),
                                                    Row(children: [
                                                      Expanded(
                                                          child: Container(
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF0F172A),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          8)),
                                                              child: TextField(
                                                                  controller:
                                                                      recIntervalCtrl,
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12),
                                                                  decoration: const InputDecoration(
                                                                      isDense:
                                                                          true,
                                                                      border: InputBorder
                                                                          .none,
                                                                      contentPadding: EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              12,
                                                                          vertical:
                                                                              8))))),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                          recFrequency ==
                                                                  'daily'
                                                              ? 'day(s)'
                                                              : recFrequency ==
                                                                      'weekly'
                                                                  ? 'week(s)'
                                                                  : recFrequency ==
                                                                          'monthly'
                                                                      ? 'month(s)'
                                                                      : 'year(s)',
                                                          style:
                                                              const TextStyle(
                                                                  color: Colors
                                                                      .white60,
                                                                  fontSize: 13))
                                                    ])
                                                  ]))
                                            ]),
                                            if (recFrequency == 'weekly') ...[
                                              const SizedBox(height: 16),
                                              const Text("On these days",
                                                  style: TextStyle(
                                                      color: Colors.white60,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    {'label': 'S', 'id': 0},
                                                    {'label': 'M', 'id': 1},
                                                    {'label': 'T', 'id': 2},
                                                    {'label': 'W', 'id': 3},
                                                    {'label': 'T', 'id': 4},
                                                    {'label': 'F', 'id': 5},
                                                    {'label': 'S', 'id': 6},
                                                  ].map((dayInfo) {
                                                    int dayId =
                                                        dayInfo['id'] as int;
                                                    String label =
                                                        dayInfo['label']
                                                            as String;
                                                    bool isSelected =
                                                        recDaysOfWeek
                                                            .contains(dayId);
                                                    return GestureDetector(
                                                        onTap: () {
                                                          setModalState(() {
                                                            if (isSelected) {
                                                              recDaysOfWeek
                                                                  .remove(
                                                                      dayId);
                                                            } else {
                                                              recDaysOfWeek
                                                                  .add(dayId);
                                                            }
                                                          });
                                                        },
                                                        child: Container(
                                                          width: 32,
                                                          height: 32,
                                                          alignment:
                                                              Alignment.center,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: isSelected
                                                                ? const Color(
                                                                    0xFF3B82F6)
                                                                : const Color(
                                                                    0xFF0F172A),
                                                            shape:
                                                                BoxShape.circle,
                                                          ),
                                                          child: Text(label,
                                                              style: TextStyle(
                                                                  color: isSelected
                                                                      ? Colors
                                                                          .white
                                                                      : Colors
                                                                          .white60,
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold)),
                                                        ));
                                                  }).toList())
                                            ],
                                            const SizedBox(height: 16),
                                            const Divider(
                                                color: Colors.white10),
                                            const SizedBox(height: 8),
                                            const Text("End Condition",
                                                style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 8),
                                            Theme(
                                                data: Theme.of(context)
                                                    .copyWith(
                                                        unselectedWidgetColor:
                                                            Colors.white38),
                                                child: Column(
                                                  children: [
                                                    RadioListTile<String>(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: const Text(
                                                            "Never (Runs forever)",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13)),
                                                        value: 'never',
                                                        groupValue: recEndType,
                                                        activeColor:
                                                            const Color(
                                                                0xFF3B82F6),
                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setModalState(() =>
                                                                recEndType =
                                                                    val);
                                                        }),
                                                    RadioListTile<String>(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Row(children: [
                                                          const Text("After",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      13)),
                                                          const SizedBox(
                                                              width: 8),
                                                          Container(
                                                              width: 60,
                                                              height: 32,
                                                              decoration: BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF0F172A),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          6)),
                                                              child: TextField(
                                                                  controller:
                                                                      recOccurrencesCtrl,
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          12),
                                                                  onTap: () =>
                                                                      setModalState(() =>
                                                                          recEndType =
                                                                              'occurrences'),
                                                                  decoration: const InputDecoration(
                                                                      isDense:
                                                                          true,
                                                                      border: InputBorder
                                                                          .none,
                                                                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)))),
                                                          const SizedBox(
                                                              width: 8),
                                                          const Text(
                                                              "occurrences",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      13)),
                                                        ]),
                                                        value: 'occurrences',
                                                        groupValue: recEndType,
                                                        activeColor:
                                                            const Color(
                                                                0xFF3B82F6),
                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setModalState(() =>
                                                                recEndType =
                                                                    val);
                                                        }),
                                                    RadioListTile<String>(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: Row(children: [
                                                          const Text("On date",
                                                              style: TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      13)),
                                                          const SizedBox(
                                                              width: 8),
                                                          Expanded(
                                                              child:
                                                                  GestureDetector(
                                                                      onTap:
                                                                          () async {
                                                                        setModalState(() =>
                                                                            recEndType =
                                                                                'date');
                                                                        DateTime?
                                                                            picked =
                                                                            await showDatePicker(
                                                                          context:
                                                                              context,
                                                                          initialDate:
                                                                              recEndDate ?? DateTime.now(),
                                                                          firstDate:
                                                                              DateTime.now(),
                                                                          lastDate:
                                                                              DateTime(2100),
                                                                          builder:
                                                                              (context, child) {
                                                                            return Theme(
                                                                              data: ThemeData.dark(),
                                                                              child: child!,
                                                                            );
                                                                          },
                                                                        );
                                                                        if (picked !=
                                                                            null) {
                                                                          setModalState(() =>
                                                                              recEndDate = picked);
                                                                        }
                                                                      },
                                                                      child: Container(
                                                                          height:
                                                                              32,
                                                                          alignment: Alignment
                                                                              .centerLeft,
                                                                          padding: const EdgeInsets
                                                                              .symmetric(
                                                                              horizontal:
                                                                                  12),
                                                                          decoration: BoxDecoration(
                                                                              color: const Color(
                                                                                  0xFF0F172A),
                                                                              borderRadius: BorderRadius.circular(
                                                                                  6)),
                                                                          child: Text(
                                                                              recEndDate != null ? "${recEndDate!.month.toString().padLeft(2, '0')}/${recEndDate!.day.toString().padLeft(2, '0')}/${recEndDate!.year.toString()}" : 'mm/dd/yyyy',
                                                                              style: TextStyle(color: recEndDate != null ? Colors.white : Colors.white38, fontSize: 12)))))
                                                        ]),
                                                        value: 'date',
                                                        groupValue: recEndType,
                                                        activeColor:
                                                            const Color(
                                                                0xFF3B82F6),
                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setModalState(() =>
                                                                recEndType =
                                                                    val);
                                                        }),
                                                  ],
                                                )),
                                            const SizedBox(height: 8),
                                            const Divider(
                                                color: Colors.white10),
                                            Theme(
                                                data: Theme.of(context)
                                                    .copyWith(
                                                        unselectedWidgetColor:
                                                            Colors.white38),
                                                child: Column(
                                                  children: [
                                                    CheckboxListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: const Text(
                                                            "Skip weekends (M-F only)",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13)),
                                                        value: recSkipWeekends,
                                                        activeColor:
                                                            const Color(
                                                                0xFF3B82F6),
                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setModalState(() =>
                                                                recSkipWeekends =
                                                                    val);
                                                        }),
                                                    CheckboxListTile(
                                                        contentPadding:
                                                            EdgeInsets.zero,
                                                        title: const Text(
                                                            "Auto-notify customer when new jobs generate",
                                                            style: TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13)),
                                                        value: recAutoNotify,
                                                        activeColor:
                                                            const Color(
                                                                0xFF3B82F6),
                                                        onChanged: (val) {
                                                          if (val != null)
                                                            setModalState(() =>
                                                                recAutoNotify =
                                                                    val);
                                                        }),
                                                  ],
                                                ))
                                          ])))
                            ],
                            const SizedBox(height: 20),
                            const Text("Special Instructions",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white10)),
                                child: TextField(
                                    controller: notesCtrl,
                                    maxLines: 3,
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 13),
                                    decoration: const InputDecoration(
                                        hintText: "Enter entry codes...",
                                        hintStyle:
                                            TextStyle(color: Colors.white38),
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.all(16)))),
                            const SizedBox(height: 40),
                            SizedBox(
                              width: double.infinity,
                              height: 55,
                              child: ElevatedButton(
                                onPressed: isSaving
                                    ? null
                                    : () async {
                                        void _showErr(String msg) {
                                          showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF1E293B),
                                                      title: const Text(
                                                          "Validation Error",
                                                          style: TextStyle(
                                                              color: Colors
                                                                  .white)),
                                                      content: Text(msg,
                                                          style: const TextStyle(
                                                              color: Colors
                                                                  .white70)),
                                                      actions: [
                                                        TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                    ctx),
                                                            child: const Text(
                                                                "OK",
                                                                style: TextStyle(
                                                                    color: Color(
                                                                        0xFF3B82F6))))
                                                      ]));
                                        }

                                        if (selectedCustomerId == null ||
                                            addressCtrl.text.isEmpty) {
                                          _showErr(
                                              "Customer and Address are required.");
                                          return;
                                        }
                                        if (isRecurring &&
                                            recFrequency == 'weekly' &&
                                            recDaysOfWeek.isEmpty) {
                                          _showErr(
                                              "Select at least one day for weekly recurrence.");
                                          return;
                                        }
                                        if (selectedWorkerIds.length > 1 &&
                                            selectedTeamLeaderId == null) {
                                          _showErr(
                                              "Please select a Team Leader from the assigned workers.");
                                          return;
                                        }

                                        setModalState(() => isSaving = true);
                                        try {
                                          String startDateStr =
                                              DateFormat('yyyy-MM-dd')
                                                  .format(selectedDate);
                                          String startTimeStr =
                                              '${selectedStartTime.hour.toString().padLeft(2, '0')}:${selectedStartTime.minute.toString().padLeft(2, '0')}:00';
                                          String? endDateStr;
                                          String? endTimeStr;
                                          if (selectedEndTime != null) {
                                            endDateStr = startDateStr;
                                            endTimeStr =
                                                '${selectedEndTime!.hour.toString().padLeft(2, '0')}:${selectedEndTime!.minute.toString().padLeft(2, '0')}:00';
                                          }

                                          Map<String, dynamic> payload = {
                                            'title': jobTitleCtrl.text.trim(),
                                            'customer_id': selectedCustomerId,
                                            'customer_name': selectedCustomerName,
                                            'address': addressCtrl.text.trim(),
                                            'latitude': latitude,
                                            'longitude': longitude,
                                            'job_type': selectedJobType ?? 'Standard',
                                            'items': selectedItems,
                                            'is_recurring': isRecurring,
                                            'recurring_pattern': isRecurring
                                                ? {
                                                    'frequency': recFrequency,
                                                    'interval': int.tryParse(recIntervalCtrl.text) ?? 1,
                                                    'days_of_week': recFrequency == 'weekly' ? recDaysOfWeek : [],
                                                    'end_type': recEndType == 'occurrences'
                                                        ? 'after'
                                                        : (recEndType == 'date' ? 'on_date' : recEndType),
                                                    'end_date': recEndType == 'date' && recEndDate != null
                                                        ? "${recEndDate!.year.toString().padLeft(4, '0')}-${recEndDate!.month.toString().padLeft(2, '0')}-${recEndDate!.day.toString().padLeft(2, '0')}"
                                                        : null,
                                                    'end_after_occurrences': recEndType == 'occurrences'
                                                        ? int.tryParse(recOccurrencesCtrl.text)
                                                        : null,
                                                    'skip_weekends': recSkipWeekends,
                                                    'auto_notify': recAutoNotify,
                                                  }
                                                : null,
                                            'start_date': startDateStr,
                                            'start_time': startTimeStr,
                                            'end_date': endDateStr,
                                            'end_time': endTimeStr,
                                            'assigned_workers': selectedWorkerIds,
                                            'assigned_teams': selectedTeamIds,
                                            'team_leader_id': selectedWorkerIds.length == 1
                                                ? selectedWorkerIds[0]
                                                : selectedTeamLeaderId,
                                            'notes': notesCtrl.text.trim(),
                                            'status': 'assigned',
                                            'created_at': DateTime.now().toIso8601String(),
                                          };

                                          if (selectedAddressId != null) {
                                            payload['address_id'] = selectedAddressId;
                                          } else if (newAddressData != null) {
                                            payload['new_address'] = newAddressData;
                                            payload['save_to_customer'] = saveToCustomerProfile;
                                          }

                                          await ApiService.instance.post('/admin/jobs', payload);

                                          final messenger = ScaffoldMessenger.of(context);
                                          Navigator.pop(context);
                                          if (widget.onJobCreated != null) {
                                            widget.onJobCreated!();
                                          }
                                          messenger.showSnackBar(const SnackBar(
                                              content: Text(
                                                  "Success! Job assigned.",
                                                  style: TextStyle(
                                                      color: Colors.white)),
                                              backgroundColor:
                                                  Color(0xFF10B981)));
                                        } catch (e) {
                                          setModalState(() => isSaving = false);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  content: Text("Error: $e")));
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12))),
                                child: isSaving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white)
                                    : const Text("Assign & Dispatch Job",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white)),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                child: Row(children: const [
                  Text("Customers",
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 19,
                          fontWeight: FontWeight.w600))
                ])),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingCustomers
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF3B82F6)))
                  : _customersList.isEmpty
                      ? Center(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                              Icon(Icons.business_center_outlined,
                                  color: Colors.white24, size: 64),
                              SizedBox(height: 16),
                              Text("No customers yet.",
                                  style: TextStyle(
                                      color: Colors.white60, fontSize: 18))
                            ]))
                      : RefreshIndicator(
                          onRefresh: _fetchCustomers,
                          color: const Color(0xFF3B82F6),
                          backgroundColor: const Color(0xFF1E293B),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24.0, vertical: 8.0),
                            itemCount: _customersList.length,
                            itemBuilder: (context, index) {
                              var data =
                                  _customersList[index] as Map<String, dynamic>;
                              var docId = data['id'].toString();
                              return GestureDetector(
                                onTap: () =>
                                    _showCustomerDetailsModal(docId, data),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border:
                                          Border.all(color: Colors.white10)),
                                  child: Row(
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6)
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          child: const Icon(Icons.business,
                                              color: Color(0xFF3B82F6))),
                                      const SizedBox(width: 16),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(
                                                '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                                                        .trim()
                                                        .isEmpty
                                                    ? 'Unknown Customer'
                                                    : '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'
                                                        .trim(),
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            Text(
                                                (data['address1'] ??
                                                        (data['primary_address'] !=
                                                                null
                                                            ? data['primary_address']
                                                                ['address1']
                                                            : null)) ??
                                                    'No address',
                                                style: const TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 13))
                                          ])),
                                      const Icon(Icons.chevron_right,
                                          color: Colors.white24),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

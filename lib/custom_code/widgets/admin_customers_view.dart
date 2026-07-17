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
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;
  final bool openCreateJobModal;
  final bool openCreateCustomerModal;

  @override
  State<AdminCustomersView> createState() => _AdminCustomersViewState();
}

class _AdminCustomersViewState extends State<AdminCustomersView> {
  String _adminName = "Admin";
  bool _isLoadingCustomers = true;
  List<dynamic> _customersList = [];
  Timer? _refreshTimer;
  String? _googleMapsApiKey;

  List<String> _jobTypes = ["Standard Clean", "Deep Clean", "Move In/Out"];
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
        _showAddCustomerDialog();
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
      if (mounted && settings is Map && settings.containsKey('google_maps_api_key')) {
        _googleMapsApiKey = settings['google_maps_api_key'];
      }
    } catch (e) {
      debugPrint("Error fetching maps key: $e");
    }
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await ApiService.instance.get('/customers');
      if (mounted) {
        setState(() {
          // Check if paginated or raw list
          dynamic dataObj = res is Map && res.containsKey('data') ? res['data'] : res;
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
    return TextField(
      controller: ctrl,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: isAddress
              ? const Icon(Icons.location_on, color: Color(0xFF3B82F6))
              : null,
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF3B82F6))),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF3B82F6)))),
    );
  }

  // =====================================================================
  // 🚀 MENÚ DE PERFIL UNIFICADO (IGUAL AL TEAM Y AL MAPA)
  // =====================================================================
  void _showAdminPersonalInfoModal() {
    TextEditingController firstNameCtrl = TextEditingController(text: _adminName.split(' ').first);
    TextEditingController lastNameCtrl = TextEditingController(text: _adminName.split(' ').length > 1 ? _adminName.split(' ').sublist(1).join(' ') : '');
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
                                          if (firstNameCtrl.text.trim().isEmpty || lastNameCtrl.text.trim().isEmpty)
                                            return;
                                          setModalState(() => isSaving = true);
                                          try {
                                            await ApiService.instance.put('/auth/profile', {
                                              'first_name': firstNameCtrl.text.trim(),
                                              'last_name': lastNameCtrl.text.trim(),
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
  void _showAddCustomerDialog(
      {StateSetter? parentSetState,
      Function(String, String, double, double)? onCustomerCreated}) {
    TextEditingController firstNameCtrl = TextEditingController();
    TextEditingController lastNameCtrl = TextEditingController();
    TextEditingController phoneCtrl = TextEditingController();
    TextEditingController emailCtrl = TextEditingController();
    TextEditingController addressCtrl = TextEditingController();

    List<dynamic> placePredictions = [];
    double lat = 0.0;
    double lng = 0.0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setDialogState) {
        Future<void> searchPlaces(String query) async {
          if (query.isEmpty) {
            setDialogState(() => placePredictions = []);
            return;
          }
          try {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['status'] == 'OK') {
                setDialogState(() => placePredictions = List<dynamic>.from(data['predictions'] ?? []));
              }
            }
          } catch (e) {
            debugPrint("Error Autocomplete: $e");
          }
        }

        Future<void> getPlaceDetails(String placeId) async {
          try {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['status'] == 'OK') {
                var location = data['result']['geometry']['location'];
                setDialogState(() {
                  lat = location['lat'];
                  lng = location['lng'];
                });
              }
            }
          } catch (e) {
            debugPrint("Error Details: $e");
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Add New Customer",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildSimpleTextField(firstNameCtrl, "First Name"),
              const SizedBox(height: 12),
              _buildSimpleTextField(lastNameCtrl, "Last Name"),
              const SizedBox(height: 12),
              _buildSimpleTextField(phoneCtrl, "Phone Number"),
              const SizedBox(height: 12),
              _buildSimpleTextField(emailCtrl, "Email Address"),
              const SizedBox(height: 12),
              _buildSimpleTextField(addressCtrl, "Start typing address...",
                  isAddress: true, onChanged: (val) {
                if (val.length > 3) {
                  searchPlaces(val);
                } else {
                  setDialogState(() => placePredictions = []);
                }
              }),
              if (placePredictions.isNotEmpty)
                Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: placePredictions
                        .map<Widget>((p) => ListTile(
                              title: Text(p['description']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              onTap: () async {
                                String pId = p['place_id']?.toString() ?? '';
                                setDialogState(() {
                                  addressCtrl.text =
                                      p['description']?.toString() ?? '';
                                  placePredictions.clear();
                                });
                                await getPlaceDetails(pId);
                              },
                            ))
                        .toList(),
                  ),
                ),
              if (lat != 0.0) ...[
                const SizedBox(height: 8),
                const Row(children: [
                  Icon(Icons.gps_fixed, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 6),
                  Text("Address Confirmed",
                      style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ]),
              ]
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel",
                    style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                if (firstNameCtrl.text.isNotEmpty && lastNameCtrl.text.isNotEmpty) {
                  var newDoc = await ApiService.instance.post('/customers', {
                    'first_name': firstNameCtrl.text.trim(),
                    'last_name': lastNameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'address1': addressCtrl.text.trim(),
                    'lat': lat,
                    'lng': lng,
                  });
                  if (onCustomerCreated != null) {
                    onCustomerCreated(newDoc['id'].toString(), '${firstNameCtrl.text.trim()} ${lastNameCtrl.text.trim()}', lat, lng);
                  } else {
                    _fetchCustomers();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Customer created successfully!",
                              style: TextStyle(color: Colors.white)),
                          backgroundColor: Colors.green));
                    }
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Save Customer",
                  style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  void _showEditCustomerDialog(String customerId, Map<String, dynamic> customerData) {
    TextEditingController firstNameCtrl =
        TextEditingController(text: customerData['first_name'] ?? customerData['name']?.split(' ').first ?? '');
    TextEditingController lastNameCtrl =
        TextEditingController(text: customerData['last_name'] ?? (customerData['name'] != null && customerData['name'].contains(' ') ? customerData['name'].split(' ').sublist(1).join(' ') : ''));
    TextEditingController phoneCtrl =
        TextEditingController(text: customerData['phone']);
    TextEditingController emailCtrl =
        TextEditingController(text: customerData['email']);
    TextEditingController addressCtrl =
        TextEditingController(text: customerData['address1'] ?? (customerData['primary_address'] != null ? customerData['primary_address']['address1'] : ''));

    List<dynamic> placePredictions = [];
    double lat = customerData['lat'] != null
        ? (customerData['lat'] as num).toDouble()
        : 0.0;
    double lng = customerData['lng'] != null
        ? (customerData['lng'] as num).toDouble()
        : 0.0;

    showDialog(
      context: context,
      builder: (dialogContext) =>
          StatefulBuilder(builder: (context, setDialogState) {
        Future<void> searchPlaces(String query) async {
          if (query.isEmpty) {
            setDialogState(() => placePredictions = []);
            return;
          }
          try {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['status'] == 'OK') {
                setDialogState(() => placePredictions = List<dynamic>.from(data['predictions'] ?? []));
              }
            }
          } catch (e) {
            debugPrint("Error Autocomplete: $e");
          }
        }

        Future<void> getPlaceDetails(String placeId) async {
          try {
            if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
            final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
            final response = await http.get(uri);
            if (response.statusCode == 200) {
              final data = jsonDecode(response.body);
              if (data['status'] == 'OK') {
                var location = data['result']['geometry']['location'];
                setDialogState(() {
                  lat = location['lat'];
                  lng = location['lng'];
                });
              }
            }
          } catch (e) {
            debugPrint("Error Details: $e");
          }
        }

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text("Edit Customer Info",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _buildSimpleTextField(firstNameCtrl, "First Name"),
              const SizedBox(height: 12),
              _buildSimpleTextField(lastNameCtrl, "Last Name"),
              const SizedBox(height: 12),
              _buildSimpleTextField(phoneCtrl, "Phone Number"),
              const SizedBox(height: 12),
              _buildSimpleTextField(emailCtrl, "Email Address"),
              const SizedBox(height: 12),
              _buildSimpleTextField(addressCtrl, "Start typing address...",
                  isAddress: true, onChanged: (val) {
                if (val.length > 3) {
                  searchPlaces(val);
                } else {
                  setDialogState(() => placePredictions = []);
                }
              }),
              if (placePredictions.isNotEmpty)
                Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFF0D1B2A),
                      borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12))),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: placePredictions
                        .map<Widget>((p) => ListTile(
                              title: Text(p['description']?.toString() ?? '',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              onTap: () async {
                                String pId = p['place_id']?.toString() ?? '';
                                setDialogState(() {
                                  addressCtrl.text =
                                      p['description']?.toString() ?? '';
                                  placePredictions.clear();
                                });
                                await getPlaceDetails(pId);
                              },
                            ))
                        .toList(),
                  ),
                ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel",
                    style: TextStyle(color: Colors.white60))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6)),
              onPressed: () async {
                if (firstNameCtrl.text.isNotEmpty && lastNameCtrl.text.isNotEmpty) {
                  await ApiService.instance.put('/customers/$customerId', {
                    'first_name': firstNameCtrl.text.trim(),
                    'last_name': lastNameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                    'email': emailCtrl.text.trim(),
                    'address1': addressCtrl.text.trim(),
                    'lat': lat,
                    'lng': lng,
                  });
                  Navigator.pop(dialogContext);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Customer updated successfully!",
                          style: TextStyle(color: Colors.white)),
                      backgroundColor: Color(0xFF10B981)));
                }
              },
              child: const Text("Save Changes",
                  style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
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
                                await ApiService.instance.delete('/customers/$customerId');
                                _fetchCustomers();
                                if (mounted) {
                                  Navigator.pop(ctx); // Cierra modal de confirmación
                                  Navigator.pop(context); // Cierra modal de detalles del customere
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
                      future: ApiService.instance.get('/admin/jobs?customer_id=$customerId'),
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
                                id, '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'.trim().isEmpty ? 'Customer' : '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'.trim()),
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
                            Text('${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'.trim().isEmpty ? 'No Name' : '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'.trim(),
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
                                  id, '${customerData['first_name'] ?? ''} ${customerData['last_name'] ?? ''}'.trim()),
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
    TextEditingController notesCtrl = TextEditingController();
    TextEditingController addressCtrl = TextEditingController();

    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    String? selectedJobType;
    String selectedFrequency = "One-time";
    String selectedDuration = "1 Month";

    List<String> currentSelectedDays = [];
    final List<String> weekDays = [
      "Mon",
      "Tue",
      "Wed",
      "Thu",
      "Fri",
      "Sat",
      "Sun"
    ];

    String? selectedCustomerId;
    String? selectedCustomerName;
    List<String> currentSelectedTasks = [];

    List<String> selectedWorkerIds = [];
    String? selectedTeamLeaderId;
    List<dynamic> placePredictions = [];
    bool isSaving = false;

    double latitude = 0.0;
    double longitude = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.90,
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setModalState) {
            Future<void> searchPlaces(String query) async {
              if (query.isEmpty) {
                setModalState(() => placePredictions = []);
                return;
              }
              try {
                if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(query)}&key=$_googleMapsApiKey");
                final response = await http.get(uri);
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if (data['status'] == 'OK') {
                    setModalState(() => placePredictions = List<dynamic>.from(data['predictions'] ?? []));
                  }
                }
              } catch (e) {
                debugPrint("Cloud Function Error (Autocomplete): $e");
              }
            }

            Future<void> getPlaceDetails(String placeId) async {
              try {
                if (_googleMapsApiKey == null || _googleMapsApiKey!.isEmpty) return;
                final uri = Uri.parse("https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$_googleMapsApiKey");
                final response = await http.get(uri);
                if (response.statusCode == 200) {
                  final data = jsonDecode(response.body);
                  if (data['status'] == 'OK') {
                    var location = data['result']['geometry']['location'];
                    setModalState(() {
                      latitude = location['lat'];
                      longitude = location['lng'];
                    });
                  }
                }
              } catch (e) {
                debugPrint("Cloud Function Error (Details): $e");
              }
            }

            Future<void> addNewItemDialog(String title, bool isJobType) async {
              TextEditingController newItemCtrl = TextEditingController();
              await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    title: Text("Add New $title",
                        style: const TextStyle(color: Colors.white)),
                    content: TextField(
                        controller: newItemCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                            hintText: "Enter name...",
                            hintStyle: TextStyle(color: Colors.white38),
                            enabledBorder: UnderlineInputBorder(
                                borderSide:
                                    BorderSide(color: Color(0xFF3B82F6))))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel",
                              style: TextStyle(color: Colors.white60))),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6)),
                          onPressed: () {
                            if (newItemCtrl.text.isNotEmpty) {
                              setModalState(() {
                                if (isJobType) {
                                  _jobTypes.add(newItemCtrl.text.trim());
                                  selectedJobType = newItemCtrl.text.trim();
                                } else {
                                  _availableTasks.add(newItemCtrl.text.trim());
                                  currentSelectedTasks
                                      .add(newItemCtrl.text.trim());
                                }
                              });
                            }
                            Navigator.pop(context);
                          },
                          child: const Text("Save",
                              style: TextStyle(color: Colors.white)))
                    ]),
              );
            }

            void showMultiSelectWorkerDialog(List<dynamic> workers) {
              showDialog(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return StatefulBuilder(builder: (context, setDialogState) {
                      return AlertDialog(
                        backgroundColor: const Color(0xFF1E293B),
                        title: const Text("Select Team Members",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        content: SizedBox(
                          width: double.maxFinite,
                          height: 300,
                          child: ListView.builder(
                            itemCount: workers.length,
                            itemBuilder: (context, index) {
                              var doc = workers[index];
                              var data = doc as Map<String, dynamic>;
                              String docId = data['id'].toString();
                              bool isSelected =
                                  selectedWorkerIds.contains(docId);

                              return CheckboxListTile(
                                title: Text(data['display_name'] ?? 'Worker',
                                    style:
                                        const TextStyle(color: Colors.white)),
                                value: isSelected,
                                activeColor: const Color(0xFF3B82F6),
                                checkColor: Colors.white,
                                side: const BorderSide(color: Colors.white60),
                                onChanged: (bool? val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedWorkerIds.add(docId);
                                    } else {
                                      selectedWorkerIds.remove(docId);
                                      if (selectedTeamLeaderId == docId) {
                                        selectedTeamLeaderId = null;
                                      }
                                    }
                                  });
                                  setModalState(() {});
                                },
                              );
                            },
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
                          const Text("Select Customer",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              List<DropdownMenuItem<String>> customerItems =
                                  _customersList.map((customer) {
                                return DropdownMenuItem<String>(
                                    value: customer['id'].toString(),
                                    child: Text('${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim().isEmpty ? 'Unknown' : '${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}'.trim(),
                                        style: const TextStyle(
                                            color: Colors.white)));
                              }).toList();

                              customerItems.insert(
                                  0,
                                  const DropdownMenuItem(
                                      value: "ADD_NEW",
                                      child: Row(children: [
                                        Icon(Icons.person_add,
                                            color: Color(0xFF10B981), size: 20),
                                        SizedBox(width: 8),
                                        Text("Add New Customer",
                                            style: TextStyle(
                                                color: Color(0xFF10B981),
                                                fontWeight: FontWeight.bold))
                                      ])));

                              return Container(
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
                                    value: selectedCustomerId,
                                    hint: const Text("Choose a customer...",
                                        style:
                                            TextStyle(color: Colors.white38)),
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        color: Color(0xFF3B82F6)),
                                    items: customerItems,
                                    onChanged: (val) {
                                      if (val == "ADD_NEW") {
                                        _showAddCustomerDialog(parentSetState: setModalState);
                                      } else if (val != null) {
                                        var selectedDoc = _customersList
                                            .firstWhere((d) => d['id'].toString() == val);

                                        setModalState(() {
                                          selectedCustomerId = val;
                                          selectedCustomerName = '${selectedDoc['first_name'] ?? ''} ${selectedDoc['last_name'] ?? ''}'.trim();
                                          if (selectedDoc['address1'] != null &&
                                              selectedDoc['address1']
                                                  .toString()
                                                  .isNotEmpty) {
                                            addressCtrl.text = selectedDoc['address1'];
                                            latitude = selectedDoc['lat'] != null
                                                ? (double.tryParse(selectedDoc['lat'].toString()) ?? 0.0)
                                                : 0.0;
                                            longitude = selectedDoc['lng'] != null
                                                ? (double.tryParse(selectedDoc['lng'].toString()) ?? 0.0)
                                                : 0.0;
                                          } else if (selectedDoc['primary_address'] != null) {
                                            addressCtrl.text = selectedDoc['primary_address']['address1'] ?? '';
                                            latitude = selectedDoc['primary_address']['latitude'] != null
                                                ? (double.tryParse(selectedDoc['primary_address']['latitude'].toString()) ?? 0.0)
                                                : 0.0;
                                            longitude = selectedDoc['primary_address']['longitude'] != null
                                                ? (double.tryParse(selectedDoc['primary_address']['longitude'].toString()) ?? 0.0)
                                                : 0.0;
                                          }
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text("Service Address",
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
                            child: Column(
                              children: [
                                TextField(
                                  controller: addressCtrl,
                                  onChanged: (val) {
                                    if (val.length > 3) {
                                      searchPlaces(val);
                                    } else {
                                      setModalState(
                                          () => placePredictions = []);
                                    }
                                  },
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                      hintText: "Start typing address...",
                                      hintStyle:
                                          TextStyle(color: Colors.white38),
                                      prefixIcon: Icon(Icons.location_on,
                                          color: Color(0xFF3B82F6)),
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 16)),
                                ),
                                if (placePredictions.isNotEmpty)
                                  Container(
                                    decoration: const BoxDecoration(
                                        color: Color(0xFF0D1B2A),
                                        borderRadius: BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12))),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: placePredictions
                                          .map<Widget>((p) => ListTile(
                                                title: Text(
                                                    p['description']
                                                            ?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13)),
                                                onTap: () async {
                                                  String pId = p['place_id']
                                                          ?.toString() ??
                                                      '';
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
                                  )
                              ],
                            ),
                          ),
                          if (latitude != 0.0) ...[
                            const SizedBox(height: 8),
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
                          const SizedBox(height: 20),
                          const Text("Job Type",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                items: [
                                  ..._jobTypes.map((type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type,
                                          style: const TextStyle(
                                              color: Colors.white)))),
                                  const DropdownMenuItem(
                                      value: "ADD_NEW",
                                      child: Row(children: [
                                        Icon(Icons.add,
                                            color: Color(0xFF3B82F6), size: 20),
                                        SizedBox(width: 8),
                                        Text("Add new job type",
                                            style: TextStyle(
                                                color: Color(0xFF3B82F6),
                                                fontWeight: FontWeight.bold))
                                      ]))
                                ],
                                onChanged: (val) {
                                  if (val == "ADD_NEW") {
                                    addNewItemDialog("Job Type", true);
                                  } else {
                                    setModalState(() => selectedJobType = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text("Task Checklist",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              ..._availableTasks.map((task) {
                                bool isSelected =
                                    currentSelectedTasks.contains(task);
                                return GestureDetector(
                                    onTap: () => setModalState(() {
                                          isSelected
                                              ? currentSelectedTasks
                                                  .remove(task)
                                              : currentSelectedTasks.add(task);
                                        }),
                                    child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        decoration: BoxDecoration(
                                            color: isSelected
                                                ? const Color(0xFF3B82F6)
                                                : const Color(0xFF1E293B),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                            border: Border.all(
                                                color: isSelected
                                                    ? const Color(0xFF3B82F6)
                                                    : Colors.white24)),
                                        child: Text(task,
                                            style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : Colors.white60,
                                                fontSize: 13))));
                              }),
                              GestureDetector(
                                  onTap: () => addNewItemDialog("Task", false),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16, vertical: 8),
                                      decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: const Color(0xFF3B82F6),
                                              style: BorderStyle.solid)),
                                      child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add,
                                                color: Color(0xFF3B82F6),
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text("Add task",
                                                style: TextStyle(
                                                    color: Color(0xFF3B82F6),
                                                    fontSize: 13))
                                          ]))),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text("Start Date",
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
                                            TimeOfDay? pickedTime = await showTimePicker(
                                                context: context,
                                                initialTime: selectedTime,
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
                                                selectedDate = pickedDate;
                                                selectedTime = pickedTime;
                                              });
                                            }
                                          }
                                        },
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 10, vertical: 16),
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
                                                    "${DateFormat('MMM d').format(selectedDate)}, ${selectedTime.format(context)}",
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 13),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              )
                                            ])))
                                  ])),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    const Text("Frequency",
                                        style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF1E293B),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                        child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                                isExpanded: true,
                                                dropdownColor:
                                                    const Color(0xFF1E293B),
                                                value: selectedFrequency,
                                                icon: const Icon(
                                                    Icons.keyboard_arrow_down,
                                                    color: Color(0xFF3B82F6)),
                                                items: _frequencies
                                                    .map((freq) => DropdownMenuItem(
                                                        value: freq,
                                                        child: Text(freq,
                                                            style: const TextStyle(
                                                                color: Colors
                                                                    .white))))
                                                    .toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setModalState(() =>
                                                        selectedFrequency =
                                                            val);
                                                  }
                                                })))
                                  ])),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (selectedFrequency == "Custom") ...[
                            const Text("Select Days",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: weekDays.map((day) {
                                bool isSelected =
                                    currentSelectedDays.contains(day);
                                return GestureDetector(
                                  onTap: () => setModalState(() {
                                    isSelected
                                        ? currentSelectedDays.remove(day)
                                        : currentSelectedDays.add(day);
                                  }),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF3B82F6)
                                            : const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: isSelected
                                                ? const Color(0xFF3B82F6)
                                                : Colors.white24)),
                                    child: Text(day,
                                        style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white60,
                                            fontSize: 13)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],
                          if (selectedFrequency != "One-time") ...[
                            const Text("Duration",
                                style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(12)),
                                child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                        isExpanded: true,
                                        dropdownColor: const Color(0xFF1E293B),
                                        value: selectedDuration,
                                        icon: const Icon(
                                            Icons.keyboard_arrow_down,
                                            color: Color(0xFF3B82F6)),
                                        items: _durations
                                            .map((d) => DropdownMenuItem(
                                                value: d,
                                                child: Text(d,
                                                    style: const TextStyle(
                                                        color: Colors.white))))
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setModalState(
                                                () => selectedDuration = val);
                                          }
                                        })))
                          ],
                          const SizedBox(height: 20),
                          const Text("Assign Team",
                              style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          FutureBuilder<dynamic>(
                              future: workersFuture,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                var workers = snapshot.data is Map && snapshot.data.containsKey('data') ? snapshot.data['data'] : (snapshot.data is List ? snapshot.data : []);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  InkWell(
                                      onTap: () =>
                                          showMultiSelectWorkerDialog(workers),
                                      child: Container(
                                          padding: const EdgeInsets.all(16),
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
                                                Text(
                                                    selectedWorkerIds.isEmpty
                                                        ? "Tap to select workers..."
                                                        : "${selectedWorkerIds.length} worker(s) selected",
                                                    style: TextStyle(
                                                        color: selectedWorkerIds
                                                                .isEmpty
                                                            ? Colors.white38
                                                            : Colors.white,
                                                        fontSize: 16)),
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
                                                  color: Colors.white38)),
                                          icon: const Icon(Icons.star,
                                              color: Color(0xFFF59E0B)),
                                          items: workers
                                              .where((w) => selectedWorkerIds
                                                  .contains(w['id'].toString()))
                                              .map<DropdownMenuItem<String>>((doc) {
                                            var data = doc
                                                as Map<String, dynamic>;
                                            return DropdownMenuItem<String>(
                                                value: data['id'].toString(),
                                                child: Text(
                                                    "${data['display_name']} (Leader)",
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFF59E0B),
                                                        fontWeight:
                                                            FontWeight.bold)));
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
                                  style: const TextStyle(color: Colors.white),
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
                                                  backgroundColor: const Color(0xFF1E293B),
                                                  title: const Text("Validation Error", style: TextStyle(color: Colors.white)),
                                                  content: Text(msg, style: const TextStyle(color: Colors.white70)),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK", style: TextStyle(color: Color(0xFF3B82F6))))
                                                  ]
                                                ));
                                      }

                                      if (selectedCustomerId == null ||
                                          addressCtrl.text.isEmpty) {
                                        _showErr("Customer and Address are required.");
                                        return;
                                      }
                                      if (selectedFrequency == "Custom" &&
                                          currentSelectedDays.isEmpty) {
                                        _showErr("Select at least one day for Custom frequency.");
                                        return;
                                      }
                                      if (selectedWorkerIds.length > 1 &&
                                          selectedTeamLeaderId == null) {
                                        _showErr("Please select a Team Leader from the assigned workers.");
                                        return;
                                      }

                                      setModalState(() => isSaving = true);
                                      try {
                                        DateTime start = DateTime(
                                            selectedDate.year,
                                            selectedDate.month,
                                            selectedDate.day,
                                            selectedTime.hour,
                                            selectedTime.minute);

                                        await ApiService.instance.post('/admin/jobs', {'customer_id': selectedCustomerId,
                                          'customer_name': selectedCustomerName,
                                          'address': addressCtrl.text.trim(),
                                          'latitude': latitude,
                                          'longitude': longitude,
                                          'job_type':
                                              selectedJobType ?? 'Standard',
                                          'tasks': currentSelectedTasks,
                                          'frequency': selectedFrequency,
                                          'duration':
                                              selectedFrequency == "One-time"
                                                  ? null
                                                  : selectedDuration,
                                          'custom_days':
                                              selectedFrequency == "Custom"
                                                  ? currentSelectedDays
                                                  : [],
                                          'scheduled_time':
                                              start.toIso8601String(),
                                          'assigned_workers': selectedWorkerIds,
                                          'team_leader_id':
                                              selectedWorkerIds.length == 1
                                                  ? selectedWorkerIds[0]
                                                  : selectedTeamLeaderId,
                                          'notes': notesCtrl.text.trim(),
                                          // 🚀 FIX: STATUS INICIAL ES 'ASSIGNED'
                                          'status': 'assigned',
                                          'created_at':
                                              DateTime.now().toIso8601String(),});

                                        Navigator.pop(context);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
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
                                      borderRadius: BorderRadius.circular(12))),
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
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_getGreeting(),
                            style: const TextStyle(
                                color: Colors.white60, fontSize: 16)),
                        const SizedBox(height: 4),
                        Text(_adminName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold))
                      ]),
                  GestureDetector(
                      onTap: _showAdminProfileModal,
                      child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: const Color(0xFF3B82F6), width: 2)),
                          child: Center(
                              child: Text(_getUserInitial(_adminName),
                                  style: const TextStyle(
                                      color: Color(0xFF3B82F6),
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold))))),
                ],
              ),
            ),
            Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(children: const [
                  Text("Customer Directory",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold))
                ])),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoadingCustomers
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF3B82F6)))
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
                            var data = _customersList[index] as Map<String, dynamic>;
                            var docId = data['id'].toString();
                            return GestureDetector(
                              onTap: () => _showCustomerDetailsModal(docId, data),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white10)),
                                child: Row(
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF3B82F6)
                                                .withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.business,
                                            color: Color(0xFF3B82F6))),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Text('${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim().isEmpty ? 'Unknown Customer' : '${data['first_name'] ?? ''} ${data['last_name'] ?? ''}'.trim(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          Text((data['address1'] ?? (data['primary_address'] != null ? data['primary_address']['address1'] : null)) ?? 'No address',
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

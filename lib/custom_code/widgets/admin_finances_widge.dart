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
import '../../auth/laravel_auth_manager.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';

class AdminFinancesWidge extends StatefulWidget {
  const AdminFinancesWidge({
    super.key,
    this.width,
    this.height,
    required this.onLogout,
  });

  final double? width;
  final double? height;
  final Future Function() onLogout;

  @override
  State<AdminFinancesWidge> createState() => _AdminFinancesWidgeState();
}

class _AdminFinancesWidgeState extends State<AdminFinancesWidge> {
  final BaseAuthUser? _currentUser = currentUser;
  String _adminName = "Admin";

  bool _isShowingPayroll = false;
  String _timeFilter = "This Month";
  final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

  // Data State
  bool _isLoading = true;
  double _totalRevenue = 0.0;
  double _outstanding = 0.0;
  double _totalPayouts = 0.0;
  List<dynamic> _paidInvoices = [];
  List<dynamic> _unpaidInvoices = [];
  List<dynamic> _allPayouts = [];
  List<dynamic> _unpaidWorkers = [];

  final ApiService _api = ApiService.instance;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _loadDashboardData();
  }

  Future<void> _loadAdminProfile() async {
    if (_currentUser != null && _currentUser!.displayName != null) {
      if (mounted) setState(() => _adminName = _currentUser!.displayName!);
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final summary =
          await _api.get('admin/finance/dashboard?period=$_timeFilter');
      final data = summary['data'] ?? summary;

      _totalRevenue = (data['total_revenue'] ?? 0).toDouble();
      _outstanding = (data['outstanding'] ?? 0).toDouble();
      _totalPayouts = (data['total_payouts'] ?? 0).toDouble();

      _paidInvoices = data['paid_invoices'] ?? [];
      _unpaidInvoices = data['unpaid_invoices'] ?? [];
      _allPayouts = data['all_payouts'] ?? [];

      // Load unpaid workers if showing payroll tab
      if (_isShowingPayroll) {
        await _loadUnpaidWorkers();
      }
    } catch (e) {
      print('Error loading dashboard: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadUnpaidWorkers() async {
    try {
      final workerRes = await _api.get('admin/payroll/workers');
      if (mounted) {
        setState(() {
          _unpaidWorkers = workerRes['data'] ?? [];
        });
      }
    } catch (e) {
      print('Error loading unpaid workers: $e');
      if (mounted) {
        setState(() {
          _unpaidWorkers = [];
        });
      }
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
                            Text(_currentUser?.email ?? "",
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13))
                          ]))
                    ]),
                  ),
                  const SizedBox(height: 24),
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

  void _showMetricDetailsModal(
      String title, double totalAmount, List<dynamic> docs, bool isPaid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          height: MediaQuery.of(context).size.height * 0.7,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(currencyFormat.format(totalAmount),
                      style: TextStyle(
                          color: isPaid
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text("Included in $_timeFilter",
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text("No records found.",
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var data = docs[index];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: Icon(
                                    isPaid
                                        ? Icons.check_circle
                                        : Icons.schedule,
                                    color: isPaid
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFF59E0B)),
                                title: Text(
                                    data['customer'] != null
                                        ? '${data['customer']['first_name'] ?? ''} ${data['customer']['last_name'] ?? ''}'.trim().isEmpty ? 'Unknown' : '${data['customer']['first_name'] ?? ''} ${data['customer']['last_name'] ?? ''}'.trim()
                                        : 'Unknown',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(data['notes'] ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                                trailing: Text(
                                    currencyFormat.format(
                                        (data['amount'] ?? 0).toDouble()),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              );
                            }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPayoutMetricDetailsModal(
      String title, double totalAmount, List<dynamic> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1B2A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          height: MediaQuery.of(context).size.height * 0.7,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
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
                  Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(currencyFormat.format(totalAmount),
                      style: const TextStyle(
                          color: Color(0xFF8B5CF6),
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Text("All payouts in $_timeFilter",
                      style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Expanded(
                    child: docs.isEmpty
                        ? const Center(
                            child: Text("No records found.",
                                style: TextStyle(color: Colors.white38)))
                        : ListView.builder(
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              var data = docs[index];
                              String workerName = 'Payroll Run';
                              if (data['workers'] != null && data['workers'].isNotEmpty) {
                                var firstWorker = data['workers'][0];
                                if (firstWorker['user'] != null) {
                                  workerName = '${firstWorker['user']['first_name']} ${firstWorker['user']['last_name']}';
                                }
                              } else if (data['processor'] != null) {
                                workerName = '${data['processor']['first_name'] ?? ''} ${data['processor']['last_name'] ?? ''}'.trim().isEmpty ? 'Payroll Run' : '${data['processor']['first_name'] ?? ''} ${data['processor']['last_name'] ?? ''}'.trim();
                              }
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.outbound,
                                    color: Color(0xFF8B5CF6)),
                                title: Text(workerName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(data['notes'] ?? 'Payroll run',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white60, fontSize: 12)),
                                trailing: Text(
                                    currencyFormat.format(
                                        (data['total_amount'] ?? 0).toDouble()),
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                              );
                            }),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showPayoutModal(Map<String, dynamic> workerData) {
    bool isSaving = false;
    double grossAmount = (workerData['total_amount'] ?? 0).toDouble();
    double taxAmount = (workerData['tax_amount'] ?? 0).toDouble();
    double netAmount = (workerData['net_amount'] ?? grossAmount).toDouble();
    double totalHours = (workerData['total_hours'] ?? 0).toDouble();
    String workerName =
        '${workerData['user']['first_name']} ${workerData['user']['last_name']}';
    int workerId = workerData['user_id'];
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1B2A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Process Payroll",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                        child: const Row(children: [
                          Icon(Icons.sync, color: Color(0xFF3B82F6), size: 14),
                          SizedBox(width: 4),
                          Text("Auto-Synced",
                              style: TextStyle(
                                  color: Color(0xFF3B82F6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold))
                        ]),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text("Paying $workerName for $totalHours hours.",
                      style:
                          const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6))),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Gross Pay:",
                                style: TextStyle(
                                    color: Colors.white60, fontSize: 16)),
                            Text(currencyFormat.format(grossAmount),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Tax Deduction:",
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 14)),
                            Text('-${currencyFormat.format(taxAmount)}',
                                style: const TextStyle(
                                    color: Colors.redAccent, fontSize: 16)),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: Colors.white24, height: 1),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Net Payout:",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text(currencyFormat.format(netAmount),
                                style: const TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent.withOpacity(0.5))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                          )
                        ]
                      )
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: (isSaving || netAmount <= 0)
                          ? null
                          : () async {
                              setModalState(() => isSaving = true);
                                setModalState(() => errorMessage = null);
                                try {
                                  // Calls our Laravel API to process payroll
                                  await _api.post('admin/payroll/process', {
                                    'worker_ids': [workerId],
                                    'period_start': workerData['period_start'],
                                    'period_end': workerData['period_end'],
                                    'pay_method': 'ach',
                                    'notes': 'Processed from mobile app'
                                  });

                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              "Payroll processed successfully!"),
                                          backgroundColor: Color(0xFF10B981)));

                                  // Refresh Data
                                  _loadDashboardData();
                                } catch (e) {
                                  setModalState(() {
                                    isSaving = false;
                                    errorMessage = e.toString().replaceAll("Exception: ", "");
                                  });
                                }
                              },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Approve & Pay",
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
          );
        });
      },
    );
  }

  void _markAsPaid(String invoiceId) async {
    try {
      await _api.patch('admin/invoices/$invoiceId/pay', {});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Invoice marked as PAID!"),
          backgroundColor: Color(0xFF10B981)));
      _loadDashboardData();
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildInvoiceCard(Map<String, dynamic> data) {
    bool isPaid = data['invoice_status'] == 'paid';

    return Container(
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
                  color: isPaid
                      ? const Color(0xFF10B981).withOpacity(0.2)
                      : const Color(0xFFF59E0B).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(isPaid ? Icons.check_circle : Icons.schedule,
                  color: isPaid
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF59E0B))),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['customer'] != null ? ('${data['customer']['first_name'] ?? ''} ${data['customer']['last_name'] ?? ''}'.trim().isEmpty ? 'Client' : '${data['customer']['first_name'] ?? ''} ${data['customer']['last_name'] ?? ''}'.trim()) : 'Client',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 4),
                Text(
                  data['issue_date'] != null 
                      ? DateFormat('MMM d, yyyy').format(DateTime.tryParse(data['issue_date'].toString()) ?? DateTime.now())
                      : 'N/A',
                  style: const TextStyle(color: Colors.white60, fontSize: 13)
                )
              ]
            )
          ),
          
          // Middle-Left Column: Invoice Number
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Invoice", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                Text("${data['invoice_number'] ?? 'N/A'}", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          
          // Middle-Right Column: Total Amount
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Total", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                Text(currencyFormat.format(double.tryParse(data['total']?.toString() ?? '0') ?? 0.0),
                    style: TextStyle(
                        color: isPaid ? Colors.white : const Color(0xFFF59E0B),
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          
          // Far Right Column: Mark Paid Button
          if (!isPaid)
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      backgroundColor: const Color(0xFF1E293B),
                      title: const Text("Confirm Payment", style: TextStyle(color: Colors.white)),
                      content: const Text("Are you sure you want to mark this invoice as paid?", style: TextStyle(color: Colors.white70)),
                      actions: [
                        TextButton(
                          child: const Text("Cancel", style: TextStyle(color: Colors.white60)),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                          child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.of(context).pop();
                            _markAsPaid(data['id'].toString());
                          },
                        ),
                      ],
                    );
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5))
                ),
                child: const Text("Mark Paid",
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text("PAID",
                  style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double netProfit = _totalRevenue - _totalPayouts;
    Color netProfitColor =
        netProfit >= 0 ? const Color(0xFF06B6D4) : const Color(0xFFEF4444);

    double totalBilled = _totalRevenue + _outstanding;
    double collectionProgress =
        totalBilled > 0 ? (_totalRevenue / totalBilled) : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _loadDashboardData,
              color: const Color(0xFF3B82F6),
              backgroundColor: const Color(0xFF1E293B),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // --- HEADER ---
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
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    dropdownColor: const Color(0xFF1E293B),
                                    value: _timeFilter,
                                    icon: const Icon(Icons.keyboard_arrow_down,
                                        color: Color(0xFF3B82F6), size: 16),
                                    items: [
                                      'Today',
                                      'This Week',
                                      'This Month',
                                      'This Year'
                                    ]
                                        .map((f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(f,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _timeFilter = val;
                                          _loadDashboardData();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                  onTap: _showAdminProfileModal,
                                  child: Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: const Color(0xFF3B82F6),
                                              width: 2)),
                                      child: Center(
                                          child: Text(
                                              _getUserInitial(_adminName),
                                              style: const TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontSize: 20,
                                                  fontWeight:
                                                      FontWeight.bold))))),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Row(children: const [
                          Text("Financial Hub",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold))
                        ])),
                    const SizedBox(height: 24),

                    Column(
                      children: [
                        // --- KPI CARDS SUPERIORES ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Expanded(
                                  child: GestureDetector(
                                onTap: () => _showMetricDetailsModal(
                                    "Gross Revenue",
                                    _totalRevenue,
                                    _paidInvoices,
                                    true),
                                child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: Colors.white10)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFF10B981)
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)),
                                                    child: const Icon(
                                                        Icons
                                                            .account_balance_wallet,
                                                        color:
                                                            Color(0xFF10B981),
                                                        size: 20)),
                                                const Text("Paid",
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF10B981),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ]),
                                          const SizedBox(height: 16),
                                          Text(
                                              currencyFormat
                                                  .format(_totalRevenue),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          const Text("Gross Revenue",
                                              style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13))
                                        ])),
                              )),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: GestureDetector(
                                onTap: () => _showMetricDetailsModal(
                                    "Outstanding Balance",
                                    _outstanding,
                                    _unpaidInvoices,
                                    false),
                                child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: const Color(0xFFF59E0B)
                                                .withOpacity(0.3))),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFFF59E0B)
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)),
                                                    child: const Icon(
                                                        Icons.pending_actions,
                                                        color:
                                                            Color(0xFFF59E0B),
                                                        size: 20)),
                                                const Text("Due",
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFFF59E0B),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ]),
                                          const SizedBox(height: 16),
                                          Text(
                                              currencyFormat
                                                  .format(_outstanding),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          const Text("Outstanding",
                                              style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13))
                                        ])),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // --- KPI CARDS INFERIORES ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                          color:
                                              netProfitColor.withOpacity(0.1),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: netProfitColor
                                                  .withOpacity(0.5))),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                              8),
                                                      decoration: BoxDecoration(
                                                          color: netProfitColor
                                                              .withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(8)),
                                                      child: Icon(
                                                          Icons.insights,
                                                          color: netProfitColor,
                                                          size: 20)),
                                                  Text("Margin",
                                                      style: TextStyle(
                                                          color: netProfitColor,
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold))
                                                ]),
                                            const SizedBox(height: 16),
                                            Text(
                                                currencyFormat
                                                    .format(netProfit),
                                                style: TextStyle(
                                                    color: netProfitColor,
                                                    fontSize: 24,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 4),
                                            const Text("Net Profit",
                                                style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 13))
                                          ]))),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: GestureDetector(
                                onTap: () => _showPayoutMetricDetailsModal(
                                    "Payment History",
                                    _totalPayouts,
                                    _allPayouts),
                                child: Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(20),
                                        border:
                                            Border.all(color: Colors.white10)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                        color: const Color(
                                                                0xFF8B5CF6)
                                                            .withOpacity(0.2),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)),
                                                    child: const Icon(
                                                        Icons.outbound,
                                                        color:
                                                            Color(0xFF8B5CF6),
                                                        size: 20)),
                                                const Text("Sent",
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF8B5CF6),
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ]),
                                          const SizedBox(height: 16),
                                          Text(
                                              currencyFormat
                                                  .format(_totalPayouts),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 4),
                                          const Text("Total Payouts",
                                              style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 13))
                                        ])),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (totalBilled > 0)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text("Collection Progress",
                                        style: TextStyle(
                                            color: Colors.white60,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                    Text(
                                        "${(collectionProgress * 100).toStringAsFixed(0)}% Collected",
                                        style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: LinearProgressIndicator(
                                    value: collectionProgress,
                                    backgroundColor: const Color(0xFF1E293B),
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Color(0xFF10B981)),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10)),
                            child: Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _isShowingPayroll = false);
                                      _loadDashboardData();
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                          color: !_isShowingPayroll
                                              ? const Color(0xFF3B82F6)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Center(
                                          child: Text("Client Invoices",
                                              style: TextStyle(
                                                  color: !_isShowingPayroll
                                                      ? Colors.white
                                                      : Colors.white60,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() => _isShowingPayroll = true);
                                      _loadDashboardData();
                                      if (_unpaidWorkers.isEmpty) {
                                        _loadUnpaidWorkers();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      decoration: BoxDecoration(
                                          color: _isShowingPayroll
                                              ? const Color(0xFF3B82F6)
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Center(
                                          child: Text("Team Payroll",
                                              style: TextStyle(
                                                  color: _isShowingPayroll
                                                      ? Colors.white
                                                      : Colors.white60,
                                                  fontWeight:
                                                      FontWeight.bold))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // CONDITIONAL LISTS
                        if (!_isShowingPayroll)
                          (_paidInvoices.isEmpty && _unpaidInvoices.isEmpty)
                              ? Center(
                                  child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                      const Icon(Icons.receipt_long,
                                          color: Colors.white24, size: 64),
                                      const SizedBox(height: 16),
                                      Text("No invoices found in $_timeFilter.",
                                          style: const TextStyle(
                                              color: Colors.white60,
                                              fontSize: 16))
                                    ]))
                              : SingleChildScrollView(
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0, vertical: 8.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (_unpaidInvoices.isNotEmpty) ...[
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Awaiting Payment",
                                                style: TextStyle(
                                                    color: Colors.white60,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 1.1)),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                  color: const Color(0xFFF59E0B)
                                                      .withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Text(
                                                  "${_unpaidInvoices.length} Unpaid",
                                                  style: const TextStyle(
                                                      color: Color(0xFFF59E0B),
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            )
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        ..._unpaidInvoices
                                            .map(
                                                (doc) => _buildInvoiceCard(doc))
                                            .toList(),
                                        const SizedBox(height: 16),
                                      ],
                                      if (_paidInvoices.isNotEmpty) ...[
                                        const Text("Completed Payments",
                                            style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1)),
                                        const SizedBox(height: 12),
                                        ..._paidInvoices
                                            .map(
                                                (doc) => _buildInvoiceCard(doc))
                                            .toList(),
                                      ],
                                    ],
                                  ),
                                )
                        else
                          _unpaidWorkers.isEmpty
                              ? const Center(
                                  child: Text("No workers to pay.",
                                      style: TextStyle(color: Colors.white60)))
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24.0, vertical: 8.0),
                                  itemCount: _unpaidWorkers.length,
                                  itemBuilder: (context, index) {
                                    var workerData = _unpaidWorkers[index];
                                    var user = workerData['user'];

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: Colors.white10)),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                              radius: 24,
                                              backgroundColor:
                                                  const Color(0xFF3B82F6)
                                                      .withOpacity(0.2),
                                              child: Text(
                                                  user['first_name']?[0]
                                                          ?.toUpperCase() ??
                                                      'W',
                                                  style: const TextStyle(
                                                      color: Color(0xFF3B82F6),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 18))),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                    '${user['first_name']} ${user['last_name']}',
                                                    style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold)),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Text("REG / OT", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                                            Text("${workerData['regular_hours'] ?? 0}h / ${workerData['overtime_hours'] ?? 0}h", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                            const SizedBox(height: 8),
                                                            const Text("TRAVEL / GAP", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                                            Text("${workerData['travel_hours'] ?? 0}h / ${workerData['gap_hours'] ?? 0}h", style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                          ]
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            const Text("GROSS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                                            Text(currencyFormat.format((workerData['total_amount'] ?? 0).toDouble()), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                                            const SizedBox(height: 8),
                                                            const Text("TAX", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                                            Text("-${currencyFormat.format((workerData['tax_amount'] ?? 0).toDouble())}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                                          ]
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                                                            const Text("NET", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                                                            Text(currencyFormat.format((workerData['net_amount'] ?? workerData['total_amount'] ?? 0).toDouble()), style: const TextStyle(color: Color(0xFF10B981), fontSize: 16, fontWeight: FontWeight.bold)),
                                                            const SizedBox(height: 16),
                                                          ]
                                                        ),
                                                      )
                                                  ]
                                                )
                                              ],
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showPayoutModal(
                                                    workerData),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                                  decoration: BoxDecoration(
                                                      color: Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: const Color(
                                                              0xFF3B82F6))),
                                                  child: const Text(
                                                      "Review & Pay",
                                                      style: TextStyle(
                                                          color:
                                                              Color(0xFF3B82F6),
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold)),
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    );
                                  },
                                ),
                      ],
                    ), // End inner Column
                  ],
                ), // End outer Column
              ), // End SingleChildScrollView
            ), // End RefreshIndicator
            
            // Loading Overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFF0D1B2A).withOpacity(0.6),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
                  ),
                ),
              ),
          ],
        ), // End Stack
      ), // End SafeArea
    ); // End Scaffold
  }
}

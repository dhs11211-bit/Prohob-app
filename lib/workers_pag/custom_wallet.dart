// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart'; // Imports other custom widgets
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:intl/intl.dart';
import '../backend/api_service.dart';

class CustomWallet extends StatefulWidget {
  const CustomWallet({Key? key, this.width, this.height}) : super(key: key);
  final double? width;
  final double? height;
  @override
  _CustomWalletState createState() => _CustomWalletState();
}

class _CustomWalletState extends State<CustomWallet> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color text = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);

  bool _isLoading = true;
  String _error = '';

  double _hourlyRate = 25.0;
  double _taxRate = 0.15;

  double _thisWeekHours = 0.0;
  double _thisWeekGross = 0.0;
  double _thisWeekNet = 0.0;

  double _lastWeekHours = 0.0;
  double _lastWeekGross = 0.0;
  double _lastWeekNet = 0.0;

  List<Map<String, dynamic>> _thisWeekGrid = [];
  List<Map<String, dynamic>> _lastWeekGrid = [];
  List<dynamic> _recentTransactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final data = await ApiService.instance.get('/earnings');

      _hourlyRate = double.parse(data['hourly_rate'].toString());
      _taxRate = double.parse(data['tax_rate'].toString());

      final tw = data['this_week'];
      _thisWeekHours = double.parse(tw['hours'].toString());
      _thisWeekGross = double.parse(tw['gross'].toString());
      _thisWeekNet = double.parse(tw['net'].toString());

      final lw = data['last_week'];
      _lastWeekHours = double.parse(lw['hours'].toString());
      _lastWeekGross = double.parse(lw['gross'].toString());
      _lastWeekNet = double.parse(lw['net'].toString());

      _recentTransactions = data['recent_transactions'] ?? [];

      _thisWeekGrid = _buildGrid(tw['logs']);
      _lastWeekGrid = _buildGrid(lw['logs']);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _buildGrid(List<dynamic> logs) {
    List<Map<String, dynamic>> grid = [
      {'day': 'Mon', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Tue', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Wed', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Thu', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Fri', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Sat', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'},
      {'day': 'Sun', 'hrs': 0.0, 'pay': 0.0, 'in': '--:--', 'out': '--:--'}
    ];

    for (var log in logs) {
      if (log['clock_in'] != null) {
        DateTime clockIn = DateTime.parse(log['clock_in']);
        int weekdayIndex = clockIn.weekday - 1;

        double hours = double.parse(log['hours'].toString());
        double earned = double.parse(log['earned'].toString());

        grid[weekdayIndex]['hrs'] += hours;
        grid[weekdayIndex]['pay'] += earned;
        grid[weekdayIndex]['in'] = DateFormat('hh:mm a').format(clockIn);
        if (log['clock_out'] != null) {
          grid[weekdayIndex]['out'] =
              DateFormat('hh:mm a').format(DateTime.parse(log['clock_out']));
        } else {
          grid[weekdayIndex]['out'] = 'In Progress';
        }
      }
    }

    return grid;
  }

  void _showModal(String title, Widget content) {
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32))),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: muted.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 24),
                  Text(title,
                      style: TextStyle(
                          color: text,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  content,
                  const SizedBox(height: 30)
                ])));
  }

  void _openLastWeekGraphModal(List<Map<String, dynamic>> lastWeekData) {
    _showModal(
        'Last Week Breakdown',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('HOURS WORKED LAST WEEK',
                style: TextStyle(
                    color: muted, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              height: 150,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: card, borderRadius: BorderRadius.circular(20)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: lastWeekData.map((d) {
                  double factor = (d['hrs'] / 12.0).clamp(0.0, 1.0);
                  return GestureDetector(
                    onTap: () => d['hrs'] > 0
                        ? {
                            Navigator.pop(context),
                            _showModal(
                                '${d['day']} (Last Week)',
                                Column(children: [
                                  _row('Clock In Time', '${d['in']}', false,
                                      valColor: neonAction),
                                  _row('Clock Out Time', '${d['out']}', false,
                                      valColor: accentBlue),
                                  const Divider(color: Colors.white10),
                                  _row('Total Logged Hours',
                                      '${d['hrs'].toStringAsFixed(1)}h', true),
                                  _row('Gross Earned',
                                      '\$${d['pay'].toStringAsFixed(2)}', true)
                                ]))
                          }
                        : null,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (d['hrs'] > 0)
                          Text('${d['hrs'].toStringAsFixed(1)}',
                              style: TextStyle(
                                  color: text,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Container(
                            width: 16,
                            height: 80 * factor,
                            decoration: BoxDecoration(
                                color: d['hrs'] > 0
                                    ? accentBlue
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Text(d['day'],
                            style: TextStyle(color: muted, fontSize: 10))
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ));
  }

  void _showTransactionDetail(Map<String, dynamic> tx) {
    _showModal(
        'Transaction Detail',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: Text('+\$${tx['amount']}',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 40,
                      fontWeight: FontWeight.bold))),
          const SizedBox(height: 24),
          _row('Status', tx['status'] ?? 'Completed', true, valColor: Colors.green),
          _row('Date Processed', tx['date'], false),
          _row('Transaction ID', tx['id'], false),
          _row('Destination', tx['bank'] ?? 'Bank Account', false),
          const Divider(color: Colors.white10, height: 40),
          SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentBlue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: Icon(Icons.download_rounded, color: accentBlue),
                  label: Text('Download PDF Receipt',
                      style: TextStyle(
                          color: accentBlue, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Downloading receipt...')));
                  }))
        ]));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: bg,
        width: widget.width ?? double.infinity,
        height: MediaQuery.of(context).size.height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Container(
        color: bg,
        width: widget.width ?? double.infinity,
        height: MediaQuery.of(context).size.height,
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading wallet data', style: TextStyle(color: muted)),
            const SizedBox(height: 10),
            ElevatedButton(
                onPressed: _fetchWalletData, child: const Text('Retry'))
          ],
        )),
      );
    }

    return Container(
      color: bg,
      width: widget.width ?? double.infinity,
      height: MediaQuery.of(context).size.height,
      child: RefreshIndicator(
        onRefresh: _fetchWalletData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          child: Padding(
            padding: const EdgeInsets.only(
                top: 12, bottom: 120, left: 24, right: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Financial Status',
                          style: TextStyle(
                              color: text,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      GestureDetector(
                          onTap: () => _showModal(
                              'Rate & Tax Details',
                              Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _row('Base Rate',
                                        '\$${_hourlyRate.toStringAsFixed(2)}/hr', true),
                                    _row(
                                        'Est. Withholding Tax',
                                        '${(_taxRate * 100).toInt()}%',
                                        false,
                                        valColor: Colors.redAccent),
                                    const Divider(color: Colors.white10),
                                    Text(
                                        'Your Admin handles your tax rate updates.',
                                        style: TextStyle(
                                            color: muted, fontSize: 12))
                                  ])),
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                  color: accentBlue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(
                                  '\$${_hourlyRate.toStringAsFixed(2)} / hr',
                                  style: TextStyle(
                                      color: accentBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14))))
                    ]),
                const SizedBox(height: 24),
                Container(
                    height: 215,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                        color: card, borderRadius: BorderRadius.circular(24)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('THIS WEEK\'S HOURS',
                              style: TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Expanded(
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _thisWeekGrid.map((d) {
                                    double factor =
                                        (d['hrs'] / 12.0).clamp(0.0, 1.0);
                                    return GestureDetector(
                                        onTap: () => d['hrs'] > 0
                                            ? _showModal(
                                                '${d['day']} Shift Details',
                                                Column(children: [
                                                  _row('Clock In Time',
                                                      '${d['in']}', false,
                                                      valColor: neonAction),
                                                  _row('Clock Out Time',
                                                      '${d['out']}', false,
                                                      valColor: accentBlue),
                                                  const Divider(
                                                      color: Colors.white10),
                                                  _row(
                                                      'Total Logged Hours',
                                                      '${d['hrs'].toStringAsFixed(1)}h',
                                                      true),
                                                  _row(
                                                      'Gross Earned',
                                                      '\$${d['pay'].toStringAsFixed(2)}',
                                                      true)
                                                ]))
                                            : null,
                                        child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              if (d['hrs'] > 0)
                                                Text(
                                                    '${d['hrs'].toStringAsFixed(1)}',
                                                    style: TextStyle(
                                                        color: text,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Container(
                                                  width: 20,
                                                  height: 100 * factor,
                                                  decoration: BoxDecoration(
                                                      color: d['hrs'] > 0
                                                          ? neonAction
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              4))),
                                              const SizedBox(height: 6),
                                              Text(d['day'],
                                                  style: TextStyle(
                                                      color: muted,
                                                      fontSize: 10))
                                            ]));
                                  }).toList()))
                        ])),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(
                      child: GestureDetector(
                          onTap: () => _showModal(
                              'This Week Breakdown',
                              Column(children: [
                                _row(
                                    'Total Week Hours',
                                    '${_thisWeekHours.toStringAsFixed(1)} hrs',
                                    true),
                                _row(
                                    'Gross Payment',
                                    '\$${_thisWeekGross.toStringAsFixed(2)}',
                                    false),
                                _row(
                                    'Taxes Withheld (${(_taxRate * 100).toInt()}%)',
                                    '-\$${(_thisWeekGross * _taxRate).toStringAsFixed(2)}',
                                    false,
                                    valColor: Colors.redAccent),
                                const Divider(color: Colors.white10),
                                _row(
                                    'Net Take-Home Pay',
                                    '\$${_thisWeekNet.toStringAsFixed(2)}',
                                    true,
                                    valColor: neonAction)
                              ])),
                          child: _sumCard(
                              'This Week (Net)',
                              '\$${_thisWeekNet.toStringAsFixed(2)}',
                              '${_thisWeekHours.toStringAsFixed(1)} hrs',
                              neonAction))),
                  const SizedBox(width: 16),
                  Expanded(
                      child: GestureDetector(
                          onTap: () => _openLastWeekGraphModal(_lastWeekGrid),
                          child: _sumCard(
                              'Last Week (Net)',
                              '\$${_lastWeekNet.toStringAsFixed(2)}',
                              '${_lastWeekHours.toStringAsFixed(1)} hrs',
                              accentBlue))),
                ]),
                const SizedBox(height: 32),
                Text('RECENT TRANSACTIONS',
                    style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 16),
                
                if (_recentTransactions.isEmpty)
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 50, horizontal: 20),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(24),
                          border:
                              Border.all(color: Colors.white.withOpacity(0.05))),
                      child: Column(children: [
                        Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: bg, shape: BoxShape.circle),
                            child: Icon(Icons.receipt_long_outlined,
                                color: accentBlue.withOpacity(0.5), size: 50)),
                        const SizedBox(height: 20),
                        Text('No Recent Transactions',
                            style: TextStyle(
                                color: text,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                            'When you get paid, your direct deposits will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: muted, fontSize: 13))
                      ]))
                else
                  Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(24)),
                      child: Column(
                          children: _recentTransactions.map((tx) {
                        Map<String, dynamic> txDataForModal = {
                          'id': tx['id'].toString(),
                          'type': tx['type'] ?? 'Direct Deposit',
                          'date': tx['date'] ?? 'Pending',
                          'amount': double.parse(tx['amount'].toString())
                              .toStringAsFixed(2),
                          'bank': tx['bank'] ?? 'Bank Account',
                          'status': tx['status'] ?? 'Completed'
                        };
                        return Column(children: [
                          InkWell(
                              onTap: () =>
                                  _showTransactionDetail(txDataForModal),
                              child: _txRow(
                                  txDataForModal['type'],
                                  txDataForModal['date'],
                                  '+\$${txDataForModal['amount']}')),
                          if (tx != _recentTransactions.last)
                            const Divider(color: Colors.white10, height: 30)
                        ]);
                      }).toList()))
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sumCard(String t, String a, String h, Color c) => Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(t, style: TextStyle(color: muted, fontSize: 13))
        ]),
        const SizedBox(height: 12),
        Text(a,
            style: TextStyle(
                color: text, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(h, style: TextStyle(color: muted, fontSize: 13))
      ]));
  Widget _row(String l, String v, bool b, {Color? valColor}) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: TextStyle(color: muted, fontSize: 16)),
        Text(v,
            style: TextStyle(
                color: valColor ?? text,
                fontSize: 18,
                fontWeight: b ? FontWeight.bold : FontWeight.normal))
      ]));
  Widget _txRow(String t, String d, String a) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(Icons.account_balance, color: accentBlue, size: 20)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: TextStyle(color: text, fontWeight: FontWeight.bold)),
            Text(d, style: TextStyle(color: muted, fontSize: 12))
          ])
        ]),
        Text(a,
            style: const TextStyle(
                color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16))
      ]);
}

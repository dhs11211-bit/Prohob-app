import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';
import 'quote_signature_screen.dart';

class QuoteDetailScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailScreen({Key? key, required this.quoteId}) : super(key: key);

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color neonAction = const Color(0xFFD4FF00);

  Map<String, dynamic>? _quote;
  bool _isLoading = true;
  
  // Option selection
  int _activeTabIndex = 0; // 0 = Base Quote, 1 = Option 1, etc.

  @override
  void initState() {
    super.initState();
    _fetchQuote();
  }

  Future<void> _fetchQuote() async {
    try {
      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/quotes/${widget.quoteId}',
      );
      
      final data = res['data'];
      setState(() {
        _quote = data;
        
        // If there's options and the quote is still draft/sent, 
        // we might default to the first option instead of Base
        if (data != null && data['options'] != null && data['options'].isNotEmpty) {
          _activeTabIndex = 1; // Default to first option
        }
      });
    } catch (e) {
      debugPrint('Error fetching quote: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'converted':
        return Colors.green;
      case 'declined':
        return Colors.red;
      case 'sent':
      case 'viewed':
        return accentBlue;
      default:
        return muted;
    }
  }

  List<dynamic> _getActiveDetails() {
    if (_quote == null) return [];
    if (_activeTabIndex == 0) return _quote!['details'] ?? [];
    
    final opts = _quote!['options'] ?? [];
    if (opts.isEmpty || _activeTabIndex - 1 >= opts.length) return [];
    return opts[_activeTabIndex - 1]['details'] ?? [];
  }
  
  List<dynamic> _getActiveMaterials() {
    if (_quote == null) return [];
    if (_activeTabIndex == 0) return _quote!['materials'] ?? [];
    
    final opts = _quote!['options'] ?? [];
    if (opts.isEmpty || _activeTabIndex - 1 >= opts.length) return [];
    return opts[_activeTabIndex - 1]['materials'] ?? [];
  }
  
  double _getSubtotal() {
    final details = _getActiveDetails();
    return details.fold(0.0, (sum, item) {
      final q = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final p = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      return sum + (q * p);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          title: const Text('Estimate Detail', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_quote == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
        ),
        body: const Center(
          child: Text('Failed to load estimate', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final status = _quote!['status'] ?? 'draft';
    final customer = _quote!['customer']?['name'] ?? 'Unknown';
    final options = _quote!['options'] ?? [];
    final hasOptions = options.isNotEmpty;
    
    final subtotal = _getSubtotal();
    final taxRate = double.tryParse(_quote!['tax_rate']?.toString() ?? '0') ?? 0;
    final tax = subtotal * (taxRate / 100);
    final discount = double.tryParse(_quote!['discount_value']?.toString() ?? '0') ?? 0;
    final total = subtotal + tax - discount;

    final isPercentage = _quote!['deposit_percentage'] != null;
    final deposit = isPercentage 
      ? total * (double.parse(_quote!['deposit_percentage'].toString()) / 100)
      : double.tryParse(_quote!['deposit_required']?.toString() ?? '0') ?? 0;

    final isReadOnly = ['accepted', 'converted', 'declined'].contains(status.toLowerCase());

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(_quote!['quote_number'] ?? 'Estimate', style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Header Info
                Text(
                  _quote!['title'] ?? 'Estimate',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Prepared for: $customer', style: TextStyle(color: muted, fontSize: 16)),
                const SizedBox(height: 24),

                // Options Tabs
                if (hasOptions) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(0, 'Base Quote'),
                        for (int i = 0; i < options.length; i++)
                          _buildTabButton(i + 1, options[i]['name'] ?? 'Option ${i+1}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                // Active Option Notes
                if (_activeTabIndex > 0 && options[_activeTabIndex - 1]['notes'] != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentBlue.withOpacity(0.3)),
                    ),
                    child: Text(
                      options[_activeTabIndex - 1]['notes'],
                      style: TextStyle(color: accentBlue.withOpacity(0.9), fontSize: 14),
                    ),
                  ),

                // Line Items
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Line Items',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ..._getActiveDetails().map((item) {
                        final q = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                        final p = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    if (item['description'] != null)
                                      Text(item['description'], style: TextStyle(color: muted, fontSize: 12)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat.currency(symbol: '\$').format(q * p),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${q}x @ \$${p}',
                                    style: TextStyle(color: muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Materials
                if (_getActiveMaterials().isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Materials & Supplies',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ..._getActiveMaterials().map((mat) {
                          final q = double.tryParse(mat['quantity_required']?.toString() ?? '1') ?? 1;
                          final c = double.tryParse(mat['unit_cost']?.toString() ?? '0') ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(mat['name'] ?? '', style: TextStyle(color: Colors.white70))),
                                Text(
                                  '${q}x @ \$${c}',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Financials
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTotalsRow('Subtotal', subtotal),
                      if (tax > 0) _buildTotalsRow('Tax ($taxRate%)', tax),
                      if (discount > 0) _buildTotalsRow('Discount', discount, isRed: true),
                      const Divider(color: Colors.white24, height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(NumberFormat.currency(symbol: '\$').format(total), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (deposit > 0) ...[
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Required Deposit', style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                            Text(NumberFormat.currency(symbol: '\$').format(deposit), style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ]
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
          ),
          
          // Bottom Action
          if (!isReadOnly)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: bg,
                border: const Border(top: BorderSide(color: Colors.white10)),
              ),
              child: ElevatedButton(
                onPressed: () async {
                  int? optId;
                  if (_activeTabIndex > 0) {
                    optId = options[_activeTabIndex - 1]['id'];
                  }
                  
                  final success = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QuoteSignatureScreen(
                        quoteId: widget.quoteId,
                        selectedOptionId: optId,
                      ),
                    ),
                  );
                  
                  if (success == true) {
                    _fetchQuote(); // Reload to show accepted status
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('Accept & Sign', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isActive = _activeTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? accentBlue : card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? accentBlue : Colors.white24),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : muted,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsRow(String label, double amount, {bool isRed = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: muted)),
          Text(
            isRed ? '-${NumberFormat.currency(symbol: '\$').format(amount)}' : NumberFormat.currency(symbol: '\$').format(amount),
            style: TextStyle(color: isRed ? Colors.redAccent : Colors.white),
          ),
        ],
      ),
    );
  }
}

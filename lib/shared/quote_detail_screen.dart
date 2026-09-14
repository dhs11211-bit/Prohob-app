import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '/backend/api_service.dart';
import 'quote_signature_screen.dart';
import 'job_detail_screen.dart';
import 'create_quote_screen.dart';
import '/shared/toast_service.dart';

class QuoteDetailScreen extends StatefulWidget {
  final int quoteId;

  const QuoteDetailScreen({Key? key, required this.quoteId}) : super(key: key);

  @override
  State<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends State<QuoteDetailScreen> {
  final Color bg = const Color(0xFF0F172A);
  final Color card = const Color(0xFF1E293B);
  final Color cardBorder = const Color(0xFF334155);
  final Color textWhite = Colors.white;
  final Color muted = const Color(0xFF94A3B8);
  final Color accentBlue = const Color(0xFF3B82F6);
  final Color purple = const Color(0xFF8B5CF6);
  final Color neonAction = const Color(0xFFD4FF00);
  final Color accentGreen = const Color(0xFF10B981);
  final Color accentAmber = const Color(0xFFF59E0B);
  final Color accentRed = const Color(0xFFEF4444);

  Map<String, dynamic>? _quote;
  bool _isLoading = true;
  bool _isActionRunning = false;
  
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
      
      Map<String, dynamic>? data;
      if (res.containsKey('data') && res['data'] is Map) {
        data = Map<String, dynamic>.from(res['data']);
      } else {
        data = Map<String, dynamic>.from(res);
      }

      if (mounted) {
        setState(() {
          _quote = data;
          if (data != null && data['options'] != null && (data['options'] as List).isNotEmpty) {
            final selectedOptId = data['selected_option_id'];
            if (selectedOptId != null) {
              final options = data['options'] as List;
              final idx = options.indexWhere((o) => o['id'] == selectedOptId);
              if (idx >= 0) {
                _activeTabIndex = idx + 1;
              }
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching quote: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return accentGreen;
      case 'converted':
        return const Color(0xFF10B981);
      case 'declined':
        return accentRed;
      case 'sent':
        return accentBlue;
      case 'viewed':
        return purple;
      case 'expired':
        return accentAmber;
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

  double _getMaterialsTotal() {
    final mats = _getActiveMaterials();
    return mats.fold(0.0, (sum, m) {
      final q = double.tryParse(m['quantity_required']?.toString() ?? '1') ?? 1;
      final p = double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0;
      return sum + (q * p);
    });
  }

  double _getTotalCost() {
    double itemCost = 0;
    for (final item in _getActiveDetails()) {
      final q = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      final c = double.tryParse(item['cost']?.toString() ?? '0') ?? 0;
      itemCost += (q * c);
    }
    return itemCost + _getMaterialsTotal();
  }

  // --- Zero-Blind-Click Dialog ---
  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
    IconData? icon,
  }) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: isDestructive ? accentRed : accentBlue, size: 22),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? accentRed : accentBlue,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  // --- Lifecycle Action Handlers ---

  Future<void> _convertQuoteToJob() async {
    final confirmed = await _showConfirmDialog(
      title: 'Convert Estimate to Job',
      message: 'This will approve the estimate and create an active field job with all items and materials. Proceed?',
      confirmText: 'Convert to Job',
      icon: Icons.work_outline_rounded,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      final res = await ApiService.instance.request(
        method: 'POST',
        endpoint: '/quotes/${widget.quoteId}/convert',
      );

      if (mounted) ToastService.success(context, 'Estimate converted to Job successfully!');

      final jobData = res.containsKey('data') ? res['data'] : res;
      final rawJobId = jobData is Map ? jobData['id'] : null;
      final int? jobId = rawJobId is int ? rawJobId : int.tryParse(rawJobId?.toString() ?? '');

      if (jobId != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SharedJobDetailScreen(jobId: jobId)),
        );
      } else {
        _fetchQuote();
      }
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to convert quote: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _createInvoice() async {
    final confirmed = await _showConfirmDialog(
      title: 'Create Invoice from Estimate',
      message: 'This will generate a billing invoice with all line items and materials. Proceed?',
      confirmText: 'Create Invoice',
      icon: Icons.receipt_long_rounded,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      await ApiService.instance.request(
        method: 'POST',
        endpoint: '/quotes/${widget.quoteId}/create-invoice',
      );
      if (mounted) ToastService.success(context, 'Invoice created successfully!');
      _fetchQuote();
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to create invoice: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _duplicateQuote() async {
    final confirmed = await _showConfirmDialog(
      title: 'Duplicate Estimate',
      message: 'Create an identical draft copy of this estimate?',
      confirmText: 'Duplicate',
      icon: Icons.copy_rounded,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      final res = await ApiService.instance.request(
        method: 'POST',
        endpoint: '/quotes/${widget.quoteId}/duplicate',
      );
      final newQuote = res.containsKey('data') ? res['data'] : res;
      if (mounted) ToastService.success(context, 'Estimate duplicated successfully!');

      if (newQuote?['id'] != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => QuoteDetailScreen(quoteId: newQuote['id'])),
        );
      }
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to duplicate: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _markAcceptedManually() async {
    final confirmed = await _showConfirmDialog(
      title: 'Mark Accepted (Staff)',
      message: 'Mark this estimate as accepted on behalf of the customer?',
      confirmText: 'Mark Accepted',
      icon: Icons.check_circle_outline,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      await ApiService.instance.request(
        method: 'POST',
        endpoint: '/quotes/${widget.quoteId}/accept-manual',
      );
      if (mounted) ToastService.success(context, 'Estimate marked as accepted!');
      _fetchQuote();
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _revertToDraft() async {
    final confirmed = await _showConfirmDialog(
      title: 'Revert to Draft',
      message: 'Reverting allows you to modify line items and options again. Proceed?',
      confirmText: 'Revert to Draft',
      icon: Icons.undo_rounded,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      await ApiService.instance.request(
        method: 'POST',
        endpoint: '/quotes/${widget.quoteId}/revert-draft',
      );
      if (mounted) ToastService.success(context, 'Estimate reverted to draft.');
      _fetchQuote();
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to revert: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _deleteQuote() async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Estimate',
      message: 'Are you sure you want to delete this estimate? This action cannot be undone.',
      confirmText: 'Delete',
      isDestructive: true,
      icon: Icons.delete_forever,
    );
    if (!confirmed) return;

    setState(() => _isActionRunning = true);
    try {
      await ApiService.instance.request(
        method: 'DELETE',
        endpoint: '/quotes/${widget.quoteId}',
      );
      if (mounted) {
        ToastService.info(context, 'Estimate deleted.');
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to delete: $e');
    } finally {
      if (mounted) setState(() => _isActionRunning = false);
    }
  }

  Future<void> _downloadPdf() async {
    try {
      final token = await ApiService.instance.getToken();
      final url = '${ApiService.baseUrl}/quotes/${widget.quoteId}/pdf' +
          (token != null ? '?token=$token' : '');
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) ToastService.error(context, 'Could not open PDF viewer');
      }
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to open PDF: $e');
    }
  }

  void _openSendModal() {
    final customer = _quote!['customer'];
    final defaultEmail = customer?['email'] ?? '';
    final emailCtrl = TextEditingController(text: defaultEmail);
    final subjectCtrl = TextEditingController(text: 'Estimate #${_quote!['quote_number']}: ${_quote!['title'] ?? 'Proposal'}');
    final msgCtrl = TextEditingController(text: 'Hello ${customer?['first_name'] ?? 'there'},\n\nPlease review your estimate proposal attached as a PDF.');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Send Estimate Proposal', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: accentBlue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Branded company PDF is automatically compiled and attached to this email.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Recipient Email *',
                labelStyle: TextStyle(color: muted),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: subjectCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Subject',
                labelStyle: TextStyle(color: muted),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: msgCtrl,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Message Body',
                labelStyle: TextStyle(color: muted),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (emailCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  setState(() => _isActionRunning = true);
                  try {
                    await ApiService.instance.request(
                      method: 'POST',
                      endpoint: '/quotes/${widget.quoteId}/send',
                      body: {
                        'recipient_email': emailCtrl.text.trim(),
                        'subject': subjectCtrl.text.trim(),
                        'message': msgCtrl.text.trim(),
                      },
                    );
                    if (mounted) ToastService.success(context, 'Estimate sent to customer!');
                    _fetchQuote();
                  } catch (e) {
                    if (mounted) ToastService.error(context, 'Failed to send estimate: $e');
                  } finally {
                    if (mounted) setState(() => _isActionRunning = false);
                  }
                },
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send Estimate Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Visual Stepper Widget ---
  Widget _buildLifecycleStepper(String status) {
    final stages = ['draft', 'sent', 'viewed', 'accepted', 'converted'];
    final currentIdx = stages.indexOf(status.toLowerCase());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Proposal Lifecycle', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              if (status.toLowerCase() == 'declined')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: accentRed.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('DECLINED', style: TextStyle(color: accentRed, fontSize: 10, fontWeight: FontWeight.bold)),
                )
              else if (status.toLowerCase() == 'expired')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: accentAmber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                  child: Text('EXPIRED', style: TextStyle(color: accentAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(stages.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepBefore = index ~/ 2;
                final isDone = currentIdx >= 0 && stepBefore < currentIdx;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isDone ? neonAction : Colors.white12,
                  ),
                );
              }

              final stepIdx = index ~/ 2;
              final stageName = stages[stepIdx];
              final isPassed = currentIdx >= 0 && stepIdx <= currentIdx;
              final isCurrent = currentIdx >= 0 && stepIdx == currentIdx;

              return Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isPassed ? (isCurrent ? neonAction : accentBlue) : bg,
                      border: Border.all(
                        color: isPassed ? (isCurrent ? neonAction : accentBlue) : Colors.white24,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: isPassed && !isCurrent
                          ? const Icon(Icons.check, size: 12, color: Colors.white)
                          : Text(
                              '${stepIdx + 1}',
                              style: TextStyle(
                                color: isCurrent ? Colors.black : Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stageName[0].toUpperCase() + stageName.substring(1),
                    style: TextStyle(
                      color: isCurrent ? Colors.white : muted,
                      fontSize: 10,
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // --- Customer Card Widget ---
  Widget _buildCustomerCard(Map<String, dynamic>? customer, Map<String, dynamic>? address) {
    if (customer == null) return const SizedBox.shrink();

    final fn = customer['first_name'] ?? '';
    final ln = customer['last_name'] ?? '';
    final name = '$fn $ln'.trim();
    final company = customer['company_name'];
    final phone = customer['phone'] ?? customer['mobile'];
    final email = customer['email'];

    String addressText = '';
    if (address != null) {
      final street = address['address_line1'] ?? address['street'] ?? '';
      final city = address['city'] ?? '';
      final st = address['state'] ?? '';
      addressText = '$street, $city $st'.trim();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: accentBlue.withOpacity(0.2),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                  style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : 'Customer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (company != null && company.toString().isNotEmpty)
                      Text(company.toString(), style: TextStyle(color: muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          if (addressText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: muted),
                const SizedBox(width: 6),
                Expanded(child: Text(addressText, style: TextStyle(color: muted, fontSize: 12))),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              if (phone != null && phone.toString().isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    icon: const Icon(Icons.call, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentGreen,
                      side: BorderSide(color: accentGreen.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              if (phone != null && phone.toString().isNotEmpty && email != null)
                const SizedBox(width: 8),
              if (email != null && email.toString().isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('mailto:$email')),
                    icon: const Icon(Icons.email_outlined, size: 14),
                    label: const Text('Email', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentBlue,
                      side: BorderSide(color: accentBlue.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              if (addressText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final query = Uri.encodeComponent(addressText);
                      launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$query'));
                    },
                    icon: const Icon(Icons.map_outlined, size: 14),
                    label: const Text('Map', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: purple,
                      side: BorderSide(color: purple.withOpacity(0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_quote == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg, elevation: 0),
        body: const Center(child: Text('Failed to load estimate', style: TextStyle(color: Colors.white))),
      );
    }

    final status = _quote!['status'] ?? 'draft';
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

    final totalCost = _getTotalCost();
    final grossProfit = (subtotal - discount) - totalCost;
    final marginPct = (subtotal - discount) > 0 ? (grossProfit / (subtotal - discount)) * 100 : 0.0;

    final isConverted = status.toLowerCase() == 'converted';
    final isAccepted = status.toLowerCase() == 'accepted';
    final isDraft = status.toLowerCase() == 'draft';

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(_quote!['quote_number'] ?? 'Estimate', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.18),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.4)),
              ),
              child: Text(
                status.toUpperCase(),
                style: TextStyle(
                  color: _getStatusColor(status),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            color: card,
            onSelected: (val) {
              switch (val) {
                case 'send':
                  _openSendModal();
                  break;
                case 'convert_job':
                  _convertQuoteToJob();
                  break;
                case 'create_invoice':
                  _createInvoice();
                  break;
                case 'duplicate':
                  _duplicateQuote();
                  break;
                case 'revert_draft':
                  _revertToDraft();
                  break;
                case 'mark_accepted':
                  _markAcceptedManually();
                  break;
                case 'edit':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CreateQuoteScreen(initialQuote: _quote)),
                  ).then((_) => _fetchQuote());
                  break;
                case 'download_pdf':
                  _downloadPdf();
                  break;
                case 'delete':
                  _deleteQuote();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              if (isDraft || status == 'sent')
                const PopupMenuItem(value: 'send', child: Text('Send to Customer', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'download_pdf', child: Text('Download / View PDF', style: TextStyle(color: Colors.white))),
              if (!isConverted)
                const PopupMenuItem(value: 'convert_job', child: Text('1-Click Convert to Job', style: TextStyle(color: Color(0xFF10B981)))),
              const PopupMenuItem(value: 'create_invoice', child: Text('Create Invoice', style: TextStyle(color: Colors.white))),
              const PopupMenuItem(value: 'duplicate', child: Text('Duplicate Estimate', style: TextStyle(color: Colors.white))),
              if (!isDraft && !isConverted)
                const PopupMenuItem(value: 'revert_draft', child: Text('Revert to Draft', style: TextStyle(color: Colors.white))),
              if (!isAccepted && !isConverted)
                const PopupMenuItem(value: 'mark_accepted', child: Text('Mark Accepted Manually', style: TextStyle(color: Colors.white))),
              if (isDraft)
                const PopupMenuItem(value: 'edit', child: Text('Edit Estimate', style: TextStyle(color: Colors.white))),
              if (!isConverted)
                const PopupMenuItem(value: 'delete', child: Text('Delete Estimate', style: TextStyle(color: Colors.redAccent))),
            ],
          ),
        ],
      ),
      body: _isActionRunning
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4FF00)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Visual Lifecycle Stepper
                _buildLifecycleStepper(status),
                const SizedBox(height: 16),

                // 2. Customer Action Card
                _buildCustomerCard(_quote!['customer'], _quote!['address']),
                const SizedBox(height: 16),

                // 3. Estimate Details Header
                Text(
                  _quote!['title'] ?? 'Estimate',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (_quote!['introduction'] != null) ...[
                  const SizedBox(height: 6),
                  Text(_quote!['introduction'], style: TextStyle(color: muted, fontSize: 14)),
                ],
                const SizedBox(height: 20),

                // 4. Multi-tier Options Tabs
                if (hasOptions) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildTabButton(0, 'Base Quote'),
                        for (int i = 0; i < options.length; i++)
                          _buildTabButton(i + 1, options[i]['name'] ?? 'Option ${i + 1}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. Line Items ("Our Item Project Way")
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Line Items',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ..._getActiveDetails().map((item) {
                        final q = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                        final p = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                        final category = item['category']?['name'];

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
                                    if (category != null) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: purple.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(category, style: TextStyle(color: purple, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    NumberFormat.currency(symbol: '\$').format(q * p),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  Text(
                                    '${q} ${item['unit'] ?? 'unit'} @ \$${p}',
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

                // 6. Materials
                if (_getActiveMaterials().isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Required Materials & Supplies',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        ..._getActiveMaterials().map((mat) {
                          final q = double.tryParse(mat['quantity_required']?.toString() ?? '1') ?? 1;
                          final c = double.tryParse(mat['unit_price']?.toString() ?? '0') ?? 0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(mat['name'] ?? '', style: const TextStyle(color: Colors.white70))),
                                Text('${q} ${mat['unit'] ?? 'unit'} @ \$${c}', style: TextStyle(color: muted, fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 7. Financial Breakdown & Margin
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTotalsRow('Subtotal', subtotal),
                      if (tax > 0) _buildTotalsRow('Tax ($taxRate%)', tax),
                      if (discount > 0) _buildTotalsRow('Discount', discount, isRed: true),
                      const Divider(color: Colors.white24, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(NumberFormat.currency(symbol: '\$').format(total), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (deposit > 0) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Required Deposit Due', style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                            Text(NumberFormat.currency(symbol: '\$').format(deposit), style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                      const Divider(color: Colors.white12, height: 24),
                      // Estimator Margin Preview
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Total Est. Cost', style: TextStyle(color: muted, fontSize: 11)),
                              Text(NumberFormat.currency(symbol: '\$').format(totalCost), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gross Profit', style: TextStyle(color: muted, fontSize: 11)),
                              Text(NumberFormat.currency(symbol: '\$').format(grossProfit), style: TextStyle(color: marginPct >= 30 ? accentGreen : accentAmber, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (marginPct >= 30 ? accentGreen : accentAmber).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${marginPct.toStringAsFixed(1)}% Margin',
                              style: TextStyle(color: marginPct >= 30 ? accentGreen : accentAmber, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 8. Notes & Terms
                if (_quote!['notes'] != null || _quote!['internal_notes'] != null || _quote!['terms'] != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_quote!['notes'] != null) ...[
                          const Text('Customer Notes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(_quote!['notes'], style: TextStyle(color: muted, fontSize: 13)),
                          const SizedBox(height: 12),
                        ],
                        if (_quote!['internal_notes'] != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentAmber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: accentAmber.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lock_outline, size: 12, color: accentAmber),
                                    const SizedBox(width: 4),
                                    Text('Internal Staff Note', style: TextStyle(color: accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_quote!['internal_notes'], style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (_quote!['terms'] != null) ...[
                          const Text('Terms & Conditions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(_quote!['terms'], style: TextStyle(color: muted, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // 9. Quick Actions Row
                if (!isConverted) ...[
                  ElevatedButton.icon(
                    onPressed: _convertQuoteToJob,
                    icon: const Icon(Icons.flash_on_rounded, size: 18),
                    label: const Text('1-Click Convert to Job', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (!isConverted && !isAccepted) ...[
                  OutlinedButton.icon(
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
                      if (success == true) _fetchQuote();
                    },
                    icon: const Icon(Icons.draw_rounded, size: 18),
                    label: const Text('Sign Proposal with Client', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accentBlue,
                      side: BorderSide(color: accentBlue),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                OutlinedButton.icon(
                  onPressed: _openSendModal,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Send Estimate via Email', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                  label: const Text('Download / Preview PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 30),
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
          border: Border.all(color: isActive ? accentBlue : cardBorder),
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

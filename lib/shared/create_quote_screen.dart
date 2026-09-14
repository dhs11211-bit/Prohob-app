import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/api_service.dart';
import '/shared/toast_service.dart';

class CreateQuoteScreen extends StatefulWidget {
  final Map<String, dynamic>? initialQuote;

  const CreateQuoteScreen({Key? key, this.initialQuote}) : super(key: key);

  @override
  State<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends State<CreateQuoteScreen> {
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

  final _formKey = GlobalKey<FormState>();

  // Customer & Location
  List<dynamic> _customers = [];
  Map<String, dynamic>? _selectedCustomer;
  List<dynamic> _addresses = [];
  Map<String, dynamic>? _selectedAddress;
  bool _isLoadingCustomers = true;

  // Basic Details
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _introController = TextEditingController();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 30));
  
  // Tax & Discount
  final TextEditingController _taxRateController = TextEditingController(text: '0');
  String _discountType = 'fixed'; // 'fixed' or 'percentage'
  final TextEditingController _discountValController = TextEditingController(text: '0');

  // Deposit
  String _depositMode = 'fixed'; // 'fixed' or 'percentage'
  final TextEditingController _depositRequiredController = TextEditingController(text: '0');
  final TextEditingController _depositPctController = TextEditingController(text: '0');

  // Line Items & Materials
  List<Map<String, dynamic>> _details = [];
  List<Map<String, dynamic>> _materials = [];

  // Multi-tier options
  bool _enableOptions = false;
  List<Map<String, dynamic>> _options = []; // [{name: 'Option 1', notes: '', details: [], materials: []}]

  // Notes & Terms
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _internalNotesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _introController.dispose();
    _taxRateController.dispose();
    _discountValController.dispose();
    _depositRequiredController.dispose();
    _depositPctController.dispose();
    _notesController.dispose();
    _internalNotesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _fetchCustomers(),
      _fetchSettings(),
    ]);

    if (widget.initialQuote != null) {
      _populateFromQuote(widget.initialQuote!);
    }
  }

  void _populateFromQuote(Map<String, dynamic> q) {
    _titleController.text = q['title'] ?? '';
    _introController.text = q['introduction'] ?? '';
    _taxRateController.text = (q['tax_rate'] ?? 0).toString();
    _discountType = q['discount_type'] ?? 'fixed';
    _discountValController.text = (q['discount_value'] ?? 0).toString();

    if (q['deposit_percentage'] != null) {
      _depositMode = 'percentage';
      _depositPctController.text = q['deposit_percentage'].toString();
    } else {
      _depositMode = 'fixed';
      _depositRequiredController.text = (q['deposit_required'] ?? 0).toString();
    }

    _notesController.text = q['notes'] ?? '';
    _internalNotesController.text = q['internal_notes'] ?? '';
    _termsController.text = q['terms'] ?? '';

    if (q['details'] != null && q['details'] is List) {
      _details = List<Map<String, dynamic>>.from(q['details']);
    }
    if (q['materials'] != null && q['materials'] is List) {
      _materials = List<Map<String, dynamic>>.from(q['materials']);
    }
    if (q['options'] != null && q['options'] is List && (q['options'] as List).isNotEmpty) {
      _enableOptions = true;
      _options = List<Map<String, dynamic>>.from(q['options']);
    }

    if (q['customer_id'] != null) {
      final cust = _customers.firstWhere(
        (c) => c['id'] == q['customer_id'],
        orElse: () => null,
      );
      if (cust != null) {
        _onCustomerSelected(cust, addressId: q['address_id']);
      }
    }
    setState(() {});
  }

  Future<void> _fetchSettings() async {
    try {
      final res = await ApiService.instance.request(method: 'GET', endpoint: '/settings');
      final tax = res['tax_rate'] ?? res['default_tax_rate'];
      if (tax != null && _taxRateController.text == '0') {
        _taxRateController.text = tax.toString();
      }
    } catch (_) {}
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await ApiService.instance.request(method: 'GET', endpoint: '/customers');
      List<dynamic> list = [];
      final raw = res['data'];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'];
      }
      setState(() {
        _customers = list;
        _isLoadingCustomers = false;
      });
    } catch (e) {
      debugPrint('Error fetching customers: $e');
      setState(() => _isLoadingCustomers = false);
    }
  }

  Future<void> _onCustomerSelected(Map<String, dynamic> customer, {dynamic addressId}) async {
    setState(() {
      _selectedCustomer = customer;
      _selectedAddress = null;
      _addresses = [];
    });

    try {
      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/addresses',
        queryParams: {'customer_id': customer['id']},
      );
      List<dynamic> addrs = [];
      final raw = res['data'];
      if (raw is List) {
        addrs = raw;
      }
      setState(() {
        _addresses = addrs;
        if (addressId != null) {
          _selectedAddress = addrs.firstWhere((a) => a['id'] == addressId, orElse: () => null);
        }
        if (_selectedAddress == null && addrs.isNotEmpty) {
          _selectedAddress = addrs.firstWhere(
            (a) => a['is_primary'] == true || a['is_primary'] == 1,
            orElse: () => addrs.first,
          );
        }
      });
    } catch (e) {
      debugPrint('Error fetching customer addresses: $e');
    }
  }

  // Financial Calculations
  double get _subtotal {
    return _details.fold(0.0, (sum, d) {
      final q = double.tryParse(d['quantity']?.toString() ?? '1') ?? 1;
      final p = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
      return sum + (q * p);
    });
  }

  double get _materialsSubtotal {
    return _materials.fold(0.0, (sum, m) {
      final q = double.tryParse(m['quantity_required']?.toString() ?? '1') ?? 1;
      final p = double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0;
      return sum + (q * p);
    });
  }

  double get _discountAmount {
    final sub = _subtotal;
    final val = double.tryParse(_discountValController.text) ?? 0;
    if (_discountType == 'percentage') {
      return sub * (val / 100);
    }
    return val > sub ? sub : val;
  }

  double get _taxableSubtotal {
    double taxable = 0;
    for (final d in _details) {
      if (d['taxable'] == true || d['taxable'] == 1 || d['taxable'] == null) {
        final q = double.tryParse(d['quantity']?.toString() ?? '1') ?? 1;
        final p = double.tryParse(d['price']?.toString() ?? '0') ?? 0;
        taxable += (q * p);
      }
    }
    return taxable;
  }

  double get _taxAmount {
    final sub = _subtotal;
    if (sub <= 0) return 0;
    final ratio = (sub - _discountAmount) / sub;
    final rate = double.tryParse(_taxRateController.text) ?? 0;
    return (_taxableSubtotal * ratio) * (rate / 100);
  }

  double get _total {
    return (_subtotal - _discountAmount) + _taxAmount;
  }

  double get _totalCost {
    double cost = 0;
    for (final d in _details) {
      final q = double.tryParse(d['quantity']?.toString() ?? '1') ?? 1;
      final c = double.tryParse(d['cost']?.toString() ?? '0') ?? 0;
      cost += (q * c);
    }
    cost += _materialsSubtotal;
    return cost;
  }

  double get _grossProfit {
    final revenue = _subtotal - _discountAmount;
    return revenue - _totalCost;
  }

  double get _marginPercentage {
    final revenue = _subtotal - _discountAmount;
    if (revenue <= 0) return 0;
    return (_grossProfit / revenue) * 100;
  }

  double get _depositDue {
    if (_depositMode == 'percentage') {
      final pct = double.tryParse(_depositPctController.text) ?? 0;
      return _total * (pct / 100);
    }
    return double.tryParse(_depositRequiredController.text) ?? 0;
  }

  Future<void> _openCatalogPicker() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CatalogPickerSheet(
        onItemSelected: (item) {
          setState(() {
            _details.add({
              'item_id': item['id'],
              'name': item['name'] ?? 'Line Item',
              'description': item['description'],
              'quantity': 1,
              'price': double.tryParse(item['price']?.toString() ?? '0') ?? 0,
              'cost': double.tryParse(item['cost']?.toString() ?? '0') ?? 0,
              'unit': item['unit'] ?? 'unit',
              'taxable': item['taxable'] ?? true,
              'category_id': item['category_id'],
              'category_name': item['category']?['name'],
              'category_color': item['category']?['color'],
            });
          });
        },
        onAddCustom: () => _openCustomItemDialog(),
      ),
    );
  }

  void _openCustomItemDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final existing = isEdit ? _details[editIndex] : null;

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final qtyCtrl = TextEditingController(text: (existing?['quantity'] ?? 1).toString());
    final priceCtrl = TextEditingController(text: (existing?['price'] ?? 0).toString());
    final costCtrl = TextEditingController(text: (existing?['cost'] ?? 0).toString());
    final unitCtrl = TextEditingController(text: existing?['unit'] ?? 'unit');
    bool taxable = existing?['taxable'] ?? true;
    bool saveToCatalog = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEdit ? 'Edit Line Item' : 'Add Custom Line Item',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField('Item / Service Name *', nameCtrl),
                const SizedBox(height: 12),
                _buildTextField('Description / Scope', descCtrl, maxLines: 2),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Quantity', qtyCtrl, isNumeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField('Unit (hr, sqft, unit)', unitCtrl)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildTextField('Unit Price (\$)', priceCtrl, isNumeric: true)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildTextField('Unit Cost (\$)', costCtrl, isNumeric: true)),
                  ],
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Taxable item', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  value: taxable,
                  activeColor: accentBlue,
                  onChanged: (v) => setDialogState(() => taxable = v ?? true),
                ),
                if (!isEdit && (existing?['item_id'] == null))
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Save to Items Catalog', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Adds this service to your reusable catalog', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    value: saveToCatalog,
                    activeColor: purple,
                    onChanged: (v) => setDialogState(() => saveToCatalog = v),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: muted)),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                final itemData = {
                  'id': existing?['id'],
                  'item_id': existing?['item_id'],
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  'quantity': double.tryParse(qtyCtrl.text) ?? 1,
                  'price': double.tryParse(priceCtrl.text) ?? 0,
                  'cost': double.tryParse(costCtrl.text) ?? 0,
                  'unit': unitCtrl.text.trim().isEmpty ? 'unit' : unitCtrl.text.trim(),
                  'taxable': taxable,
                  'save_to_catalog': saveToCatalog,
                };
                setState(() {
                  if (isEdit) {
                    _details[editIndex] = itemData;
                  } else {
                    _details.add(itemData);
                  }
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
              child: Text(isEdit ? 'Save Changes' : 'Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  void _openMaterialDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final existing = isEdit ? _materials[editIndex] : null;

    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final descCtrl = TextEditingController(text: existing?['description'] ?? '');
    final qtyCtrl = TextEditingController(text: (existing?['quantity_required'] ?? 1).toString());
    final priceCtrl = TextEditingController(text: (existing?['unit_price'] ?? 0).toString());
    final unitCtrl = TextEditingController(text: existing?['unit'] ?? 'unit');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isEdit ? 'Edit Material / Part' : 'Add Material / Part',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField('Material / Part Name *', nameCtrl),
              const SizedBox(height: 12),
              _buildTextField('Description / Notes', descCtrl, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildTextField('Quantity', qtyCtrl, isNumeric: true)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTextField('Unit (ea, ft, box)', unitCtrl)),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField('Unit Cost (\$)', priceCtrl, isNumeric: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: muted)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              final q = double.tryParse(qtyCtrl.text) ?? 1;
              final p = double.tryParse(priceCtrl.text) ?? 0;
              final matData = {
                'id': existing?['id'],
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'quantity_required': q,
                'unit_price': p,
                'total_price': q * p,
                'unit': unitCtrl.text.trim().isEmpty ? 'unit' : unitCtrl.text.trim(),
              };
              setState(() {
                if (isEdit) {
                  _materials[editIndex] = matData;
                } else {
                  _materials.add(matData);
                }
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: purple),
            child: Text(isEdit ? 'Save' : 'Add Material'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadTermsTemplate() async {
    try {
      final res = await ApiService.instance.request(method: 'GET', endpoint: '/terms-templates');
      List<dynamic> templates = [];
      final raw = res['data'];
      if (raw is List) {
        templates = raw;
      }

      if (templates.isEmpty) {
        if (mounted) ToastService.info(context, 'No terms templates found.');
        return;
      }

      showModalBottomSheet(
        context: context,
        backgroundColor: card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: templates.length,
          separatorBuilder: (_, __) => const Divider(color: Colors.white10),
          itemBuilder: (ctx, idx) {
            final t = templates[idx];
            return ListTile(
              title: Text(t['name'] ?? 'Template', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(
                t['content'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: muted, fontSize: 12),
              ),
              onTap: () {
                setState(() => _termsController.text = t['content'] ?? '');
                Navigator.pop(ctx);
                ToastService.success(context, 'Template applied.');
              },
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) ToastService.error(context, 'Failed to load templates: $e');
    }
  }

  Future<void> _saveQuote({bool sendImmediately = false}) async {
    if (_selectedCustomer == null) {
      ToastService.warning(context, 'Please select a customer.');
      return;
    }

    if (_details.isEmpty && !_enableOptions) {
      ToastService.warning(context, 'Please add at least one line item.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final payload = {
        'customer_id': _selectedCustomer!['id'],
        'address_id': _selectedAddress?['id'],
        'title': _titleController.text.trim().isEmpty ? 'Estimate' : _titleController.text.trim(),
        'introduction': _introController.text.trim().isEmpty ? null : _introController.text.trim(),
        'expiry_date': DateFormat('yyyy-MM-dd').format(_expiryDate),
        'tax_rate': double.tryParse(_taxRateController.text) ?? 0,
        'discount_type': _discountType,
        'discount_value': double.tryParse(_discountValController.text) ?? 0,
        'deposit_required': _depositMode == 'fixed' ? (double.tryParse(_depositRequiredController.text) ?? 0) : null,
        'deposit_percentage': _depositMode == 'percentage' ? (double.tryParse(_depositPctController.text) ?? 0) : null,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        'internal_notes': _internalNotesController.text.trim().isEmpty ? null : _internalNotesController.text.trim(),
        'terms': _termsController.text.trim().isEmpty ? null : _termsController.text.trim(),
        'status': sendImmediately ? 'sent' : 'draft',
        'details': _details,
        'materials': _materials,
        if (_enableOptions) 'options': _options,
      };

      dynamic savedQuote;
      if (widget.initialQuote != null && widget.initialQuote!['id'] != null) {
        savedQuote = await ApiService.instance.request(
          method: 'PUT',
          endpoint: '/quotes/${widget.initialQuote!['id']}',
          body: payload,
        );
      } else {
        savedQuote = await ApiService.instance.request(
          method: 'POST',
          endpoint: '/quotes',
          body: payload,
        );
      }

      final dynamic quoteId = (savedQuote is Map && savedQuote.containsKey('data') && savedQuote['data'] is Map)
          ? savedQuote['data']['id']
          : (savedQuote is Map ? savedQuote['id'] : null);

      if (sendImmediately && quoteId != null) {
        await ApiService.instance.request(
          method: 'POST',
          endpoint: '/quotes/$quoteId/send',
          body: {
            'recipient_email': _selectedCustomer!['email'],
          },
        );
      }

      if (mounted) {
        ToastService.success(
          context,
          sendImmediately ? 'Quote created and sent to customer!' : 'Quote saved successfully!',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Error saving quote: $e');
      if (mounted) ToastService.error(context, 'Failed to save quote: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Text(
          widget.initialQuote != null ? 'Edit Estimate' : 'New Estimate',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFFD4FF00)),
            tooltip: 'Save as Draft',
            onPressed: _isSaving ? null : () => _saveQuote(sendImmediately: false),
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4FF00)))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Customer & Service Location
                  _buildSectionHeader(Icons.person, 'Customer & Location'),
                  _buildCustomerCard(),
                  const SizedBox(height: 20),

                  // 2. Estimate Details
                  _buildSectionHeader(Icons.description, 'Estimate Info'),
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
                        _buildTextField('Estimate Title *', _titleController, hint: 'e.g. HVAC Replacement & Ductwork'),
                        const SizedBox(height: 12),
                        _buildTextField('Scope / Introduction', _introController, maxLines: 2, hint: 'Brief intro shown to client'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Expiry Date', style: TextStyle(color: muted, fontSize: 12)),
                                  const SizedBox(height: 4),
                                  InkWell(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _expiryDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) setState(() => _expiryDate = picked);
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 38,
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      alignment: Alignment.centerLeft,
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: cardBorder),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            DateFormat('MMM d, yyyy').format(_expiryDate),
                                            style: const TextStyle(color: Colors.white, fontSize: 13),
                                          ),
                                          Icon(Icons.calendar_today, size: 14, color: muted),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField('Tax Rate (%)', _taxRateController, isNumeric: true),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Line Items ("Our Item Project Way")
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(Icons.format_list_bulleted, 'Line Items ("Our Item Project Way")'),
                      IconButton(
                        onPressed: _openCatalogPicker,
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: accentBlue, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  _buildLineItemsSection(),
                  const SizedBox(height: 20),

                  // 4. Materials & Supplies
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionHeader(Icons.construction, 'Required Materials & Supplies'),
                      IconButton(
                        onPressed: () => _openMaterialDialog(),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(color: purple, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  _buildMaterialsSection(),
                  const SizedBox(height: 20),

                  // 5. Multi-tier Options Toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Multi-Tier Package Options', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      subtitle: Text('Good / Better / Best packages for customer', style: TextStyle(color: muted, fontSize: 12)),
                      value: _enableOptions,
                      activeColor: purple,
                      onChanged: (v) => setState(() => _enableOptions = v),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Deposit & Discount
                  _buildSectionHeader(Icons.payments, 'Deposit & Discounts'),
                  _buildDepositAndDiscountCard(),
                  const SizedBox(height: 20),

                  // 7. Live Profitability Preview
                  _buildSectionHeader(Icons.insights, 'Live Margin & Profitability Preview'),
                  _buildProfitabilityCard(),
                  const SizedBox(height: 20),

                  // 8. Notes & Terms
                  _buildSectionHeader(Icons.notes, 'Notes & Terms'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildTextField('Customer Notes (Visible on PDF)', _notesController, maxLines: 2),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accentAmber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accentAmber.withOpacity(0.3)),
                          ),
                          child: _buildTextField('Internal Notes (Staff Eyes Only)', _internalNotesController, maxLines: 2),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Terms & Conditions', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            TextButton.icon(
                              onPressed: _loadTermsTemplate,
                              icon: const Icon(Icons.file_copy_outlined, size: 14, color: Color(0xFF3B82F6)),
                              label: const Text('Load Template', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12)),
                            ),
                          ],
                        ),
                        _buildTextField('', _termsController, maxLines: 3, hint: 'Payment terms, warranties, and clauses'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // 9. Save Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _saveQuote(sendImmediately: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(color: cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save as Draft', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _saveQuote(sendImmediately: true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save & Send', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accentBlue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard() {
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
          if (_isLoadingCustomers)
            const Center(child: CircularProgressIndicator(color: Colors.white24))
          else
            _buildDropdownField<dynamic>(
              label: 'Select Customer *',
              value: _selectedCustomer,
              hint: 'Choose customer...',
              items: _customers.map((c) {
                final name = '${c['first_name'] ?? ''} ${c['last_name'] ?? ''}'.trim();
                final company = c['company_name'];
                final label = company != null && company.toString().isNotEmpty ? '$name ($company)' : (name.isEmpty ? (c['email'] ?? 'Customer #${c['id']}') : name);
                return DropdownMenuItem<dynamic>(
                  value: c,
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (c) {
                if (c != null) _onCustomerSelected(c);
              },
            ),

          if (_selectedCustomer != null && _addresses.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildDropdownField<dynamic>(
              label: 'Service Location',
              value: _selectedAddress,
              hint: 'Select service address...',
              items: _addresses.map((a) {
                final text = '${a['address_line1'] ?? a['street'] ?? ''}, ${a['city'] ?? ''} ${a['state'] ?? ''}'.trim();
                return DropdownMenuItem<dynamic>(
                  value: a,
                  child: Text(text.isEmpty ? 'Address #${a['id']}' : text, style: const TextStyle(color: Colors.white, fontSize: 13), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (a) => setState(() => _selectedAddress = a),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLineItemsSection() {
    if (_details.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inventory_2_outlined, size: 36, color: muted),
              const SizedBox(height: 8),
              Text('No line items added yet.', style: TextStyle(color: muted)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _openCatalogPicker,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add from Items Catalog'),
                style: ElevatedButton.styleFrom(backgroundColor: accentBlue),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _details.length,
        separatorBuilder: (_, __) => Divider(color: cardBorder, height: 1),
        itemBuilder: (ctx, idx) {
          final item = _details[idx];
          final q = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
          final p = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          final total = q * p;
          final category = item['category_name'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Expanded(
                  child: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Text(
                  NumberFormat.currency(symbol: '\$').format(total),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item['description'] != null && item['description'].toString().isNotEmpty)
                  Text(item['description'], style: TextStyle(color: muted, fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('${q} ${item['unit'] ?? 'unit'} @ \$${p}', style: TextStyle(color: muted, fontSize: 12)),
                    if (category != null) ...[
                      const SizedBox(width: 8),
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
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, size: 18, color: muted),
                  onPressed: () => _openCustomItemDialog(editIndex: idx),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => setState(() => _details.removeAt(idx)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialsSection() {
    if (_materials.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cardBorder),
        ),
        child: Center(
          child: Text('No required materials specified.', style: TextStyle(color: muted, fontSize: 13)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _materials.length,
        separatorBuilder: (_, __) => Divider(color: cardBorder, height: 1),
        itemBuilder: (ctx, idx) {
          final m = _materials[idx];
          final q = double.tryParse(m['quantity_required']?.toString() ?? '1') ?? 1;
          final p = double.tryParse(m['unit_price']?.toString() ?? '0') ?? 0;
          final total = q * p;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(m['name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            subtitle: Text('${q} ${m['unit'] ?? 'unit'} @ \$${p}', style: TextStyle(color: muted, fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(NumberFormat.currency(symbol: '\$').format(total), style: const TextStyle(color: Colors.white, fontSize: 13)),
                IconButton(
                  icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                  onPressed: () => setState(() => _materials.removeAt(idx)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDepositAndDiscountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          // Discount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _buildTextField('Discount Value', _discountValController, isNumeric: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildDropdownField<String>(
                  label: 'Type',
                  value: _discountType,
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed \$')),
                    DropdownMenuItem(value: 'percentage', child: Text('Percent %')),
                  ],
                  onChanged: (v) => setState(() => _discountType = v ?? 'fixed'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Deposit
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: _depositMode == 'fixed'
                    ? _buildTextField('Deposit Required (\$)', _depositRequiredController, isNumeric: true)
                    : _buildTextField('Deposit Required (%)', _depositPctController, isNumeric: true),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildDropdownField<String>(
                  label: 'Deposit Mode',
                  value: _depositMode,
                  items: const [
                    DropdownMenuItem(value: 'fixed', child: Text('Fixed \$')),
                    DropdownMenuItem(value: 'percentage', child: Text('Percent %')),
                  ],
                  onChanged: (v) => setState(() => _depositMode = v ?? 'fixed'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfitabilityCard() {
    final margin = _marginPercentage;
    final isGoodMargin = margin >= 30;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isGoodMargin ? accentGreen.withOpacity(0.3) : accentAmber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', _subtotal),
          if (_discountAmount > 0) _buildSummaryRow('Discount', -_discountAmount, isNegative: true),
          if (_taxAmount > 0) _buildSummaryRow('Estimated Tax', _taxAmount),
          const Divider(color: Colors.white24, height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Grand Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                NumberFormat.currency(symbol: '\$').format(_total),
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_depositDue > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Required Deposit Due', style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold)),
                Text(
                  NumberFormat.currency(symbol: '\$').format(_depositDue),
                  style: TextStyle(color: accentBlue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const Divider(color: Colors.white12, height: 24),
          // Estimator Margin Row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Estimated Cost', style: TextStyle(color: muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          NumberFormat.currency(symbol: '\$').format(_totalCost),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gross Profit', style: TextStyle(color: muted, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          NumberFormat.currency(symbol: '\$').format(_grossProfit),
                          style: TextStyle(color: isGoodMargin ? accentGreen : accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isGoodMargin ? accentGreen : accentAmber).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: (isGoodMargin ? accentGreen : accentAmber).withOpacity(0.3)),
                  ),
                  child: Text(
                    '${margin.toStringAsFixed(1)}% Margin',
                    style: TextStyle(
                      color: isGoodMargin ? accentGreen : accentAmber,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double val, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: muted, fontSize: 13)),
          Text(
            (isNegative ? '-' : '') + NumberFormat.currency(symbol: '\$').format(val.abs()),
            style: TextStyle(color: isNegative ? Colors.redAccent : Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, {int maxLines = 1, bool isNumeric = false, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
        TextFormField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: muted.withOpacity(0.5), fontSize: 13),
            filled: true,
            fillColor: bg,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 12 : 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: accentBlue)),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    String? hint,
  }) {
    String displayLabel = hint ?? 'Select...';
    bool isSelected = false;
    for (final item in items) {
      if (item.value == value) {
        if (item.child is Text) {
          final t = item.child as Text;
          displayLabel = t.data ?? t.textSpan?.toPlainText() ?? '';
        }
        isSelected = true;
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(label, style: TextStyle(color: muted, fontSize: 12)),
          const SizedBox(height: 4),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            return Theme(
              data: Theme.of(context).copyWith(
                highlightColor: Colors.white10,
                splashColor: accentBlue.withValues(alpha: 0.1),
              ),
              child: PopupMenuButton<T>(
                tooltip: '',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 4),
                color: card,
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: cardBorder),
                ),
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: constraints.maxWidth,
                  maxHeight: 200, // ~4-5 items, scrollable if more
                ),
                onSelected: onChanged,
                itemBuilder: (ctx) {
                  return items.map((item) {
                    final bool isCurrent = item.value == value;
                    return PopupMenuItem<T>(
                      value: item.value,
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: DefaultTextStyle(
                              style: TextStyle(
                                color: isCurrent ? accentBlue : Colors.white,
                                fontSize: 13,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              ),
                              child: item.child,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check, size: 16, color: accentBlue),
                          ],
                        ],
                      ),
                    );
                  }).toList();
                },
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayLabel,
                          style: TextStyle(
                            color: isSelected ? Colors.white : muted.withValues(alpha: 0.5),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: muted, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ─── Modal Sheet for Catalog Selection ───────────────────────────────────────────

class _CatalogPickerSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onItemSelected;
  final VoidCallback onAddCustom;

  const _CatalogPickerSheet({Key? key, required this.onItemSelected, required this.onAddCustom}) : super(key: key);

  @override
  State<_CatalogPickerSheet> createState() => _CatalogPickerSheetState();
}

class _CatalogPickerSheetState extends State<_CatalogPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems([String search = '']) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.request(
        method: 'GET',
        endpoint: '/items',
        queryParams: search.isNotEmpty ? {'search': search} : null,
      );
      List<dynamic> list = [];
      final raw = res['data'];
      if (raw is List) {
        list = raw;
      }
      setState(() {
        _items = list;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Select Item from Catalog', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search catalog items...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: (val) => _fetchItems(val),
          ),
          const SizedBox(height: 12),
          ListTile(
            onTap: () {
              Navigator.pop(context);
              widget.onAddCustom();
            },
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFF3B82F6), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.add, color: Colors.white),
            ),
            title: const Text('Create Custom Line Item', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: const Text('Add unique service with "Save to Catalog" option', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          const Divider(color: Colors.white12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : _items.isEmpty
                    ? const Center(child: Text('No catalog items found.', style: TextStyle(color: Colors.white54)))
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
                          final category = item['category']?['name'];

                          return ListTile(
                            title: Text(item['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text(
                              '${item['unit'] ?? 'unit'} • ${category ?? 'General'}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                            trailing: Text(
                              NumberFormat.currency(symbol: '\$').format(price),
                              style: const TextStyle(color: Color(0xFFD4FF00), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onItemSelected(item);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

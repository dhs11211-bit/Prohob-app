import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import '../shared/toast_service.dart';
import 'line_items_editor.dart';
import 'searchable_dropdown.dart';

class CreateInvoiceModal extends StatefulWidget {
  final String? initialJobId;
  final String? initialCustomerId;
  final double? initialAmount;
  final VoidCallback? onInvoiceCreated;
  final Map<String, dynamic>? existingInvoice;

  const CreateInvoiceModal({
    Key? key,
    this.initialJobId,
    this.initialCustomerId,
    this.initialAmount,
    this.onInvoiceCreated,
    this.existingInvoice,
  }) : super(key: key);

  @override
  State<CreateInvoiceModal> createState() => _CreateInvoiceModalState();
}

class _CreateInvoiceModalState extends State<CreateInvoiceModal> {
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  List<dynamic> _customers = [];
  List<dynamic> _jobs = [];

  String? _selectedCustomerId;
  String? _selectedJobId;

  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _descriptionCtrl = TextEditingController();

  List<Map<String, dynamic>> _lineItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingInvoice != null) {
      final inv = widget.existingInvoice!;
      _selectedCustomerId = inv['customer_id']?.toString();
      _selectedJobId = inv['job_id']?.toString();
      _amountCtrl.text =
          (double.tryParse(inv['total']?.toString() ?? '0') ?? 0.0)
              .toStringAsFixed(2);
      _descriptionCtrl.text = inv['notes'] ?? '';
      if (inv['line_items'] != null && inv['line_items'] is List) {
        _lineItems = List<Map<String, dynamic>>.from(
            (inv['line_items'] as List).map((i) => {
                  'description': i['description'] ?? '',
                  'quantity': i['quantity'] ?? 1,
                  'unit_price': i['unit_price'] ?? 0,
                  'tax_rate': i['tax_rate'] ?? 0,
                  'discount': i['discount'] ?? 0,
                }));
      }
    } else {
      _selectedCustomerId = widget.initialCustomerId;
      _selectedJobId = widget.initialJobId;
      if (widget.initialAmount != null) {
        _amountCtrl.text = widget.initialAmount!.toStringAsFixed(2);
      }
    }
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final custData = await ApiService.instance.get('/admin/customers');
      final jobsData = await ApiService.instance.get('/admin/jobs');

      if (mounted) {
        setState(() {
          _customers = custData is List
              ? custData
              : (custData is Map && custData['data'] is List
                  ? custData['data']
                  : []);
          _jobs = jobsData is List
              ? jobsData
              : (jobsData is Map && jobsData['data'] is List
                  ? jobsData['data']
                  : []);

          if (_selectedJobId != null && _selectedCustomerId == null) {
            final job = _jobs.firstWhere(
                (j) => j['id'].toString() == _selectedJobId,
                orElse: () => null);
            if (job != null && job['customer_id'] != null) {
              _selectedCustomerId = job['customer_id'].toString();
            }
          }

          if (_selectedCustomerId != null) {
            final exists = _customers
                .any((c) => c['id'].toString() == _selectedCustomerId);
            if (!exists) {
              _customers.add({
                'id': _selectedCustomerId,
                'first_name': 'Assigned',
                'last_name': 'Customer',
              });
            }
          }

          if (_selectedJobId != null) {
            final exists =
                _jobs.any((j) => j['id'].toString() == _selectedJobId);
            if (!exists) {
              _jobs.add({
                'id': _selectedJobId,
                'title': 'Assigned Job',
                'customer_id': _selectedCustomerId,
              });
            }
            _fetchJobDetailsAndItems(_selectedJobId!);
          }
        });
      }
    } catch (e) {
      if (mounted) ToastService.error(context, "Failed to load data");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchJobDetailsAndItems(String jobId) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.instance.get('/jobs/$jobId');
      if (mounted) {
        final jobData =
            res is Map<String, dynamic> ? (res['data'] ?? res) : res;
        if (jobData != null && jobData['details'] is List) {
          final List<dynamic> details = jobData['details'];
          setState(() {
            _lineItems = details
                .map((d) => {
                      'description': d['service_item']?['name'] ??
                          d['description'] ??
                          'Job Item',
                      'unit_price': d['price'] ?? 0.0,
                      'quantity': d['quantity'] ?? 1,
                    })
                .toList();
          });
        }
      }
    } catch (e) {
      print('Failed to fetch job details: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onJobSelected(String? jobId) {
    if (jobId == _selectedJobId) return;
    setState(() {
      _selectedJobId = jobId;
      if (jobId == null) {
        _lineItems = []; // clear items if job is unselected
      }
    });

    if (jobId != null) {
      // auto-select customer if available in job list
      final job = _jobs.firstWhere((j) => j['id'].toString() == jobId,
          orElse: () => null);
      if (job != null) {
        final rawCustId = job['customer_id'] ??
            (job['customer'] != null ? job['customer']['id'] : null);
        if (rawCustId != null) {
          final custId = rawCustId.toString();
          setState(() {
            if (!_customers.any((c) => c['id'].toString() == custId)) {
              _customers.add({
                'id': custId,
                'first_name': job['customer_name'] ??
                    (job['customer'] != null
                        ? job['customer']['first_name']
                        : 'Assigned'),
                'last_name': job['customer_name'] != null
                    ? ''
                    : (job['customer'] != null
                        ? job['customer']['last_name']
                        : 'Customer'),
              });
            }
            _selectedCustomerId = custId;
          });
        }
      }
      _fetchJobDetailsAndItems(jobId);
    }
  }

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) {
      if (mounted) ToastService.error(context, "Please select a customer.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final desc = _descriptionCtrl.text.trim();
      final payload = {
        'customer_id': _selectedCustomerId,
        'job_id': _selectedJobId,
        'total_amount': _amountCtrl.text.trim(),
        'notes': desc,
        'line_items': _lineItems,
      };

      if (widget.existingInvoice != null) {
        final id = widget.existingInvoice!['id'];
        await ApiService.instance.put('/admin/invoices/$id', payload);
        if (mounted)
          ToastService.success(context, "Invoice updated successfully!");
      } else {
        await ApiService.instance.post('/admin/invoices', payload);
        if (mounted)
          ToastService.success(context, "Invoice created successfully!");
      }

      if (widget.onInvoiceCreated != null) widget.onInvoiceCreated!();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ToastService.error(context,
            'Failed to save invoice: ${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<dynamic> filteredJobs = _jobs;
    if (_selectedCustomerId != null) {
      filteredJobs = _jobs
          .where((j) =>
              j['customer_id'].toString() == _selectedCustomerId ||
              j['id'].toString() == _selectedJobId)
          .toList();
    }

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              24,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 200, child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.existingInvoice != null
                                ? "Edit Invoice"
                                : "Create Invoice",
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.close, color: Colors.white54),
                            onPressed: () => Navigator.pop(context),
                          )
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text("Select Customer",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      SearchableDropdown(
                        value: _selectedCustomerId,
                        hint: "Choose a customer...",
                        items: _customers.map((c) {
                          String label =
                              "${c['first_name'] ?? ''} ${c['last_name'] ?? ''}"
                                  .trim();
                          if (label.isEmpty) label = 'Unknown';
                          return {'value': c['id'].toString(), 'label': label};
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCustomerId = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text("Attach to Job (Optional)",
                          style:
                              TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      widget.initialJobId != null
                          ? TextFormField(
                              initialValue: "Job #${widget.initialJobId}",
                              readOnly: true,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                isDense: true,
                              ),
                            )
                          : Autocomplete<Map<String, dynamic>>(
                              displayStringForOption: (j) =>
                                  "Job #${j['id']} - ${j['title'] ?? 'No Title'}",
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) async {
                                final query = textEditingValue.text.trim();
                                if (query.isEmpty) {
                                  return filteredJobs
                                      .map((e) => e as Map<String, dynamic>)
                                      .toList();
                                }

                                try {
                                  final now = DateTime.now();
                                  final startDate = now
                                      .subtract(const Duration(days: 10))
                                      .toIso8601String()
                                      .split('T')[0];
                                  final endDate = now
                                      .add(const Duration(days: 30))
                                      .toIso8601String()
                                      .split('T')[0];

                                  final res = await ApiService.instance.get(
                                      '/admin/jobs?search=$query&start_date=$startDate&end_date=$endDate');
                                  final List<dynamic> data =
                                      res is List ? res : (res['data'] ?? []);

                                  if (mounted) {
                                    setState(() {
                                      for (var job in data) {
                                        if (!_jobs.any((j) =>
                                            j['id'].toString() ==
                                            job['id'].toString())) {
                                          _jobs.add(job);
                                        }
                                      }
                                    });
                                  }

                                  return data
                                      .map((e) => e as Map<String, dynamic>)
                                      .toList();
                                } catch (e) {
                                  return [];
                                }
                              },
                              onSelected: (selection) =>
                                  _onJobSelected(selection['id'].toString()),
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                // Sync current selected job into the field
                                if (_selectedJobId != null &&
                                    textEditingController.text.isEmpty) {
                                  final j = _jobs.firstWhere(
                                      (job) =>
                                          job['id'].toString() ==
                                          _selectedJobId,
                                      orElse: () => null);
                                  if (j != null) {
                                    textEditingController.text =
                                        "Job #${j['id']} - ${j['title'] ?? 'No Title'}";
                                  }
                                }
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Search Job ID or Title...',
                                    hintStyle:
                                        const TextStyle(color: Colors.white38),
                                    filled: true,
                                    fillColor: const Color(0xFF1E293B),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    isDense: true,
                                    suffixIcon: _selectedJobId != null
                                        ? IconButton(
                                            icon: const Icon(Icons.clear,
                                                size: 16,
                                                color: Colors.white54),
                                            onPressed: () {
                                              textEditingController.clear();
                                              _onJobSelected(null);
                                            },
                                          )
                                        : null,
                                  ),
                                  validator: (val) {
                                    if ((val != null && val.isNotEmpty) &&
                                        _selectedJobId == null) {
                                      return 'Please select a job from the list.';
                                    }
                                    return null;
                                  },
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(10),
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width -
                                          40,
                                      height: 200,
                                      child: ListView.builder(
                                        padding: const EdgeInsets.all(8.0),
                                        itemCount: options.length,
                                        itemBuilder:
                                            (BuildContext context, int index) {
                                          final j = options.elementAt(index);
                                          return ListTile(
                                            title: Text(
                                                "Job #${j['id']} - ${j['title'] ?? 'No Title'}",
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13)),
                                            onTap: () {
                                              onSelected(j);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                      const SizedBox(height: 16),
                      LineItemsEditor(
                        initialItems: _lineItems,
                        isReadOnly: false,
                        onItemsChanged: (items, total) {
                          setState(() {
                            _lineItems = items;
                            _amountCtrl.text = total.toStringAsFixed(2);
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        readOnly: false,
                        decoration: InputDecoration(
                          labelText: "Total Amount (\$)",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                        validator: (val) => (val == null || val.isEmpty)
                            ? 'Amount is required'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionCtrl,
                        maxLines: 2,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "Description",
                          labelStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _submitInvoice,
                          child: Text(
                              widget.existingInvoice != null
                                  ? "Save Changes"
                                  : "Create Invoice",
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

void showCreateInvoiceModal(BuildContext context,
    {String? initialJobId,
    String? initialCustomerId,
    double? initialAmount,
    VoidCallback? onInvoiceCreated}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    useSafeArea: true,
    builder: (ctx) => CreateInvoiceModal(
      initialJobId: initialJobId,
      initialCustomerId: initialCustomerId,
      initialAmount: initialAmount,
      onInvoiceCreated: onInvoiceCreated,
    ),
  );
}

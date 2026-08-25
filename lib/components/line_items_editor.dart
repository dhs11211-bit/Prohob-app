import 'package:flutter/material.dart';
import '../backend/api_service.dart';
import '../shared/toast_service.dart';
import 'searchable_dropdown.dart';

class LineItemsEditor extends StatefulWidget {
  final List<Map<String, dynamic>> initialItems;
  final bool isReadOnly;
  final Function(List<Map<String, dynamic>> items, double total) onItemsChanged;

  const LineItemsEditor({
    Key? key,
    this.initialItems = const [],
    this.isReadOnly = false,
    required this.onItemsChanged,
  }) : super(key: key);

  @override
  State<LineItemsEditor> createState() => _LineItemsEditorState();
}

class _LineItemsEditorState extends State<LineItemsEditor> {
  List<Map<String, dynamic>> _selectedItems = [];
  List<Map<String, dynamic>> _catalogItems = [];
  bool _isLoadingCatalog = false;

  // Quick Add State
  bool _isAddingNew = false;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _qtyCtrl = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _selectedItems = List<Map<String, dynamic>>.from(widget.initialItems);
    if (!widget.isReadOnly) {
      _loadCatalogItems();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifyParent());
  }

  @override
  void didUpdateWidget(covariant LineItemsEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItems != oldWidget.initialItems ||
        widget.isReadOnly != oldWidget.isReadOnly) {
      setState(() {
        _selectedItems = List<Map<String, dynamic>>.from(widget.initialItems);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _notifyParent());
    }
  }

  Future<void> _loadCatalogItems() async {
    setState(() => _isLoadingCatalog = true);
    try {
      final res = await ApiService.instance.get('/items');
      if (mounted) {
        setState(() {
          if (res is List) {
            _catalogItems = res.map((e) => e as Map<String, dynamic>).toList();
          } else if (res is Map && res['data'] is List) {
            _catalogItems = (res['data'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();
          }
        });
      }
    } catch (e) {
      print('Failed to load items catalog: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCatalog = false);
    }
  }

  void _notifyParent() {
    double total = 0.0;
    for (var item in _selectedItems) {
      double price = double.tryParse(item['unit_price']?.toString() ??
              item['price']?.toString() ??
              '0') ??
          0.0;
      int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      total += (price * qty);
    }
    widget.onItemsChanged(_selectedItems, total);
  }

  void _addQuickItem() {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0.0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;

    if (name.isEmpty) {
      ToastService.error(context, "Item name is required");
      return;
    }

    setState(() {
      _selectedItems.add({
        'description': name,
        'unit_price': price,
        'quantity': qty,
        'is_quick_add': true,
      });
      _nameCtrl.clear();
      _priceCtrl.clear();
      _qtyCtrl.text = '1';
      _isAddingNew = false;
    });
    _notifyParent();
  }

  void _addCatalogItem(Map<String, dynamic> catalogItem) {
    setState(() {
      _selectedItems.add({
        'item_id': catalogItem['id'],
        'description': catalogItem['name'] ?? catalogItem['description'],
        'unit_price': catalogItem['price'] ?? 0.0,
        'quantity': 1,
      });
    });
    _notifyParent();
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
    _notifyParent();
  }

  Widget _buildCatalogDropdown() {
    return SearchableDropdown(
      value: null,
      hint: _isLoadingCatalog ? "Loading items..." : "Select item...",
      items: _catalogItems.isEmpty
          ? [
              {'value': 'no_items', 'label': 'No items available'}
            ]
          : _catalogItems.map((item) {
              return {
                'value': item['id'].toString(),
                'label': "${item['name']} - \$${item['price']}"
              };
            }).toList(),
      onChanged: (val) {
        if (val == null || val == 'no_items') return;
        final selected =
            _catalogItems.firstWhere((i) => i['id'].toString() == val);
        _addCatalogItem(selected);
      },
    );
  }

  Widget _buildQuickAddForm() {
    return Container(
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
                child: TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Item Name',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Price',
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: _addQuickItem,
              child: const Text("Add Item",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedItems.isNotEmpty) ...[
          const Text("Line Items",
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          ..._selectedItems.asMap().entries.map((entry) {
            int idx = entry.key;
            var item = entry.value;
            String desc = item['description']?.toString() ?? 'Item';
            double price = double.tryParse(item['unit_price']?.toString() ??
                    item['price']?.toString() ??
                    '0') ??
                0.0;
            int qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(desc,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('Qty: $qty',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11)),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: TextFormField(
                      initialValue: price.toStringAsFixed(2),
                      readOnly: widget.isReadOnly,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        filled: true,
                        fillColor: const Color(
                            0xFF0F172A), // Darker background to look like an input
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none),
                        prefixText: '\$',
                        prefixStyle: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      onChanged: (val) {
                        item['unit_price'] = double.tryParse(val) ?? 0.0;
                        _notifyParent();
                      },
                    ),
                  ),
                  if (!widget.isReadOnly) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () => _removeItem(idx),
                      child: const Icon(Icons.close,
                          color: Colors.redAccent, size: 18),
                    )
                  ]
                ],
              ),
            );
          }).toList(),
          const SizedBox(height: 12),
        ],
        if (!widget.isReadOnly) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Items",
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
              if (!_isAddingNew)
                GestureDetector(
                  onTap: () => setState(() {
                    _isAddingNew = true;
                    _priceCtrl.text = "0";
                    _qtyCtrl.text = "1";
                  }),
                  child: const Row(children: [
                    Icon(Icons.add_circle, color: Color(0xFF3B82F6), size: 16),
                    SizedBox(width: 4),
                    Text("Add quick item",
                        style:
                            TextStyle(color: Color(0xFF3B82F6), fontSize: 13))
                  ]),
                )
            ],
          ),
          const SizedBox(height: 8),
          if (_isAddingNew) _buildQuickAddForm() else _buildCatalogDropdown()
        ]
      ],
    );
  }
}

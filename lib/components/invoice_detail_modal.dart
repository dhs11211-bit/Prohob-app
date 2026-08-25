import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'create_invoice_modal.dart';

void showInvoiceDetailModal(
    BuildContext context, Map<String, dynamic> invoice) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => InvoiceDetailModal(invoice: invoice),
  );
}

class InvoiceDetailModal extends StatelessWidget {
  final Map<String, dynamic> invoice;

  const InvoiceDetailModal({Key? key, required this.invoice}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color bg = Color(0xFF020617);
    const Color cardBg = Color(0xFF0F172A);
    const Color textWhite = Colors.white;
    const Color muted = Color(0xFF94A3B8);
    const Color accent = Color(0xFF3B82F6);

    final customer = invoice['customer'] ?? {};
    final String customerName =
        "${customer['first_name'] ?? ''} ${customer['last_name'] ?? ''}".trim();
    final items = invoice['line_items'] ?? [];

    String formatDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return '-';
      try {
        final parsed = DateTime.parse(dateStr).toLocal();
        return DateFormat('MMM dd, yyyy').format(parsed);
      } catch (e) {
        return dateStr;
      }
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: const Border(bottom: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice['invoice_number'] ?? 'Invoice',
                      style: const TextStyle(
                          color: textWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (invoice['invoice_status'] ?? 'Draft')
                            .toString()
                            .toUpperCase(),
                        style: const TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (invoice['invoice_status'] == 'draft')
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueAccent),
                        onPressed: () {
                          Navigator.pop(context);
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            useSafeArea: true,
                            builder: (ctx) => CreateInvoiceModal(
                              existingInvoice: invoice,
                              onInvoiceCreated: () {
                                // Since we popped this modal, the caller will need to refresh the list,
                                // but we don't have a callback here. The user will refresh manually or the
                                // parent screen should handle it.
                              },
                            ),
                          );
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.close, color: muted),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                )
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info block
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Issue Date',
                          formatDate(invoice['issue_date']), muted, textWhite),
                      const SizedBox(height: 12),
                      _buildInfoRow('Due Date', formatDate(invoice['due_date']),
                          muted, textWhite),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          'Customer',
                          customerName.isEmpty ? 'Unknown' : customerName,
                          muted,
                          textWhite),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text('LINE ITEMS',
                    style: TextStyle(
                        color: muted,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2)),
                const SizedBox(height: 12),

                // Line items
                if (items is List && items.isNotEmpty)
                  ...items
                      .map((item) => Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['description'] ?? 'Item',
                                    style: const TextStyle(
                                        color: textWhite,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                        '${item['quantity']} x \$${item['unit_price']}',
                                        style: const TextStyle(
                                            color: muted, fontSize: 13)),
                                    Text(
                                        '\$${item['total'] ?? (double.tryParse(item['quantity']?.toString() ?? '1')! * double.tryParse(item['unit_price']?.toString() ?? '0')!).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: textWhite,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                )
                              ],
                            ),
                          ))
                      .toList()
                else
                  const Text('No line items found.',
                      style: TextStyle(color: muted)),

                const SizedBox(height: 24),

                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(
                          'Subtotal',
                          '\$${invoice['subtotal'] ?? '0.00'}',
                          muted,
                          textWhite),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          'Tax',
                          '\$${invoice['tax_amount'] ?? '0.00'}',
                          muted,
                          textWhite),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                          'Discount',
                          '-\$${invoice['discount_amount'] ?? '0.00'}',
                          muted,
                          Colors.greenAccent),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total',
                              style: TextStyle(
                                  color: textWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                          Text('\$${invoice['total'] ?? '0.00'}',
                              style: const TextStyle(
                                  color: accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      String label, String value, Color labelColor, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: labelColor, fontSize: 14)),
        Text(value,
            style: TextStyle(
                color: valueColor, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

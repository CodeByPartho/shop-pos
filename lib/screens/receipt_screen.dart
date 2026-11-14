import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../utils/format.dart';
import '../utils/receipt_text.dart';
import '../utils/share_text.dart';

class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ShopPOS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dayLabel(sale.dateTime)} at ${timeLabel(sale.dateTime)}',
                  textAlign: TextAlign.center,
                ),
                Text(
                  'Bill #${sale.id}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                if (sale.customerName != null)
                  Text(
                    'Customer: ${sale.customerName}',
                    textAlign: TextAlign.center,
                  ),
                const Divider(height: 32),
                for (final item in sale.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.name} x ${item.quantity}',
                          ),
                        ),
                        Text(money(item.lineTotal)),
                      ],
                    ),
                  ),
                const Divider(height: 32),
                _totalRow('Subtotal', money(sale.effectiveSubtotal)),
                if (sale.discountAmount > 0)
                  _totalRow(
                    'Discount',
                    '-${money(sale.discountAmount)}',
                  ),
                if (sale.taxAmount > 0)
                  _totalRow('Tax', money(sale.taxAmount)),
                _totalRow('Total', money(sale.total), bold: true),
                _totalRow(
                  'Paid by ${PaymentMethods.label(sale.paymentMethod)}',
                  money(sale.cashGiven),
                ),
                if (sale.change > 0)
                  _totalRow('Change', money(sale.change), bold: true),
                if (sale.isCreditSale)
                  _totalRow(
                    'Due',
                    money(sale.amountDue),
                    bold: true,
                  ),
                const SizedBox(height: 24),
                const Text(
                  'Thank you for shopping with us.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () =>
                      shareOrCopyText(context, receiptText(sale)),
                  icon: const Icon(Icons.share),
                  label: const Text('Share receipt'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: receiptText(sale)),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Receipt copied.'),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy receipt'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('New sale'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 18 : 15,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(value, style: style),
        ],
      ),
    );
  }
}

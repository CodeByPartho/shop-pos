import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/pos_logic.dart';
import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';
import '../utils/receipt_text.dart';
import '../utils/share_text.dart';

/// Customer credit ledger (udhaar / baki khata): who owes what, each
/// customer's ledger, record payments, and share a payment reminder.
class KhataScreen extends StatelessWidget {
  const KhataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final owing = state.customers
        .map((c) => (customer: c, balance: state.balanceOf(c.id)))
        .toList()
      ..sort((a, b) => b.balance.compareTo(a.balance));
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total outstanding',
                    style: TextStyle(color: Colors.grey),
                  ),
                  Text(
                    money(state.outstandingTotal),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${owing.where((e) => e.balance > 0).length} customers owe money',
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _addCustomer(context, state),
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add customer'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: owing.isEmpty
              ? const Center(
                  child: Text(
                    'No khata customers yet.\nSell on credit from the Cart tab to start one.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: owing.length,
                  itemBuilder: (context, index) {
                    final entry = owing[index];
                    final customer = entry.customer;
                    final balance = entry.balance;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            customer.name.characters.first,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(customer.name),
                        subtitle: Text(
                          customer.phone.isEmpty
                              ? 'No phone saved'
                              : customer.phone,
                        ),
                        trailing: Text(
                          balance > 0
                              ? 'Owes ${money(balance)}'
                              : balance < 0
                                  ? 'Overpaid ${money(-balance)}'
                                  : 'Settled',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: balance > 0
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  KhataDetailScreen(customer: customer),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _addCustomer(BuildContext context, PosState state) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New khata customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                return;
              }
              state.addCustomer(
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
              );
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class KhataDetailScreen extends StatelessWidget {
  const KhataDetailScreen({super.key, required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final balance = state.balanceOf(customer.id);
    final entries = ledgerForCustomer(state.ledger, customer.id);
    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Balance',
                      style: TextStyle(color: Colors.grey),
                    ),
                    Text(
                      money(balance),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: balance > 0
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (customer.phone.isNotEmpty)
                      Text('Phone: ${customer.phone}'),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: balance <= 0
                        ? null
                        : () => _recordPayment(context, state),
                    icon: const Icon(Icons.payments),
                    label: const Text('Record payment'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: balance <= 0
                        ? null
                        : () => shareOrCopyText(
                              context,
                              khataReminderText(
                                customerName: customer.name,
                                balance: balance,
                                shopName: 'ShopPOS',
                              ),
                            ),
                    icon: const Icon(Icons.share),
                    label: const Text('Remind'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No ledger entries yet.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final isSale = entry.kind == 'sale';
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            isSale
                                ? Icons.shopping_bag
                                : Icons.payments,
                          ),
                          title: Text(
                            isSale ? 'Credit sale' : 'Payment received',
                          ),
                          subtitle: Text(
                            '${shortDayLabel(entry.dateTime)} at '
                            '${timeLabel(entry.dateTime)}'
                            '${entry.note.isEmpty ? '' : '\n${entry.note}'}',
                          ),
                          isThreeLine: entry.note.isNotEmpty,
                          trailing: Text(
                            '${isSale ? '+' : '-'}${money(entry.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSale
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _recordPayment(BuildContext context, PosState state) async {
    final amountController = TextEditingController();
    String method = PaymentMethods.cash;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Record payment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (Taka)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PaymentMethods.cash,
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethods.bkash,
                    child: Text('bKash'),
                  ),
                  DropdownMenuItem(
                    value: PaymentMethods.nagad,
                    child: Text('Nagad'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => method = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final amount =
                    int.tryParse(amountController.text.trim()) ?? 0;
                final saved = state.recordPayment(
                  customerId: customer.id,
                  amount: amount.toDouble(),
                  method: method,
                );
                if (!saved && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a whole-Taka amount up to what is owed.',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Save payment'),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded.')),
      );
    }
  }
}

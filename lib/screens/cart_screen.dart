import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/pos_logic.dart';
import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';
import 'receipt_screen.dart';
import 'scan_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _paidController = TextEditingController();
  final TextEditingController _splitCashController = TextEditingController();
  final TextEditingController _splitDigitalController =
      TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  String _discountKind = 'none';
  String _method = PaymentMethods.cash;
  String? _customerId;

  @override
  void dispose() {
    _paidController.dispose();
    _splitCashController.dispose();
    _splitDigitalController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  BillTotals _bill(PosState state) {
    final subtotal = state.cartTotal.round();
    return computeBill(
      subtotal: subtotal,
      discountKind: _discountKind,
      discountValue: double.tryParse(_discountController.text.trim()) ?? 0,
      taxRatePercent: state.taxRatePercent,
    );
  }

  double _paidNow(BillTotals bill) {
    if (_method == PaymentMethods.split) {
      final cash =
          double.tryParse(_splitCashController.text.trim()) ?? 0;
      final digital =
          double.tryParse(_splitDigitalController.text.trim()) ?? 0;
      return cash + digital;
    }
    return double.tryParse(_paidController.text.trim()) ?? 0;
  }

  String? _validationError(PosState state, BillTotals bill) {
    final paid = _paidNow(bill);
    if (_method == PaymentMethods.credit) {
      if (_customerId == null) {
        return 'Pick a customer for a credit sale.';
      }
      if (paid < 0) {
        return 'Paid now cannot be negative.';
      }
      if (paid >= bill.total) {
        return 'Paid in full is not a credit sale. Pick Cash, bKash or Nagad.';
      }
      return null;
    }
    if (paid < bill.total) {
      return 'Paid is short by ${money(bill.total - paid)}.';
    }
    return null;
  }

  void _setPaid(String value) {
    setState(() => _paidController.text = value);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final items = state.cartItems;
    final bill = _bill(state);
    final paid = _paidNow(bill);
    final error = items.isEmpty ? null : _validationError(state, bill);
    final canCheckout = items.isNotEmpty && error == null && bill.total > 0;
    final change = paid - bill.total;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openScanner(context, state),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan barcode'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: items.isEmpty
                    ? null
                    : () async {
                        final label = await _askParkLabel(context);
                        if (label != null && context.mounted) {
                          state.parkCart(label);
                          _paidController.clear();
                          _splitCashController.clear();
                          _splitDigitalController.clear();
                        }
                      },
                icon: const Icon(Icons.pause_circle_outline),
                label: const Text('Park sale'),
              ),
            ],
          ),
        ),
        if (state.parked.isNotEmpty)
          SizedBox(
            height: 64,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              itemCount: state.parked.length,
              itemBuilder: (context, index) {
                final parked = state.parked[index];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InputChip(
                    avatar: const Icon(Icons.play_arrow, size: 18),
                    label: Text(
                      '${parked.label} (${money(parked.total)})',
                    ),
                    onPressed: () => state.resumeParked(parked.id),
                    onDeleted: () => state.deleteParked(parked.id),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Cart is empty.\nAdd products from the Products tab.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${money(item.price)} each  |  '
                          'Line total ${money(item.lineTotal)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => state.setQuantity(
                                item.productId,
                                item.quantity - 1,
                              ),
                            ),
                            Text(
                              '${item.quantity}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () => state.setQuantity(
                                item.productId,
                                item.quantity + 1,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () =>
                                  state.removeFromCart(item.productId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _discountKind,
                        decoration: const InputDecoration(
                          labelText: 'Discount',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'none',
                            child: Text('No discount'),
                          ),
                          DropdownMenuItem(
                            value: 'percent',
                            child: Text('Percent %'),
                          ),
                          DropdownMenuItem(
                            value: 'amount',
                            child: Text('Taka off'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _discountKind = value);
                          }
                        },
                      ),
                    ),
                    if (_discountKind != 'none') ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _discountController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: _discountKind == 'percent'
                                ? 'Discount %'
                                : 'Discount (Taka)',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                _amountRow('Subtotal', money(bill.subtotal)),
                if (bill.discount > 0)
                  _amountRow('Discount', '-${money(bill.discount)}'),
                if (bill.tax > 0)
                  _amountRow(
                    'Tax (${state.taxRatePercent.toStringAsFixed(0)}%)',
                    money(bill.tax),
                  ),
                _amountRow('Total', money(bill.total), bold: true),
                const SizedBox(height: 12),
                const Text(
                  'Payment method',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final method in PaymentMethods.all)
                      ChoiceChip(
                        label: Text(PaymentMethods.label(method)),
                        selected: _method == method,
                        onSelected: (_) => setState(() => _method = method),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_method == PaymentMethods.split) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _splitCashController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cash part (Taka)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _splitDigitalController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'bKash/Nagad part (Taka)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  TextField(
                    controller: _paidController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: _method == PaymentMethods.credit
                          ? 'Paid now (Taka, can be 0)'
                          : 'Paid (Taka)',
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final quick in [bill.total, 100, 500, 1000, 2000])
                        ActionChip(
                          label: Text(
                            quick == bill.total ? 'Exact' : '$quick',
                          ),
                          onPressed: items.isEmpty
                              ? null
                              : () => _setPaid('$quick'),
                        ),
                    ],
                  ),
                ],
                if (_method == PaymentMethods.credit) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: _customerId,
                          decoration: const InputDecoration(
                            labelText: 'Customer (khata)',
                            border: OutlineInputBorder(),
                          ),
                          items: state.customers
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(
                                    '${c.name} (owes ${money(state.balanceOf(c.id))})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _customerId = value),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: () => _addCustomer(context, state),
                        icon: const Icon(Icons.person_add),
                        label: const Text('New'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _method == PaymentMethods.credit ? 'Due' : 'Change',
                    ),
                    Text(
                      money(
                        _method == PaymentMethods.credit
                            ? bill.total - paid
                            : (change < 0 ? 0 : change),
                      ),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            _method == PaymentMethods.credit
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: items.isEmpty
                          ? null
                          : () {
                              state.clearCart();
                              _paidController.clear();
                              _splitCashController.clear();
                              _splitDigitalController.clear();
                            },
                      child: const Text('Clear'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: canCheckout
                            ? () {
                                final sale = state.checkout(
                                  bill: bill,
                                  paidNow: paid,
                                  paymentMethod: _method,
                                  customerId: _method ==
                                          PaymentMethods.credit
                                      ? _customerId
                                      : null,
                                );
                                if (sale != null && context.mounted) {
                                  _paidController.clear();
                                  _splitCashController.clear();
                                  _splitDigitalController.clear();
                                  _discountController.clear();
                                  setState(() {
                                    _discountKind = 'none';
                                  });
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ReceiptScreen(sale: sale),
                                    ),
                                  );
                                }
                              }
                            : null,
                        icon: const Icon(Icons.payment),
                        label: Text(
                          _method == PaymentMethods.credit
                              ? 'Sell on credit'
                              : 'Checkout',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 18 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 20 : 15,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openScanner(BuildContext context, PosState state) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => const ScanScreen(),
      ),
    );
    if (code == null || !context.mounted) {
      return;
    }
    final added = state.addByBarcode(code);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? 'Added ${state.findByBarcode(code)!.name} to the cart.'
              : 'No product with barcode $code. Add it on the Products tab.',
        ),
      ),
    );
  }

  Future<String?> _askParkLabel(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Park this sale'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Label (for example: man in red shirt)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().isEmpty
                  ? 'Parked sale'
                  : controller.text.trim(),
            ),
            child: const Text('Park'),
          ),
        ],
      ),
    );
  }

  Future<void> _addCustomer(BuildContext context, PosState state) async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final created = await showDialog<Customer>(
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
              Navigator.pop(
                dialogContext,
                state.addCustomer(
                  name: nameController.text.trim(),
                  phone: phoneController.text.trim(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (created != null) {
      setState(() => _customerId = created.id);
    }
  }
}

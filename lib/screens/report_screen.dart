import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/pos_logic.dart';
import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';

enum _Range { day, week, month }

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _anchor = DateTime.now();
  _Range _range = _Range.day;

  (DateTime, DateTime) _bounds() {
    switch (_range) {
      case _Range.day:
        final start = DateTime(_anchor.year, _anchor.month, _anchor.day);
        return (start, start.add(const Duration(days: 1)));
      case _Range.week:
        final start = weekStart(_anchor);
        return (start, start.add(const Duration(days: 7)));
      case _Range.month:
        final start = monthStart(_anchor);
        final next = start.month == 12
            ? DateTime(start.year + 1, 1, 1)
            : DateTime(start.year, start.month + 1, 1);
        return (start, next);
    }
  }

  String _rangeLabel() {
    final (start, end) = _bounds();
    switch (_range) {
      case _Range.day:
        return dayLabel(start);
      case _Range.week:
        return 'Week of ${shortDayLabel(start)} to '
            '${shortDayLabel(end.subtract(const Duration(days: 1)))}';
      case _Range.month:
        return '${_monthName(start.month)} ${start.year}';
    }
  }

  String _monthName(int month) => const [
        '',
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final (start, end) = _bounds();
    final sales = salesInRange(state.sales, start, end);
    final summary = rangeSummary(sales);
    final top = topProducts(sales);
    final topProfit = topProfitProducts(sales);
    final byMethod = totalsByPaymentMethod(sales);
    final rangeExpenses = state.expenses
        .where((e) => !e.dateTime.isBefore(start) && e.dateTime.isBefore(end))
        .toList();
    final expenseTotal = expensesTotal(rangeExpenses);
    final net = summary.grossProfit - expenseTotal;
    final chartDays = _range == _Range.month ? 30 : 7;
    final chartEnd = _range == _Range.day ? _anchor : end.subtract(const Duration(days: 1));
    final chart = dailyTotalsForChart(state.sales, chartEnd, chartDays);
    final chartMax = chart.fold<double>(0, (m, v) => v > m ? v : m);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SegmentedButton<_Range>(
          segments: const [
            ButtonSegment(value: _Range.day, label: Text('Day')),
            ButtonSegment(value: _Range.week, label: Text('Week')),
            ButtonSegment(value: _Range.month, label: Text('Month')),
          ],
          selected: {_range},
          onSelectionChanged: (selected) =>
              setState(() => _range = selected.first),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _rangeLabel(),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _anchor,
                  firstDate: DateTime(2026, 1, 1),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _anchor = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Pick date'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _statCard('Total sales', money(summary.totalSales)),
            ),
            const SizedBox(width: 12),
            Expanded(child: _statCard('Bills', '${summary.billCount}')),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard('Average bill', money(summary.averageBill)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Gross profit',
                money(summary.grossProfit),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Margin',
                '${summary.marginPercent.toStringAsFixed(1)}%',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Net profit',
                money(net),
                note: 'Profit minus expenses',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _statCard(
                'Expenses',
                money(expenseTotal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Cash in drawer',
                money(cashDrawerTotal(sales)),
                note: 'Cash sales only',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard(
                'Outstanding',
                money(state.outstandingTotal),
                note: 'Total khata due',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Sales, last $chartDays days',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < chart.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  width: double.infinity,
                                  height: chartMax == 0
                                      ? 0
                                      : (chart[i] / chartMax) * 84,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${chartEnd.subtract(Duration(days: chartDays - 1 - i)).day}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'By payment method',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (byMethod.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No sales in this period yet.'),
            ),
          )
        else
          for (final entry in byMethod.entries)
            Card(
              child: ListTile(
                title: Text(PaymentMethods.label(entry.key)),
                trailing: Text(
                  money(entry.value),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        const SizedBox(height: 24),
        const Text(
          'Top products',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No sales in this period yet.'),
            ),
          )
        else
          for (var rank = 0; rank < top.length; rank++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${rank + 1}')),
                title: Text(top[rank].name),
                subtitle: Text('${top[rank].quantity} sold'),
                trailing: Text(
                  money(top[rank].revenue),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        const SizedBox(height: 24),
        const Text(
          'Most profitable products',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (topProfit.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No profit data yet. Add a cost price to products to see profit.',
              ),
            ),
          )
        else
          for (var rank = 0; rank < topProfit.length; rank++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${rank + 1}')),
                title: Text(topProfit[rank].name),
                trailing: Text(
                  money(topProfit[rank].profit),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Expenses',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _addExpense(context, state),
              icon: const Icon(Icons.add),
              label: const Text('Add expense'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (rangeExpenses.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No expenses in this period yet.'),
            ),
          )
        else
          for (final expense in rangeExpenses)
            Card(
              child: ListTile(
                title: Text(expense.category),
                subtitle: Text(
                  '${shortDayLabel(expense.dateTime)}'
                  '${expense.note.isEmpty ? '' : '  |  ${expense.note}'}',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      money(expense.amount),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => state.deleteExpense(expense.id),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _statCard(String label, String value, {String? note}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (note != null)
              Text(note, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Future<void> _addExpense(BuildContext context, PosState state) async {
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String category = expenseCategories.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Add expense'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => category = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (Taka)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
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
                final amount =
                    int.tryParse(amountController.text.trim()) ?? 0;
                if (amount <= 0) {
                  return;
                }
                state.addExpense(
                  category: category,
                  amount: amount.toDouble(),
                  note: noteController.text.trim(),
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
  }
}

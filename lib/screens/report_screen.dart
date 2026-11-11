import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/pos_logic.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime _day = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final summary = dailySummary(state.sales, _day);
    final top = topProducts(salesOnDay(state.sales, _day));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              dayLabel(_day),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _day,
                  firstDate: DateTime(2026, 1, 1),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _day = picked);
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: const Text('Pick day'),
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
            Expanded(
              child: _statCard('Bills', '${summary.billCount}'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _statCard('Average bill', money(summary.averageBill)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Top products today',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (top.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No sales on this day yet.'),
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
      ],
    );
  }

  Widget _statCard(String label, String value) {
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
          ],
        ),
      ),
    );
  }
}

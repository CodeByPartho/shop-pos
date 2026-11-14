import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';
import 'receipt_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final sales = state.sales;
    if (sales.isEmpty) {
      return const Center(
        child: Text(
          'No sales yet.\nComplete a checkout to see it here.',
          textAlign: TextAlign.center,
        ),
      );
    }
    final Map<String, List<Sale>> byDay = {};
    for (final sale in sales) {
      final key = shortDayLabel(sale.dateTime);
      byDay.putIfAbsent(key, () => []).add(sale);
    }
    final days = byDay.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: days.length,
      itemBuilder: (context, dayIndex) {
        final day = days[dayIndex];
        final daySales = byDay[day]!;
        final dayTotal = daySales.fold<double>(
          0,
          (sum, sale) => sum + sale.total,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    day,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${daySales.length} bills  |  ${money(dayTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            for (final sale in daySales)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt),
                  title: Text(
                    '${sale.items.length} item types, ${sale.itemCount} items',
                  ),
                  subtitle: Text(
                    '${timeLabel(sale.dateTime)}  |  '
                    '${PaymentMethods.label(sale.paymentMethod)}'
                    '${sale.isCreditSale ? '  |  Due ${money(sale.amountDue)}' : ''}',
                  ),
                  trailing: Text(
                    money(sale.total),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ReceiptScreen(sale: sale),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

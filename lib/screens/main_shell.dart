import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pos_state.dart';
import 'cart_screen.dart';
import 'history_screen.dart';
import 'khata_screen.dart';
import 'products_screen.dart';
import 'report_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const List<Widget> _tabs = [
    ProductsScreen(),
    CartScreen(),
    HistoryScreen(),
    ReportScreen(),
    KhataScreen(),
  ];

  static const List<String> _titles = [
    'ShopPOS',
    'Cart',
    'Sales History',
    'Report',
    'Khata',
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final cartCount = state.cartCount;
    final lowCount = state.lowStockList.length;
    final owingCount =
        state.customers.where((c) => state.balanceOf(c.id) > 0).length;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Shop settings',
            onPressed: () => _showSettingsDialog(context, state),
          ),
          if (_index == 0)
            IconButton(
              icon: const Icon(Icons.restore),
              tooltip: 'Reset demo data',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Reset demo data?'),
                    content: const Text(
                      'This restores the 12 demo products and clears all sales, khata, expenses and parked sales.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  context.read<PosState>().resetDemoData();
                }
              },
            ),
        ],
      ),
      body: _tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: Badge(
              label: Text('$lowCount'),
              isLabelVisible: lowCount > 0,
              child: const Icon(Icons.store),
            ),
            label: 'Products',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$cartCount'),
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart),
            ),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long),
            label: 'History',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('$owingCount'),
              isLabelVisible: owingCount > 0,
              child: const Icon(Icons.book),
            ),
            label: 'Khata',
          ),
        ],
      ),
    );
  }

  Future<void> _showSettingsDialog(
    BuildContext context,
    PosState state,
  ) async {
    final taxController = TextEditingController(
      text: state.taxRatePercent == 0
          ? ''
          : state.taxRatePercent.toStringAsFixed(0),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Shop settings'),
        content: TextField(
          controller: taxController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Tax / VAT rate % (0 means tax off)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final rate =
                  double.tryParse(taxController.text.trim()) ?? 0;
              state.setTaxRate(rate);
              Navigator.pop(dialogContext);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

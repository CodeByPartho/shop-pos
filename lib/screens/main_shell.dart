import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/pos_state.dart';
import 'cart_screen.dart';
import 'history_screen.dart';
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
  ];

  static const List<String> _titles = [
    'ShopPOS',
    'Cart',
    'Sales History',
    'Daily Report',
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<PosState>().cartCount;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
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
                      'This restores the 12 demo products and clears all sales.',
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
          const NavigationDestination(
            icon: Icon(Icons.store),
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
        ],
      ),
    );
  }
}

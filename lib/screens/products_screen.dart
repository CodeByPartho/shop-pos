import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';
import 'scan_screen.dart';

const List<String> productCategories = [
  'Grocery',
  'Snacks',
  'Personal Care',
  'General',
];

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  String _categoryFilter = 'All';
  bool _lowStockOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final query = _query.toLowerCase();
    final categories = [
      'All',
      ...{for (final p in state.products) p.category},
    ];
    final visible = state.products.where((p) {
      if (_categoryFilter != 'All' && p.category != _categoryFilter) {
        return false;
      }
      if (_lowStockOnly && !p.isLowStock) {
        return false;
      }
      if (query.isEmpty) {
        return true;
      }
      return p.name.toLowerCase().contains(query) ||
          (p.barcode ?? '').toLowerCase().contains(query);
    }).toList();
    final lowCount = state.lowStockList.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name or barcode',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Scan barcode',
                onPressed: () => _openScanner(context, state),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showProductDialog(context, state, null),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              for (final category in categories)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category),
                    selected: _categoryFilter == category,
                    onSelected: (_) =>
                        setState(() => _categoryFilter = category),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('Low stock ($lowCount)'),
                  selected: _lowStockOnly,
                  onSelected: (value) =>
                      setState(() => _lowStockOnly = value),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No products match.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final product = visible[index];
                    final inCart = state.inCart(product.id);
                    final outOfStock = product.stock == 0;
                    final maxed = inCart >= product.stock;
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            product.name.characters.first,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(product.name)),
                            if (product.isLowStock)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Low',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onErrorContainer,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${money(product.price)}  |  ${product.category}\n'
                          'Stock: ${product.stock}'
                          '${product.costPrice > 0 ? '  |  Cost ${money(product.costPrice)}' : ''}'
                          '${product.barcode == null ? '' : '\nBarcode: ${product.barcode}'}',
                        ),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (inCart > 0)
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                tooltip: 'Remove one from cart',
                                onPressed: () => state.setQuantity(
                                  product.id,
                                  inCart - 1,
                                ),
                              ),
                            if (inCart > 0)
                              Text(
                                '$inCart',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.add_circle),
                              color: Theme.of(context).colorScheme.primary,
                              tooltip: outOfStock
                                  ? 'Out of stock'
                                  : 'Add to cart',
                              onPressed: (outOfStock || maxed)
                                  ? null
                                  : () => state.addToCart(product.id),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (choice) {
                                if (choice == 'restock') {
                                  _showRestockDialog(context, state, product);
                                } else if (choice == 'edit') {
                                  _showProductDialog(context, state, product);
                                } else if (choice == 'delete') {
                                  state.deleteProduct(product.id);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'restock',
                                  child: Text('Add stock'),
                                ),
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit product'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete product'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
    if (added) {
      final product = state.findByBarcode(code)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${product.name} to the cart.')),
      );
    } else if (state.findByBarcode(code) != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That product is out of stock.'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No product with barcode $code. Add it below.'),
        ),
      );
      _showProductDialog(context, state, null, prefilledBarcode: code);
    }
  }

  void _showProductDialog(
    BuildContext context,
    PosState state,
    Product? product, {
    String? prefilledBarcode,
  }) {
    final isEdit = product != null;
    final nameController = TextEditingController(text: product?.name ?? '');
    final priceController = TextEditingController(
      text: product == null ? '' : '${product.price.toInt()}',
    );
    final costController = TextEditingController(
      text: product == null ? '' : '${product.costPrice.toInt()}',
    );
    final stockController = TextEditingController(
      text: product == null ? '' : '${product.stock}',
    );
    final barcodeController = TextEditingController(
      text: product?.barcode ?? prefilledBarcode ?? '',
    );
    final lowStockController = TextEditingController(
      text: '${product?.lowStockAt ?? 5}',
    );
    String category = product?.category ?? productCategories.first;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit product' : 'Add product'),
          content: SingleChildScrollView(
            child: Column(
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
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Selling price (Taka)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cost price (Taka, optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stockController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isEdit ? 'Stock' : 'Opening stock',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Barcode (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lowStockController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Warn when stock is at or below',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: productCategories.contains(category)
                      ? category
                      : 'General',
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: productCategories
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => category = value);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price =
                    int.tryParse(priceController.text.trim()) ?? 0;
                final cost =
                    int.tryParse(costController.text.trim()) ?? 0;
                final stock = int.tryParse(stockController.text.trim()) ?? 0;
                final lowAt =
                    int.tryParse(lowStockController.text.trim()) ?? 5;
                if (name.isEmpty || price <= 0 || stock < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Enter a name, a price above zero and a stock of zero or more.',
                      ),
                    ),
                  );
                  return;
                }
                final barcode = barcodeController.text.trim().isEmpty
                    ? null
                    : barcodeController.text.trim();
                if (isEdit) {
                  state.updateProduct(
                    productId: product.id,
                    name: name,
                    price: price.toDouble(),
                    stock: stock,
                    category: category,
                    costPrice: cost.toDouble(),
                    barcode: barcode,
                    lowStockAt: lowAt < 0 ? 0 : lowAt,
                  );
                } else {
                  state.addProduct(
                    name: name,
                    price: price.toDouble(),
                    stock: stock,
                    category: category,
                    costPrice: cost.toDouble(),
                    barcode: barcode,
                    lowStockAt: lowAt < 0 ? 0 : lowAt,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: Text(isEdit ? 'Save changes' : 'Save product'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRestockDialog(
    BuildContext context,
    PosState state,
    Product product,
  ) {
    final controller = TextEditingController(text: '10');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Add stock: ${product.name}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantity to add',
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
              final amount = int.tryParse(controller.text.trim()) ?? 0;
              state.restock(product.id, amount);
              Navigator.pop(dialogContext);
            },
            child: const Text('Add stock'),
          ),
        ],
      ),
    );
  }
}

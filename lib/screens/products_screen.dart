import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/pos_state.dart';
import '../utils/format.dart';

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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<PosState>();
    final query = _query.toLowerCase();
    final visible = state.products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
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
                    hintText: 'Search products',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _showAddProductDialog(context, state),
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No products match the search.'))
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
                        title: Text(product.name),
                        subtitle: Text(
                          '${money(product.price)}  |  ${product.category}\n'
                          'Stock: ${product.stock}',
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

  void _showAddProductDialog(BuildContext context, PosState state) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    String category = productCategories.first;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Add product'),
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
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Price (Taka)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: stockController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Opening stock',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameController.text.trim();
                final price =
                    double.tryParse(priceController.text.trim()) ?? 0;
                final stock = int.tryParse(stockController.text.trim()) ?? 0;
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
                state.addProduct(
                  name: name,
                  price: price,
                  stock: stock,
                  category: category,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('Save product'),
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

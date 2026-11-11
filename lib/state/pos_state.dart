import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/pos_logic.dart';
import '../models/models.dart';

const String _storageKey = 'shop_pos_data_v1';

int _idCounter = 0;

String _newId(String prefix) {
  _idCounter++;
  return '$prefix-${DateTime.now().millisecondsSinceEpoch}-$_idCounter';
}

List<Product> seedProducts() => [
      Product(id: 'p-rice', name: 'Rice 1 kg', price: 72, stock: 40, category: 'Grocery'),
      Product(id: 'p-sugar', name: 'Sugar 1 kg', price: 120, stock: 25, category: 'Grocery'),
      Product(id: 'p-oil', name: 'Cooking Oil 1 L', price: 175, stock: 18, category: 'Grocery'),
      Product(id: 'p-salt', name: 'Salt 1 kg', price: 42, stock: 30, category: 'Grocery'),
      Product(id: 'p-tea', name: 'Tea 100 g', price: 95, stock: 22, category: 'Grocery'),
      Product(id: 'p-noodles', name: 'Instant Noodles', price: 35, stock: 48, category: 'Snacks'),
      Product(id: 'p-biscuits', name: 'Biscuits 250 g', price: 45, stock: 36, category: 'Snacks'),
      Product(id: 'p-eggs', name: 'Eggs (dozen)', price: 150, stock: 15, category: 'Grocery'),
      Product(id: 'p-milk', name: 'Milk 1 L', price: 110, stock: 12, category: 'Grocery'),
      Product(id: 'p-soap', name: 'Bath Soap', price: 55, stock: 28, category: 'Personal Care'),
      Product(id: 'p-shampoo', name: 'Shampoo 200 ml', price: 130, stock: 14, category: 'Personal Care'),
      Product(id: 'p-toothpaste', name: 'Toothpaste 100 g', price: 95, stock: 20, category: 'Personal Care'),
    ];

class PosState extends ChangeNotifier {
  PosState();

  bool loaded = false;
  List<Product> products = [];
  List<Sale> sales = [];
  Map<String, int> cart = {};
  String? lastSaleId;

  Sale? get lastSale {
    if (lastSaleId == null) {
      return null;
    }
    for (final sale in sales) {
      if (sale.id == lastSaleId) {
        return sale;
      }
    }
    return null;
  }

  int get cartCount => cart.values.fold(0, (sum, qty) => sum + qty);

  List<SaleItem> get cartItems {
    final items = <SaleItem>[];
    for (final entry in cart.entries) {
      Product? product;
      for (final candidate in products) {
        if (candidate.id == entry.key) {
          product = candidate;
          break;
        }
      }
      if (product != null) {
        items.add(
          SaleItem(
            productId: product.id,
            name: product.name,
            price: product.price,
            quantity: entry.value,
          ),
        );
      }
    }
    return items;
  }

  double get cartTotal => cartSubtotal(cartItems);

  int inCart(String productId) => cart[productId] ?? 0;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _seed();
    } else {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        products = (data['products'] as List)
            .map((e) => Product.fromJson(e as Map<String, dynamic>))
            .toList();
        sales = (data['sales'] as List)
            .map((e) => Sale.fromJson(e as Map<String, dynamic>))
            .toList();
        lastSaleId = data['lastSaleId'] as String?;
      } catch (_) {
        _seed();
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'products': products.map((p) => p.toJson()).toList(),
      'sales': sales.map((s) => s.toJson()).toList(),
      'lastSaleId': lastSaleId,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _seed() {
    products = seedProducts();
    sales = [];
    cart = {};
    lastSaleId = null;
  }

  void addToCart(String productId) {
    final product = products.firstWhere((p) => p.id == productId);
    final current = cart[productId] ?? 0;
    if (current >= product.stock) {
      return;
    }
    cart[productId] = current + 1;
    notifyListeners();
  }

  void setQuantity(String productId, int quantity) {
    final product = products.firstWhere((p) => p.id == productId);
    if (quantity <= 0) {
      cart.remove(productId);
    } else if (quantity <= product.stock) {
      cart[productId] = quantity;
    }
    notifyListeners();
  }

  void removeFromCart(String productId) {
    cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  /// Saves the cart as a sale, decrements stock and clears the cart.
  /// Returns the sale, or null when the cart is empty, cash is short,
  /// or stock is not enough.
  Sale? checkout(double cashGiven) {
    final items = cartItems;
    if (items.isEmpty) {
      return null;
    }
    final total = cartSubtotal(items);
    if (cashGiven < total) {
      return null;
    }
    final updated = applySaleToStock(products, items);
    if (updated == null) {
      return null;
    }
    products = updated;
    final sale = Sale(
      id: _newId('sale'),
      dateTime: DateTime.now(),
      items: items,
      total: total,
      cashGiven: cashGiven,
    );
    sales.insert(0, sale);
    lastSaleId = sale.id;
    cart.clear();
    _save();
    notifyListeners();
    return sale;
  }

  void addProduct({
    required String name,
    required double price,
    required int stock,
    required String category,
  }) {
    products.add(
      Product(
        id: _newId('p'),
        name: name,
        price: price,
        stock: stock,
        category: category,
      ),
    );
    products.sort((a, b) => a.name.compareTo(b.name));
    _save();
    notifyListeners();
  }

  void restock(String productId, int amount) {
    final index = products.indexWhere((p) => p.id == productId);
    if (index == -1 || amount <= 0) {
      return;
    }
    products[index] = products[index].copyWith(
      stock: products[index].stock + amount,
    );
    _save();
    notifyListeners();
  }

  void deleteProduct(String productId) {
    products.removeWhere((p) => p.id == productId);
    cart.remove(productId);
    _save();
    notifyListeners();
  }

  void resetDemoData() {
    _seed();
    _save();
    notifyListeners();
  }
}

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
      Product(
        id: 'p-rice',
        name: 'Rice 1 kg',
        price: 72,
        costPrice: 60,
        stock: 40,
        category: 'Grocery',
        barcode: '100001',
      ),
      Product(
        id: 'p-sugar',
        name: 'Sugar 1 kg',
        price: 120,
        costPrice: 105,
        stock: 25,
        category: 'Grocery',
        barcode: '100002',
      ),
      Product(
        id: 'p-oil',
        name: 'Cooking Oil 1 L',
        price: 175,
        costPrice: 158,
        stock: 18,
        category: 'Grocery',
        barcode: '100003',
      ),
      Product(
        id: 'p-salt',
        name: 'Salt 1 kg',
        price: 42,
        costPrice: 34,
        stock: 30,
        category: 'Grocery',
        barcode: '100004',
      ),
      Product(
        id: 'p-tea',
        name: 'Tea 100 g',
        price: 95,
        costPrice: 78,
        stock: 22,
        category: 'Grocery',
        barcode: '100005',
      ),
      Product(
        id: 'p-noodles',
        name: 'Instant Noodles',
        price: 35,
        costPrice: 26,
        stock: 48,
        category: 'Snacks',
        barcode: '100006',
      ),
      Product(
        id: 'p-biscuits',
        name: 'Biscuits 250 g',
        price: 45,
        costPrice: 34,
        stock: 36,
        category: 'Snacks',
        barcode: '100007',
      ),
      Product(
        id: 'p-eggs',
        name: 'Eggs (dozen)',
        price: 150,
        costPrice: 132,
        stock: 15,
        category: 'Grocery',
        barcode: '100008',
      ),
      Product(
        id: 'p-milk',
        name: 'Milk 1 L',
        price: 110,
        costPrice: 96,
        stock: 12,
        category: 'Grocery',
        barcode: '100009',
      ),
      Product(
        id: 'p-soap',
        name: 'Bath Soap',
        price: 55,
        costPrice: 42,
        stock: 28,
        category: 'Personal Care',
        barcode: '100010',
      ),
      Product(
        id: 'p-shampoo',
        name: 'Shampoo 200 ml',
        price: 130,
        costPrice: 102,
        stock: 14,
        category: 'Personal Care',
        barcode: '100011',
      ),
      Product(
        id: 'p-toothpaste',
        name: 'Toothpaste 100 g',
        price: 95,
        costPrice: 72,
        stock: 20,
        category: 'Personal Care',
        barcode: '100012',
      ),
    ];

const List<String> expenseCategories = [
  'Rent',
  'Transport',
  'Supplies',
  'Helper pay',
  'Other',
];

class PosState extends ChangeNotifier {
  PosState();

  bool loaded = false;
  List<Product> products = [];
  List<Sale> sales = [];
  List<Customer> customers = [];
  List<LedgerEntry> ledger = [];
  List<Expense> expenses = [];
  List<ParkedSale> parked = [];
  Map<String, int> cart = {};
  String? lastSaleId;

  /// VAT / tax rate in percent. 0 means tax is off (the usual case for
  /// a small shop). Stored as a shop setting.
  double taxRatePercent = 0;

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
            costPrice: product.costPrice,
          ),
        );
      }
    }
    return items;
  }

  double get cartTotal => cartSubtotal(cartItems);

  int inCart(String productId) => cart[productId] ?? 0;

  List<Product> get lowStockList => lowStockProducts(products);

  double get outstandingTotal => totalOutstanding(ledger);

  double balanceOf(String customerId) => customerBalance(ledger, customerId);

  Product? findByBarcode(String code) => findProductByBarcode(products, code);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null) {
      _seed();
    } else {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        // Each section parses on its own so one bad section (for
        // example old saved data missing new fields) cannot wipe the
        // rest. Models default every v1.1.0 field.
        products = _parseList<Product>(
          data['products'],
          (e) => Product.fromJson(e as Map<String, dynamic>),
        );
        sales = _parseList<Sale>(
          data['sales'],
          (e) => Sale.fromJson(e as Map<String, dynamic>),
        );
        customers = _parseList<Customer>(
          data['customers'],
          (e) => Customer.fromJson(e as Map<String, dynamic>),
        );
        ledger = _parseList<LedgerEntry>(
          data['ledger'],
          (e) => LedgerEntry.fromJson(e as Map<String, dynamic>),
        );
        expenses = _parseList<Expense>(
          data['expenses'],
          (e) => Expense.fromJson(e as Map<String, dynamic>),
        );
        parked = _parseList<ParkedSale>(
          data['parked'],
          (e) => ParkedSale.fromJson(e as Map<String, dynamic>),
        );
        lastSaleId = data['lastSaleId'] as String?;
        taxRatePercent =
            (data['taxRatePercent'] as num?)?.toDouble() ?? 0;
        if (products.isEmpty && sales.isEmpty && customers.isEmpty) {
          _seed();
        }
      } catch (_) {
        _seed();
      }
    }
    loaded = true;
    notifyListeners();
  }

  List<T> _parseList<T>(dynamic raw, T Function(dynamic) parse) {
    if (raw is! List) {
      return <T>[];
    }
    final out = <T>[];
    for (final item in raw) {
      try {
        out.add(parse(item));
      } catch (_) {
        // Skip one bad row instead of losing the whole list.
      }
    }
    return out;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'products': products.map((p) => p.toJson()).toList(),
      'sales': sales.map((s) => s.toJson()).toList(),
      'customers': customers.map((c) => c.toJson()).toList(),
      'ledger': ledger.map((e) => e.toJson()).toList(),
      'expenses': expenses.map((e) => e.toJson()).toList(),
      'parked': parked.map((p) => p.toJson()).toList(),
      'lastSaleId': lastSaleId,
      'taxRatePercent': taxRatePercent,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  void _seed() {
    products = seedProducts();
    sales = [];
    customers = [];
    ledger = [];
    expenses = [];
    parked = [];
    cart = {};
    lastSaleId = null;
    taxRatePercent = 0;
  }

  void setTaxRate(double rate) {
    taxRatePercent = rate.clamp(0, 100);
    _save();
    notifyListeners();
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

  /// Add one unit of the product with this barcode to the cart.
  /// Returns false when no product has the barcode or it is out of stock.
  bool addByBarcode(String code) {
    final product = findByBarcode(code);
    if (product == null) {
      return false;
    }
    final current = cart[product.id] ?? 0;
    if (current >= product.stock) {
      return false;
    }
    cart[product.id] = current + 1;
    notifyListeners();
    return true;
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

  /// Park the current cart under [label] and clear it. The cart can be
  /// resumed later from the Cart tab. Returns false when the cart is empty.
  bool parkCart(String label) {
    final items = cartItems;
    if (items.isEmpty) {
      return false;
    }
    parked.add(
      ParkedSale(
        id: _newId('park'),
        label: label.trim().isEmpty ? 'Parked sale' : label.trim(),
        dateTime: DateTime.now(),
        items: items,
      ),
    );
    cart.clear();
    _save();
    notifyListeners();
    return true;
  }

  /// Resume a parked sale into the cart. Items that no longer have
  /// enough stock are capped at what is on hand. Returns false when
  /// the parked sale is missing.
  bool resumeParked(String parkedId) {
    final index = parked.indexWhere((p) => p.id == parkedId);
    if (index == -1) {
      return false;
    }
    final sale = parked.removeAt(index);
    for (final item in sale.items) {
      final product = products
          .where((p) => p.id == item.productId)
          .firstOrNull;
      if (product == null) {
        continue;
      }
      final already = cart[item.productId] ?? 0;
      final wanted = already + item.quantity;
      cart[item.productId] =
          wanted > product.stock ? product.stock : wanted;
      if (cart[item.productId] == 0) {
        cart.remove(item.productId);
      }
    }
    _save();
    notifyListeners();
    return true;
  }

  void deleteParked(String parkedId) {
    parked.removeWhere((p) => p.id == parkedId);
    _save();
    notifyListeners();
  }

  /// Saves the cart as a sale, decrements stock and clears the cart.
  ///
  /// [bill] is the priced bill from [computeBill] (whole Taka).
  /// [paidNow] is what the customer pays at the counter. For cash,
  /// bKash, Nagad and split sales it must cover the total; for a credit
  /// sale it may be less (even zero) and [customerId] is required, with
  /// the rest recorded in the khata ledger.
  /// Returns the sale, or null when the cart is empty, the payment is
  /// not enough, or stock is not enough.
  Sale? checkout({
    required BillTotals bill,
    required double paidNow,
    String paymentMethod = PaymentMethods.cash,
    String? customerId,
  }) {
    final items = cartItems;
    if (items.isEmpty) {
      return null;
    }
    final total = bill.total.toDouble();
    final isCredit = paymentMethod == PaymentMethods.credit;
    if (isCredit) {
      // A credit sale needs a customer and a part payment below the
      // total. A full payment is a normal sale, not credit.
      if (customerId == null || paidNow < 0 || paidNow >= total) {
        return null;
      }
    } else if (paidNow < total) {
      return null;
    }
    final updated = applySaleToStock(products, items);
    if (updated == null) {
      return null;
    }
    products = updated;
    final amountDue = isCredit ? total - paidNow : 0.0;
    String? customerName;
    if (customerId != null) {
      final customer =
          customers.where((c) => c.id == customerId).firstOrNull;
      customerName = customer?.name;
    }
    final sale = Sale(
      id: _newId('sale'),
      dateTime: DateTime.now(),
      items: items,
      total: total,
      cashGiven: paidNow,
      subtotal: bill.subtotal.toDouble(),
      discountAmount: bill.discount.toDouble(),
      taxAmount: bill.tax.toDouble(),
      paymentMethod: paymentMethod,
      amountDue: amountDue,
      customerId: customerId,
      customerName: customerName,
    );
    sales.insert(0, sale);
    lastSaleId = sale.id;
    if (isCredit && amountDue > 0 && customerId != null) {
      ledger.add(
        LedgerEntry(
          id: _newId('led'),
          customerId: customerId,
          dateTime: sale.dateTime,
          kind: 'sale',
          amount: amountDue,
          saleId: sale.id,
          note: 'Credit sale ${sale.id}',
        ),
      );
    }
    cart.clear();
    _save();
    notifyListeners();
    return sale;
  }

  Customer addCustomer({required String name, String phone = ''}) {
    final customer = Customer(
      id: _newId('cust'),
      name: name.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );
    customers.add(customer);
    customers.sort((a, b) => a.name.compareTo(b.name));
    _save();
    notifyListeners();
    return customer;
  }

  /// Record a payment from a customer against their khata balance.
  /// Returns false when the customer is missing or the amount is not
  /// a positive whole-Taka amount, or it exceeds what they owe.
  bool recordPayment({
    required String customerId,
    required double amount,
    String method = PaymentMethods.cash,
    String note = '',
  }) {
    if (!customers.any((c) => c.id == customerId)) {
      return false;
    }
    if (amount <= 0 || amount != amount.roundToDouble()) {
      return false;
    }
    if (amount > balanceOf(customerId)) {
      return false;
    }
    ledger.add(
      LedgerEntry(
        id: _newId('led'),
        customerId: customerId,
        dateTime: DateTime.now(),
        kind: 'payment',
        amount: amount,
        note: note.isEmpty
            ? 'Payment by ${PaymentMethods.label(method)}'
            : note,
      ),
    );
    _save();
    notifyListeners();
    return true;
  }

  void addExpense({
    required String category,
    required double amount,
    String note = '',
    DateTime? date,
  }) {
    expenses.add(
      Expense(
        id: _newId('exp'),
        dateTime: date ?? DateTime.now(),
        category: category,
        amount: amount,
        note: note,
      ),
    );
    expenses.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _save();
    notifyListeners();
  }

  void deleteExpense(String expenseId) {
    expenses.removeWhere((e) => e.id == expenseId);
    _save();
    notifyListeners();
  }

  void addProduct({
    required String name,
    required double price,
    required int stock,
    required String category,
    double costPrice = 0,
    String? barcode,
    int lowStockAt = 5,
  }) {
    products.add(
      Product(
        id: _newId('p'),
        name: name,
        price: price,
        stock: stock,
        category: category,
        costPrice: costPrice,
        barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
        lowStockAt: lowStockAt,
      ),
    );
    products.sort((a, b) => a.name.compareTo(b.name));
    _save();
    notifyListeners();
  }

  void updateProduct({
    required String productId,
    required String name,
    required double price,
    required int stock,
    required String category,
    required double costPrice,
    String? barcode,
    required int lowStockAt,
  }) {
    final index = products.indexWhere((p) => p.id == productId);
    if (index == -1) {
      return;
    }
    products[index] = Product(
      id: productId,
      name: name,
      price: price,
      stock: stock,
      category: category,
      costPrice: costPrice,
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      lowStockAt: lowStockAt,
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

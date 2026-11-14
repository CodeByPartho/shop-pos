class Product {
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category = 'General',
    this.costPrice = 0,
    this.barcode,
    this.lowStockAt = 5,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        category: json['category'] as String? ?? 'General',
        // New in v1.1.0: defaulted so v1.0.0 saved data still loads.
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
        barcode: json['barcode'] as String?,
        lowStockAt: json['lowStockAt'] as int? ?? 5,
      );

  final String id;
  final String name;
  final double price;
  int stock;
  final String category;

  /// What the shop paid per unit. 0 means unknown (no profit shown).
  final double costPrice;

  /// Optional barcode printed on the pack. Null when not set.
  final String? barcode;

  /// Warn when stock falls to this level or below. Default 5.
  final int lowStockAt;

  bool get isLowStock => stock <= lowStockAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
        'costPrice': costPrice,
        'barcode': barcode,
        'lowStockAt': lowStockAt,
      };

  Product copyWith({
    int? stock,
    String? name,
    double? price,
    String? category,
    double? costPrice,
    String? barcode,
    int? lowStockAt,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        price: price ?? this.price,
        stock: stock ?? this.stock,
        category: category ?? this.category,
        costPrice: costPrice ?? this.costPrice,
        barcode: barcode ?? this.barcode,
        lowStockAt: lowStockAt ?? this.lowStockAt,
      );
}

class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.costPrice = 0,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['productId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
        // New in v1.1.0: old sales have no cost snapshot, profit is 0.
        costPrice: (json['costPrice'] as num?)?.toDouble() ?? 0,
      );

  final String productId;
  final String name;
  final double price;
  final int quantity;

  /// Cost price snapshot taken at sale time, for profit reporting.
  final double costPrice;

  double get lineTotal => price * quantity;

  double get lineProfit => (price - costPrice) * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
        'costPrice': costPrice,
      };
}

/// Payment methods recorded on a sale. No money moves inside the app;
/// the method only records how the customer paid.
class PaymentMethods {
  static const String cash = 'cash';
  static const String bkash = 'bkash';
  static const String nagad = 'nagad';
  static const String split = 'split';
  static const String credit = 'credit';

  static const List<String> all = [cash, bkash, nagad, split, credit];

  static String label(String method) {
    switch (method) {
      case cash:
        return 'Cash';
      case bkash:
        return 'bKash';
      case nagad:
        return 'Nagad';
      case split:
        return 'Split';
      case credit:
        return 'Credit';
      default:
        return 'Cash';
    }
  }
}

class Sale {
  Sale({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.total,
    required this.cashGiven,
    this.subtotal,
    this.discountAmount = 0,
    this.taxAmount = 0,
    this.paymentMethod = PaymentMethods.cash,
    this.amountDue = 0,
    this.customerId,
    this.customerName,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    final total = (json['total'] as num).toDouble();
    final cashGiven =
        (json['cashGiven'] as num?)?.toDouble() ?? total;
    return Sale(
      id: json['id'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      items: (json['items'] as List)
          .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: total,
      cashGiven: cashGiven,
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      discountAmount: (json['discountAmount'] as num?)?.toDouble() ?? 0,
      taxAmount: (json['taxAmount'] as num?)?.toDouble() ?? 0,
      paymentMethod:
          json['paymentMethod'] as String? ?? PaymentMethods.cash,
      amountDue: (json['amountDue'] as num?)?.toDouble() ?? 0,
      customerId: json['customerId'] as String?,
      customerName: json['customerName'] as String?,
    );
  }

  final String id;
  final DateTime dateTime;
  final List<SaleItem> items;
  final double total;

  /// Amount paid at checkout (cash, mobile money, or part payment).
  /// For a fully paid sale this is at least the total; for a credit
  /// sale it is the part paid now (possibly zero).
  final double cashGiven;

  /// Sum of line totals before discount and tax. Null on v1.0.0 sales,
  /// where it equals the total.
  final double? subtotal;

  final double discountAmount;
  final double taxAmount;
  final String paymentMethod;

  /// Still owed by the customer. Zero for fully paid sales.
  final double amountDue;

  final String? customerId;
  final String? customerName;

  double get effectiveSubtotal => subtotal ?? total;

  /// Change to hand back. Zero on credit or exact mobile payments.
  double get change => cashGiven > total ? cashGiven - total : 0;

  bool get isCreditSale => amountDue > 0;

  /// Gross profit on this sale: item margins minus the bill discount.
  /// Tax is collected for the government, not profit, so it is excluded.
  double get grossProfit {
    final itemsProfit =
        items.fold<double>(0, (sum, item) => sum + item.lineProfit);
    return itemsProfit - discountAmount;
  }

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'cashGiven': cashGiven,
        'subtotal': effectiveSubtotal,
        'discountAmount': discountAmount,
        'taxAmount': taxAmount,
        'paymentMethod': paymentMethod,
        'amountDue': amountDue,
        'customerId': customerId,
        'customerName': customerName,
      };
}

/// A customer who buys on credit (udhaar / baki khata).
class Customer {
  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    required this.createdAt,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  final String id;
  final String name;
  final String phone;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// One line in a customer's khata. A 'sale' entry adds to what the
/// customer owes; a 'payment' entry reduces it.
class LedgerEntry {
  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.dateTime,
    required this.kind,
    required this.amount,
    this.saleId,
    this.note = '',
  });

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        kind: json['kind'] as String,
        amount: (json['amount'] as num).toDouble(),
        saleId: json['saleId'] as String?,
        note: json['note'] as String? ?? '',
      );

  final String id;
  final String customerId;
  final DateTime dateTime;

  /// 'sale' (owes more) or 'payment' (owes less).
  final String kind;
  final double amount;
  final String? saleId;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customerId': customerId,
        'dateTime': dateTime.toIso8601String(),
        'kind': kind,
        'amount': amount,
        'saleId': saleId,
        'note': note,
      };
}

/// A shop expense: rent, transport, supplies, helper pay.
class Expense {
  Expense({
    required this.id,
    required this.dateTime,
    required this.category,
    required this.amount,
    this.note = '',
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        note: json['note'] as String? ?? '',
      );

  final String id;
  final DateTime dateTime;
  final String category;
  final double amount;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'category': category,
        'amount': amount,
        'note': note,
      };
}

/// A cart parked mid-sale so the queue can keep moving.
class ParkedSale {
  ParkedSale({
    required this.id,
    required this.label,
    required this.dateTime,
    required this.items,
  });

  factory ParkedSale.fromJson(Map<String, dynamic> json) => ParkedSale(
        id: json['id'] as String,
        label: json['label'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        items: (json['items'] as List)
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String label;
  final DateTime dateTime;
  final List<SaleItem> items;

  double get total => items.fold(0, (sum, item) => sum + item.lineTotal);

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
      };
}

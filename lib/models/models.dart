class Product {
  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.category = 'General',
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        category: json['category'] as String? ?? 'General',
      );

  final String id;
  final String name;
  final double price;
  int stock;
  final String category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'category': category,
      };

  Product copyWith({int? stock}) => Product(
        id: id,
        name: name,
        price: price,
        stock: stock ?? this.stock,
        category: category,
      );
}

class SaleItem {
  SaleItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
        productId: json['productId'] as String,
        name: json['name'] as String,
        price: (json['price'] as num).toDouble(),
        quantity: json['quantity'] as int,
      );

  final String productId;
  final String name;
  final double price;
  final int quantity;

  double get lineTotal => price * quantity;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'name': name,
        'price': price,
        'quantity': quantity,
      };
}

class Sale {
  Sale({
    required this.id,
    required this.dateTime,
    required this.items,
    required this.total,
    required this.cashGiven,
  });

  factory Sale.fromJson(Map<String, dynamic> json) => Sale(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        items: (json['items'] as List)
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: (json['total'] as num).toDouble(),
        cashGiven: (json['cashGiven'] as num).toDouble(),
      );

  final String id;
  final DateTime dateTime;
  final List<SaleItem> items;
  final double total;
  final double cashGiven;

  double get change => cashGiven - total;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'cashGiven': cashGiven,
      };
}

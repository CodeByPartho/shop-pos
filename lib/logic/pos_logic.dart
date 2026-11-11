import '../models/models.dart';

/// Total price of the items in a cart.
double cartSubtotal(List<SaleItem> items) =>
    items.fold(0, (sum, item) => sum + item.lineTotal);

/// Change to hand back for a cash payment. Negative when cash is short.
double changeDue(double total, double cashGiven) => cashGiven - total;

/// Returns a new product list with stock decremented for each sold item.
/// Returns null when a product is missing or any item would take stock
/// below zero. The input list is never changed.
List<Product>? applySaleToStock(List<Product> products, List<SaleItem> items) {
  final updated = products.map((product) => product.copyWith()).toList();
  for (final item in items) {
    final index = updated.indexWhere((p) => p.id == item.productId);
    if (index == -1) {
      return null;
    }
    final nextStock = updated[index].stock - item.quantity;
    if (nextStock < 0) {
      return null;
    }
    updated[index] = updated[index].copyWith(stock: nextStock);
  }
  return updated;
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Sales that happened on [day], newest first.
List<Sale> salesOnDay(List<Sale> sales, DateTime day) {
  final daySales = sales.where((sale) => sameDay(sale.dateTime, day)).toList();
  daySales.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return daySales;
}

class DailySummary {
  DailySummary({required this.totalSales, required this.billCount});

  final double totalSales;
  final int billCount;

  double get averageBill => billCount == 0 ? 0 : totalSales / billCount;
}

DailySummary dailySummary(List<Sale> sales, DateTime day) {
  final daySales = salesOnDay(sales, day);
  return DailySummary(
    totalSales: daySales.fold(0, (sum, sale) => sum + sale.total),
    billCount: daySales.length,
  );
}

class TopProduct {
  TopProduct({required this.name, required this.quantity, required this.revenue});

  final String name;
  final int quantity;
  final double revenue;
}

/// Best selling products across [sales], ranked by quantity sold.
List<TopProduct> topProducts(List<Sale> sales, {int limit = 5}) {
  final Map<String, TopProduct> byName = {};
  for (final sale in sales) {
    for (final item in sale.items) {
      final existing = byName[item.name];
      if (existing == null) {
        byName[item.name] = TopProduct(
          name: item.name,
          quantity: item.quantity,
          revenue: item.lineTotal,
        );
      } else {
        byName[item.name] = TopProduct(
          name: item.name,
          quantity: existing.quantity + item.quantity,
          revenue: existing.revenue + item.lineTotal,
        );
      }
    }
  }
  final ranked = byName.values.toList()
    ..sort((a, b) => b.quantity.compareTo(a.quantity));
  return ranked.take(limit).toList();
}

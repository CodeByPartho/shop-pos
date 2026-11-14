import '../models/models.dart';

/// Total price of the items in a cart.
double cartSubtotal(List<SaleItem> items) =>
    items.fold(0, (sum, item) => sum + item.lineTotal);

/// Change to hand back for a cash payment. Negative when cash is short.
double changeDue(double total, double cashGiven) => cashGiven - total;

/// Round any money value to whole Taka. All bill math in this app
/// works in whole Taka so paisa rounding never leaks into totals.
int roundTaka(double value) => value.round();

/// Result of pricing a bill. Every amount is whole Taka.
class BillTotals {
  BillTotals({
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
  });

  final int subtotal;
  final int discount;
  final int tax;
  final int total;
}

/// Price a bill from a whole-Taka subtotal.
///
/// [discountKind] is 'none', 'percent' or 'amount'. A percent discount
/// is clamped to 0-100; an amount discount is clamped to the subtotal,
/// so the total can never go below zero. Tax is charged on the amount
/// after discount, at [taxRatePercent] (0 means tax off).
BillTotals computeBill({
  required int subtotal,
  String discountKind = 'none',
  double discountValue = 0,
  double taxRatePercent = 0,
}) {
  final safeSubtotal = subtotal < 0 ? 0 : subtotal;
  var discount = 0;
  if (discountKind == 'percent') {
    final pct = discountValue.clamp(0, 100);
    discount = ((safeSubtotal * pct) / 100).round();
  } else if (discountKind == 'amount') {
    discount = discountValue.round().clamp(0, safeSubtotal);
  }
  final afterDiscount = safeSubtotal - discount;
  final tax = taxRatePercent <= 0
      ? 0
      : ((afterDiscount * taxRatePercent) / 100).round();
  return BillTotals(
    subtotal: safeSubtotal,
    discount: discount,
    tax: tax,
    total: afterDiscount + tax,
  );
}

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

/// Sales from [start] (inclusive) to [end] (exclusive), newest first.
List<Sale> salesInRange(List<Sale> sales, DateTime start, DateTime end) {
  final ranged = sales
      .where(
        (sale) =>
            !sale.dateTime.isBefore(start) && sale.dateTime.isBefore(end),
      )
      .toList();
  ranged.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return ranged;
}

/// First day (midnight) of the week containing [day], Monday first.
DateTime weekStart(DateTime day) {
  final midnight = DateTime(day.year, day.month, day.day);
  return midnight.subtract(Duration(days: midnight.weekday - 1));
}

/// First day (midnight) of the month containing [day].
DateTime monthStart(DateTime day) => DateTime(day.year, day.month, 1);

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

/// Summary for any list of sales: revenue, bills, gross profit and
/// margin. Margin is 0 when there is no revenue.
class RangeSummary {
  RangeSummary({
    required this.totalSales,
    required this.billCount,
    required this.grossProfit,
  });

  final double totalSales;
  final int billCount;
  final double grossProfit;

  double get averageBill => billCount == 0 ? 0 : totalSales / billCount;

  double get marginPercent =>
      totalSales == 0 ? 0 : (grossProfit / totalSales) * 100;
}

RangeSummary rangeSummary(List<Sale> sales) => RangeSummary(
      totalSales: sales.fold(0, (sum, sale) => sum + sale.total),
      billCount: sales.length,
      grossProfit: sales.fold(0, (sum, sale) => sum + sale.grossProfit),
    );

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

class TopProfitProduct {
  TopProfitProduct({required this.name, required this.profit});

  final String name;
  final double profit;
}

/// Products ranked by gross profit earned across [sales].
List<TopProfitProduct> topProfitProducts(List<Sale> sales, {int limit = 5}) {
  final Map<String, double> byName = {};
  for (final sale in sales) {
    for (final item in sale.items) {
      byName[item.name] = (byName[item.name] ?? 0) + item.lineProfit;
    }
  }
  final ranked = byName.entries
      .map((e) => TopProfitProduct(name: e.key, profit: e.value))
      .toList()
    ..sort((a, b) => b.profit.compareTo(a.profit));
  return ranked.take(limit).toList();
}

/// Total revenue per payment method across [sales].
Map<String, double> totalsByPaymentMethod(List<Sale> sales) {
  final totals = <String, double>{};
  for (final sale in sales) {
    totals[sale.paymentMethod] =
        (totals[sale.paymentMethod] ?? 0) + sale.total;
  }
  return totals;
}

/// Cash that should be in the drawer from [sales]: cash and split sales
/// count only their cash part, which is the amount paid now minus any
/// change handed back. Mobile money and credit sales add no cash.
double cashDrawerTotal(List<Sale> sales) {
  var cash = 0.0;
  for (final sale in sales) {
    if (sale.paymentMethod == PaymentMethods.cash ||
        sale.paymentMethod == PaymentMethods.split) {
      cash += sale.cashGiven - sale.change;
    }
  }
  return cash;
}

/// Find a product by its barcode. The code is trimmed before matching;
/// an empty code never matches. Returns null when no product has it.
Product? findProductByBarcode(List<Product> products, String code) {
  final cleaned = code.trim();
  if (cleaned.isEmpty) {
    return null;
  }
  for (final product in products) {
    if (product.barcode != null && product.barcode!.trim() == cleaned) {
      return product;
    }
  }
  return null;
}

/// Products at or below their low-stock level, lowest stock first.
List<Product> lowStockProducts(List<Product> products) {
  final low = products.where((p) => p.isLowStock).toList();
  low.sort((a, b) => a.stock.compareTo(b.stock));
  return low;
}

/// What one customer still owes: sale entries minus payment entries.
double customerBalance(List<LedgerEntry> entries, String customerId) {
  var balance = 0.0;
  for (final entry in entries) {
    if (entry.customerId != customerId) {
      continue;
    }
    if (entry.kind == 'sale') {
      balance += entry.amount;
    } else if (entry.kind == 'payment') {
      balance -= entry.amount;
    }
  }
  return balance;
}

/// Total still owed across all customers.
double totalOutstanding(List<LedgerEntry> entries) {
  var total = 0.0;
  for (final entry in entries) {
    if (entry.kind == 'sale') {
      total += entry.amount;
    } else if (entry.kind == 'payment') {
      total -= entry.amount;
    }
  }
  return total;
}

/// Ledger entries for one customer, newest first.
List<LedgerEntry> ledgerForCustomer(
  List<LedgerEntry> entries,
  String customerId,
) {
  final mine =
      entries.where((e) => e.customerId == customerId).toList();
  mine.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  return mine;
}

/// Total expenses in [expenses].
double expensesTotal(List<Expense> expenses) =>
    expenses.fold(0, (sum, e) => sum + e.amount);

/// Net profit for a period: gross profit from sales minus expenses.
double netProfit(List<Sale> sales, List<Expense> expenses) =>
    rangeSummary(sales).grossProfit - expensesTotal(expenses);

/// Daily revenue totals for the [days] days ending on [endDay],
/// oldest first, for the report bar chart.
List<double> dailyTotalsForChart(
  List<Sale> sales,
  DateTime endDay,
  int days,
) {
  final totals = <double>[];
  final end = DateTime(endDay.year, endDay.month, endDay.day);
  for (var i = days - 1; i >= 0; i--) {
    final day = end.subtract(Duration(days: i));
    totals.add(dailySummary(sales, day).totalSales);
  }
  return totals;
}

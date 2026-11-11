import 'package:flutter_test/flutter_test.dart';
import 'package:shop_pos/logic/pos_logic.dart';
import 'package:shop_pos/models/models.dart';

List<Product> testProducts() => [
      Product(id: 'p1', name: 'Rice 1 kg', price: 72, stock: 10),
      Product(id: 'p2', name: 'Tea 100 g', price: 95, stock: 5),
      Product(id: 'p3', name: 'Soap', price: 55, stock: 0),
    ];

void main() {
  group('cart totals', () {
    test('empty cart totals zero', () {
      expect(cartSubtotal([]), 0);
    });

    test('sums price times quantity for each line', () {
      final items = [
        SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 2),
        SaleItem(productId: 'p2', name: 'Tea 100 g', price: 95, quantity: 3),
      ];
      expect(cartSubtotal(items), 72 * 2 + 95 * 3);
    });

    test('single item total equals price times quantity', () {
      final items = [
        SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 4),
      ];
      expect(cartSubtotal(items), 288);
    });
  });

  group('change due', () {
    test('exact cash gives zero change', () {
      expect(changeDue(200, 200), 0);
    });

    test('overpayment gives the difference back', () {
      expect(changeDue(237, 500), 263);
    });

    test('short cash gives a negative value', () {
      expect(changeDue(500, 200), -300);
    });
  });

  group('stock decrement', () {
    test('decrements stock for each sold item', () {
      final items = [
        SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 3),
        SaleItem(productId: 'p2', name: 'Tea 100 g', price: 95, quantity: 2),
      ];
      final updated = applySaleToStock(testProducts(), items);
      expect(updated, isNotNull);
      expect(updated![0].stock, 7);
      expect(updated[1].stock, 3);
      expect(updated[2].stock, 0);
    });

    test('selling the exact remaining stock leaves zero', () {
      final items = [
        SaleItem(productId: 'p2', name: 'Tea 100 g', price: 95, quantity: 5),
      ];
      final updated = applySaleToStock(testProducts(), items);
      expect(updated, isNotNull);
      expect(updated![1].stock, 0);
    });

    test('returns null when quantity exceeds stock', () {
      final items = [
        SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 11),
      ];
      expect(applySaleToStock(testProducts(), items), isNull);
    });

    test('returns null when product is already out of stock', () {
      final items = [
        SaleItem(productId: 'p3', name: 'Soap', price: 55, quantity: 1),
      ];
      expect(applySaleToStock(testProducts(), items), isNull);
    });

    test('returns null for an unknown product', () {
      final items = [
        SaleItem(productId: 'nope', name: 'Ghost', price: 10, quantity: 1),
      ];
      expect(applySaleToStock(testProducts(), items), isNull);
    });

    test('does not change the original product list', () {
      final products = testProducts();
      final items = [
        SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 3),
      ];
      applySaleToStock(products, items);
      expect(products[0].stock, 10);
    });
  });

  group('daily sales', () {
    Sale saleOn(DateTime day, double total) => Sale(
          id: 's-${day.day}',
          dateTime: day,
          items: [
            SaleItem(
              productId: 'p1',
              name: 'Rice 1 kg',
              price: 72,
              quantity: 2,
            ),
          ],
          total: total,
          cashGiven: total,
        );

    test('salesOnDay keeps only that calendar day', () {
      final sales = [
        saleOn(DateTime(2026, 11, 11, 9), 144),
        saleOn(DateTime(2026, 11, 11, 18), 200),
        saleOn(DateTime(2026, 11, 10, 12), 300),
      ];
      expect(salesOnDay(sales, DateTime(2026, 11, 11)).length, 2);
    });

    test('daily summary totals sales and counts bills', () {
      final sales = [
        saleOn(DateTime(2026, 11, 11, 9), 144),
        saleOn(DateTime(2026, 11, 11, 18), 200),
        saleOn(DateTime(2026, 11, 10, 12), 300),
      ];
      final summary = dailySummary(sales, DateTime(2026, 11, 11));
      expect(summary.totalSales, 344);
      expect(summary.billCount, 2);
      expect(summary.averageBill, 172);
    });

    test('daily summary is zero on a day with no sales', () {
      final summary = dailySummary([], DateTime(2026, 11, 11));
      expect(summary.totalSales, 0);
      expect(summary.billCount, 0);
      expect(summary.averageBill, 0);
    });

    test('top products rank by quantity sold', () {
      final sales = [
        Sale(
          id: 's1',
          dateTime: DateTime(2026, 11, 11, 9),
          items: [
            SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 2),
            SaleItem(productId: 'p2', name: 'Tea 100 g', price: 95, quantity: 5),
          ],
          total: 619,
          cashGiven: 700,
        ),
        Sale(
          id: 's2',
          dateTime: DateTime(2026, 11, 11, 12),
          items: [
            SaleItem(productId: 'p1', name: 'Rice 1 kg', price: 72, quantity: 1),
          ],
          total: 72,
          cashGiven: 100,
        ),
      ];
      final top = topProducts(sales);
      expect(top.length, 2);
      expect(top[0].name, 'Tea 100 g');
      expect(top[0].quantity, 5);
      expect(top[1].name, 'Rice 1 kg');
      expect(top[1].quantity, 3);
      expect(top[1].revenue, 216);
    });
  });
}

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

  group('bill math', () {
    test('no discount and no tax totals the subtotal', () {
      final bill = computeBill(subtotal: 500);
      expect(bill.subtotal, 500);
      expect(bill.discount, 0);
      expect(bill.tax, 0);
      expect(bill.total, 500);
    });

    test('zero percent discount changes nothing', () {
      final bill = computeBill(
        subtotal: 500,
        discountKind: 'percent',
        discountValue: 0,
      );
      expect(bill.discount, 0);
      expect(bill.total, 500);
    });

    test('ten percent discount on 500 is 50 off', () {
      final bill = computeBill(
        subtotal: 500,
        discountKind: 'percent',
        discountValue: 10,
      );
      expect(bill.discount, 50);
      expect(bill.total, 450);
    });

    test('100 percent discount makes the total zero', () {
      final bill = computeBill(
        subtotal: 500,
        discountKind: 'percent',
        discountValue: 100,
      );
      expect(bill.discount, 500);
      expect(bill.total, 0);
    });

    test('percent above 100 is clamped to 100', () {
      final bill = computeBill(
        subtotal: 500,
        discountKind: 'percent',
        discountValue: 150,
      );
      expect(bill.discount, 500);
      expect(bill.total, 0);
    });

    test('amount discount is clamped to the subtotal', () {
      final bill = computeBill(
        subtotal: 200,
        discountKind: 'amount',
        discountValue: 999,
      );
      expect(bill.discount, 200);
      expect(bill.total, 0);
    });

    test('tax off means zero tax', () {
      final bill = computeBill(subtotal: 500, taxRatePercent: 0);
      expect(bill.tax, 0);
      expect(bill.total, 500);
    });

    test('tax is charged on the amount after discount', () {
      final bill = computeBill(
        subtotal: 1000,
        discountKind: 'percent',
        discountValue: 10,
        taxRatePercent: 15,
      );
      expect(bill.discount, 100);
      expect(bill.tax, 135);
      expect(bill.total, 1035);
    });

    test('tax rounds to whole Taka', () {
      final bill = computeBill(subtotal: 333, taxRatePercent: 15);
      expect(bill.tax, 50);
      expect(bill.total, 383);
    });

    test('negative subtotal is treated as zero', () {
      final bill = computeBill(subtotal: -50);
      expect(bill.total, 0);
    });
  });

  group('profit', () {
    test('profit is margin minus discount, tax excluded', () {
      final sale = Sale(
        id: 's1',
        dateTime: DateTime(2026, 11, 14, 10),
        items: [
          SaleItem(
            productId: 'p1',
            name: 'Rice 1 kg',
            price: 72,
            quantity: 2,
            costPrice: 60,
          ),
          SaleItem(
            productId: 'p2',
            name: 'Tea 100 g',
            price: 95,
            quantity: 1,
            costPrice: 95,
          ),
        ],
        total: 229,
        cashGiven: 250,
        subtotal: 239,
        discountAmount: 10,
        taxAmount: 0,
      );
      expect(sale.grossProfit, 24 - 10);
    });

    test('unknown cost price counts the full price as profit', () {
      final sale = Sale(
        id: 's1',
        dateTime: DateTime(2026, 11, 14, 10),
        items: [
          SaleItem(productId: 'p1', name: 'Rice', price: 72, quantity: 1),
        ],
        total: 72,
        cashGiven: 72,
      );
      expect(sale.grossProfit, 72);
    });

    test('range summary totals profit and margin', () {
      final sales = [
        Sale(
          id: 's1',
          dateTime: DateTime(2026, 11, 14, 10),
          items: [
            SaleItem(
              productId: 'p1',
              name: 'Rice',
              price: 100,
              quantity: 2,
              costPrice: 60,
            ),
          ],
          total: 200,
          cashGiven: 200,
        ),
        Sale(
          id: 's2',
          dateTime: DateTime(2026, 11, 14, 11),
          items: [
            SaleItem(
              productId: 'p2',
              name: 'Tea',
              price: 100,
              quantity: 1,
              costPrice: 90,
            ),
          ],
          total: 100,
          cashGiven: 100,
        ),
      ];
      final summary = rangeSummary(sales);
      expect(summary.totalSales, 300);
      expect(summary.billCount, 2);
      expect(summary.grossProfit, 90);
      expect(summary.marginPercent, 30);
    });

    test('net profit subtracts expenses', () {
      final sales = [
        Sale(
          id: 's1',
          dateTime: DateTime(2026, 11, 14, 10),
          items: [
            SaleItem(
              productId: 'p1',
              name: 'Rice',
              price: 100,
              quantity: 1,
              costPrice: 60,
            ),
          ],
          total: 100,
          cashGiven: 100,
        ),
      ];
      final expenses = [
        Expense(
          id: 'e1',
          dateTime: DateTime(2026, 11, 14),
          category: 'Transport',
          amount: 15,
        ),
      ];
      expect(netProfit(sales, expenses), 25);
    });
  });

  group('barcode lookup', () {
    final products = [
      Product(id: 'p1', name: 'Rice', price: 72, stock: 5, barcode: '100001'),
      Product(id: 'p2', name: 'Tea', price: 95, stock: 5),
    ];

    test('finds a product by its barcode', () {
      expect(findProductByBarcode(products, '100001')?.id, 'p1');
    });

    test('trims whitespace around the code', () {
      expect(findProductByBarcode(products, '  100001  ')?.id, 'p1');
    });

    test('returns null for an unknown barcode', () {
      expect(findProductByBarcode(products, '999999'), isNull);
    });

    test('returns null for an empty code', () {
      expect(findProductByBarcode(products, '   '), isNull);
    });

    test('a product without a barcode never matches', () {
      expect(findProductByBarcode(products, 'Tea'), isNull);
    });
  });

  group('low stock', () {
    test('flags stock at or below the threshold', () {
      final products = [
        Product(id: 'p1', name: 'A', price: 10, stock: 5, lowStockAt: 5),
        Product(id: 'p2', name: 'B', price: 10, stock: 6, lowStockAt: 5),
        Product(id: 'p3', name: 'C', price: 10, stock: 0, lowStockAt: 5),
      ];
      final low = lowStockProducts(products);
      expect(low.map((p) => p.id).toList(), ['p3', 'p1']);
    });

    test('custom threshold is honoured', () {
      final product =
          Product(id: 'p1', name: 'A', price: 10, stock: 9, lowStockAt: 10);
      expect(product.isLowStock, isTrue);
    });
  });

  group('khata ledger', () {
    final entries = [
      LedgerEntry(
        id: 'l1',
        customerId: 'c1',
        dateTime: DateTime(2026, 11, 13),
        kind: 'sale',
        amount: 500,
      ),
      LedgerEntry(
        id: 'l2',
        customerId: 'c1',
        dateTime: DateTime(2026, 11, 14),
        kind: 'payment',
        amount: 200,
      ),
      LedgerEntry(
        id: 'l3',
        customerId: 'c2',
        dateTime: DateTime(2026, 11, 14),
        kind: 'sale',
        amount: 100,
      ),
    ];

    test('balance is sales minus payments for one customer', () {
      expect(customerBalance(entries, 'c1'), 300);
    });

    test('other customers do not affect the balance', () {
      expect(customerBalance(entries, 'c2'), 100);
    });

    test('total outstanding sums every customer', () {
      expect(totalOutstanding(entries), 400);
    });

    test('full payment settles the balance to zero', () {
      final settled = [
        ...entries,
        LedgerEntry(
          id: 'l4',
          customerId: 'c1',
          dateTime: DateTime(2026, 11, 14),
          kind: 'payment',
          amount: 300,
        ),
      ];
      expect(customerBalance(settled, 'c1'), 0);
    });

    test('ledger for one customer is newest first', () {
      final mine = ledgerForCustomer(entries, 'c1');
      expect(mine.length, 2);
      expect(mine.first.id, 'l2');
    });
  });

  group('payment methods and ranges', () {
    Sale sale(
      String method,
      double total,
      double paid,
      DateTime when,
    ) =>
        Sale(
          id: 's-$method-${when.day}',
          dateTime: when,
          items: [
            SaleItem(productId: 'p1', name: 'Rice', price: total, quantity: 1),
          ],
          total: total,
          cashGiven: paid,
          paymentMethod: method,
          amountDue: method == 'credit' ? total - paid : 0,
        );

    test('totals split by payment method', () {
      final sales = [
        sale('cash', 100, 100, DateTime(2026, 11, 14, 9)),
        sale('bkash', 200, 200, DateTime(2026, 11, 14, 10)),
        sale('cash', 50, 50, DateTime(2026, 11, 14, 11)),
      ];
      final totals = totalsByPaymentMethod(sales);
      expect(totals['cash'], 150);
      expect(totals['bkash'], 200);
    });

    test('cash drawer counts cash sales only, minus change', () {
      final sales = [
        sale('cash', 100, 150, DateTime(2026, 11, 14, 9)),
        sale('bkash', 200, 200, DateTime(2026, 11, 14, 10)),
        sale('credit', 300, 100, DateTime(2026, 11, 14, 11)),
      ];
      expect(cashDrawerTotal(sales), 100);
    });

    test('week range starts on Monday', () {
      // 2026-11-14 is a Saturday.
      expect(weekStart(DateTime(2026, 11, 14)), DateTime(2026, 11, 9));
    });

    test('salesInRange keeps only the week', () {
      final sales = [
        sale('cash', 100, 100, DateTime(2026, 11, 9, 9)),
        sale('cash', 200, 200, DateTime(2026, 11, 14, 9)),
        sale('cash', 300, 300, DateTime(2026, 11, 8, 9)),
      ];
      final week = salesInRange(
        sales,
        DateTime(2026, 11, 9),
        DateTime(2026, 11, 16),
      );
      expect(week.length, 2);
    });

    test('credit sale reports its due amount', () {
      final credit = sale('credit', 300, 100, DateTime(2026, 11, 14, 11));
      expect(credit.isCreditSale, isTrue);
      expect(credit.amountDue, 200);
      expect(credit.change, 0);
    });
  });

  group('old saved data still loads', () {
    test('product without new fields gets defaults', () {
      final product = Product.fromJson({
        'id': 'p1',
        'name': 'Rice',
        'price': 72,
        'stock': 10,
        'category': 'Grocery',
      });
      expect(product.costPrice, 0);
      expect(product.barcode, isNull);
      expect(product.lowStockAt, 5);
    });

    test('sale without new fields gets defaults', () {
      final sale = Sale.fromJson({
        'id': 's1',
        'dateTime': '2026-11-10T10:00:00.000',
        'items': [
          {'productId': 'p1', 'name': 'Rice', 'price': 72, 'quantity': 2},
        ],
        'total': 144,
        'cashGiven': 200,
      });
      expect(sale.paymentMethod, 'cash');
      expect(sale.discountAmount, 0);
      expect(sale.taxAmount, 0);
      expect(sale.amountDue, 0);
      expect(sale.subtotal, isNull);
      expect(sale.effectiveSubtotal, 144);
      expect(sale.change, 56);
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

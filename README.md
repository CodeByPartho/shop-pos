# ShopPOS

Offline first point of sale app for small shops, built with Flutter. Day 4 of a one app per day reference build series by Partho Sarothi Paik.

## What it does

- **Products:** list of shop products with price and stock. Add a new product (name, price, opening stock, category), search by name, add stock, or delete a product.
- **Cart:** add items from the product list, change quantities, remove items. The cart never lets you add more than the stock on hand.
- **Checkout:** enter the cash given, see the change due, and complete the sale. Checkout saves the sale and decrements stock. Cash short of the total cannot be checked out.
- **Receipt:** after checkout, a receipt screen shows the bill number, items, total, cash given and change. Any past sale can be reopened from History.
- **Sales history:** past sales grouped by day, with bill count and day total.
- **Daily report:** pick a day and see total sales, number of bills, average bill, and the top products sold that day.
- **Offline first:** all data is stored on the device with shared_preferences (JSON). No account, no server, no internet needed.

## Demo data

The app ships with 12 realistic shop products (rice, sugar, cooking oil, salt, tea, noodles, biscuits, eggs, milk, soap, shampoo, toothpaste) priced in Taka. Use the reset button in the app bar to restore the demo products and clear all sales.

## Tech

- Flutter with Material 3 dark theme and a #39FF88 accent
- State: provider
- Persistence: shared_preferences (JSON)
- Formatting: intl (Taka currency, dates)
- Dependencies only: provider, intl, shared_preferences, flutter_lints (dev)

## Run it

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```

16 unit tests cover cart totals, change due, stock decrement (including over-selling and out of stock cases), daily sales filtering, daily summaries and top product ranking.

## Project structure

- `lib/models/models.dart` - Product, SaleItem and Sale models with JSON support
- `lib/logic/pos_logic.dart` - pure logic: cart totals, change, stock decrement, daily summaries, top products
- `lib/state/pos_state.dart` - app state, cart, checkout, persistence and demo seed
- `lib/screens/` - products, cart, receipt, history, daily report and main shell
- `lib/utils/format.dart` - Taka and date formatting
- `test/pos_logic_test.dart` - unit tests for the logic layer

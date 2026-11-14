# ShopPOS Improvement Plan (research only, no code changed)

App: ShopPOS v1.0.0, offline-first Flutter POS for small shops.
Repo: github.com/CodeByPartho/shop-pos. Local code: ~/workspace/reference-builds/shop-pos/
Stack today: provider, intl, shared_preferences. Material 3 dark theme, #39FF88 accent.
Demo seed: 12 products in Taka. Reset option exists.

## What exists today (verified by reading lib/)

- Products: add (name, price, stock, category), search by name, add stock, delete. No edit, no barcode, no cost price, no low-stock level, no supplier, no photo.
- Cart: add, change quantity, remove, capped at stock. No hold/park, no discount, no quick cash buttons.
- Checkout: cash only. Cash given, change due, saves sale, decrements stock. No payment method, no partial payment, no credit sale.
- Receipt: on-screen only, bill number, items, total, cash, change. No share, no PDF, no print.
- History: sales grouped by day, reopen receipt. No refund, no void, no edit.
- Report: one day only (date picker), total sales, bills, average bill, top products. No week/month, no profit, no charts, no breakdown by payment method.
- Storage: one shared_preferences JSON blob under key shop_pos_data_v1. No backup, no export, no migration path.
- Models: Product has id, name, price, stock, category. Sale has id, dateTime, items, total, cashGiven. SaleItem snapshots name and price only, not cost.

## Research sources

- Square POS and Loyverse free-plan comparisons: technologyadvice.com/blog/sales/free-pos-system/, selecthub.com/pos-software/square-pos-vs-loyverse-pos/, businessexpert.co.uk/payment-processing/best-free-pos-systems/
- Loyverse feature and pricing detail: merchantswitch.com/blog/loyverse-review-uk, loyverse.com/en-us/download-loyverse, merchantmaverick.com/reviews/loyverse-review/
- Kyte and eHopper: play.google.com/store/apps/details?id=com.kyte, getapp.com/retail-consumer-services-software/a/ehopper/
- Bangladesh POS and khata apps (the local competition): tukri.bd/, appbrain.com/app/shohoj-hishab-shop-pos-khata/com.shohojhishab.app, bakirkhata.com/en/, bisnesy.com/tour, itqano.com/products/dokaniai
- Flutter packages: pub.dev/packages/mobile_scanner (v7.4.4), pub.dev/packages/share_plus (v13.3.1, needs Flutter 3.38+), pub.dev/packages/whatsapp_share_plus, pub.dev/packages/posprint_kit (v1.0.0, Bangla support), pub.dev/packages/print_bluetooth_thermal, pub.dev/packages/esc_pos_utils_plus

## Ranked improvement list (highest user value first)

### 1. Barcode scanning via camera
Why: typing or searching every item is the slowest part of the counter; scanning is what makes a POS feel like a POS.
Feasibility: Medium. Add a nullable barcode field to Product (old data keeps working). Add a scan button on Products and Cart. New lib/screens/scan_screen.dart using MobileScanner with DetectionSpeed.noDuplicates; on detect, look up the product by barcode and add it to the cart. Unknown barcode opens the add-product dialog with the code prefilled. Also keep a manual barcode text field, because cheap USB scanners act like keyboards and need no code at all.
New dep: mobile_scanner ^7.4.0 (free). Android needs the CAMERA permission in AndroidManifest.xml; iOS needs NSCameraUsageDescription. Works on web through the ZXing fallback.
Files: pubspec.yaml, lib/models/models.dart, lib/state/pos_state.dart, lib/screens/products_screen.dart, lib/screens/cart_screen.dart, new lib/screens/scan_screen.dart, android/app/src/main/AndroidManifest.xml, test/pos_logic_test.dart.

### 2. Cost price, profit, and weekly/monthly reports
Why: total sales is not profit. The shopkeeper needs to know what was actually earned, and by which product.
Feasibility: Easy to medium. Add costPrice to Product and snapshot it on SaleItem at sale time. Profit per sale is sum((price minus cost) times qty). Extend the report screen with week and month range pickers, gross profit, margin percent, best profit products, and a simple bar chart of the last 7 or 30 days. Pure Dart aggregation in pos_logic.dart; only the chart needs a package.
New dep: fl_chart (latest stable, free) for the bars.
Files: lib/models/models.dart, lib/logic/pos_logic.dart, lib/state/pos_state.dart, lib/screens/products_screen.dart (cost field in add/edit form), lib/screens/report_screen.dart, test/pos_logic_test.dart.

### 3. Customer credit ledger (udhaar / baki khata)
Why: every Bangladeshi neighbourhood shop sells on credit. Paper khata gets lost, wet or torn, and nobody knows who owes what. Every local competitor (Tukri, Shohoj Hishab, Bakir Khata, Bisnesy) leads with this; Square and Loyverse do not have it, which is exactly the gap a BD shop app can win on.
Feasibility: Medium. New Customer model (name, optional phone) and LedgerEntry model (customerId, saleId, amount, debit or credit, date). Checkout gains "Sell on credit" or partial payment: paid now plus due. New Khata tab lists customers by balance owed, shows each customer's ledger, and records payments (cash, bKash or Nagad). Report shows total outstanding. No SMS (that costs money); a payment reminder can be shared as WhatsApp text through share_plus, see item 7.
New dep: none on its own.
Files: lib/models/models.dart, lib/state/pos_state.dart, new lib/screens/khata_screen.dart, lib/screens/cart_screen.dart, lib/screens/receipt_screen.dart, lib/screens/main_shell.dart, test/pos_logic_test.dart.

### 4. Low-stock alerts
Why: an out-of-stock fast seller is a lost sale every time. The app shows stock numbers today but never warns about them.
Feasibility: Easy. Add a lowStockAt threshold per product (default 5, editable). Products tab shows a red badge and a "Low stock" filter chip; optionally a daily local notification listing low items.
New dep: none for in-app warnings; flutter_local_notifications (free) only if reminders are wanted.
Files: lib/models/models.dart, lib/state/pos_state.dart, lib/screens/products_screen.dart, lib/screens/main_shell.dart (badge), test/pos_logic_test.dart.

### 5. Discounts and optional tax / VAT
Why: regulars expect a small discount and festival offers are normal; a VAT-registered shop needs tax on the bill. Discounts are core checkout features in both Square and Loyverse.
Feasibility: Easy. Add per-line discount (percent or Taka) and bill-level discount. Sale stores subtotal, discount, tax and total; the cart screen shows the breakdown. Tax rate is a shop setting, default 0 (off), since most small shops do not charge VAT. Keep amounts in whole Taka to avoid paisa rounding confusion.
New dep: none.
Files: lib/models/models.dart, lib/logic/pos_logic.dart, lib/state/pos_state.dart, lib/screens/cart_screen.dart, lib/screens/receipt_screen.dart, test/pos_logic_test.dart.

### 6. Payment methods: cash, bKash, Nagad, split payment
Why: customers increasingly pay by bKash or Nagad. Recording everything as cash makes the daily cash count wrong.
Feasibility: Easy to medium. Add a paymentMethod field to Sale (cash, bKash, Nagad, card, split). Checkout shows a method selector and, for split, two amount fields. Report breaks totals down by method; the cash drawer total counts cash only. No payment API and no credentials: the app only records the method the shopkeeper selects, and the money moves outside the app.
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, lib/screens/cart_screen.dart, lib/screens/receipt_screen.dart, lib/screens/report_screen.dart, lib/screens/history_screen.dart, test/pos_logic_test.dart.

### 7. Receipt sharing (WhatsApp / share sheet) and PDF receipt
Why: customers ask for the bill on WhatsApp. A shareable receipt is free proof of purchase and free marketing.
Feasibility: Easy. Build a plain-text receipt from the Sale (all fields already exist) and share it through the system share sheet; the customer picks WhatsApp. Optional PDF version for a cleaner look, saved to a temp file and shared as a file. No WhatsApp API, no account, no cost.
New dep: share_plus (free; latest version compatible with the installed Flutter SDK, noting v13 needs Flutter 3.38 or newer). For PDF: pdf plus path_provider (both free).
Files: lib/screens/receipt_screen.dart, new lib/utils/receipt_text.dart, pubspec.yaml, test/pos_logic_test.dart.

### 8. Expense tracking and daily profit and loss
Why: rent, transport, shop supplies and helper pay eat the margin. Without expenses the profit number from item 2 is fiction.
Feasibility: Easy. New Expense model (date, category, amount, note) and an Expenses tab with add and list. Report shows sales profit minus expenses equals net profit for the day, week or month.
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, new lib/screens/expenses_screen.dart, lib/screens/report_screen.dart, lib/screens/main_shell.dart, test/pos_logic_test.dart.

### 9. Supplier info and purchase tracking
Why: restock today adds stock with no record of what it cost or who supplied it, so cost price drifts and supplier dues are invisible.
Feasibility: Medium. New Supplier model (name, phone) and Purchase model (supplierId, productId, qty, unitCost, date, paid or due). The restock dialog becomes a purchase entry that adds stock and updates the product cost price (latest cost, or weighted average). A supplier screen shows what is owed per supplier. This is what makes item 2 profit numbers stay accurate over time.
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, lib/screens/products_screen.dart, new lib/screens/suppliers_screen.dart, lib/screens/main_shell.dart, test/pos_logic_test.dart.

### 10. Backup, export and restore (CSV / JSON)
Why: all data lives in one shared_preferences JSON blob on one phone. A lost phone or a bad update wipes the whole shop.
Feasibility: Easy to medium. Export all data as a JSON backup and sales as CSV; share or save the file. Import restores from a picked file behind a confirm dialog. Keep the existing reset option untouched.
New dep: file_picker and path_provider (free); share_plus from item 7 for sending the file.
Files: new lib/services/backup_service.dart, lib/state/pos_state.dart (export/import), lib/screens/main_shell.dart (backup button), pubspec.yaml.

### 11. Edit product, category filter, product photos
Why: price changes are daily work and today require delete and re-add, which loses the product id and history link. Photos make the grid faster to scan at the counter.
Feasibility: Easy for edit and filter, medium for photos. Add an edit dialog reusing the add-product form plus an updateProduct method; add category chips to filter the list. Optional photo with image_picker, stored as a local file path.
New dep: image_picker (free) only for photos.
Files: lib/screens/products_screen.dart, lib/state/pos_state.dart, lib/models/models.dart.

### 12. Hold / park sale and quick cash buttons
Why: a customer who forgot their wallet blocks the whole queue. Parked sales and one-tap 100 / 500 / 1000 cash buttons keep the line moving.
Feasibility: Easy. Store parked carts (cart map plus label and time) in state and persistence; cart screen gets Park and Resume. Cash field gets Exact, 100, 500, 1000, 2000 quick chips.
New dep: none.
Files: lib/state/pos_state.dart, lib/screens/cart_screen.dart, lib/models/models.dart (or parked carts as a list in state).

### 13. Bluetooth thermal printing
Why: a printed receipt looks professional and customers expect one at bigger shops. BD competitors all print on cheap 58/80 mm Bluetooth printers.
Feasibility: Medium to hard. Build ESC/POS bytes from the Sale, reusing the receipt text builder from item 7. Add a settings screen to scan and pair a printer, and a Print button on the receipt and in history. Needs a physical printer to test; keep printing optional and keep share as the fallback.
New dep: posprint_kit ^1.0.0 (free, simplest API, supports Bangla text, WiFi/Bluetooth/USB) or esc_pos_utils_plus plus print_bluetooth_thermal.
Files: lib/screens/receipt_screen.dart, new lib/services/printer_service.dart, new settings screen, pubspec.yaml, android/app/src/main/AndroidManifest.xml (Bluetooth permissions).

### 14. Multiple users / cashiers with PIN
Why: with a helper at the counter the owner cannot tell who sold what or who gave an unauthorised discount. Staff accountability is a standard Square/Loyverse paid feature and a top complaint about free POS apps.
Feasibility: Medium. New Cashier model (name, 4-digit PIN stored locally, role owner or staff). PIN screen on app start or on switch user. Sale records cashierId; report filters by cashier; staff role cannot delete products, reset data or see profit. No accounts, no server; the PIN is local only.
New dep: none (flutter_secure_storage is optional for the PIN).
Files: lib/models/models.dart, lib/state/pos_state.dart, new lib/screens/pin_screen.dart, lib/main.dart, lib/screens/report_screen.dart, lib/screens/products_screen.dart (permission checks), lib/screens/main_shell.dart.

### 15. Shift open / close and cash reconciliation
Why: the owner closes the day by counting cash in hand. The app should say what cash should be there.
Feasibility: Medium. New Shift model (openedAt, openingCash, expectedCash, countedCash, closedAt) plus cash-in/out entries during the shift. Close-shift screen shows expected vs counted and the difference; report shows the shift summary. Pairs with item 6, since only cash sales count toward the drawer.
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, new lib/screens/shift_screen.dart, lib/screens/report_screen.dart, lib/screens/main_shell.dart.

### 16. Refunds, voids and sale correction
Why: wrong items and returns happen daily. Today the only fix is to live with a wrong sale, which corrupts reports and stock.
Feasibility: Medium. Add a refund/void action on a sale in History: it returns stock, records a negative sale or a voided flag, and keeps the original for audit. Void needs the owner PIN if multi-user (item 14) is on.
New dep: none.
Files: lib/models/models.dart, lib/logic/pos_logic.dart, lib/state/pos_state.dart, lib/screens/history_screen.dart, test/pos_logic_test.dart.

### 17. Bangla language toggle
Why: many shopkeepers and helpers read Bangla better than English. Every BD competitor is Bangla-first.
Feasibility: Easy to medium. intl is already a dependency; add Bangla strings behind a language setting and a toggle in settings. Product names stay as typed. Use flutter_localizations, which ships with the Flutter SDK (no new package).
New dep: none.
Files: new lib/l10n/ strings, lib/main.dart, lib/screens/main_shell.dart, all screens (string extraction).

### 18. Customer list and simple loyalty
Why: regulars are the business. A name on the bill and a small reward brings them back. Loyverse includes loyalty free.
Feasibility: Medium. Reuses the Customer model from item 3: attach a customer to a sale, show their total spent and visit count, optional points (1 point per 100 Taka, redeemable for a discount).
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, lib/screens/cart_screen.dart, new customers screen, lib/screens/report_screen.dart.

### 19. Stock count, expiry dates and dead stock report
Why: the shelf never matches the app after months of manual mistakes, and perishables expire unsold.
Feasibility: Medium. Add an optional expiryDate to Product; add a stock-count mode that takes counted quantities and shows the variance; report lists expired or near-expiry items and products with zero sales in 30 days.
New dep: none.
Files: lib/models/models.dart, lib/state/pos_state.dart, lib/screens/products_screen.dart, lib/screens/report_screen.dart.

### 20. Migrate storage to SQLite when data grows
Why: one shared_preferences JSON string is fine for 12 products and a few hundred sales, but gets slow and risky at thousands of sales, and range queries (weekly reports) get expensive.
Feasibility: Hard. Migrate to Drift (or sqflite) with a one-time migration from the JSON blob, keeping the same models and provider state. Keep offline-first and keep reset. Do this only after items 1 to 10: it touches everything and has no user-visible payoff on its own.
New dep: drift plus drift_flutter (or sqflite), free.
Files: pubspec.yaml, new lib/data/database.dart, lib/state/pos_state.dart, all screens indirectly, test/pos_logic_test.dart.

## Deliberately NOT recommended (breaks the hard constraints)

- Cloud sync or accounts: needs a server, ongoing cost, and credentials.
- Card payment processing inside the app: needs a payment provider merchant account; Square/Stripe merchant services are not straightforward for Bangladesh shops, and bKash/Nagad merchant APIs need a merchant account and credentials.
- SMS reminders: SMS credit is a paid consumable in Bangladesh.
- AI features: need a paid API key.

## Suggested build order (differs from value rank: quick wins first)

- v1.1 quick wins: items 4 (low stock), 5 (discounts/tax), 11 (edit product), 12 (park sale), 7 (receipt share). All easy, no hardware, no new screens except small ones.
- v1.2 money truth: items 2 (cost/profit/reports), 6 (payment methods), 8 (expenses), 3 (khata). These four together answer "what did I really earn and who owes me".
- v1.3 buying and safety: items 9 (suppliers/purchases), 10 (backup/export).
- v2.0 counter speed and hardware: items 1 (barcode), 13 (printing), 16 (refunds).
- v2.1 team and trust: items 14 (cashiers/PIN), 15 (shifts), 17 (Bangla), 18 (loyalty), 19 (stock count), 20 (SQLite).

## Notes for the builder

- Keep the demo seed and reset exactly as they are; new fields must be nullable or defaulted so old saved data still loads.
- The GitHub Pages web build exists, so every feature should degrade gracefully on web: camera scanning works (ZXing fallback), Bluetooth printing does not, and the share sheet falls back to download/copy.
- Keep whole-Taka amounts everywhere; avoid paisa decimals in the UI.
- Every money feature (profit, khata, expenses, shifts) should get unit tests in test/pos_logic_test.dart the same way cart totals and stock decrement do today.

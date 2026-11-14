import '../models/models.dart';
import 'format.dart';

/// Plain-text receipt that can be shared to WhatsApp or any app from
/// the system share sheet, or copied when sharing is unavailable.
String receiptText(Sale sale) {
  final lines = <String>[
    'ShopPOS',
    '${dayLabel(sale.dateTime)} at ${timeLabel(sale.dateTime)}',
    'Bill #${sale.id}',
    '------------------------------',
  ];
  for (final item in sale.items) {
    lines.add(
      '${item.name} x ${item.quantity}  ${money(item.lineTotal)}',
    );
  }
  lines.add('------------------------------');
  lines.add('Subtotal  ${money(sale.effectiveSubtotal)}');
  if (sale.discountAmount > 0) {
    lines.add('Discount  -${money(sale.discountAmount)}');
  }
  if (sale.taxAmount > 0) {
    lines.add('Tax  ${money(sale.taxAmount)}');
  }
  lines.add('Total  ${money(sale.total)}');
  lines.add('Paid by ${PaymentMethods.label(sale.paymentMethod)}: '
      '${money(sale.cashGiven)}');
  if (sale.change > 0) {
    lines.add('Change  ${money(sale.change)}');
  }
  if (sale.isCreditSale) {
    lines.add(
      'Due: ${money(sale.amountDue)}'
      '${sale.customerName == null ? '' : ' (${sale.customerName})'}',
    );
  }
  lines.add('Thank you for shopping with us.');
  return lines.join('\n');
}

/// Short payment reminder for a khata customer, ready to share on
/// WhatsApp or copy. No message is ever sent by the app itself.
String khataReminderText({
  required String customerName,
  required double balance,
  required String shopName,
}) {
  return 'Hello $customerName, this is $shopName. '
      'Your pending balance is ${money(balance)}. '
      'Please pay at your convenience. Thank you.';
}

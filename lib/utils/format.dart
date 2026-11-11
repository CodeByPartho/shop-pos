import 'package:intl/intl.dart';

final NumberFormat taka = NumberFormat.currency(
  symbol: '\u09f3',
  decimalDigits: 0,
);

String money(double value) => taka.format(value);

String dayLabel(DateTime date) => DateFormat('EEEE, d MMMM yyyy').format(date);

String shortDayLabel(DateTime date) => DateFormat('d MMM yyyy').format(date);

String timeLabel(DateTime date) => DateFormat('h:mm a').format(date);

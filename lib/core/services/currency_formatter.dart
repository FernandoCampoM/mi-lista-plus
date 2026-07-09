import 'package:intl/intl.dart';

import '../../domain/entities/country.dart';

class CurrencyFormatter {
  CurrencyFormatter(this.country);

  final Country country;

  String money(num value) {
    final decimalDigits = value % 1 == 0 ? 0 : 2;
    final amount = NumberFormat.decimalPatternDigits(
      locale: country.locale,
      decimalDigits: decimalDigits,
    ).format(value);

    final symbol = NumberFormat.simpleCurrency(
      locale: country.locale,
      name: country.currencyCode,
      decimalDigits: decimalDigits,
    ).currencySymbol;

    return '$symbol $amount';
  }
}

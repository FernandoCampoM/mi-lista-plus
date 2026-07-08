import 'package:intl/intl.dart';

import '../../domain/entities/country.dart';

class CurrencyFormatter {
  CurrencyFormatter(this.country);

  final Country country;

  String money(num value) {
    return NumberFormat.simpleCurrency(
      locale: country.locale,
      name: country.currencyCode,
      decimalDigits: value % 1 == 0 ? 0 : 2,
    ).format(value);
  }
}

class Country {
  const Country({
    required this.code,
    required this.name,
    required this.currencyCode,
    required this.flagEmoji,
    required this.locale,
  });

  final String code;
  final String name;
  final String currencyCode;
  final String flagEmoji;
  final String locale;
}

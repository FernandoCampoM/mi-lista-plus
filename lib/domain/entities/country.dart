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

const defaultCountryCode = 'COL';

const supportedCountries = [
  Country(code: 'COL', name: 'Colombia', currencyCode: 'COP', flagEmoji: '🇨🇴', locale: 'es_CO'),
  Country(code: 'DEU', name: 'Alemania', currencyCode: 'EUR', flagEmoji: '🇩🇪', locale: 'de_DE'),
  Country(code: 'ARG', name: 'Argentina', currencyCode: 'ARS', flagEmoji: '🇦🇷', locale: 'es_AR'),
  Country(code: 'BOL', name: 'Bolivia', currencyCode: 'BOB', flagEmoji: '🇧🇴', locale: 'es_BO'),
  Country(code: 'BRA', name: 'Brasil', currencyCode: 'BRL', flagEmoji: '🇧🇷', locale: 'pt_BR'),
  Country(code: 'BEL', name: 'Bélgica', currencyCode: 'EUR', flagEmoji: '🇧🇪', locale: 'fr_BE'),
  Country(code: 'CHL', name: 'Chile', currencyCode: 'CLP', flagEmoji: '🇨🇱', locale: 'es_CL'),
  
  Country(code: 'CRI', name: 'Costa Rica', currencyCode: 'CRC', flagEmoji: '🇨🇷', locale: 'es_CR'),
  Country(code: 'ECU', name: 'Ecuador', currencyCode: 'USD', flagEmoji: '🇪🇨', locale: 'es_EC'),
  Country(code: 'SLV', name: 'El Salvador', currencyCode: 'USD', flagEmoji: '🇸🇻', locale: 'es_SV'),
  Country(code: 'ESP', name: 'España', currencyCode: 'EUR', flagEmoji: '🇪🇸', locale: 'es_ES'),
  Country(code: 'USA', name: 'Estados Unidos', currencyCode: 'USD', flagEmoji: '🇺🇸', locale: 'en_US'),
  Country(code: 'FRA', name: 'Francia', currencyCode: 'EUR', flagEmoji: '🇫🇷', locale: 'fr_FR'),
  Country(code: 'GTM', name: 'Guatemala', currencyCode: 'GTQ', flagEmoji: '🇬🇹', locale: 'es_GT'),
  Country(code: 'HND', name: 'Honduras', currencyCode: 'HNL', flagEmoji: '🇭🇳', locale: 'es_HN'),
  Country(code: 'ITA', name: 'Italia', currencyCode: 'EUR', flagEmoji: '🇮🇹', locale: 'it_IT'),
  Country(code: 'MEX', name: 'México', currencyCode: 'MXN', flagEmoji: '🇲🇽', locale: 'es_MX'),
  Country(code: 'NIC', name: 'Nicaragua', currencyCode: 'NIO', flagEmoji: '🇳🇮', locale: 'es_NI'),
  Country(code: 'PAN', name: 'Panamá', currencyCode: 'USD', flagEmoji: '🇵🇦', locale: 'es_PA'),
  Country(code: 'PRY', name: 'Paraguay', currencyCode: 'PYG', flagEmoji: '🇵🇾', locale: 'es_PY'),
  Country(code: 'NLD', name: 'Países Bajos', currencyCode: 'EUR', flagEmoji: '🇳🇱', locale: 'nl_NL'),
  Country(code: 'PER', name: 'Perú', currencyCode: 'PEN', flagEmoji: '🇵🇪', locale: 'es_PE'),
  Country(code: 'PRT', name: 'Portugal', currencyCode: 'EUR', flagEmoji: '🇵🇹', locale: 'pt_PT'),
  Country(code: 'IRL', name: 'República De Irlanda', currencyCode: 'EUR', flagEmoji: '🇮🇪', locale: 'en_IE'),
  Country(code: 'DOM', name: 'República Dominicana', currencyCode: 'DOP', flagEmoji: '🇩🇴', locale: 'es_DO'),
  Country(code: 'RUS', name: 'Rusia', currencyCode: 'RUB', flagEmoji: '🇷🇺', locale: 'ru_RU'),
  Country(code: 'GB_SCT', name: 'Uk (Escocia)', currencyCode: 'GBP', flagEmoji: '🇬🇧', locale: 'en_GB'),
  Country(code: 'GB_WLS', name: 'Uk (Gales)', currencyCode: 'GBP', flagEmoji: '🇬🇧', locale: 'en_GB'),
  Country(code: 'GB_NIR', name: 'Uk (Irlanda Del Norte)', currencyCode: 'GBP', flagEmoji: '🇬🇧', locale: 'en_GB'),
  Country(code: 'URY', name: 'Uruguay', currencyCode: 'UYU', flagEmoji: '🇺🇾', locale: 'es_UY'),
];

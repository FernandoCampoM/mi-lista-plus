// ── NUEVO: pruebas del texto que acompaña la imagen compartida ──────────
// Propósito: fijar que el pie de la imagen solo lleve productos y total.
// Depende de: ShareSimulationService.buildImageCaption.
// No modifica: pruebas existentes.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mi_lista_plus/core/services/currency_formatter.dart';
import 'package:mi_lista_plus/core/services/share_simulation_service.dart';
import 'package:mi_lista_plus/domain/entities/cart_item.dart';
import 'package:mi_lista_plus/domain/entities/country.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/simulation.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es_CO'));

  const country = Country(
    code: 'COL',
    name: 'Colombia',
    currencyCode: 'COP',
    flagEmoji: '',
    locale: 'es_CO',
  );

  Product product(String id, String name, double price, int points) => Product(
        id: id,
        countryCode: 'COL',
        name: name,
        code: id,
        category: ProductCategory.nutrition,
        suggestedPrice: price,
        points: points,
        imageUrl: '',
        updatedAt: DateTime(2026, 1, 1),
        discountPrices: {40: price * .6},
      );

  final simulation = Simulation(
    id: 'abc123',
    countryCode: 'COL',
    customerName: 'Laura Gómez',
    discountPercent: 0,
    createdAt: DateTime(2026, 10, 5),
    items: [
      CartItem(product: product('f', 'Fibra', 50000, 25), quantity: 1),
      CartItem(product: product('a', 'Aloe', 40000, 18), quantity: 3),
    ],
  );

  test('el pie de la imagen lleva solo productos y total', () {
    final caption = ShareSimulationService.buildImageCaption(
      simulation: simulation,
      country: country,
    );

    expect(caption, contains('1 × Fibra'));
    expect(caption, contains('3 × Aloe'));
    expect(
      caption,
      contains('Total: ${CurrencyFormatter(country).money(simulation.totalAmount)}'),
    );
    expect(caption, isNot(contains('abc123')));
    expect(caption, isNot(contains('Laura')));
    expect(caption, isNot(contains('COL')));
    expect(caption, isNot(contains('pts')));
    expect(caption.trim().split('\n'), hasLength(5));
  });

  test('compartir como texto no cambia', () {
    final text = ShareSimulationService.buildShareText(
      simulation: simulation,
      country: country,
    );
    expect(text, contains('#abc123'));
    expect(text, contains('pts'));
  });
}

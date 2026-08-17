import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/utils/text_search.dart';

void main() {
  test('busqueda de productos ignora tildes y mayusculas', () {
    expect(
      searchMatchesProduct(
        query: 'Tonico',
        name: 'Tónico Herbal',
        code: 'ABC-1',
      ),
      isTrue,
    );
    expect(
      searchMatchesProduct(
        query: 'PINa',
        name: 'Aloe Beta Piña',
        code: '4250',
      ),
      isTrue,
    );
  });
}

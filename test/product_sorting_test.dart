import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/presentation/models/product_sort_option.dart';

void main() {
  final alpha = _product('a', 'Alpha', 90, 30);
  final beta = _product('b', 'Beta', 120, 20);
  final delta = _product('d', 'Delta', 70, 0);
  final echo = _product('e', 'Echo', 80, 0);
  final gamma = _product('g', 'Gamma', 60, 10);

  test('ordena existencias descendentes y desempata alfabeticamente', () {
    final products = [echo, gamma, beta, delta, alpha];

    sortProducts(
      products,
      ProductSortOption.stock,
      quantities: {
        alpha.id: 5,
        beta.id: 5,
        gamma.id: 2,
        delta.id: 0,
        echo.id: 0,
      },
    );

    expect(
      products.map((product) => product.name),
      ['Alpha', 'Beta', 'Gamma', 'Delta', 'Echo'],
    );
  });

  test('comparte los criterios de precio y puntos con el catalogo', () {
    final byPrice = [alpha, beta, gamma];
    sortProducts(byPrice, ProductSortOption.lowerPrice);
    expect(byPrice.map((product) => product.name), ['Gamma', 'Alpha', 'Beta']);

    final byPoints = [gamma, beta, alpha];
    sortProducts(byPoints, ProductSortOption.morePoints);
    expect(byPoints.map((product) => product.name), ['Alpha', 'Beta', 'Gamma']);
  });
}

Product _product(
  String id,
  String name,
  double suggestedPrice,
  int points,
) {
  return Product(
    id: id,
    countryCode: 'COL',
    name: name,
    code: id,
    category: ProductCategory.nutrition,
    suggestedPrice: suggestedPrice,
    points: points,
    imageUrl: '',
    updatedAt: DateTime(2026),
    discountPrices: {40: suggestedPrice * .6},
  );
}

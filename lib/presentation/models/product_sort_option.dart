import '../../domain/entities/product.dart';

enum ProductSortOption {
  stock,
  az,
  za,
  lowerPrice,
  higherPrice,
  morePoints,
  lessPoints,
  bestPointsPerCurrency,
}

const catalogProductSortOptions = [
  ProductSortOption.az,
  ProductSortOption.za,
  ProductSortOption.lowerPrice,
  ProductSortOption.higherPrice,
  ProductSortOption.morePoints,
  ProductSortOption.lessPoints,
  ProductSortOption.bestPointsPerCurrency,
];

String productSortLabel(ProductSortOption option) {
  return switch (option) {
    ProductSortOption.stock => 'Existencias',
    ProductSortOption.az => 'A-Z',
    ProductSortOption.za => 'Z-A',
    ProductSortOption.lowerPrice => 'Menor precio',
    ProductSortOption.higherPrice => 'Mayor precio',
    ProductSortOption.morePoints => 'Mas puntos',
    ProductSortOption.lessPoints => 'Menos puntos',
    ProductSortOption.bestPointsPerCurrency => 'Mas puntos por \$',
  };
}

void sortProducts(
  List<Product> products,
  ProductSortOption? option, {
  Map<String, int> quantities = const {},
}) {
  if (option == null) return;

  products.sort((a, b) {
    final comparison = switch (option) {
      ProductSortOption.stock =>
        (quantities[b.id] ?? 0).compareTo(quantities[a.id] ?? 0),
      ProductSortOption.az => _compareNames(a, b),
      ProductSortOption.za => _compareNames(b, a),
      ProductSortOption.lowerPrice =>
        a.suggestedPrice.compareTo(b.suggestedPrice),
      ProductSortOption.higherPrice =>
        b.suggestedPrice.compareTo(a.suggestedPrice),
      ProductSortOption.morePoints => b.points.compareTo(a.points),
      ProductSortOption.lessPoints => a.points.compareTo(b.points),
      ProductSortOption.bestPointsPerCurrency =>
        _comparePointsPerCurrency(a, b),
    };
    return comparison != 0 ? comparison : _compareNames(a, b);
  });
}

int _comparePointsPerCurrency(Product a, Product b) {
  final aHasPoints = a.points > 0;
  final bHasPoints = b.points > 0;
  if (aHasPoints != bHasPoints) return aHasPoints ? -1 : 1;
  if (!aHasPoints) return _compareNames(a, b);

  final byCostPerPoint =
      a.costPerPointAt40!.compareTo(b.costPerPointAt40!);
  if (byCostPerPoint != 0) return byCostPerPoint;

  final byPoints = b.points.compareTo(a.points);
  if (byPoints != 0) return byPoints;
  return a.priceForDiscount(40).compareTo(b.priceForDiscount(40));
}

int _compareNames(Product a, Product b) {
  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
}

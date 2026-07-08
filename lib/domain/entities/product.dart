enum ProductCategory { nutrition, beauty, kit }

class Product {
  const Product({
    required this.id,
    required this.countryCode,
    required this.name,
    required this.code,
    required this.category,
    required this.suggestedPrice,
    required this.points,
    required this.imageUrl,
    required this.updatedAt,
    this.discountPrices = const {},
    this.description,
  });

  final String id;
  final String countryCode;
  final String name;
  final String code;
  final ProductCategory category;
  final double suggestedPrice;
  final int points;
  final String imageUrl;
  final DateTime updatedAt;
  final Map<int, double> discountPrices;
  final String? description;

  bool get hasDiscounts => discountPrices.isNotEmpty;

  double priceForDiscount(int discountPercent) {
    if (!hasDiscounts || discountPercent == 0) return suggestedPrice;
    return discountPrices[discountPercent] ?? suggestedPrice;
  }
}

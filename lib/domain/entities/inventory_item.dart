import 'product.dart';

class InventoryItem {
  const InventoryItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  InventoryItem copyWith({int? quantity}) {
    return InventoryItem(
      product: product,
      quantity: quantity ?? this.quantity,
    );
  }

  double get suggestedValue => product.suggestedPrice * quantity;

  double get discountedValue40 => product.priceForDiscount(40) * quantity;

  double get profit40 => suggestedValue - discountedValue40;
}

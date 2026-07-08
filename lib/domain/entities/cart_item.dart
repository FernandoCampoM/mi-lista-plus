import 'product.dart';

class CartItem {
  const CartItem({required this.product, required this.quantity});

  final Product product;
  final int quantity;

  CartItem copyWith({int? quantity}) {
    return CartItem(product: product, quantity: quantity ?? this.quantity);
  }

  int get totalPoints => product.points * quantity;

  double subtotal(int discountPercent) {
    return product.priceForDiscount(discountPercent) * quantity;
  }
}

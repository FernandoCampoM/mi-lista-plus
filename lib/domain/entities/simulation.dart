import 'cart_item.dart';

class Simulation {
  const Simulation({
    required this.id,
    required this.countryCode,
    required this.customerName,
    required this.discountPercent,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String countryCode;
  final String customerName;
  final int discountPercent;
  final DateTime createdAt;
  final List<CartItem> items;

  int get totalPoints => items.fold(0, (sum, item) => sum + item.totalPoints);

  double get totalAmount {
    return items.fold(
      0,
      (sum, item) => sum + item.subtotal(discountPercent),
    );
  }
}

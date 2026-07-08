import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/cart_badge_button.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/quantity_control.dart';

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({required this.product, super.key});

  final Product product;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final product = widget.product;
    final unitPrice = product.priceForDiscount(state.selectedDiscount);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Detalle del producto',
            showBack: true,
            actions: const [CartBadgeButton()],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: _cardDecoration(),
                  child: Row(
                    children: [
                      ProductAvatar(product: product, size: 62),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text('Puntos: ${product.points == 0 ? 'N/A' : product.points}'),
                            Text('Precio sugerido: ${formatter.money(product.suggestedPrice)}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                if (product.hasDiscounts)
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Descuento',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 14),
                        Text('Mi descuento: ${state.selectedDiscount}%'),
                        const SizedBox(height: 10),
                        ...product.discountPrices.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(child: Text('Descuento ${entry.key}%')),
                                Text(formatter.money(entry.value)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: _cardDecoration(),
                    child: const Text(
                      'Producto de precio fijo: no aplica descuento ni puntos.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    QuantityControl(
                      quantity: quantity,
                      onRemove: () {
                        if (quantity <= 1) return;
                        setState(() => quantity--);
                      },
                      onAdd: () => setState(() => quantity++),
                    ),
                    const SizedBox(width: 28),
                    Text(
                      formatter.money(unitPrice * quantity),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                PrimaryButton(
                  label: 'AGREGAR',
                  onPressed: () {
                    state.addProduct(product, quantity: quantity);
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(height: 10),
                PrimaryButton(
                  label: 'COMPARTIR',
                  outlined: true,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      boxShadow: const [
        BoxShadow(
          color: Color(0x12000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}

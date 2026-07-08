import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';
import '../screens/cart_screen.dart';

class CartBadgeButton extends StatelessWidget {
  const CartBadgeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton.filled(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
          icon: const Icon(Icons.shopping_cart),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(.13),
            foregroundColor: Colors.white,
          ),
        ),
        if (state.cartUnits > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
              child: Text(
                '${state.cartUnits}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

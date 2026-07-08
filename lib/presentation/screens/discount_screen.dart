import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';
import '../widgets/primary_button.dart';

class DiscountScreen extends StatelessWidget {
  const DiscountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    const options = [0, 25, 30, 35, 40];

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            height: MediaQuery.paddingOf(context).top + 52,
            color: AppColors.deepPurple,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const Text(
                  'Descuento',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                ),
                const SizedBox(height: 12),
                ...options.map(
                  (option) => RadioListTile<int>(
                    value: option,
                    groupValue: state.selectedDiscount,
                    activeColor: AppColors.orange,
                    title: Text(option == 0 ? 'Precio Sugerido' : 'Descuento $option%'),
                    onChanged: (value) => state.setDiscount(value ?? 0),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: 'CONFIRMAR',
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

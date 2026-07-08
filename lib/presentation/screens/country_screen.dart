import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../state/app_scope.dart';
import 'home_screen.dart';

class CountryScreen extends StatelessWidget {
  const CountryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Image.asset('assets/images/logo.png', height: 180),
              const SizedBox(height: 28),
              Text(
                'Elige tu pais',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.deepPurple,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Descargaremos el catalogo correcto de productos, precios y moneda.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 28),
              ...state.countries.map(
                (country) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () async {
                      await state.loadCountry(country);
                      if (context.mounted) {
                        await Navigator.pushReplacement(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const HomeScreen(),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.purple,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: Text('${country.flagEmoji}  ${country.name}'),
                  ),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

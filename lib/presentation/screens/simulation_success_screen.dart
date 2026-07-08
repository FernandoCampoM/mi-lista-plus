import 'package:flutter/material.dart' hide Simulation;

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/simulation.dart';
import '../state/app_scope.dart';
import '../widgets/primary_button.dart';
import 'home_screen.dart';
import 'simulation_detail_screen.dart';

class SimulationSuccessScreen extends StatelessWidget {
  const SimulationSuccessScreen({required this.simulation, super.key});

  final Simulation simulation;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          Container(
            height: 180,
            width: double.infinity,
            color: AppColors.green,
            child: const SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Simulacion generada exitosamente',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Info(label: 'Fecha de la simulacion', value: '${simulation.createdAt.day}/${simulation.createdAt.month}/${simulation.createdAt.year}'),
                  _Info(label: 'ID de simulacion', value: simulation.id),
                  _Info(label: 'Pais', value: simulation.countryCode),
                  _Info(label: 'Descuento', value: simulation.discountPercent == 0 ? 'Precio sugerido' : '${simulation.discountPercent}%'),
                  _Info(label: 'Puntos', value: '${simulation.totalPoints}'),
                  _Info(label: 'Precio total', value: formatter.money(simulation.totalAmount)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  PrimaryButton(
                    label: 'VER DETALLE',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => SimulationDetailScreen(simulation: simulation),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'VER EN MIS SIMULACIONES',
                    outlined: true,
                    onPressed: () => Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute<void>(builder: (_) => const HomeScreen()),
                      (_) => false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

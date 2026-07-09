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
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: AppColors.green,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.paddingOf(context).top + 10,
                20,
                18,
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 60, color: Colors.white),
                  SizedBox(height: 10),
                  Text(
                    'Simulacion generada exitosamente',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  children: [
                    _Info(label: 'Fecha de la simulacion', value: '${simulation.createdAt.day}/${simulation.createdAt.month}/${simulation.createdAt.year}'),
                    _Info(label: 'ID de simulacion', value: simulation.id),
                    _Info(
                      label: 'Nombre',
                      value: simulation.customerName.trim().isEmpty
                          ? 'Cliente'
                          : simulation.customerName.trim(),
                    ),
                    _Info(label: 'Pais', value: simulation.countryCode),
                    _Info(label: 'Descuento', value: simulation.discountPercent == 0 ? 'Precio sugerido' : '${simulation.discountPercent}%'),
                    _Info(label: 'Puntos', value: '${simulation.totalPoints}'),
                    _Info(label: 'Precio total', value: formatter.money(simulation.totalAmount)),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

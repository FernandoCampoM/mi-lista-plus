import 'package:flutter/material.dart' hide Simulation;

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/simulation.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import 'cart_screen.dart';

class SimulationDetailScreen extends StatelessWidget {
  const SimulationDetailScreen({required this.simulation, super.key});

  final Simulation simulation;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: 'Detalles',
            showBack: true,
            actions: [
              PopupMenuButton<String>(
                tooltip: 'Opciones',
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) async {
                  if (value == 'edit') {
                    state.loadSimulationIntoCart(simulation);
                    if (context.mounted) {
                      await Navigator.pushReplacement(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    }
                  }

                  if (value == 'delete') {
                    await state.deleteSimulation(simulation);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar'),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar'),
                  ),
                ],
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Id: ${simulation.id}'),
                      Text('Pais: ${simulation.countryCode}'),
                      Text('Nombre: ${simulation.customerName}'),
                      Text(
                        simulation.discountPercent == 0
                            ? 'Precio sugerido'
                            : 'Descuento de ${simulation.discountPercent}%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mi pedido',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...simulation.items.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: _cardDecoration(),
                    child: Row(
                      children: [
                        ProductAvatar(product: item.product, size: 58),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(fontWeight: FontWeight.w900),
                              ),
                              Text('Cantidad  ${item.quantity}'),
                              Text('Puntos  ${item.totalPoints}'),
                              Text(
                                'Precio  ${formatter.money(item.subtotal(simulation.discountPercent))}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: _cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resumen de la simulacion',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${simulation.createdAt.day}/${simulation.createdAt.month}/${simulation.createdAt.year}',
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Puntos totales:')),
                          Text('${simulation.totalPoints}'),
                        ],
                      ),
                      Row(
                        children: [
                          const Expanded(child: Text('Precio total:')),
                          Text(formatter.money(simulation.totalAmount)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: SafeArea(
              top: false,
              child: PrimaryButton(label: 'COMPARTIR', onPressed: () {}),
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
          color: Color(0x10000000),
          blurRadius: 12,
          offset: Offset(0, 5),
        ),
      ],
    );
  }
}

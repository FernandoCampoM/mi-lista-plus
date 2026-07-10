import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/quantity_control.dart';
import 'discount_screen.dart';
import 'simulation_success_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final customerNameController = TextEditingController();
  late AppState _state;
  bool _loadedEditingName = false;
  bool _simulationWasSaved = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _state = AppScope.of(context);
    if (_loadedEditingName) return;

    final editingSimulation = _state.editingSimulation;
    final customerName = editingSimulation?.customerName.trim();
    if (customerName != null && customerName != 'Cliente') {
      customerNameController.text = customerName;
    }
    _loadedEditingName = true;
  }

  @override
  void dispose() {
    if (!_simulationWasSaved) {
      _state.clearEditingSimulation(notify: false);
    }
    customerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final isEditingSimulation = state.editingSimulation != null;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(title: 'Productos', showBack: true),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                TextField(
                  controller: customerNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre (opcional)',
                    hintText: 'Nombre',
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Productos',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
                const SizedBox(height: 10),
                if (state.cartItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 42),
                    child: Center(child: Text('Aun no has agregado productos.')),
                  ),
                ...state.cartItems.map(
                  (item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
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
                                  Text('Puntos  ${item.product.points == 0 ? 'N/A' : item.product.points}'),
                                  Text('Precio sugerido  ${formatter.money(item.product.suggestedPrice)}'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            QuantityControl(
                              quantity: item.quantity,
                              onRemove: () => state.decreaseProduct(item.product),
                              onAdd: () => state.addProduct(item.product),
                            ),
                            const SizedBox(width: 18),
                            Text(
                              formatter.money(item.subtotal(state.selectedDiscount)),
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const DiscountScreen(),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Descuento',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        Text(
                          state.selectedDiscount == 0
                              ? 'Precio sugerido'
                              : 'Descuento ${state.selectedDiscount}%',
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Expanded(child: Text('Puntos')),
                      Text('${state.cartPoints}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Expanded(child: Text('Total')),
                      Text(formatter.money(state.cartTotal), style: const TextStyle(fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: isEditingSimulation
                        ? 'ACTUALIZAR SIMULACION'
                        : 'GENERAR SIMULACION',
                    onPressed: state.cartItems.isEmpty
                        ? null
                        : () async {
                            final simulation = await state.createSimulation(
                              customerName: customerNameController.text,
                            );
                            _simulationWasSaved = true;
                            await AppScope.adsOf(context).recordImportantAction(
                              ImportantAdAction.simulationGenerated,
                            );
                            if (context.mounted) {
                              await Navigator.pushReplacement(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => SimulationSuccessScreen(
                                    simulation: simulation,
                                  ),
                                ),
                              );
                            }
                          },
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'SEGUIR AGREGANDO',
                    outlined: true,
                    onPressed: () => Navigator.pop(context),
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

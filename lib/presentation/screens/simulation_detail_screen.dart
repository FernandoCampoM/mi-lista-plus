import 'package:flutter/material.dart' hide Simulation;
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../core/services/share_simulation_service.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import 'cart_screen.dart';
import 'register_sale_screen.dart';
import 'sale_detail_screen.dart';

class SimulationDetailScreen extends StatelessWidget {
  const SimulationDetailScreen({required this.simulation, super.key});

  final Simulation simulation;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final convertedSale = state.saleForSimulation(simulation.id);

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PrimaryButton(
                    label: convertedSale == null
                        ? 'CONVERTIR EN VENTA'
                        : 'VER VENTA REGISTRADA',
                    onPressed: () => _convertToSale(
                      context,
                      convertedSale,
                    ),
                  ),
                  const SizedBox(height: 10),
                  PrimaryButton(
                    label: 'COMPARTIR',
                    outlined: true,
                    onPressed: () => _openShareSheet(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _convertToSale(
    BuildContext context,
    Sale? existingSale,
  ) async {
    if (existingSale != null) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SaleDetailScreen(saleId: existingSale.id),
        ),
      );
      return;
    }

    final state = AppScope.of(context);
    try {
      final issues = state.simulationInventoryIssues(simulation);
      if (issues.isNotEmpty) {
        await _showInventoryIssues(context, issues);
        return;
      }

      final sale = await Navigator.push<Sale>(
        context,
        MaterialPageRoute<Sale>(
          builder: (_) => RegisterSaleScreen(
            templateSimulation: simulation,
          ),
        ),
      );
      if (!context.mounted || sale == null) return;

      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => SaleDetailScreen(saleId: sale.id),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _showInventoryIssues(
    BuildContext context,
    List<SimulationInventoryIssue> issues,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Inventario insuficiente'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'No es posible convertir la simulacion. Revisa estos productos:',
              ),
              const SizedBox(height: 12),
              ...issues.map(
                (issue) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${issue.productName}\n'
                    '  Requeridas: ${issue.requiredQuantity} · '
                    'Disponibles: ${issue.availableQuantity}',
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ENTENDIDO'),
          ),
        ],
      ),
    );
  }

  Future<void> _openShareSheet(BuildContext context) async {
    final state = AppScope.of(context);
    final country = state.selectedCountry!;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image, color: AppColors.purple),
                  title: const Text('Compartir como imagen'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _shareImageWithLoader(context, country);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.article, color: AppColors.purple),
                  title: const Text('Compartir como texto'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await ShareSimulationService.shareAsText(
                      simulation: simulation,
                      country: country,
                    );
                    if (context.mounted) {
                      await AppScope.adsOf(context).recordImportantAction(
                        ImportantAdAction.simulationShared,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  Future<void> _shareImageWithLoader(BuildContext context, dynamic country) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _GeneratingImageDialog(),
    );

    try {
      final imageFile = await ShareSimulationService.buildImageFile(
        simulation: simulation,
        country: country,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      await Share.shareXFiles(
        [imageFile],
        text: 'Simulación #${simulation.id}',
      );
      if (context.mounted) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.simulationShared,
        );
      }
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo generar la imagen. Inténtalo de nuevo.'),
          ),
        );
      }
    }
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


class _GeneratingImageDialog extends StatelessWidget {
  const _GeneratingImageDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 18),
            Text(
              'Generando imagen...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              'Esto puede tardar unos segundos.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

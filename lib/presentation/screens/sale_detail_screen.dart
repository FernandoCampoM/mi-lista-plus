import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/product_avatar.dart';
import 'register_sale_screen.dart';

class SaleDetailScreen extends StatelessWidget {
  const SaleDetailScreen({required this.saleId, super.key});

  final String saleId;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final sale = state.sales.firstWhere((item) => item.id == saleId);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final number = state.saleNumberOf(sale).toString().padLeft(4, '0');

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(
            title: 'Detalle de venta',
            showBack: true,
            titleFontSize: 20,
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.purple,
                      child: Icon(Icons.shopping_bag, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Venta #$number',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(_formatDate(sale.soldAt)),
                          if (sale.customerName != 'Cliente')
                            Text(sale.customerName),
                        ],
                      ),
                    ),
                    _StatusBadge(status: sale.status),
                  ],
                ),
                const SizedBox(height: 16),
                _SaleMetrics(sale: sale, formatter: formatter),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: const BorderSide(color: AppColors.line)),
                  leading: Icon(sale.isDelivered ? Icons.check_circle : Icons.local_shipping_outlined, color: sale.isDelivered ? AppColors.green : AppColors.orange),
                  title: Text(sale.isDelivered ? 'Pedido entregado' : 'Pendiente de confirmar entrega', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: sale.deliveredAt == null ? null : Text(_formatDate(sale.deliveredAt!)),
                  trailing: !sale.isDelivered && sale.customerId != null
                      ? TextButton(
                          onPressed: () => _confirmDelivery(context, sale),
                          child: const Text('CONFIRMAR'),
                        )
                      : null,
                ),
                const SizedBox(height: 22),
                const Text(
                  'Productos vendidos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...sale.items.map(
                  (item) => _SoldProductRow(
                    item: item,
                    countryCode: sale.countryCode,
                    formatter: formatter,
                  ),
                ),
                const SizedBox(height: 14),
                _FinancialSummary(sale: sale, formatter: formatter),
                const SizedBox(height: 18),
                if (sale.isCompleted)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _edit(context, sale),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('EDITAR VENTA'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _duplicate(context, sale),
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('DUPLICAR'),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _duplicate(context, sale),
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('DUPLICAR VENTA'),
                  ),
                const SizedBox(height: 10),
                if (sale.isCompleted)
                  TextButton.icon(
                    onPressed: () => _cancel(context, sale),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('CANCELAR VENTA'),
                  ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () => _delete(context, sale),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ELIMINAR VENTA'),
                ),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy hh:mm a', 'es_CO').format(date);
  }

  Future<void> _edit(BuildContext context, Sale sale) async {
    await Navigator.push<Sale>(
      context,
      MaterialPageRoute<Sale>(
        builder: (_) => RegisterSaleScreen(editingSale: sale),
      ),
    );
  }

  Future<void> _duplicate(BuildContext context, Sale sale) async {
    final duplicate = await Navigator.push<Sale>(
      context,
      MaterialPageRoute<Sale>(
        builder: (_) => RegisterSaleScreen(templateSale: sale),
      ),
    );
    if (!context.mounted || duplicate == null) return;

    await Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SaleDetailScreen(saleId: duplicate.id),
      ),
    );
  }

  Future<void> _cancel(BuildContext context, Sale sale) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Cancelar esta venta?'),
            content: const Text(
              'Los productos volverán al inventario y la venta dejará de '
              'afectar las métricas mensuales.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('VOLVER'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('CANCELAR VENTA'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await AppScope.of(context).cancelSale(sale);
    if (context.mounted) {
      await AppScope.adsOf(context).recordImportantAction(
        ImportantAdAction.saleCancelled,
      );
    }
  }

  Future<void> _delete(BuildContext context, Sale sale) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('¿Eliminar esta venta?'),
            content: Text(
              sale.isCompleted
                  ? 'Los productos de esta venta volverán al inventario.'
                  : 'La venta cancelada se eliminará definitivamente.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CANCELAR'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ELIMINAR VENTA'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    await AppScope.of(context).deleteSale(sale);
    if (context.mounted) {
      await AppScope.adsOf(context).recordImportantAction(
        ImportantAdAction.saleDeleted,
      );
    }
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelivery(BuildContext context, Sale sale) async {
    await AppScope.of(context).confirmDelivery(sale);
    if (!context.mounted) return;
    await AppScope.adsOf(context).recordImportantAction(
      ImportantAdAction.deliveryConfirmed,
    );
  }
}

class _SaleMetrics extends StatelessWidget {
  const _SaleMetrics({required this.sale, required this.formatter});

  final Sale sale;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          _Metric(
            label: 'Total recibido',
            value: formatter.money(sale.effectiveReceivedAmount),
          ),
          _Metric(label: 'Puntos', value: '${sale.totalPoints}'),
          _Metric(label: 'Ganancia', value: formatter.money(sale.totalProfit)),
          _Metric(label: 'Productos', value: '${sale.totalUnits}'),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldProductRow extends StatelessWidget {
  const _SoldProductRow({
    required this.item,
    required this.countryCode,
    required this.formatter,
  });

  final SaleItem item;
  final String countryCode;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final product = Product(
      id: item.productId,
      countryCode: countryCode,
      name: item.productName,
      code: item.productCode,
      category: item.category ?? ProductCategory.nutrition,
      suggestedPrice: item.suggestedUnitPrice,
      points: item.pointsPerUnit,
      imageUrl: item.imageUrl,
      updatedAt: DateTime(2000),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          ProductAvatar(product: product, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (item.productCode.isNotEmpty)
                  Text('Código ${item.productCode}'),
                Text(
                  '${item.pointsPerUnit} pts por unidad · '
                  '${item.totalPoints} pts totales',
                ),
                if (item.isGift)
                  const Text(
                    'Obsequio',
                    style: TextStyle(color: AppColors.orange),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.quantity} ${item.quantity == 1 ? 'unidad' : 'unidades'}',
              ),
              Text(
                formatter.money(item.totalSale),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.sale, required this.formatter});

  final Sale sale;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final discount = sale.items.isEmpty ? 0 : sale.items.first.discountPercent;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de la venta',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          _FinancialRow(
            label: 'Total productos a precio público',
            value: formatter.money(sale.totalSuggested),
          ),
          _FinancialRow(
            label: 'Descuento aplicado ($discount%)',
            value: '-${formatter.money(sale.discountAmount)}',
            color: AppColors.green,
          ),
          _FinancialRow(
            label: 'Costo con $discount% de descuento',
            value: formatter.money(sale.totalCost),
            color: AppColors.purple,
          ),
          _FinancialRow(
            label: 'Dinero recibido',
            value: formatter.money(sale.effectiveReceivedAmount),
            color: AppColors.purple,
          ),
          if (sale.receivedAdjustment != 0)
            _FinancialRow(
              label: 'Ajuste frente al total calculado',
              value: formatter.money(sale.receivedAdjustment),
              color: sale.receivedAdjustment < 0
                  ? AppColors.danger
                  : AppColors.green,
            ),
          const Divider(),
          _FinancialRow(
            label: 'Ganancia obtenida',
            value: formatter.money(sale.totalProfit),
            color: AppColors.green,
            emphasized: true,
          ),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({
    required this.label,
    required this.value,
    this.color,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final Color? color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: emphasized ? FontWeight.w900 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: emphasized ? 16 : 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final SaleStatus status;

  @override
  Widget build(BuildContext context) {
    final completed = status == SaleStatus.completed;
    final color = completed ? const Color(0xFF238A53) : AppColors.danger;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        completed ? 'Completada' : 'Cancelada',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppColors.line),
    boxShadow: const [
      BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3)),
    ],
  );
}

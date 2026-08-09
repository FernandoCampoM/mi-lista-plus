import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../models/product_sort_option.dart';
import '../state/app_scope.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/product_sort_control.dart';
import 'inventory_editor_screen.dart';
import 'register_sale_screen.dart';
import 'sale_detail_screen.dart';

enum InventorySection { inventory, sales }
enum SaleHistoryFilter { all, completed, cancelled }

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    this.initialSection = InventorySection.inventory,
    super.key,
  });

  final InventorySection initialSection;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late InventorySection section = widget.initialSection;
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  SaleHistoryFilter filter = SaleHistoryFilter.all;
  ProductSortOption inventorySort = ProductSortOption.stock;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final showingSales = section == InventorySection.sales;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: showingSales ? 'Ventas' : 'Inventario',
            showBack: true,
          ),
          _SectionSelector(
            section: section,
            onChanged: (value) => setState(() => section = value),
          ),
          AdaptiveBannerAd(
            placement: showingSales
                ? BannerPlacement.sales
                : BannerPlacement.inventory,
            margin: const EdgeInsets.fromLTRB(18, 8, 18, 0),
            maxHeight: 64,
          ),
          Expanded(
            child: showingSales
                ? _SalesDashboard(
                    month: selectedMonth,
                    filter: filter,
                    formatter: formatter,
                    onPreviousMonth: _previousMonth,
                    onNextMonth: _isCurrentMonth ? null : _nextMonth,
                    onFilter: _selectFilter,
                  )
                : _InventoryOverview(
                    formatter: formatter,
                    onEdit: _openEditor,
                    sortOption: inventorySort,
                    onSortChanged: (value) => setState(
                      () => inventorySort = value ?? ProductSortOption.stock,
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: showingSales
          ? SafeArea(
              top: false,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                child: PrimaryButton(
                  label: '+ REGISTRAR NUEVA VENTA',
                  onPressed: state.inventory.isEmpty ? null : _openRegisterSale,
                ),
              ),
            )
          : null,
    );
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return selectedMonth.year == now.year && selectedMonth.month == now.month;
  }

  void _previousMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1);
    });
  }

  Future<void> _openEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const InventoryEditorScreen()),
    );
  }

  Future<void> _openRegisterSale() async {
    await Navigator.push<Sale>(
      context,
      MaterialPageRoute<Sale>(builder: (_) => const RegisterSaleScreen()),
    );
  }

  Future<void> _selectFilter() async {
    final selected = await showModalBottomSheet<SaleHistoryFilter>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Filtrar historial',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              ...SaleHistoryFilter.values.map(
                (option) => RadioListTile<SaleHistoryFilter>(
                  value: option,
                  groupValue: filter,
                  title: Text(_filterLabel(option)),
                  onChanged: (value) => Navigator.pop(context, value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => filter = selected);
  }

  String _filterLabel(SaleHistoryFilter value) {
    return switch (value) {
      SaleHistoryFilter.all => 'Todas',
      SaleHistoryFilter.completed => 'Completadas',
      SaleHistoryFilter.cancelled => 'Canceladas',
    };
  }
}

class _SectionSelector extends StatelessWidget {
  const _SectionSelector({required this.section, required this.onChanged});

  final InventorySection section;
  final ValueChanged<InventorySection> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: SegmentedButton<InventorySection>(
        segments: const [
          ButtonSegment(
            value: InventorySection.inventory,
            icon: Icon(Icons.inventory_2_outlined),
            label: Text('Inventario'),
          ),
          ButtonSegment(
            value: InventorySection.sales,
            icon: Icon(Icons.point_of_sale_outlined),
            label: Text('Ventas'),
          ),
        ],
        selected: {section},
        onSelectionChanged: (values) => onChanged(values.first),
        showSelectedIcon: false,
      ),
    );
  }
}

class _InventoryOverview extends StatelessWidget {
  const _InventoryOverview({
    required this.formatter,
    required this.onEdit,
    required this.sortOption,
    required this.onSortChanged,
  });

  final CurrencyFormatter formatter;
  final VoidCallback onEdit;
  final ProductSortOption sortOption;
  final ValueChanged<ProductSortOption?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.inventory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppColors.purple,
              ),
              const SizedBox(height: 16),
              const Text(
                'Aún no tienes productos en tu inventario.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              PrimaryButton(label: 'CREAR INVENTARIO', onPressed: onEdit),
            ],
          ),
        ),
      );
    }

    final inventory = [...state.inventory];
    final quantities = {
      for (final item in inventory) item.product.id: item.quantity,
    };
    final products = inventory.map((item) => item.product).toList();
    sortProducts(products, sortOption, quantities: quantities);
    final inventoryByProductId = {
      for (final item in inventory) item.product.id: item,
    };
    final sortedInventory = products
        .map((product) => inventoryByProductId[product.id]!)
        .toList();
    final totalPoints = inventory.fold<int>(
      0,
      (sum, item) => sum + item.product.points * item.quantity,
    );
    final nutritionPoints = inventory
        .where((item) => item.product.category == ProductCategory.nutrition)
        .fold<int>(0, (sum, item) => sum + item.product.points * item.quantity);
    final beautyPoints = inventory
        .where((item) => item.product.category == ProductCategory.beauty)
        .fold<int>(0, (sum, item) => sum + item.product.points * item.quantity);

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Resumen del inventario',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Editar inventario',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _InventoryMetric(
              label: 'Productos diferentes',
              value: '${state.inventory.length}',
            ),
            _InventoryMetric(
              label: 'Unidades disponibles',
              value: '${state.inventoryUnits}',
            ),
            _InventoryMetric(
              label: 'Valor precio público',
              value: formatter.money(state.inventorySuggestedValue),
            ),
            _InventoryMetric(
              label: 'Valor con 40% dto.',
              value: formatter.money(state.inventoryDiscountedValue40),
            ),
            _InventoryMetric(
              label: 'Puntos disponibles',
              value: '$totalPoints',
              subtitle: 'Nutrición: $nutritionPoints · Belleza: $beautyPoints',
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Productos en inventario',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        ProductSortControl(
          value: sortOption,
          options: ProductSortOption.values,
          defaultOption: ProductSortOption.stock,
          onChanged: onSortChanged,
        ),
        const SizedBox(height: 6),
        ...sortedInventory.map(
          (item) => Container(
            margin: const EdgeInsets.only(bottom: 9),
            padding: const EdgeInsets.all(12),
            decoration: _cardDecoration(),
            child: Row(
              children: [
                ProductAvatar(product: item.product, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text('${item.quantity} unidades disponibles'),
                      Text(
                        'Valor ${formatter.money(item.suggestedValue)} · '
                        '${item.product.points * item.quantity} pts',
                      ),
                      Text(
                        'Ganancia potencial ${formatter.money(item.profit40)}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const AdaptiveBannerAd(
          placement: BannerPlacement.inventory,
          margin: EdgeInsets.only(top: 8, bottom: 4),
          maxHeight: 72,
        ),
        ],
      ),
    );
  }
}

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({
    required this.label,
    required this.value,
    this.subtitle,
  });

  final String label;
  final String value;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width - 44) / 2;
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.purple,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}

class _SalesDashboard extends StatelessWidget {
  const _SalesDashboard({
    required this.month,
    required this.filter,
    required this.formatter,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onFilter,
  });

  final DateTime month;
  final SaleHistoryFilter filter;
  final CurrencyFormatter formatter;
  final VoidCallback onPreviousMonth;
  final VoidCallback? onNextMonth;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final monthSales = state.sales
        .where(
          (sale) => sale.soldAt.year == month.year && sale.soldAt.month == month.month,
        )
        .toList()
      ..sort((a, b) => b.soldAt.compareTo(a.soldAt));
    final completed = monthSales.where((sale) => sale.isCompleted).toList();
    final visible = monthSales.where((sale) {
      return switch (filter) {
        SaleHistoryFilter.all => true,
        SaleHistoryFilter.completed => sale.isCompleted,
        SaleHistoryFilter.cancelled => !sale.isCompleted,
      };
    }).toList();
    final totalSales = completed.fold<double>(
      0,
      (sum, sale) => sum + sale.effectiveReceivedAmount,
    );
    final points = completed.fold<int>(0, (sum, sale) => sum + sale.totalPoints);
    final nutritionPoints = completed.fold<int>(0, (sum, sale) {
      return sum + sale.items
          .where((item) => item.category == ProductCategory.nutrition)
          .fold<int>(0, (itemSum, item) => itemSum + item.totalPoints);
    });
    final beautyPoints = completed.fold<int>(0, (sum, sale) {
      return sum + sale.items
          .where((item) => item.category == ProductCategory.beauty)
          .fold<int>(0, (itemSum, item) => itemSum + item.totalPoints);
    });
    final profit = completed.fold<double>(0, (sum, sale) => sum + sale.totalProfit);
    final top = _topProduct(completed);
    final monthLabel = DateFormat('MMMM yyyy', 'es_CO').format(month);

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: _cardDecoration(),
          child: Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: AppColors.purple),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  toBeginningOfSentenceCase(monthLabel) ?? monthLabel,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: onPreviousMonth,
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: onNextMonth,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Resumen del mes',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        GridView.count(
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.65,
          children: [
            _DashboardMetric(
              icon: Icons.shopping_bag_outlined,
              label: 'Ventas totales',
              value: formatter.money(totalSales),
              color: AppColors.purple,
            ),
            _DashboardMetric(
              icon: Icons.star_outline,
              label: 'Puntos vendidos',
              value: '$points',
              subtitle: 'Nutrición: $nutritionPoints · Belleza: $beautyPoints',
              color: AppColors.orange,
            ),
            _DashboardMetric(
              icon: Icons.trending_up,
              label: 'Ganancia total',
              value: formatter.money(profit),
              color: AppColors.green,
            ),
            _DashboardMetric(
              icon: Icons.receipt_long_outlined,
              label: 'Ventas realizadas',
              value: '${completed.length}',
              color: const Color(0xFF6A5ACD),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _TopProductCard(top: top),
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial de ventas',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
            ),
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 18),
              label: Text(_filterLabel(filter)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (visible.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Center(child: Text('No hay ventas para este filtro.')),
          )
        else
          ...visible.map(
            (sale) => _SaleHistoryCard(
              sale: sale,
              number: state.saleNumberOf(sale),
              formatter: formatter,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SaleDetailScreen(saleId: sale.id),
                ),
              ),
            ),
          ),
        const AdaptiveBannerAd(
          placement: BannerPlacement.sales,
          margin: EdgeInsets.only(top: 8, bottom: 4),
          maxHeight: 72,
        ),
      ],
    );
  }

  String _filterLabel(SaleHistoryFilter value) {
    return switch (value) {
      SaleHistoryFilter.all => 'Todas',
      SaleHistoryFilter.completed => 'Completadas',
      SaleHistoryFilter.cancelled => 'Canceladas',
    };
  }

  _TopProduct? _topProduct(List<Sale> sales) {
    final items = <String, _TopProduct>{};
    for (final sale in sales) {
      for (final item in sale.items) {
        final current = items[item.productId];
        items[item.productId] = _TopProduct(
          item: item,
          units: (current?.units ?? 0) + item.quantity,
          revenue: (current?.revenue ?? 0) + item.totalSale,
          points: (current?.points ?? 0) + item.totalPoints,
          countryCode: sale.countryCode,
        );
      }
    }
    if (items.isEmpty) return null;
    final values = items.values.toList()
      ..sort((a, b) {
        final byUnits = b.units.compareTo(a.units);
        return byUnits != 0 ? byUnits : b.revenue.compareTo(a.revenue);
      });
    return values.first;
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 9, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductCard extends StatelessWidget {
  const _TopProductCard({required this.top});

  final _TopProduct? top;

  @override
  Widget build(BuildContext context) {
    final value = top;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EEFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.purple.withOpacity(.2)),
      ),
      child: value == null
          ? const Row(
              children: [
                Icon(Icons.workspace_premium_outlined, color: AppColors.orange),
                SizedBox(width: 10),
                Text('Producto más vendido: Sin ventas'),
              ],
            )
          : Row(
              children: [
                const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.orange,
                  size: 32,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Producto más vendido',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      Text(
                        value.item.productName,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      Text('${value.units} unidades · ${value.points} pts'),
                    ],
                  ),
                ),
                ProductAvatar(product: value.product, size: 56),
              ],
            ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  const _SaleHistoryCard({
    required this.sale,
    required this.number,
    required this.formatter,
    required this.onTap,
  });

  final Sale sale;
  final int number;
  final CurrencyFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.purple,
                child: Icon(Icons.shopping_bag_outlined, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Venta #${number.toString().padLeft(4, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Text(DateFormat('dd/MM/yyyy hh:mm a', 'es_CO').format(sale.soldAt)),
                    const SizedBox(height: 4),
                    Text('${sale.totalUnits} unidades · ${sale.totalPoints} pts'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: sale.status),
                  const SizedBox(height: 5),
                  Text(
                    formatter.money(sale.effectiveReceivedAmount),
                    style: const TextStyle(
                      color: AppColors.purple,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Ganancia ${formatter.money(sale.totalProfit)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        completed ? 'Completada' : 'Cancelada',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _TopProduct {
  const _TopProduct({
    required this.item,
    required this.units,
    required this.revenue,
    required this.points,
    required this.countryCode,
  });

  final SaleItem item;
  final int units;
  final double revenue;
  final int points;
  final String countryCode;

  Product get product => Product(
        id: item.productId,
        countryCode: countryCode,
        name: item.productName,
        code: item.productCode,
        category: ProductCategory.nutrition,
        suggestedPrice: item.suggestedUnitPrice,
        points: item.pointsPerUnit,
        imageUrl: item.imageUrl,
        updatedAt: DateTime(2000),
      );
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

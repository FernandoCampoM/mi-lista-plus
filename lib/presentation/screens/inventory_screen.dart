import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../core/utils/text_search.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../models/product_sort_option.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
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
  final TextEditingController inventorySearchController = TextEditingController();
  String inventoryQuery = '';

  @override
  void dispose() {
    inventorySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final showingSales = section == InventorySection.sales;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
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
            margin: const EdgeInsets.fromLTRB(18, 8, 18, 4),
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
                    searchController: inventorySearchController,
                    searchQuery: inventoryQuery,
                    onSearchChanged: (value) => setState(() => inventoryQuery = value),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: const Color(0xFFF8F8FA),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: PrimaryButton(
            label: '+ REGISTRAR NUEVA VENTA',
            onPressed: state.inventory.isEmpty ? null : _openRegisterSale,
          ),
        ),
      ),
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            _SegmentButton(
              selected: section == InventorySection.inventory,
              icon: Icons.inventory_2_outlined,
              label: 'Inventario',
              onTap: () => onChanged(InventorySection.inventory),
            ),
            _SegmentButton(
              selected: section == InventorySection.sales,
              icon: Icons.point_of_sale_outlined,
              label: 'Ventas',
              onTap: () => onChanged(InventorySection.sales),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.purple : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected ? Colors.white : AppColors.text,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
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
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final CurrencyFormatter formatter;
  final VoidCallback onEdit;
  final ProductSortOption sortOption;
  final ValueChanged<ProductSortOption?> onSortChanged;
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

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
              const Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.purple),
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
    final sortedInventory = _sortInventory(inventory, sortOption);
    final visibleInventory = sortedInventory.where((item) =>
        searchMatchesProduct(
          query: searchQuery,
          name: item.product.name,
          code: item.product.code,
        )).toList();
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
    final cost = state.inventoryDiscountedValue40;
    final publicValue = state.inventorySuggestedValue;
    final potentialProfit = publicValue - cost;
    // Solo para el porcentaje de margen se excluye del costo a los productos
    // sin puntos. Los KPI de costo y ganancia potencial siguen incluyendo TODO.
    final marginCost = inventory
        .where((item) => item.product.points > 0)
        .fold<double>(0, (sum, item) => sum + item.discountedValue40);
    final margin = publicValue <= 0
        ? 0.0
        : (publicValue - marginCost) / publicValue * 100;
    final lowStockItems = inventory.where((item) => item.quantity == 1).toList();
    final noStockItems = state.products
        .where((product) => (quantities[product.id] ?? 0) <= 0)
        .map((product) => InventoryItem(product: product, quantity: 0))
        .toList();
    final activeItems = inventory.where((item) => item.quantity > 0).toList();
    final inactiveItems = _inactiveProducts60Days(activeItems, state.sales);
    final lowStock = lowStockItems.length;
    final noStock = noStockItems.length;
    final active = activeItems.length;
    final inactive60 = inactiveItems.length;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
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
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ResponsiveGrid(
            preferredColumns: 4,
            minItemWidth: 150,
            children: [
              _KpiCard(
                icon: Icons.monetization_on_outlined,
                iconColor: AppColors.purple,
                label: 'Valor invertido (costo)',
                value: formatter.money(cost),
                footnote: 'Invertido en tu inventario',
              ),
              _KpiCard(
                icon: Icons.trending_up,
                iconColor: AppColors.green,
                label: 'Ganancia potencial',
                value: formatter.money(potentialProfit),
                footnote: 'Si vendes a precio público',
              ),
              _KpiCard(
                icon: Icons.sell_outlined,
                iconColor: const Color(0xFF397CE8),
                label: 'Unidades disponibles',
                value: '${state.inventoryUnits}',
                footnote: 'En $active productos diferentes',
              ),
              _KpiCard(
                icon: Icons.warning_amber_rounded,
                iconColor: AppColors.orange,
                label: 'Por agotarse',
                value: '$lowStock',
                footnote: 'Con una sola unidad disponible',
                onTap: () => _showInventoryProducts(
                  context,
                  'Productos por agotarse',
                  lowStockItems,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              final health = _InventoryHealthCard(
                noStock: noStock,
                inactive60: inactive60,
                active: active,
                totalPoints: totalPoints,
                nutritionPoints: nutritionPoints,
                beautyPoints: beautyPoints,
                onNoStock: () => _showInventoryProducts(context, 'Productos sin stock', noStockItems),
                onInactive: () => _showInventoryProducts(context, 'Productos sin movimiento (+60 días)', inactiveItems),
                onActive: () => _showInventoryProducts(context, 'Productos activos', activeItems),
              );
              final financial = _FinancialSummaryCard(
                publicValue: publicValue,
                cost: cost,
                potentialProfit: potentialProfit,
                margin: margin,
                formatter: formatter,
              );
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: health),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: financial),
                  ],
                );
              }
              return Column(children: [health, const SizedBox(height: 10), financial]);
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'Productos en inventario',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar producto en inventario...',
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar búsqueda',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ProductSortOption>(
                  value: sortOption,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Ordenar por',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: ProductSortOption.values
                      .map((item) => DropdownMenuItem(
                            value: item,
                            child: Text(
                              item == ProductSortOption.stock
                                  ? 'Existencias (mayor a menor)'
                                  : productSortLabel(item),
                            ),
                          ))
                      .toList(),
                  onChanged: onSortChanged,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => onSortChanged(ProductSortOption.stock),
                child: const Text('Limpiar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (visibleInventory.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No se encontraron productos en tu inventario.')),
            )
          else
            ...visibleInventory.map(
              (item) => _InventoryProductCard(
                item: item,
                formatter: formatter,
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

  List<InventoryItem> _sortInventory(
    List<InventoryItem> inventory,
    ProductSortOption option,
  ) {
    final quantities = {
      for (final item in inventory) item.product.id: item.quantity,
    };
    final products = inventory.map((item) => item.product).toList();
    sortProducts(products, option, quantities: quantities);
    final byProductId = {
      for (final item in inventory) item.product.id: item,
    };
    return products.map((product) => byProductId[product.id]!).toList();
  }

  List<InventoryItem> _inactiveProducts60Days(List<InventoryItem> items, List<Sale> sales) {
    final cutoff = DateTime.now().subtract(const Duration(days: 60));
    final result = <InventoryItem>[];
    for (final item in items.where((item) => item.quantity > 0)) {
      DateTime? lastSale;
      for (final sale in sales.where((sale) => sale.isCompleted)) {
        if (!sale.items.any((line) => line.productId == item.product.id)) continue;
        if (lastSale == null || sale.soldAt.isAfter(lastSale)) lastSale = sale.soldAt;
      }
      if (lastSale == null || lastSale.isBefore(cutoff)) result.add(item);
    }
    result.sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    return result;
  }

  Future<void> _showInventoryProducts(
    BuildContext context,
    String title,
    List<InventoryItem> items,
  ) async {
    final sorted = [...items]
      ..sort((a, b) => a.product.name.toLowerCase().compareTo(b.product.name.toLowerCase()));
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .72,
          minChildSize: .45,
          maxChildSize: .94,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                    ),
                    Text('${sorted.length}', style: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              Expanded(
                child: sorted.isEmpty
                    ? const Center(child: Text('No hay productos en esta categoría.'))
                    : ListView.builder(
                        controller: controller,
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        itemCount: sorted.length,
                        itemBuilder: (context, index) => _InventoryProductCard(
                          item: sorted[index],
                          formatter: formatter,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryHealthCard extends StatelessWidget {
  const _InventoryHealthCard({
    required this.noStock,
    required this.inactive60,
    required this.active,
    required this.totalPoints,
    required this.nutritionPoints,
    required this.beautyPoints,
    required this.onNoStock,
    required this.onInactive,
    required this.onActive,
  });

  final int noStock;
  final int inactive60;
  final int active;
  final int totalPoints;
  final int nutritionPoints;
  final int beautyPoints;
  final VoidCallback onNoStock;
  final VoidCallback onInactive;
  final VoidCallback onActive;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Salud de tu inventario', style: _sectionTitle),
          const SizedBox(height: 14),
          _ResponsiveGrid(
            preferredColumns: 4,
            minItemWidth: 105,
            gap: 4,
            children: [
              _MiniHealth(icon: Icons.inventory_2_outlined, label: 'Sin stock', value: '$noStock', color: AppColors.danger, onTap: onNoStock),
              _MiniHealth(icon: Icons.schedule_outlined, label: 'Sin movimiento\n(+60 días)', value: '$inactive60', color: AppColors.orange, onTap: onInactive),
              _MiniHealth(icon: Icons.inventory_2_outlined, label: 'Productos activos', value: '$active', color: AppColors.green, onTap: onActive),
              _MiniHealth(
                icon: Icons.bookmark_added_outlined,
                label: 'Puntos disponibles',
                value: '$totalPoints',
                color: AppColors.purple,
                subtitle: 'Nutrición: $nutritionPoints · Belleza: $beautyPoints',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniHealth extends StatelessWidget {
  const _MiniHealth({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
      children: [
        Icon(icon, color: AppColors.muted, size: 22),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
        if (subtitle != null)
          Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 8.5, color: AppColors.muted)),
      ],
    ),
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.publicValue,
    required this.cost,
    required this.potentialProfit,
    required this.margin,
    required this.formatter,
  });
  final double publicValue;
  final double cost;
  final double potentialProfit;
  final double margin;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Resumen financiero', style: _sectionTitle),
          const SizedBox(height: 12),
          _FinancialRow(label: 'Valor a precio público', value: formatter.money(publicValue)),
          _FinancialRow(label: 'Valor con 40% dto.', value: formatter.money(cost)),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFEAF9F4), borderRadius: BorderRadius.circular(8)),
            child: _FinancialRow(
              label: 'Ganancia potencial total',
              value: formatter.money(potentialProfit),
              valueColor: const Color(0xFF16845D),
              bold: true,
            ),
          ),
          _FinancialRow(label: 'Margen potencial', value: '${margin.toStringAsFixed(1)}%', bold: true),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow({required this.label, required this.value, this.valueColor, this.bold = false});
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: valueColor ?? AppColors.text)),
        ],
      ),
    );
  }
}

class _InventoryProductCard extends StatelessWidget {
  const _InventoryProductCard({required this.item, required this.formatter});
  final InventoryItem item;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final quantity = item.quantity;
    final status = quantity <= 0 ? 'Sin stock' : quantity >= 3 ? 'Ok' : null;
    final color = quantity <= 0 ? AppColors.danger : AppColors.green;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.purple, width: 1.4)),
            child: ProductAvatar(product: item.product, size: 48),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.product.name, maxLines: 4, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, height: 1.15)),
                const SizedBox(height: 3),
                Text('$quantity unidades disponibles · ${item.product.points * quantity} pts', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                Text('Valor ${formatter.money(item.suggestedValue)} · Costo ${formatter.money(item.discountedValue40)}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                Text('Ganancia potencial ${formatter.money(item.profit40)}', style: const TextStyle(fontSize: 10.5, color: Color(0xFF14875D), fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (status != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
              child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
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
    final monthSales = _salesForMonth(state.sales, month);
    final previousMonth = DateTime(month.year, month.month - 1);
    final previousSales = _salesForMonth(state.sales, previousMonth).where((sale) => sale.isCompleted).toList();
    final completed = monthSales.where((sale) => sale.isCompleted).toList();
    final visible = monthSales.where((sale) {
      return switch (filter) {
        SaleHistoryFilter.all => true,
        SaleHistoryFilter.completed => sale.isCompleted,
        SaleHistoryFilter.cancelled => !sale.isCompleted,
      };
    }).toList();

    final totalSales = _sumReceived(completed);
    final previousTotal = _sumReceived(previousSales);
    final profit = completed.fold<double>(0, (sum, sale) => sum + sale.totalProfit);
    final previousProfit = previousSales.fold<double>(0, (sum, sale) => sum + sale.totalProfit);
    final points = completed.fold<int>(0, (sum, sale) => sum + sale.totalPoints);
    final previousPoints = previousSales.fold<int>(0, (sum, sale) => sum + sale.totalPoints);
    final units = completed.fold<int>(0, (sum, sale) => sum + sale.totalUnits);
    final ticket = completed.isEmpty ? 0.0 : totalSales / completed.length;
    final previousTicket = previousSales.isEmpty ? 0.0 : previousTotal / previousSales.length;
    final profitPerSale = completed.isEmpty ? 0.0 : profit / completed.length;
    final previousProfitPerSale = previousSales.isEmpty ? 0.0 : previousProfit / previousSales.length;
    final margin = totalSales <= 0 ? 0.0 : profit / totalSales * 100;
    final category = _categoryTotals(completed);
    final nutritionPoints = category[ProductCategory.nutrition]!.points;
    final beautyPoints = category[ProductCategory.beauty]!.points;
    final monthLabel = DateFormat('MMMM yyyy', 'es_CO').format(month);
    final topProducts = _topProducts(completed);
    final pointsGoal = state.monthlyPointsGoal;
    final pointsProgress = math.min(1.0, pointsGoal == 0 ? 0.0 : points / pointsGoal).toDouble();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 28),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
              IconButton(onPressed: onPreviousMonth, icon: const Icon(Icons.chevron_left)),
              IconButton(onPressed: onNextMonth, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text('Resumen del mes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        _ResponsiveGrid(
          preferredColumns: 3,
          minItemWidth: 155,
          children: [
            _KpiCard(
              icon: Icons.shopping_bag_outlined,
              iconColor: AppColors.purple,
              label: 'Ventas totales',
              value: formatter.money(totalSales),
              trend: _percentTrend(totalSales, previousTotal),
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
            ),
            _KpiCard(
              icon: Icons.trending_up,
              iconColor: AppColors.green,
              label: 'Ganancia total',
              value: formatter.money(profit),
              trend: _percentTrend(profit, previousProfit),
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
              footnote: 'Margen: ${margin.toStringAsFixed(1)}%',
            ),
            _KpiCard(
              icon: Icons.star_outline,
              iconColor: AppColors.orange,
              label: 'Puntos vendidos',
              value: '$points',
              trend: points - previousPoints,
              trendAsPoints: true,
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
              footnote: 'Nutrición: $nutritionPoints · Belleza: $beautyPoints',
            ),
            _KpiCard(
              icon: Icons.receipt_long_outlined,
              iconColor: const Color(0xFF6057E8),
              label: 'Número de ventas',
              value: '${completed.length}',
              trend: completed.length - previousSales.length,
              trendAsCount: true,
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
              footnote: 'Unidades vendidas: $units',
            ),
            _KpiCard(
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF23A55A),
              label: 'Ticket promedio',
              value: formatter.money(ticket),
              trend: _percentTrend(ticket, previousTicket),
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
            ),
            _KpiCard(
              icon: Icons.pie_chart_outline,
              iconColor: AppColors.purple,
              label: 'Ganancia promedio por venta',
              value: formatter.money(profitPerSale),
              trend: _percentTrend(profitPerSale, previousProfitPerSale),
              trendSuffix: 'vs. ${_monthShort(previousMonth)}',
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 650;
            final progress = _PointsProgressCard(
              points: points,
              goal: pointsGoal,
              progress: pointsProgress,
              onTap: () => _editPointsGoal(context, state),
            );
            final categoryCard = _CategorySalesCard(category: category, formatter: formatter);
            if (wide) {
              return Row(children: [Expanded(child: progress), const SizedBox(width: 10), Expanded(child: categoryCard)]);
            }
            return Column(children: [progress, const SizedBox(height: 10), categoryCard]);
          },
        ),
        const SizedBox(height: 10),
        _TopThreeProductsCard(products: topProducts, totalSales: totalSales, formatter: formatter),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(child: Text('Historial de ventas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
            OutlinedButton.icon(
              onPressed: onFilter,
              icon: const Icon(Icons.filter_alt_outlined, size: 17),
              label: Text(_filterLabel(filter)),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
                MaterialPageRoute<void>(builder: (_) => SaleDetailScreen(saleId: sale.id)),
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

  Future<void> _editPointsGoal(BuildContext context, AppState state) async {
    var draft = '${state.monthlyPointsGoal}';
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Meta mensual de puntos'),
        content: TextFormField(
          initialValue: draft,
          autofocus: true,
          keyboardType: TextInputType.number,
          onChanged: (value) => draft = value,
          decoration: const InputDecoration(
            labelText: 'Meta de puntos',
            helperText: 'Valor predeterminado: 2500 puntos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(draft.trim());
              if (value == null || value < 1) return;
              Navigator.pop(dialogContext, value);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
    if (selected != null) await state.setMonthlyPointsGoal(selected);
  }

  List<Sale> _salesForMonth(List<Sale> source, DateTime value) => source
      .where((sale) => sale.soldAt.year == value.year && sale.soldAt.month == value.month)
      .toList()
    ..sort((a, b) => b.soldAt.compareTo(a.soldAt));

  double _sumReceived(List<Sale> sales) => sales.fold<double>(0, (sum, sale) => sum + sale.effectiveReceivedAmount);

  double _percentTrend(double current, double previous) {
    if (previous == 0) return current == 0 ? 0 : 100;
    return (current - previous) / previous * 100;
  }

  String _monthShort(DateTime value) => DateFormat('MMM', 'es_CO').format(value).replaceAll('.', '');

  Map<ProductCategory, _CategoryMetric> _categoryTotals(List<Sale> sales) {
    final result = {
      for (final category in ProductCategory.values) category: const _CategoryMetric(),
    };
    for (final sale in sales) {
      for (final item in sale.items) {
        final category = item.category ?? ProductCategory.nutrition;
        final current = result[category]!;
        result[category] = _CategoryMetric(
          value: current.value + item.totalSale,
          points: current.points + item.totalPoints,
        );
      }
    }
    return result;
  }

  List<_TopProduct> _topProducts(List<Sale> sales) {
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
    final values = items.values.toList()
      ..sort((a, b) {
        final byUnits = b.units.compareTo(a.units);
        return byUnits != 0 ? byUnits : b.revenue.compareTo(a.revenue);
      });
    return values.take(3).toList();
  }

  String _filterLabel(SaleHistoryFilter value) => switch (value) {
        SaleHistoryFilter.all => 'Todas',
        SaleHistoryFilter.completed => 'Completadas',
        SaleHistoryFilter.cancelled => 'Canceladas',
      };
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.trend,
    this.trendSuffix,
    this.footnote,
    this.trendAsPoints = false,
    this.trendAsCount = false,
    this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final num? trend;
  final String? trendSuffix;
  final String? footnote;
  final bool trendAsPoints;
  final bool trendAsCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueTrend = trend;
    final positive = valueTrend == null || valueTrend >= 0;
    final trendColor = positive ? const Color(0xFF159D5A) : AppColors.danger;
    String trendText = '';
    if (valueTrend != null) {
      final sign = positive ? '↑' : '↓';
      final absolute = valueTrend.abs();
      if (trendAsPoints) {
        trendText = '$sign ${absolute.toStringAsFixed(0)} pts';
      } else if (trendAsCount) {
        trendText = '$sign ${absolute.toStringAsFixed(0)}';
      } else {
        trendText = '$sign ${absolute.toStringAsFixed(0)}%';
      }
    }
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconColor.withOpacity(.11), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, maxLines: 2, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                if (valueTrend != null) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: trendText, style: TextStyle(color: trendColor, fontWeight: FontWeight.w800)),
                      if (trendSuffix != null) TextSpan(text: '  $trendSuffix', style: const TextStyle(color: AppColors.muted)),
                    ]),
                    style: const TextStyle(fontSize: 9.5),
                  ),
                ],
                if (footnote != null) ...[
                  const SizedBox(height: 3),
                  Text(footnote!, maxLines: 2, style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _PointsProgressCard extends StatelessWidget {
  const _PointsProgressCard({required this.points, required this.goal, required this.progress, required this.onTap});
  final int points;
  final int goal;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.purple.withOpacity(.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.track_changes_outlined, color: AppColors.purple),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Progreso de puntos del mes', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
              Text('$points / $goal pts', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE9DDF0),
                    color: AppColors.purple,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text('${(progress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Meta mensual de puntos · Toca para cambiarla', style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ],
      ),
      ),
    );
  }
}

class _CategorySalesCard extends StatelessWidget {
  const _CategorySalesCard({required this.category, required this.formatter});
  final Map<ProductCategory, _CategoryMetric> category;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    final values = [
      category[ProductCategory.nutrition]!.value,
      category[ProductCategory.beauty]!.value,
    ];
    final categoryTotal = values.fold<double>(0, (sum, value) => sum + value);
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Expanded(child: Text('Ventas por categoría', style: _sectionTitle)),
            Text('Ver detalle ›', style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ]),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CustomPaint(
                  painter: _DonutPainter(
                    values: values,
                    colors: const [AppColors.purple, AppColors.orange],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow(label: 'Nutrición', color: AppColors.purple, value: category[ProductCategory.nutrition]!.value, total: categoryTotal, formatter: formatter),
                    _LegendRow(label: 'Belleza', color: AppColors.orange, value: category[ProductCategory.beauty]!.value, total: categoryTotal, formatter: formatter),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.color, required this.value, required this.total, required this.formatter});
  final String label;
  final Color color;
  final double value;
  final double total;
  final CurrencyFormatter formatter;
  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : value / total * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 9.5))),
          Text('${formatter.money(value)} (${percent.round()}%)', style: const TextStyle(fontSize: 9.2, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.butt;
    if (total <= 0) {
      paint.color = AppColors.line;
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      if (sweep <= 0) continue;
      paint.color = colors[i % colors.length];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}

class _TopThreeProductsCard extends StatelessWidget {
  const _TopThreeProductsCard({required this.products, required this.totalSales, required this.formatter});
  final List<_TopProduct> products;
  final double totalSales;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Expanded(child: Text('Top 3 productos más vendidos', style: _sectionTitle)),
            Text('Ver todo ›', style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ]),
          const SizedBox(height: 8),
          if (products.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Sin ventas en este mes.')))
          else
            ...products.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final rankColor = switch (index) { 0 => const Color(0xFFFFB400), 1 => const Color(0xFFB8BBC6), _ => const Color(0xFFD97A45) };
              final percent = totalSales <= 0 ? 0 : item.revenue / totalSales * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    CircleAvatar(radius: 12, backgroundColor: rankColor, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                    const SizedBox(width: 9),
                    ProductAvatar(product: item.product, size: 42),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.item.productName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                          Text('${item.units} unidades · ${item.points} pts', style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatter.money(item.revenue), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                        Text('${percent.round()}% del total', style: const TextStyle(fontSize: 9, color: AppColors.muted)),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _SaleHistoryCard extends StatelessWidget {
  const _SaleHistoryCard({required this.sale, required this.number, required this.formatter, required this.onTap});
  final Sale sale;
  final int number;
  final CurrencyFormatter formatter;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: _cardDecoration(),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: AppColors.purple, child: Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Venta #${number.toString().padLeft(4, '0')}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    Text(DateFormat('dd/MM/yyyy hh:mm a', 'es_CO').format(sale.soldAt), style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                    Text('${sale.totalUnits} unidades · ${sale.totalPoints} pts', style: const TextStyle(fontSize: 10.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _StatusBadge(status: sale.status),
                  const SizedBox(height: 4),
                  Text(formatter.money(sale.effectiveReceivedAmount), style: const TextStyle(color: AppColors.purple, fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('Ganancia ${formatter.money(sale.totalProfit)}', style: const TextStyle(fontSize: 9.5)),
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
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
      child: Text(completed ? 'Completada' : 'Cancelada', style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.w800)),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({
    required this.children,
    this.preferredColumns = 2,
    this.minItemWidth = 150,
    this.gap = 8,
  });
  final List<Widget> children;
  final int preferredColumns;
  final double minItemWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxByWidth = math.max(1, ((constraints.maxWidth + gap) / (minItemWidth + gap)).floor());
        final columns = math.min(preferredColumns, maxByWidth);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((child) => SizedBox(width: width, child: child)).toList(),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(13), decoration: _cardDecoration(), child: child);
}

class _CategoryMetric {
  const _CategoryMetric({this.value = 0, this.points = 0});
  final double value;
  final int points;
}

class _TopProduct {
  const _TopProduct({required this.item, required this.units, required this.revenue, required this.points, required this.countryCode});
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
        category: item.category ?? ProductCategory.nutrition,
        suggestedPrice: item.suggestedUnitPrice,
        points: item.pointsPerUnit,
        imageUrl: item.imageUrl,
        updatedAt: DateTime(2000),
      );
}

const TextStyle _sectionTitle = TextStyle(fontSize: 13, fontWeight: FontWeight.w900);

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0xFFEAE7ED)),
    boxShadow: const [BoxShadow(color: Color(0x09000000), blurRadius: 10, offset: Offset(0, 3))],
  );
}

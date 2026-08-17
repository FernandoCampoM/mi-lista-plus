import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/currency_formatter.dart';
import '../../core/utils/text_search.dart';
import '../../domain/entities/inventory_item.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';

class SaleProductPickerScreen extends StatefulWidget {
  const SaleProductPickerScreen({
    required this.inventory,
    this.excludedProductIds = const {},
    required this.formatter,
    super.key,
  });

  final List<InventoryItem> inventory;
  final Set<String> excludedProductIds;
  final CurrencyFormatter formatter;

  @override
  State<SaleProductPickerScreen> createState() =>
      _SaleProductPickerScreenState();
}

class _SaleProductPickerScreenState
    extends State<SaleProductPickerScreen> {
  final searchController = TextEditingController();
  final selectedProductIds = <String>{};
  String query = '';

  List<InventoryItem> get availableInventory {
    return widget.inventory.where((item) {
      if (item.quantity <= 0 ||
          widget.excludedProductIds.contains(item.product.id)) {
        return false;
      }
      return searchMatchesProduct(query: query, name: item.product.name, code: item.product.code);
    }).toList();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = availableInventory;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          const AppHeader(
            title: 'Agregar productos',
            showBack: true,
            titleFontSize: 20,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: TextField(
              controller: searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => query = value),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar por nombre o codigo...',
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar busqueda',
                        onPressed: () {
                          searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedProductIds.isEmpty
                        ? '${inventory.length} productos disponibles'
                        : '${selectedProductIds.length} seleccionados',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selectedProductIds.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(selectedProductIds.clear),
                    child: const Text('LIMPIAR'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: inventory.isEmpty
                ? const _EmptyPickerResult()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    itemCount: inventory.length,
                    itemBuilder: (context, index) {
                      final item = inventory[index];
                      final selected =
                          selectedProductIds.contains(item.product.id);
                      return _PickerProductRow(
                        item: item,
                        selected: selected,
                        onChanged: (value) => _setSelected(
                          item.product.id,
                          value,
                        ),
                        formatter: widget.formatter,
                      );
                    },
                  ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
            child: SafeArea(
              top: false,
              child: PrimaryButton(
                label: selectedProductIds.isEmpty
                    ? 'SELECCIONA PRODUCTOS'
                    : 'AGREGAR (${selectedProductIds.length})',
                onPressed: selectedProductIds.isEmpty
                    ? null
                    : () => Navigator.pop(
                          context,
                          Set<String>.of(selectedProductIds),
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setSelected(String productId, bool selected) {
    setState(() {
      if (selected) {
        selectedProductIds.add(productId);
      } else {
        selectedProductIds.remove(productId);
      }
    });
  }
}

class _PickerProductRow extends StatelessWidget {
  const _PickerProductRow({
    required this.item,
    required this.selected,
    required this.onChanged,
    required this.formatter,
  });

  final InventoryItem item;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFF6EEFA) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? AppColors.purple : AppColors.line,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(!selected),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ProductAvatar(product: item.product, size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    if (item.product.code.isNotEmpty)
                      Text(
                        'Codigo ${item.product.code}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      '${item.quantity} ${item.quantity == 1 ? 'unidad disponible' : 'unidades disponibles'}',
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      'Publico ${formatter.money(item.product.suggestedPrice)} · '
                      '${item.product.points} puntos',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Checkbox(
                value: selected,
                onChanged: (value) => onChanged(value ?? false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyPickerResult extends StatelessWidget {
  const _EmptyPickerResult();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 54,
              color: AppColors.muted,
            ),
            SizedBox(height: 12),
            Text(
              'No hay productos disponibles para agregar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

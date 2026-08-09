import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/product.dart';
import '../models/product_sort_option.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/product_sort_control.dart';

class InventoryEditorScreen extends StatefulWidget {
  const InventoryEditorScreen({super.key});

  @override
  State<InventoryEditorScreen> createState() => _InventoryEditorScreenState();
}

class _InventoryEditorScreenState extends State<InventoryEditorScreen> {
  final quantities = <String, int>{};
  final quantityControllers = <String, TextEditingController>{};
  String query = '';
  ProductSortOption sortOption = ProductSortOption.stock;
  bool initialized = false;
  bool dirty = false;
  bool saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final state = AppScope.of(context);
    for (final item in state.inventory) {
      quantities[item.product.id] = item.quantity;
    }
    for (final product in state.products) {
      quantityControllers[product.id] = TextEditingController(
        text: '${quantities[product.id] ?? 0}',
      );
    }
    initialized = true;
  }

  @override
  void dispose() {
    for (final controller in quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final products = state.products.where((product) {
      final normalized = query.trim().toLowerCase();
      return normalized.isEmpty ||
          product.name.toLowerCase().contains(normalized) ||
          product.code.toLowerCase().contains(normalized);
    }).toList();
    sortProducts(products, sortOption, quantities: quantities);

    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: Column(
          children: [
            AppHeader(
              title: state.inventory.isEmpty
                  ? 'Crear inventario'
                  : 'Editar inventario',
              showBack: true,
              titleFontSize: 20,
              showCountrySelector: false,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Column(
                children: [
                  TextField(
                    onChanged: (value) => setState(() => query = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Buscar producto...',
                    ),
                  ),
                  const SizedBox(height: 8),
                  ProductSortControl(
                    value: sortOption,
                    options: ProductSortOption.values,
                    defaultOption: ProductSortOption.stock,
                    onChanged: (value) => setState(
                      () => sortOption = value ?? ProductSortOption.stock,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                itemCount: products.length,
                findChildIndexCallback: (key) {
                  if (key is! ValueKey<String>) return null;
                  final index = products.indexWhere(
                    (product) => product.id == key.value,
                  );
                  return index < 0 ? null : index;
                },
                itemBuilder: (context, index) {
                  final product = products[index];
                  final quantity = quantities[product.id] ?? 0;
                  return _InventoryProductRow(
                    key: ValueKey(product.id),
                    product: product,
                    quantityController: quantityControllers[product.id]!,
                    formatter: formatter,
                    onRemove: quantity == 0
                        ? null
                        : () => _setQuantity(product.id, quantity - 1),
                    onAdd: () => _setQuantity(product.id, quantity + 1),
                    onQuantityChanged: (value) =>
                        _setQuantityFromText(product.id, value),
                  );
                },
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              child: SafeArea(
                top: false,
                child: PrimaryButton(
                  label: saving
                      ? 'GUARDANDO...'
                      : state.inventory.isEmpty
                          ? 'GUARDAR INVENTARIO'
                          : 'GUARDAR CAMBIOS',
                  onPressed: saving ? null : _save,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setQuantity(String productId, int value) {
    if (value < 0) return;
    setState(() {
      quantities[productId] = value;
      final controller = quantityControllers[productId];
      if (controller != null && controller.text != '$value') {
        controller.value = TextEditingValue(
          text: '$value',
          selection: TextSelection.collapsed(offset: '$value'.length),
        );
      }
      dirty = true;
    });
  }

  void _setQuantityFromText(String productId, String rawValue) {
    final value = rawValue.isEmpty ? 0 : int.tryParse(rawValue);
    if (value == null || value < 0) return;
    setState(() {
      quantities[productId] = value;
      dirty = true;
    });
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await AppScope.of(context).saveInventoryQuantities(quantities);
      dirty = false;
      if (mounted) {
        await AppScope.adsOf(context).recordImportantAction(
          ImportantAdAction.inventoryUpdated,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el inventario: $error')),
      );
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cambios pendientes'),
            content: const Text(
              'Tienes cambios sin guardar. ¿Deseas salir y descartarlos?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('CONTINUAR EDITANDO'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('DESCARTAR'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({
    required this.product,
    required this.quantityController,
    required this.formatter,
    required this.onRemove,
    required this.onAdd,
    required this.onQuantityChanged,
    super.key,
  });

  final Product product;
  final TextEditingController quantityController;
  final CurrencyFormatter formatter;
  final VoidCallback? onRemove;
  final VoidCallback onAdd;
  final ValueChanged<String> onQuantityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          ProductAvatar(product: product, size: 54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('Precio público: ${formatter.money(product.suggestedPrice)}'),
                Text('Puntos: ${product.points}'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Disminuir',
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                padding: EdgeInsets.zero,
                onPressed: onRemove,
                icon: const Icon(Icons.remove, size: 18),
              ),
              SizedBox(
                width: 52,
                child: TextField(
                  controller: quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  textAlign: TextAlign.center,
                  onChanged: onQuantityChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Aumentar',
                constraints: const BoxConstraints.tightFor(width: 32, height: 32),
                padding: EdgeInsets.zero,
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

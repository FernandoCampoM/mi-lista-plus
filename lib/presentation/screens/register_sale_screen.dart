import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/sale.dart';
import '../state/app_scope.dart';
import '../widgets/app_header.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/quantity_control.dart';

class RegisterSaleScreen extends StatefulWidget {
  const RegisterSaleScreen({
    this.editingSale,
    this.templateSale,
    super.key,
  });

  final Sale? editingSale;
  final Sale? templateSale;

  @override
  State<RegisterSaleScreen> createState() => _RegisterSaleScreenState();
}

class _RegisterSaleScreenState extends State<RegisterSaleScreen> {
  final customerController = TextEditingController();
  final receivedAmountController = TextEditingController();
  final quantities = <String, int>{};
  final giftProductIds = <String>{};
  int discountPercent = 40;
  bool saving = false;
  bool initialized = false;
  String productQuery = '';
  bool receivedAmountWasEdited = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final source = widget.editingSale ?? widget.templateSale;
    if (source != null) {
      customerController.text = source.customerName == 'Cliente'
          ? ''
          : source.customerName;
      if (source.items.isNotEmpty) {
        discountPercent = source.items.first.discountPercent;
      }
      for (final item in source.items) {
        quantities[item.productId] = item.quantity;
        if (item.isGift) giftProductIds.add(item.productId);
      }
      if (widget.editingSale != null) {
        final received = source.effectiveReceivedAmount;
        receivedAmountController.text = received % 1 == 0
            ? received.toStringAsFixed(0)
            : received.toStringAsFixed(2);
        receivedAmountWasEdited = true;
      }
    }
    if (!receivedAmountWasEdited) {
      _updateDefaultReceivedAmount();
    }
    initialized = true;
  }

  @override
  void dispose() {
    customerController.dispose();
    receivedAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final formatter = CurrencyFormatter(state.selectedCountry!);
    final availableInventory = state.inventoryAvailableForSale(
      widget.editingSale,
    );
    final isEditing = widget.editingSale != null;
    final normalizedQuery = productQuery.trim().toLowerCase();
    final filteredInventory = availableInventory.where((item) {
      return normalizedQuery.isEmpty ||
          item.product.name.toLowerCase().contains(normalizedQuery) ||
          item.product.code.toLowerCase().contains(normalizedQuery);
    }).toList();
    final calculatedTotal = _totalSale(availableInventory);
    final receivedAmount = _receivedAmount ?? calculatedTotal;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: isEditing ? 'Editar venta' : 'Registrar venta',
            showBack: true,
          ),
          const AdaptiveBannerAd(
            placement: BannerPlacement.sales,
            margin: EdgeInsets.fromLTRB(18, 12, 18, 0),
            maxHeight: 64,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                TextField(
                  controller: customerController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del cliente',
                    hintText: 'Cliente',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  value: discountPercent,
                  decoration: const InputDecoration(
                    labelText: 'Descuento usado para calcular el costo',
                  ),
                  items: const [25, 30, 35, 40]
                      .map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text('$value%'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => discountPercent = value);
                  },
                ),
                const SizedBox(height: 18),
                const Text(
                  'Productos vendidos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => setState(() => productQuery = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nombre o código...',
                  ),
                ),
                const SizedBox(height: 10),
                if (filteredInventory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No se encontraron productos.')),
                  )
                else
                  ...filteredInventory.map(
                    (item) => _SaleProductRow(
                      item: item,
                      quantity: quantities[item.product.id] ?? 0,
                      isGift: giftProductIds.contains(item.product.id),
                      discountPercent: discountPercent,
                      formatter: formatter,
                      onRemove: (quantities[item.product.id] ?? 0) == 0
                          ? null
                          : () => _changeQuantity(item, -1),
                      onAdd: (quantities[item.product.id] ?? 0) >= item.quantity
                          ? null
                          : () => _changeQuantity(item, 1),
                      onGiftChanged: (checked) => _setGift(item, checked),
                    ),
                  ),
                const SizedBox(height: 14),
                TextField(
                  controller: receivedAmountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {
                    receivedAmountWasEdited = true;
                  }),
                  decoration: InputDecoration(
                    labelText: 'Dinero recibido',
                    hintText: calculatedTotal.toStringAsFixed(0),
                    helperText:
                        'Déjalo vacío para usar el total calculado de la venta.',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 8),
                _TotalsCard(
                  sale: calculatedTotal,
                  received: receivedAmount,
                  points: _totalPoints(availableInventory),
                  profit: receivedAmount - _totalCost(availableInventory),
                  formatter: formatter,
                ),
              ],
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
                    : isEditing
                        ? 'GUARDAR CAMBIOS'
                        : 'REGISTRAR VENTA',
                onPressed: saving ? null : _registerSale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _changeQuantity(InventoryItem item, int delta) {
    final current = quantities[item.product.id] ?? 0;
    final next = (current + delta).clamp(0, item.quantity).toInt();
    setState(() {
      quantities[item.product.id] = next;
      if (next == 0) giftProductIds.remove(item.product.id);
      _updateDefaultReceivedAmount();
    });
  }

  void _setGift(InventoryItem item, bool isGift) {
    setState(() {
      if (isGift) {
        giftProductIds.add(item.product.id);
      } else {
        giftProductIds.remove(item.product.id);
      }
      _updateDefaultReceivedAmount();
    });
  }

  void _updateDefaultReceivedAmount() {
    if (receivedAmountWasEdited) return;
    final state = AppScope.of(context);
    final availableInventory = state.inventoryAvailableForSale(
      widget.editingSale,
    );
    final total = _totalSale(availableInventory);
    receivedAmountController.text = total % 1 == 0
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
  }

  double _totalSale(List<InventoryItem> inventory) {
    return inventory.fold(0, (total, item) {
      final quantity = quantities[item.product.id] ?? 0;
      final isGift = giftProductIds.contains(item.product.id);
      final historical = _historicalItem(item.product.id);
      final unitPrice = historical?.suggestedUnitPrice ?? item.product.suggestedPrice;
      return total + (isGift ? 0 : unitPrice * quantity);
    });
  }

  int _totalPoints(List<InventoryItem> inventory) {
    return inventory.fold(
      0,
      (total, item) {
        final historical = _historicalItem(item.product.id);
        final points = historical?.pointsPerUnit ?? item.product.points;
        return total + points * (quantities[item.product.id] ?? 0);
      },
    );
  }

  double _totalCost(List<InventoryItem> inventory) {
    return inventory.fold(0, (total, item) {
      final quantity = quantities[item.product.id] ?? 0;
      final historical = _historicalItem(item.product.id);
      final cost = historical?.costUnitPrice ??
          item.product.priceForDiscount(discountPercent);
      return total + cost * quantity;
    });
  }

  double? get _receivedAmount {
    final raw = receivedAmountController.text.trim();
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  SaleItem? _historicalItem(String productId) {
    final editingSale = widget.editingSale;
    if (editingSale == null) return null;
    for (final item in editingSale.items) {
      if (item.productId == productId &&
          item.discountPercent == discountPercent) {
        return item;
      }
    }
    return null;
  }

  Future<void> _registerSale() async {
    setState(() => saving = true);
    try {
      final state = AppScope.of(context);
      final original = widget.editingSale;
      final sale = original == null
          ? await state.registerSale(
              customerName: customerController.text,
              discountPercent: discountPercent,
              quantities: quantities,
              giftProductIds: giftProductIds,
              receivedAmount: _receivedAmount,
            )
          : await state.updateSale(
              originalSale: original,
              customerName: customerController.text,
              discountPercent: discountPercent,
              quantities: quantities,
              giftProductIds: giftProductIds,
              receivedAmount: _receivedAmount,
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            original == null
                ? 'Venta #${sale.number.toString().padLeft(4, '0')} registrada.'
                : 'Venta actualizada correctamente.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }
}

class _SaleProductRow extends StatelessWidget {
  const _SaleProductRow({
    required this.item,
    required this.quantity,
    required this.isGift,
    required this.discountPercent,
    required this.formatter,
    required this.onRemove,
    required this.onAdd,
    required this.onGiftChanged,
  });

  final InventoryItem item;
  final int quantity;
  final bool isGift;
  final int discountPercent;
  final CurrencyFormatter formatter;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final ValueChanged<bool> onGiftChanged;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
    final cost = product.priceForDiscount(discountPercent);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProductAvatar(product: product, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text('Disponibles: ${item.quantity}'),
                    Text(
                      'Público ${formatter.money(product.suggestedPrice)} · '
                      'Costo ${formatter.money(cost)}',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              QuantityControl(
                quantity: quantity,
                onRemove: onRemove,
                onAdd: onAdd,
              ),
              const Spacer(),
              Checkbox(value: isGift, onChanged: (value) => onGiftChanged(value ?? false)),
              const Text('Obsequio'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.sale,
    required this.received,
    required this.points,
    required this.profit,
    required this.formatter,
  });

  final double sale;
  final double received;
  final int points;
  final double profit;
  final CurrencyFormatter formatter;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          _TotalRow(label: 'Total calculado', value: formatter.money(sale)),
          _TotalRow(label: 'Dinero recibido', value: formatter.money(received)),
          _TotalRow(label: 'Puntos', value: '$points'),
          _TotalRow(label: 'Ganancia', value: formatter.money(profit)),
        ],
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

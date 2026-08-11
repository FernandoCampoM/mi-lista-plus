import 'package:flutter/material.dart' hide Simulation;
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_ad_service.dart';
import '../../core/services/currency_formatter.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';
import '../state/app_scope.dart';
import '../state/app_state.dart';
import '../models/sale_customer_option.dart';
import '../widgets/app_header.dart';
import '../widgets/adaptive_banner_ad.dart';
import '../widgets/primary_button.dart';
import '../widgets/product_avatar.dart';
import '../widgets/quantity_control.dart';
import '../widgets/customer_form_dialog.dart';
import 'sale_product_picker_screen.dart';

class RegisterSaleScreen extends StatefulWidget {
  const RegisterSaleScreen({
    this.editingSale,
    this.templateSale,
    this.templateSimulation,
    super.key,
  }) : assert(
          (editingSale == null ? 0 : 1) +
                  (templateSale == null ? 0 : 1) +
                  (templateSimulation == null ? 0 : 1) <=
              1,
        );

  final Sale? editingSale;
  final Sale? templateSale;
  final Simulation? templateSimulation;

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
  bool receivedAmountWasEdited = false;
  String? selectedCustomerId;
  bool delivered = false;
  DateTime? deliveredAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    final state = AppScope.of(context);
    final availableByProductId = {
      for (final item in state.inventoryAvailableForSale(widget.editingSale))
        item.product.id: item,
    };
    final saleSource = widget.editingSale ?? widget.templateSale;
    final simulationSource = widget.templateSimulation;
    if (saleSource != null) {
      selectedCustomerId = saleSource.customerId;
      delivered = saleSource.isDelivered;
      deliveredAt = saleSource.deliveredAt;
      customerController.text = saleSource.customerName == 'Cliente'
          ? ''
          : saleSource.customerName;
      if (saleSource.items.isNotEmpty) {
        discountPercent = saleSource.items.first.discountPercent;
      }
      for (final item in saleSource.items) {
        final available = availableByProductId[item.productId]?.quantity ?? 0;
        final quantity = item.quantity.clamp(0, available).toInt();
        if (quantity > 0) {
          quantities[item.productId] = quantity;
          if (item.isGift) giftProductIds.add(item.productId);
        }
      }
      if (widget.editingSale != null) {
        final received = saleSource.effectiveReceivedAmount;
        receivedAmountController.text = received % 1 == 0
            ? received.toStringAsFixed(0)
            : received.toStringAsFixed(2);
        receivedAmountWasEdited = true;
      }
    } else if (simulationSource != null) {
      customerController.text = simulationSource.customerName == 'Cliente'
          ? ''
          : simulationSource.customerName;
      if (const [25, 30, 35, 40]
          .contains(simulationSource.discountPercent)) {
        discountPercent = simulationSource.discountPercent;
      }
      for (final item in simulationSource.items) {
        final available =
            availableByProductId[item.product.id]?.quantity ?? 0;
        final quantity = item.quantity.clamp(0, available).toInt();
        if (quantity > 0) quantities[item.product.id] = quantity;
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
    final selectedInventory = availableInventory
        .where((item) => (quantities[item.product.id] ?? 0) > 0)
        .toList();
    final hasProductsToAdd = availableInventory.any(
      (item) =>
          item.quantity > 0 && (quantities[item.product.id] ?? 0) == 0,
    );
    final calculatedTotal = _totalSale(availableInventory);
    final receivedAmount = _receivedAmount ?? calculatedTotal;
    final customerOptions = _customerOptions(state);
    final customerIds = customerOptions.map((item) => item.id).toSet();
    final dropdownCustomerId = customerIds.contains(selectedCustomerId)
        ? selectedCustomerId
        : null;
    final selectedCustomerOption = customerOptions
        .where((item) => item.id == dropdownCustomerId)
        .firstOrNull;
    final customerWarning = _customerWarning(selectedCustomerOption);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          AppHeader(
            title: isEditing
                ? 'Editar venta'
                : widget.templateSimulation != null
                    ? 'Convertir en venta'
                    : 'Registrar venta',
            showBack: true,
            titleFontSize: 20,
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 68),
                        child: DropdownButtonFormField<String>(
                        value: dropdownCustomerId,
                        isExpanded: true,
                        itemHeight: null,
                        decoration: const InputDecoration(
                          labelText: 'Cliente',
                          contentPadding: EdgeInsets.fromLTRB(12, 16, 10, 10),
                        ),
                        hint: const Text('Seleccionar cliente'),
                        selectedItemBuilder: (context) => customerOptions
                            .map((option) => LayoutBuilder(
                                  builder: (context, constraints) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      option.name,
                                      maxLines: 2,
                                      softWrap: true,
                                      style: TextStyle(
                                        fontSize: constraints.maxWidth < 220 ? 13 : 14,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                        items: customerOptions
                            .map(
                              (option) => DropdownMenuItem(
                                value: option.id,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option.name,
                                        softWrap: true,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Row(children: [
                                        Icon(_customerStatusIcon(option), size: 14, color: _customerStatusColor(option)),
                                        const SizedBox(width: 4),
                                        Flexible(child: Text(
                                          option.statusLabel,
                                          softWrap: true,
                                          style: TextStyle(fontSize: 11, color: _customerStatusColor(option)),
                                        )),
                                      ]),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedCustomerId = value;
                          final option = customerOptions.firstWhere(
                            (item) => item.id == value,
                          );
                          customerController.text = option.name;
                        }),
                      ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      tooltip: 'Crear cliente',
                      onPressed: _createCustomer,
                      icon: const Icon(Icons.person_add_alt_1),
                    ),
                  ],
                ),
                if (selectedCustomerOption != null) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(_customerStatusIcon(selectedCustomerOption), size: 16, color: _customerStatusColor(selectedCustomerOption)),
                    const SizedBox(width: 5),
                    Expanded(child: Text(
                      selectedCustomerOption.statusLabel,
                      style: TextStyle(color: _customerStatusColor(selectedCustomerOption), fontSize: 12, fontWeight: FontWeight.w700),
                    )),
                  ]),
                ],
                if (customerWarning != null) ...[
                  const SizedBox(height: 7),
                  Text(
                    customerWarning,
                    style: const TextStyle(
                      color: AppColors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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
                if (widget.templateSimulation?.discountPercent == 0) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'La simulacion usa precio sugerido. Confirma el descuento '
                    'de compra que se utilizara para calcular el costo.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Productos seleccionados',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (selectedInventory.isNotEmpty)
                      Text(
                        '${selectedInventory.length}',
                        style: const TextStyle(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (selectedInventory.isEmpty)
                  const _EmptySelectedProducts()
                else
                  ...selectedInventory.map(
                    (item) {
                      final historical = _historicalItem(item.product.id);
                      return _SaleProductRow(
                        item: item,
                        quantity: quantities[item.product.id] ?? 0,
                        isGift: giftProductIds.contains(item.product.id),
                        suggestedUnitPrice: historical?.suggestedUnitPrice ??
                            item.product.suggestedPrice,
                        costUnitPrice: historical?.costUnitPrice ??
                            item.product.priceForDiscount(discountPercent),
                        pointsPerUnit: historical?.pointsPerUnit ?? item.product.points,
                        formatter: formatter,
                        onRemove: (quantities[item.product.id] ?? 0) <= 1
                            ? null
                            : () => _changeQuantity(item, -1),
                        onAdd:
                            (quantities[item.product.id] ?? 0) >= item.quantity
                                ? null
                                : () => _changeQuantity(item, 1),
                        onGiftChanged: (checked) => _setGift(item, checked),
                        onDelete: () => _removeProduct(item.product.id),
                      );
                    },
                  ),
                const SizedBox(height: 2),
                OutlinedButton.icon(
                  onPressed: hasProductsToAdd
                      ? () => _openProductPicker(availableInventory)
                      : null,
                  icon: const Icon(Icons.add),
                  label: Text(
                    selectedInventory.isEmpty
                        ? 'AGREGAR PRODUCTOS'
                        : 'AGREGAR OTRO PRODUCTO',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('El cliente ya recibio el pedido'),
                  subtitle: Text(delivered
                      ? 'Entrega: ${_shortDate(deliveredAt ?? DateTime.now())}'
                      : 'Quedara en Por confirmar entrega'),
                  value: delivered,
                  onChanged: (value) => setState(() {
                    delivered = value;
                    deliveredAt = value ? (deliveredAt ?? DateTime.now()) : null;
                  }),
                ),
                if (delivered)
                  TextButton.icon(
                    onPressed: _pickDeliveryDate,
                    icon: const Icon(Icons.event_outlined),
                    label: const Text('EDITAR FECHA DE ENTREGA'),
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
                onPressed: saving || selectedInventory.isEmpty
                    ? null
                    : _registerSale,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<SaleCustomerOption> _customerOptions(AppState state) =>
      buildSaleCustomerOptions(
        customers: state.customers,
        selectedCustomerId: selectedCustomerId,
        preserveHistoricalCustomer: widget.editingSale != null,
        historicalCustomerName:
            widget.editingSale?.customerName ?? customerController.text,
      );

  String? _customerWarning(SaleCustomerOption? option) {
    if (widget.editingSale == null) {
      if (selectedCustomerId != null && option == null) {
        return 'Selecciona un cliente activo con consentimiento para registrar la venta.';
      }
      return null;
    }
    if (option == null) {
      return 'Venta histórica sin cliente disponible. Puedes editarla y asociar otro cliente.';
    }
    if (!option.isEligible) {
      return 'Puedes editar la venta, pero este cliente no recibirá seguimientos ni mensajes.';
    }
    return null;
  }

  void _changeQuantity(InventoryItem item, int delta) {
    final current = quantities[item.product.id] ?? 0;
    final next = (current + delta).clamp(0, item.quantity).toInt();
    setState(() {
      quantities[item.product.id] = next;
      if (next == 0) giftProductIds.remove(item.product.id);
      _updateDefaultReceivedAmount(force: true);
    });
  }

  void _setGift(InventoryItem item, bool isGift) {
    setState(() {
      if (isGift) {
        giftProductIds.add(item.product.id);
      } else {
        giftProductIds.remove(item.product.id);
      }
      _updateDefaultReceivedAmount(force: true);
    });
  }

  void _removeProduct(String productId) {
    setState(() {
      quantities.remove(productId);
      giftProductIds.remove(productId);
      _updateDefaultReceivedAmount(force: true);
    });
  }

  Future<void> _openProductPicker(
    List<InventoryItem> availableInventory,
  ) async {
    final selectedIds = quantities.entries
        .where((entry) => entry.value > 0)
        .map((entry) => entry.key)
        .toSet();
    final addedProductIds = await Navigator.push<Set<String>>(
      context,
      MaterialPageRoute<Set<String>>(
        builder: (_) => SaleProductPickerScreen(
          inventory: availableInventory,
          excludedProductIds: selectedIds,
          formatter: CurrencyFormatter(AppScope.of(context).selectedCountry!),
        ),
      ),
    );
    if (!mounted || addedProductIds == null || addedProductIds.isEmpty) return;

    setState(() {
      for (final productId in addedProductIds) {
        quantities.putIfAbsent(productId, () => 1);
      }
      _updateDefaultReceivedAmount(force: true);
    });
  }

  void _updateDefaultReceivedAmount({bool force = false}) {
    if (receivedAmountWasEdited && !force) return;
    final state = AppScope.of(context);
    final availableInventory = state.inventoryAvailableForSale(
      widget.editingSale,
    );
    final total = _totalSale(availableInventory);
    receivedAmountController.text = total % 1 == 0
        ? total.toStringAsFixed(0)
        : total.toStringAsFixed(2);
    if (force) receivedAmountWasEdited = false;
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
              sourceSimulationId: widget.templateSimulation?.id,
              customerId: selectedCustomerId,
              delivered: delivered,
              deliveredAt: deliveredAt,
            )
          : await state.updateSale(
              originalSale: original,
              customerName: customerController.text,
              discountPercent: discountPercent,
              quantities: quantities,
              giftProductIds: giftProductIds,
              receivedAmount: _receivedAmount,
              customerId: selectedCustomerId,
              delivered: delivered,
              deliveredAt: deliveredAt,
            );
      if (!mounted) return;
      await AppScope.adsOf(context).recordImportantAction(
        original == null
            ? ImportantAdAction.saleRegistered
            : ImportantAdAction.saleUpdated,
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
      Navigator.pop(context, sale);
    } catch (error) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  Future<void> _createCustomer() async {
    final form = await showCustomerFormDialog(
      context,
      initialName: customerController.text,
    );
    if (!mounted || form == null) return;
    try {
      final customer = await AppScope.of(context).createCustomer(
        name: form.name,
        callingCode: form.callingCode,
        phoneNumber: form.phoneNumber,
        goal: form.goal,
        birthday: form.birthday,
        consentGranted: form.consentGranted,
      );
      if (!mounted) return;
      await AppScope.adsOf(context).recordImportantAction(
        ImportantAdAction.customerCreated,
      );
      if (!mounted) return;
      setState(() {
        selectedCustomerId = customer.id;
        customerController.text = customer.name;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cliente guardado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el cliente: $error')),
      );
    }
  }

  Future<void> _pickDeliveryDate() async {
    final current = deliveredAt ?? DateTime.now();
    final date = await showDatePicker(context: context, initialDate: current, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 1)));
    if (date == null || !mounted) return;
    setState(() => deliveredAt = DateTime(date.year, date.month, date.day, current.hour, current.minute));
  }

  String _shortDate(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
}

class _SaleProductRow extends StatelessWidget {
  const _SaleProductRow({
    required this.item,
    required this.quantity,
    required this.isGift,
    required this.suggestedUnitPrice,
    required this.costUnitPrice,
    required this.pointsPerUnit,
    required this.formatter,
    required this.onRemove,
    required this.onAdd,
    required this.onGiftChanged,
    required this.onDelete,
  });

  final InventoryItem item;
  final int quantity;
  final bool isGift;
  final double suggestedUnitPrice;
  final double costUnitPrice;
  final int pointsPerUnit;
  final CurrencyFormatter formatter;
  final VoidCallback? onRemove;
  final VoidCallback? onAdd;
  final ValueChanged<bool> onGiftChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final product = item.product;
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
                      'Público ${formatter.money(suggestedUnitPrice)} · '
                      'Costo ${formatter.money(costUnitPrice)}',
                    ),
                    Text('$pointsPerUnit puntos por unidad · ${pointsPerUnit * quantity} puntos'),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Eliminar producto',
                onPressed: onDelete,
                color: AppColors.danger,
                icon: const Icon(Icons.delete_outline),
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
              Checkbox(
                value: isGift,
                onChanged: (value) => onGiftChanged(value ?? false),
              ),
              const Text('Obsequio'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptySelectedProducts extends StatelessWidget {
  const _EmptySelectedProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.add_shopping_cart_outlined,
            size: 42,
            color: AppColors.muted,
          ),
          SizedBox(height: 10),
          Text(
            'Aun no has agregado productos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4),
          Text(
            'Usa el boton de abajo para seleccionar productos del inventario.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
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

Color _customerStatusColor(SaleCustomerOption option) {
  if (option.isEligible && option.statusLabel.contains('activos')) return AppColors.green;
  if (option.statusLabel.contains('archivado') ||
      option.statusLabel.contains('no disponible')) {
    return AppColors.muted;
  }
  return AppColors.orange;
}

IconData _customerStatusIcon(SaleCustomerOption option) {
  if (option.isEligible && option.statusLabel.contains('activos')) {
    return Icons.check_circle_outline;
  }
  if (option.statusLabel.contains('archivado')) return Icons.archive_outlined;
  if (option.statusLabel.contains('no disponible')) return Icons.history;
  return Icons.info_outline;
}

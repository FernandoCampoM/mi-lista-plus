import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';
import '../../domain/repositories/product_repository.dart';

enum HomeTab { products, simulations }

class AppState extends ChangeNotifier {
  AppState(this._repository);

  final ProductRepository _repository;
  final _uuid = const Uuid();

  List<Country> countries = const [];
  Country? selectedCountry;
  List<Product> products = const [];
  List<Simulation> simulations = const [];
  List<InventoryItem> inventory = const [];
  List<Sale> sales = const [];
  final Map<String, CartItem> _cart = {};
  String? errorMessage;
  bool isLoading = true;
  int selectedDiscount = 0;
  HomeTab tab = HomeTab.products;
  Simulation? editingSimulation;

  List<CartItem> get cartItems => _cart.values.toList();

  int get cartUnits {
    return cartItems.fold(0, (sum, item) => sum + item.quantity);
  }

  int get cartPoints {
    return cartItems.fold(0, (sum, item) => sum + item.totalPoints);
  }

  double get cartTotal {
    return cartItems.fold(
      0,
      (sum, item) => sum + item.subtotal(selectedDiscount),
    );
  }

  Future<void> bootstrap() async {
    isLoading = true;
    notifyListeners();

    countries = await _repository.getCountries();
    final countryCode = await _repository.getSelectedCountry();
    if (countryCode != null) {
      final storedCountry = countries.firstWhere(
        (country) => country.code == countryCode,
        orElse: () => countries.first,
      );
      await loadCountry(storedCountry, persist: false);
    }

    isLoading = false;
    notifyListeners();
  }

  Future<bool> loadCountry(Country country, {bool persist = true}) async {
    final previousCountry = selectedCountry;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      await _repository.syncProductsIfNeeded(country.code);
    } catch (error) {
      errorMessage = error.toString();
    }

    final loadedProducts = await _repository.loadProducts(country.code);

    if (loadedProducts.isEmpty) {
      selectedCountry = previousCountry;
      products = const [];
      simulations = const [];
      inventory = const [];
      sales = const [];
      _cart.clear();
      editingSimulation = null;
      selectedDiscount = 0;
      errorMessage = '${country.name} no tiene productos disponibles aun.';
      isLoading = false;
      notifyListeners();
      return false;
    }

    selectedCountry = country;
    products = loadedProducts;
    simulations = await _repository.loadSimulations(country.code);
    final storedInventory = await _repository.loadInventory(country.code);
    final productsById = {for (final product in products) product.id: product};
    inventory = storedInventory
        .map(
          (item) => InventoryItem(
            product: productsById[item.product.id] ?? item.product,
            quantity: item.quantity,
          ),
        )
        .toList();
    final loadedSales = await _repository.loadSales(country.code);
    sales = _assignMissingSaleNumbers(loadedSales);
    if (sales.any((sale) => sale.number > 0) &&
        loadedSales.any((sale) => sale.number == 0)) {
      await _repository.saveSalesAndInventory(country.code, inventory, sales);
    }
    _cart.clear();
    editingSimulation = null;
    selectedDiscount = 0;

    if (persist) {
      await _repository.saveSelectedCountry(country.code);
    }

    isLoading = false;
    notifyListeners();
    return true;
  }

  void setTab(HomeTab value) {
    tab = value;
    notifyListeners();
  }

  void setDiscount(int value) {
    selectedDiscount = value;
    notifyListeners();
  }

  void addProduct(Product product, {int quantity = 1}) {
    if (quantity < 1) return;
    final current = _cart[product.id];
    _cart[product.id] = CartItem(
      product: product,
      quantity: (current?.quantity ?? 0) + quantity,
    );
    notifyListeners();
  }

  void decreaseProduct(Product product) {
    final current = _cart[product.id];
    if (current == null) return;
    if (current.quantity <= 1) {
      _cart.remove(product.id);
    } else {
      _cart[product.id] = current.copyWith(quantity: current.quantity - 1);
    }
    notifyListeners();
  }

  int quantityOf(Product product) => _cart[product.id]?.quantity ?? 0;

  Future<Simulation> createSimulation({String customerName = ''}) async {
    if (selectedCountry == null) {
      throw StateError('Debe seleccionar un pais antes de simular.');
    }
    if (_cart.isEmpty) {
      throw StateError('Agrega al menos un producto para simular.');
    }

    final currentEditingSimulation = editingSimulation;
    final simulation = Simulation(
      id: currentEditingSimulation?.id ?? _uuid.v4().split('-').first,
      countryCode: selectedCountry!.code,
      customerName: customerName.trim().isEmpty ? 'Cliente' : customerName.trim(),
      discountPercent: selectedDiscount,
      createdAt: currentEditingSimulation?.createdAt ?? DateTime.now(),
      items: cartItems,
    );

    await _repository.saveSimulation(simulation);
    simulations = await _repository.loadSimulations(selectedCountry!.code);
    _cart.clear();
    editingSimulation = null;
    selectedDiscount = 0;
    tab = HomeTab.simulations;
    notifyListeners();
    return simulation;
  }

  Future<void> deleteSimulation(Simulation simulation) async {
    await _repository.deleteSimulation(simulation.countryCode, simulation.id);
    if (selectedCountry != null) {
      simulations = await _repository.loadSimulations(selectedCountry!.code);
    }
    notifyListeners();
  }

  Future<void> deleteSimulations(Set<String> simulationIds) async {
    if (selectedCountry == null || simulationIds.isEmpty) return;
    await _repository.deleteSimulations(selectedCountry!.code, simulationIds);
    simulations = await _repository.loadSimulations(selectedCountry!.code);
    notifyListeners();
  }

  void loadSimulationIntoCart(Simulation simulation) {
    editingSimulation = simulation;
    _cart
      ..clear()
      ..addEntries(
        simulation.items.map((item) => MapEntry(item.product.id, item)),
      );
    selectedDiscount = simulation.discountPercent;
    notifyListeners();
  }

  void clearEditingSimulation({bool notify = true}) {
    editingSimulation = null;
    if (notify) {
      notifyListeners();
    }
  }

  void cancelSimulationEditing() {
    editingSimulation = null;
    _cart.clear();
    selectedDiscount = 0;
    notifyListeners();
  }

  int get inventoryUnits {
    return inventory.fold(0, (sum, item) => sum + item.quantity);
  }

  double get inventorySuggestedValue {
    return inventory.fold(0, (sum, item) => sum + item.suggestedValue);
  }

  double get inventoryDiscountedValue40 {
    return inventory.fold(0, (sum, item) => sum + item.discountedValue40);
  }

  Future<void> saveInventoryQuantities(Map<String, int> quantities) async {
    final country = selectedCountry;
    if (country == null) {
      throw StateError('Debe seleccionar un pais antes de crear inventario.');
    }

    final next = <InventoryItem>[];
    for (final product in products) {
      final quantity = quantities[product.id] ?? 0;
      if (quantity < 0) {
        throw ArgumentError.value(
          quantity,
          product.name,
          'La cantidad no puede ser negativa.',
        );
      }
      if (quantity > 0) {
        next.add(InventoryItem(product: product, quantity: quantity));
      }
    }

    await _repository.saveInventory(country.code, next);
    inventory = await _repository.loadInventory(country.code);
    notifyListeners();
  }

  Future<Sale> registerSale({
    required String customerName,
    required int discountPercent,
    required Map<String, int> quantities,
    Set<String> giftProductIds = const {},
    double? receivedAmount,
    String? sourceSimulationId,
  }) async {
    final country = selectedCountry;
    if (country == null) {
      throw StateError('Debe seleccionar un pais antes de registrar ventas.');
    }
    if (!const [25, 30, 35, 40].contains(discountPercent)) {
      throw ArgumentError.value(
        discountPercent,
        'discountPercent',
        'El descuento debe ser 25, 30, 35 o 40.',
      );
    }
    if (sourceSimulationId != null &&
        saleForSimulation(sourceSimulationId) != null) {
      throw StateError('Esta simulacion ya fue convertida en venta.');
    }

    final result = _buildSaleResult(
      availableInventory: inventory,
      quantities: quantities,
      giftProductIds: giftProductIds,
      discountPercent: discountPercent,
    );

    final sale = Sale(
      id: _uuid.v4(),
      number: sales.fold<int>(0, (max, sale) => sale.number > max ? sale.number : max) + 1,
      countryCode: country.code,
      customerName: customerName.trim().isEmpty
          ? 'Cliente'
          : customerName.trim(),
      soldAt: DateTime.now(),
      receivedAmount: _validatedReceivedAmount(
        receivedAmount,
        result.items,
      ),
      sourceSimulationId: sourceSimulationId,
      items: result.items,
    );

    final nextSales = [sale, ...sales];
    await _repository.saveSalesAndInventory(
      country.code,
      result.inventory,
      nextSales,
    );
    inventory = result.inventory;
    sales = nextSales;
    notifyListeners();
    return sale;
  }

  Sale? saleForSimulation(String simulationId) {
    for (final sale in sales) {
      if (sale.sourceSimulationId == simulationId) return sale;
    }
    return null;
  }

  List<SimulationInventoryIssue> simulationInventoryIssues(
    Simulation simulation,
  ) {
    final country = selectedCountry;
    if (country == null || country.code != simulation.countryCode) {
      throw StateError(
        'La simulacion no pertenece al pais seleccionado actualmente.',
      );
    }

    final inventoryByProductId = {
      for (final item in inventory) item.product.id: item,
    };
    final requiredByProductId = <String, int>{};
    final productNames = <String, String>{};
    for (final item in simulation.items) {
      requiredByProductId.update(
        item.product.id,
        (quantity) => quantity + item.quantity,
        ifAbsent: () => item.quantity,
      );
      productNames[item.product.id] = item.product.name;
    }
    final issues = <SimulationInventoryIssue>[];
    for (final entry in requiredByProductId.entries) {
      final available = inventoryByProductId[entry.key]?.quantity ?? 0;
      if (available < entry.value) {
        issues.add(
          SimulationInventoryIssue(
            productId: entry.key,
            productName: productNames[entry.key]!,
            requiredQuantity: entry.value,
            availableQuantity: available,
          ),
        );
      }
    }
    return issues;
  }

  int saleNumberOf(Sale sale) {
    if (sale.number > 0) return sale.number;
    final chronological = sales.toList()
      ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    final index = chronological.indexWhere((item) => item.id == sale.id);
    return index < 0 ? 0 : index + 1;
  }

  List<InventoryItem> inventoryAvailableForSale([Sale? editingSale]) {
    if (editingSale == null || !editingSale.isCompleted) {
      return List.of(inventory);
    }
    return _restoreItemsToInventory(inventory, editingSale.items);
  }

  Future<Sale> updateSale({
    required Sale originalSale,
    required String customerName,
    required int discountPercent,
    required Map<String, int> quantities,
    Set<String> giftProductIds = const {},
    double? receivedAmount,
  }) async {
    final country = selectedCountry;
    if (country == null) {
      throw StateError('Debe seleccionar un pais antes de editar ventas.');
    }
    if (!originalSale.isCompleted) {
      throw StateError('Una venta cancelada no se puede editar.');
    }
    _validateDiscount(discountPercent);

    final available = inventoryAvailableForSale(originalSale);
    final result = _buildSaleResult(
      availableInventory: available,
      quantities: quantities,
      giftProductIds: giftProductIds,
      discountPercent: discountPercent,
      originalSale: originalSale,
    );
    final updated = originalSale.copyWith(
      customerName: customerName.trim().isEmpty
          ? 'Cliente'
          : customerName.trim(),
      items: result.items,
      receivedAmount: _validatedReceivedAmount(
        receivedAmount,
        result.items,
      ),
    );
    final nextSales = sales
        .map((sale) => sale.id == originalSale.id ? updated : sale)
        .toList();

    await _repository.saveSalesAndInventory(
      country.code,
      result.inventory,
      nextSales,
    );
    inventory = result.inventory;
    sales = nextSales;
    notifyListeners();
    return updated;
  }

  Future<Sale> cancelSale(Sale sale) async {
    final country = selectedCountry;
    if (country == null) throw StateError('No hay un pais seleccionado.');
    if (!sale.isCompleted) return sale;

    final restoredInventory = _restoreItemsToInventory(inventory, sale.items);
    final cancelled = sale.copyWith(status: SaleStatus.cancelled);
    final nextSales = sales
        .map((item) => item.id == sale.id ? cancelled : item)
        .toList();
    await _repository.saveSalesAndInventory(
      country.code,
      restoredInventory,
      nextSales,
    );
    inventory = restoredInventory;
    sales = nextSales;
    notifyListeners();
    return cancelled;
  }

  Future<void> deleteSale(Sale sale) async {
    final country = selectedCountry;
    if (country == null) throw StateError('No hay un pais seleccionado.');
    final nextInventory = sale.isCompleted
        ? _restoreItemsToInventory(inventory, sale.items)
        : List<InventoryItem>.of(inventory);
    final nextSales = sales.where((item) => item.id != sale.id).toList();
    await _repository.saveSalesAndInventory(
      country.code,
      nextInventory,
      nextSales,
    );
    inventory = nextInventory;
    sales = nextSales;
    notifyListeners();
  }

  _SaleBuildResult _buildSaleResult({
    required List<InventoryItem> availableInventory,
    required Map<String, int> quantities,
    required Set<String> giftProductIds,
    required int discountPercent,
    Sale? originalSale,
  }) {
    _validateDiscount(discountPercent);
    final selected = availableInventory
        .where((item) => (quantities[item.product.id] ?? 0) > 0)
        .toList();
    if (selected.isEmpty) {
      throw StateError('Selecciona al menos un producto para la venta.');
    }

    final originalByProduct = {
      for (final item in originalSale?.items ?? const <SaleItem>[])
        item.productId: item,
    };
    final nextInventory = <InventoryItem>[];
    final saleItems = <SaleItem>[];
    for (final availableItem in availableInventory) {
      final product = availableItem.product;
      final quantity = quantities[product.id] ?? 0;
      if (quantity < 0 || quantity > availableItem.quantity) {
        throw StateError(
          'No hay suficientes unidades de ${product.name}. '
          'Disponibles: ${availableItem.quantity}.',
        );
      }

      if (quantity > 0) {
        final historical = originalByProduct[product.id];
        final preserveHistorical = historical != null &&
            historical.discountPercent == discountPercent;
        saleItems.add(
          SaleItem(
            productId: product.id,
            productName: preserveHistorical
                ? historical.productName
                : product.name,
            productCode: preserveHistorical
                ? historical.productCode
                : product.code,
            imageUrl: preserveHistorical ? historical.imageUrl : product.imageUrl,
            quantity: quantity,
            suggestedUnitPrice: preserveHistorical
                ? historical.suggestedUnitPrice
                : product.suggestedPrice,
            costUnitPrice: preserveHistorical
                ? historical.costUnitPrice
                : product.priceForDiscount(discountPercent),
            pointsPerUnit: preserveHistorical
                ? historical.pointsPerUnit
                : product.points,
            discountPercent: discountPercent,
            isGift: giftProductIds.contains(product.id),
          ),
        );
      }

      final remaining = availableItem.quantity - quantity;
      if (remaining > 0) {
        nextInventory.add(availableItem.copyWith(quantity: remaining));
      }
    }
    return _SaleBuildResult(items: saleItems, inventory: nextInventory);
  }

  List<InventoryItem> _restoreItemsToInventory(
    List<InventoryItem> currentInventory,
    List<SaleItem> items,
  ) {
    final byProduct = {
      for (final item in currentInventory) item.product.id: item,
    };
    for (final soldItem in items) {
      final current = byProduct[soldItem.productId];
      final product = current?.product ?? _productFromSaleItem(soldItem);
      byProduct[soldItem.productId] = InventoryItem(
        product: product,
        quantity: (current?.quantity ?? 0) + soldItem.quantity,
      );
    }
    return byProduct.values.where((item) => item.quantity > 0).toList();
  }

  Product _productFromSaleItem(SaleItem item) {
    return products.firstWhere(
      (product) => product.id == item.productId,
      orElse: () => Product(
        id: item.productId,
        countryCode: selectedCountry?.code ?? '',
        name: item.productName,
        code: item.productCode,
        category: ProductCategory.nutrition,
        suggestedPrice: item.suggestedUnitPrice,
        points: item.pointsPerUnit,
        imageUrl: item.imageUrl,
        updatedAt: DateTime.now(),
        discountPrices: {item.discountPercent: item.costUnitPrice},
      ),
    );
  }

  List<Sale> _assignMissingSaleNumbers(List<Sale> source) {
    final chronological = source.toList()
      ..sort((a, b) => a.soldAt.compareTo(b.soldAt));
    final used = chronological
        .where((sale) => sale.number > 0)
        .map((sale) => sale.number)
        .toSet();
    var candidate = 1;
    final numbersById = <String, int>{};
    for (final sale in chronological) {
      if (sale.number > 0) continue;
      while (used.contains(candidate)) candidate++;
      numbersById[sale.id] = candidate;
      used.add(candidate);
      candidate++;
    }
    return source
        .map(
          (sale) => numbersById.containsKey(sale.id)
              ? sale.copyWith(number: numbersById[sale.id])
              : sale,
        )
        .toList();
  }

  void _validateDiscount(int discountPercent) {
    if (!const [25, 30, 35, 40].contains(discountPercent)) {
      throw ArgumentError.value(
        discountPercent,
        'discountPercent',
        'El descuento debe ser 25, 30, 35 o 40.',
      );
    }
  }

  double _validatedReceivedAmount(
    double? receivedAmount,
    List<SaleItem> items,
  ) {
    final calculatedTotal = items.fold<double>(
      0,
      (total, item) => total + item.totalSale,
    );
    final value = receivedAmount ?? calculatedTotal;
    if (value < 0) {
      throw ArgumentError.value(
        value,
        'receivedAmount',
        'El dinero recibido no puede ser negativo.',
      );
    }
    return value;
  }
}

class _SaleBuildResult {
  const _SaleBuildResult({required this.items, required this.inventory});

  final List<SaleItem> items;
  final List<InventoryItem> inventory;
}

class SimulationInventoryIssue {
  const SimulationInventoryIssue({
    required this.productId,
    required this.productName,
    required this.requiredQuantity,
    required this.availableQuantity,
  });

  final String productId;
  final String productName;
  final int requiredQuantity;
  final int availableQuantity;
}

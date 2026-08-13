import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up.dart';
import '../../domain/entities/follow_up_note.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/services/follow_up_schedule.dart';
import '../../data/datasources/operational_database.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../core/services/follow_up_notification_service.dart';
import '../../core/services/encrypted_backup_service.dart';

enum HomeTab { products, simulations }

class AppState extends ChangeNotifier {
  AppState(this._repository, {OperationalDatabase? operationalDatabase, FollowUpNotificationService? notificationService})
      : _operationalDatabase = operationalDatabase,
        _notificationService = notificationService;

  ProductRepository _repository;
  OperationalDatabase? _operationalDatabase;
  final FollowUpNotificationService? _notificationService;
  final _uuid = const Uuid();

  List<Country> countries = const [];
  Country? selectedCountry;
  List<Product> products = const [];
  List<Simulation> simulations = const [];
  List<InventoryItem> inventory = const [];
  List<Sale> sales = const [];
  List<Customer> customers = const [];
  List<FollowUp> followUps = const [];
  List<FollowUpNote> followUpNotes = const [];
  final Map<String, CartItem> _cart = {};
  String? errorMessage;
  bool isLoading = true;
  int selectedDiscount = 0;
  int monthlyPointsGoal = 2500;
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
    await _reloadCrm();
    await _ensureBirthdayFollowUps();
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
      final repository = _repository;
      final remoteAvailable = repository is ProductRepositoryImpl &&
          repository.remoteAvailable;
      errorMessage = remoteAvailable
          ? 'No se pudo descargar el catálogo de ${country.name}. Verifica tu conexión a Internet y vuelve a intentarlo.'
          : 'No hay un catálogo guardado para ${country.name}. Conéctate a Internet la primera vez para descargarlo.';
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
    final withCategories = _assignMissingSaleCategories(loadedSales);
    sales = _assignMissingSaleNumbers(withCategories);
    final needsCompatibilitySave = loadedSales.any(
      (sale) => sale.number == 0 || sale.items.any((item) => item.category == null),
    );
    if (needsCompatibilitySave) {
      await _repository.saveSalesAndInventory(
        country.code,
        inventory,
        sales,
        recordInventoryMovement: false,
      );
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
    String? customerId,
    bool delivered = false,
    DateTime? deliveredAt,
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
    if (_operationalDatabase != null && customerId == null) {
      throw StateError('Selecciona o crea el cliente de la venta.');
    }
    if (_operationalDatabase != null &&
        !_isCustomerEligibleForNewSale(customerId)) {
      throw StateError(
        'El cliente debe estar activo y tener consentimiento para registrar una venta.',
      );
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
      customerId: customerId,
      deliveryStatus: delivered ? DeliveryStatus.delivered : DeliveryStatus.pending,
      deliveredAt: delivered ? (deliveredAt ?? DateTime.now()) : null,
      items: result.items,
    );

    final nextSales = [sale, ...sales];
    await _repository.saveSalesAndInventory(
      country.code,
      result.inventory,
      nextSales,
      movementType: InventoryMovementType.sale,
      relatedId: sale.id,
      reason: 'Venta #${sale.number}',
    );
    inventory = result.inventory;
    sales = nextSales;
    if (sale.isDelivered && sale.customerId != null) {
      await _createDeliveryFollowUps(sale);
    }
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
    String? customerId,
    bool? delivered,
    DateTime? deliveredAt,
  }) async {
    final country = selectedCountry;
    if (country == null) {
      throw StateError('Debe seleccionar un pais antes de editar ventas.');
    }
    if (!originalSale.isCompleted) {
      throw StateError('Una venta cancelada no se puede editar.');
    }
    _validateDiscount(discountPercent);
    if (customerId != originalSale.customerId &&
        !_isCustomerEligibleForNewSale(customerId)) {
      throw StateError(
        'Solo puedes cambiar la venta a un cliente activo con consentimiento.',
      );
    }

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
      customerId: customerId,
      deliveryStatus: delivered == null
          ? originalSale.deliveryStatus
          : delivered ? DeliveryStatus.delivered : DeliveryStatus.pending,
      deliveredAt: delivered == null
          ? originalSale.deliveredAt
          : delivered ? (deliveredAt ?? DateTime.now()) : null,
      clearDeliveredAt: delivered == false,
    );
    final nextSales = sales
        .map((sale) => sale.id == originalSale.id ? updated : sale)
        .toList();

    await _repository.saveSalesAndInventory(
      country.code,
      result.inventory,
      nextSales,
      movementType: InventoryMovementType.saleEdit,
      relatedId: originalSale.id,
      reason: 'Edicion de venta #${originalSale.number}',
    );
    inventory = result.inventory;
    sales = nextSales;
    if (updated.isDelivered && updated.customerId != null) {
      await _createDeliveryFollowUps(updated);
    } else if (!updated.isDelivered) {
      await _cancelPendingFollowUpsForSale(updated.id);
    }
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
      movementType: InventoryMovementType.saleCancellation,
      relatedId: sale.id,
      reason: 'Cancelacion de venta #${sale.number}',
    );
    inventory = restoredInventory;
    sales = nextSales;
    await _cancelPendingFollowUpsForSale(sale.id);
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
      movementType: InventoryMovementType.saleCancellation,
      relatedId: sale.id,
      reason: 'Eliminacion de venta #${sale.number}',
    );
    inventory = nextInventory;
    sales = nextSales;
    await _cancelPendingFollowUpsForSale(sale.id);
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
            category: preserveHistorical
                ? historical.category ?? product.category
                : product.category,
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
        category: item.category ?? ProductCategory.nutrition,
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

  List<Sale> _assignMissingSaleCategories(List<Sale> source) {
    final productsById = {for (final product in products) product.id: product};
    return source.map((sale) {
      if (sale.items.every((item) => item.category != null)) return sale;
      return sale.copyWith(
        items: sale.items
            .map(
              (item) => item.category != null
                  ? item
                  : item.copyWith(
                      category: productsById[item.productId]?.category ??
                          ProductCategory.nutrition,
                    ),
            )
            .toList(),
      );
    }).toList();
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

  Future<void> _reloadCrm() async {
    final db = _operationalDatabase;
    if (db == null) return;
    monthlyPointsGoal = await db.monthlyPointsGoal;
    customers = await db.loadCustomers(includeArchived: true);
    followUps = await db.loadFollowUps();
    followUpNotes = await db.loadFollowUpNotes();
    await _notificationService?.reschedule(
      followUps, customers,
      reminderHour: await db.reminderHour,
    );
  }

  void attachRepository(ProductRepository repository) {
    _repository = repository;
    final db = _operationalDatabase;
    if (db != null && repository is ProductRepositoryImpl) {
      repository.attachOperationalDatabase(db);
    }
  }

  Future<void> attachOperationalDatabase(OperationalDatabase database) async {
    if (identical(_operationalDatabase, database)) return;
    _operationalDatabase = database;
    final repository = _repository;
    if (repository is ProductRepositoryImpl) {
      repository.attachOperationalDatabase(database);
    }
    await _reloadCrm();
    await _ensureBirthdayFollowUps();
    notifyListeners();
  }

  EncryptedBackupService get backupService {
    final db = _operationalDatabase;
    if (db == null) throw StateError('La base local segura no esta disponible.');
    return EncryptedBackupService(db);
  }

  Future<void> reloadAfterImport() async {
    await _reloadCrm();
    final country = selectedCountry;
    if (country != null) await loadCountry(country, persist: false);
  }

  Future<int> get reminderHour async => await _operationalDatabase?.reminderHour ?? 9;

  Future<void> setReminderHour(int hour) async {
    await _operationalDatabase?.setReminderHour(hour);
    await _reloadCrm();
    notifyListeners();
  }

  Future<void> setMonthlyPointsGoal(int goal) async {
    if (goal < 1) throw ArgumentError.value(goal, 'goal');
    monthlyPointsGoal = goal;
    await _operationalDatabase?.setMonthlyPointsGoal(goal);
    notifyListeners();
  }

  Future<int?> productFollowUpDurationDays(Product product) async =>
      _operationalDatabase?.configuredDurationDays(product.id, product.countryCode, product.category);

  Future<void> setProductFollowUpDuration(Product product, {required bool enabled, required int days}) async {
    await _operationalDatabase?.saveProductDuration(
      productId: product.id, countryCode: product.countryCode,
      enabled: enabled, days: days,
    );
  }

  Future<void> _ensureBirthdayFollowUps() async {
    final db = _operationalDatabase;
    if (db == null) return;
    final now = DateTime.now();
    final changes = <FollowUp>[];
    for (final customer in customers) {
      final birthday = customer.birthday;
      final currentPending = followUps.where((item) =>
          item.customerId == customer.id &&
          item.type == FollowUpType.birthday &&
          item.status == FollowUpStatus.pending);
      if (birthday == null ||
          customer.isArchived ||
          !customer.birthdayRemindersEnabled ||
          !customer.hasActiveConsent) {
        changes.addAll(currentPending.map(
          (item) => item.copyWith(status: FollowUpStatus.cancelled),
        ));
        continue;
      }
      final today = DateTime(now.year, now.month, now.day);
      var due = DateTime(now.year, birthday.month, birthday.day, 9);
      if (DateTime(due.year, due.month, due.day).isBefore(today)) {
        due = DateTime(now.year + 1, birthday.month, birthday.day, 9);
      }
      final completedThisYear = followUps.any((item) =>
          item.customerId == customer.id &&
          item.type == FollowUpType.birthday &&
          item.dueAt.year == now.year &&
          item.status == FollowUpStatus.completed);
      if (completedThisYear && due.year == now.year) {
        due = DateTime(now.year + 1, birthday.month, birthday.day, 9);
      }
      final pending = currentPending.toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
      FollowUp? keep;
      for (final item in pending) {
        if (item.dueAt.year == due.year && keep == null) {
          keep = item.dueAt == due ? item : item.copyWith(dueAt: due);
          if (keep != item) changes.add(keep!);
        } else {
          changes.add(item.copyWith(status: FollowUpStatus.cancelled));
        }
      }
      keep ??= FollowUp(
        id: _uuid.v4(),
        customerId: customer.id,
        type: FollowUpType.birthday,
        dueAt: due,
        createdAt: now,
      );
      if (!followUps.any((item) => item.id == keep!.id)) changes.add(keep!);
    }
    if (changes.isNotEmpty) await db.saveFollowUps(changes);
    await _reloadCrm();
  }

  Future<Customer> saveCustomer(Customer customer) async {
    final db = _operationalDatabase;
    if (db == null) throw StateError('La base local segura no esta disponible.');
    await db.saveCustomer(customer);
    await _reloadCrm();
    await _ensureBirthdayFollowUps();
    notifyListeners();
    return customer;
  }

  Future<Customer> createCustomer({
    required String name,
    required String callingCode,
    required String phoneNumber,
    String goal = '',
    DateTime? birthday,
    required bool consentGranted,
  }) async {
    if (!consentGranted) throw StateError('Debes registrar el consentimiento del cliente.');
    final now = DateTime.now();
    return saveCustomer(Customer(
      id: _uuid.v4(), name: name.trim(), callingCode: callingCode,
      phoneNumber: phoneNumber.trim(), goal: goal.trim(), birthday: birthday,
      consentAt: now, consentScopes: const {
        ConsentScope.phone, ConsentScope.birthday, ConsentScope.goals, ConsentScope.notes,
      }, createdAt: now, updatedAt: now,
    ));
  }

  Future<void> pauseCustomerFollowUp(Customer customer, {DateTime? until, String? reason}) async {
    await saveCustomer(customer.copyWith(
      followUpEnabled: false, followUpPausedUntil: until,
      followUpPauseReason: reason ?? '',
    ));
    final db = _operationalDatabase;
    if (db != null) {
      await db.saveFollowUps(followUps
          .where((item) => item.customerId == customer.id && item.status == FollowUpStatus.pending)
          .map((item) => item.copyWith(status: FollowUpStatus.paused)));
      await _reloadCrm();
      notifyListeners();
    }
  }

  Future<void> resumeCustomerFollowUp(Customer customer, {bool fromToday = true}) async {
    await saveCustomer(customer.copyWith(followUpEnabled: true, clearPausedUntil: true));
    final now = DateTime.now();
    final db = _operationalDatabase;
    if (db != null) {
      await db.saveFollowUps(followUps
          .where((item) => item.customerId == customer.id && item.status == FollowUpStatus.paused)
          .map((item) => item.copyWith(
                status: FollowUpStatus.pending,
                dueAt: fromToday && item.dueAt.isBefore(now) ? now : item.dueAt,
              )));
      await _reloadCrm();
      notifyListeners();
    }
  }

  Future<void> completeFollowUp(
    FollowUp item, {
    String notes = '',
    FollowUpContactMethod contactMethod = FollowUpContactMethod.other,
  }) async {
    final db = _operationalDatabase;
    final completedAt = DateTime.now();
    await _operationalDatabase?.saveFollowUp(item.copyWith(
      status: FollowUpStatus.completed,
      completedAt: completedAt,
      notes: notes.trim(),
    ));
    if (db != null && notes.trim().isNotEmpty) {
      await db.saveFollowUpNote(FollowUpNote(
        id: _uuid.v4(),
        customerId: item.customerId,
        followUpId: item.id,
        saleId: item.saleId,
        productId: item.productId,
        followUpType: item.type.name,
        text: notes.trim(),
        contactMethod: contactMethod,
        deviceId: db.deviceId,
        createdAt: completedAt,
      ));
    }
    await _reloadCrm();
    if (item.type == FollowUpType.birthday) {
      await _ensureBirthdayFollowUps();
    }
    if (item.type == FollowUpType.periodic) {
      final next = FollowUp(
        id: _uuid.v4(), customerId: item.customerId, saleId: item.saleId,
        type: FollowUpType.periodic, dueAt: item.dueAt.add(const Duration(days: 15)),
        createdAt: DateTime.now(),
      );
      await _operationalDatabase?.saveFollowUp(next);
      await _reloadCrm();
    }
    notifyListeners();
  }

  Future<void> addManualNote({
    required String customerId,
    required String text,
    String? saleId,
    String? productId,
    FollowUpContactMethod contactMethod = FollowUpContactMethod.other,
  }) async {
    final db = _operationalDatabase;
    if (db == null) throw StateError('La base local no esta disponible.');
    if (text.trim().isEmpty) throw ArgumentError('La nota no puede estar vacia.');
    await db.saveFollowUpNote(FollowUpNote(
      id: _uuid.v4(),
      customerId: customerId,
      saleId: saleId,
      productId: productId,
      text: text.trim(),
      contactMethod: contactMethod,
      deviceId: db.deviceId,
      createdAt: DateTime.now(),
    ));
    followUpNotes = await db.loadFollowUpNotes();
    notifyListeners();
  }

  Future<void> updateFollowUpNote(
    FollowUpNote note, {
    required String text,
    required FollowUpContactMethod contactMethod,
  }) async {
    final db = _operationalDatabase;
    if (db == null) throw StateError('La base local no esta disponible.');
    await db.saveFollowUpNote(
      note.copyWith(text: text.trim(), contactMethod: contactMethod),
    );
    followUpNotes = await db.loadFollowUpNotes();
    notifyListeners();
  }

  FollowUp? followUpById(String id) =>
      followUps.where((item) => item.id == id).firstOrNull;

  Customer? customerById(String id) =>
      customers.where((item) => item.id == id).firstOrNull;

  Sale? saleById(String? id) =>
      id == null ? null : sales.where((item) => item.id == id).firstOrNull;

  Future<void> rescheduleNotifications() => _reloadCrm();

  FollowUpNotificationService? get notificationService => _notificationService;

  Future<void> archiveCustomer(Customer customer, {bool archived = true}) async {
    final updated = customer.copyWith(
      archivedAt: archived ? DateTime.now() : null,
      clearArchivedAt: !archived,
      followUpEnabled: archived ? false : customer.followUpEnabled,
    );
    await saveCustomer(updated);
    if (archived) await pauseCustomerFollowUp(updated, reason: 'Cliente archivado');
  }

  Future<void> revokeCustomerConsent(Customer customer) async {
    final revoked = customer.copyWith(
      consentRevokedAt: DateTime.now(), followUpEnabled: false,
      allowCalls: false, allowWhatsApp: false,
    );
    await saveCustomer(revoked);
    await _cancelCustomerFollowUps(customer.id);
  }

  Future<void> reactivateCustomerConsent(
    Customer customer, {
    bool resumeFollowUp = false,
  }) async {
    final reactivated = customer.copyWith(
      consentAt: DateTime.now(),
      clearConsentRevocation: true,
      allowCalls: true,
      allowWhatsApp: true,
      followUpEnabled: resumeFollowUp ? true : customer.followUpEnabled,
    );
    await saveCustomer(reactivated);
    if (resumeFollowUp) {
      await resumeCustomerFollowUp(reactivated, fromToday: true);
    }
  }

  Future<void> updateCustomerProfile({
    required Customer customer,
    required String name,
    required String callingCode,
    required String phoneNumber,
    required String goal,
    required DateTime? birthday,
    required bool consentGranted,
  }) async {
    var updated = customer.copyWith(
      name: name.trim(),
      callingCode: callingCode.trim(),
      phoneNumber: phoneNumber.trim(),
      goal: goal.trim(),
      birthday: birthday,
      clearBirthday: birthday == null,
    );
    if (consentGranted && !customer.hasActiveConsent) {
      updated = updated.copyWith(
        consentAt: DateTime.now(),
        clearConsentRevocation: true,
        allowCalls: true,
        allowWhatsApp: true,
      );
      await saveCustomer(updated);
      return;
    }
    if (!consentGranted && customer.hasActiveConsent) {
      updated = updated.copyWith(
        consentRevokedAt: DateTime.now(),
        followUpEnabled: false,
        allowCalls: false,
        allowWhatsApp: false,
      );
      await saveCustomer(updated);
      await _cancelCustomerFollowUps(customer.id);
      return;
    }
    await saveCustomer(updated);
  }

  Future<void> confirmDelivery(Sale sale, {DateTime? deliveredAt}) async {
    if (sale.customerId == null) throw StateError('Asocia un cliente antes de confirmar la entrega.');
    final updated = sale.copyWith(
      deliveryStatus: DeliveryStatus.delivered,
      deliveredAt: deliveredAt ?? DateTime.now(),
    );
    final nextSales = sales.map((item) => item.id == sale.id ? updated : item).toList();
    await _repository.saveSalesAndInventory(
      sale.countryCode, inventory, nextSales, recordInventoryMovement: false,
    );
    sales = nextSales;
    await _createDeliveryFollowUps(updated);
    notifyListeners();
  }

  Future<void> _createDeliveryFollowUps(Sale sale) async {
    final db = _operationalDatabase;
    final deliveredAt = sale.deliveredAt;
    final customerId = sale.customerId;
    if (db == null || deliveredAt == null || customerId == null) return;
    final customer = customers.where((item) => item.id == customerId).firstOrNull;
    if (customer == null ||
        customer.isArchived ||
        !customer.hasActiveConsent ||
        !customer.followUpEnabled) {
      await _cancelPendingFollowUpsForSale(sale.id);
      return;
    }
    final existing = followUps.where((item) =>
        item.saleId == sale.id && item.status != FollowUpStatus.cancelled).toList();
    if (existing.isNotEmpty) {
      await _rescheduleSaleFollowUps(sale, existing);
      return;
    }
    final now = DateTime.now();
    final schedule = FollowUpSchedule.afterDelivery(deliveredAt);
    final items = <FollowUp>[
      for (final entry in schedule.entries)
        FollowUp(
          id: _uuid.v4(), customerId: customerId, saleId: sale.id,
          type: entry.key, dueAt: entry.value,
          createdAt: now,
        ),
    ];
    for (final saleItem in sale.items) {
      final product = products.where((item) => item.id == saleItem.productId).firstOrNull;
      if (product == null) continue;
      final daysPerUnit = await db.configuredDurationDays(
        product.id, product.countryCode, product.category,
      );
      if (daysPerUnit == null) continue;
      items.add(FollowUp(
        id: _uuid.v4(), customerId: customerId, saleId: sale.id,
        productId: saleItem.productId, type: FollowUpType.replenishment,
        dueAt: FollowUpSchedule.replenishment(
          deliveredAt,
          daysPerUnit: daysPerUnit,
          quantity: saleItem.quantity,
        ),
        createdAt: now,
      ));
    }
    await db.saveFollowUps(items);
    await _reloadCrm();
  }

  Future<void> _cancelPendingFollowUpsForSale(String saleId) async {
    final pending = followUps.where((item) =>
        item.saleId == saleId && item.status == FollowUpStatus.pending);
    await _operationalDatabase?.saveFollowUps(
      pending.map((item) => item.copyWith(status: FollowUpStatus.cancelled)),
    );
    await _reloadCrm();
  }

  bool _isCustomerEligibleForNewSale(String? customerId) {
    if (customerId == null) return false;
    final customer = customers.where((item) => item.id == customerId).firstOrNull;
    return customer != null &&
        !customer.isArchived &&
        customer.hasActiveConsent;
  }

  Future<void> _cancelCustomerFollowUps(String customerId) async {
    final cancellable = followUps.where(
      (item) =>
          item.customerId == customerId &&
          (item.status == FollowUpStatus.pending ||
              item.status == FollowUpStatus.paused),
    );
    await _operationalDatabase?.saveFollowUps(
      cancellable.map(
        (item) => item.copyWith(status: FollowUpStatus.cancelled),
      ),
    );
    await _reloadCrm();
    notifyListeners();
  }

  Future<void> _rescheduleSaleFollowUps(Sale sale, List<FollowUp> existing) async {
    final deliveredAt = sale.deliveredAt;
    final db = _operationalDatabase;
    if (deliveredAt == null || db == null) return;
    final updated = <FollowUp>[];
    for (final item in existing.where((entry) => entry.status == FollowUpStatus.pending)) {
      int? days = switch (item.type) {
        FollowUpType.dayOne => 1,
        FollowUpType.dayThree => 3,
        FollowUpType.dayEight => 8,
        FollowUpType.periodic => 23,
        _ => null,
      };
      if (item.type == FollowUpType.replenishment && item.productId != null) {
        final product = products.where((entry) => entry.id == item.productId).firstOrNull;
        final sold = sale.items.where((entry) => entry.productId == item.productId).firstOrNull;
        if (product != null && sold != null) {
          final perUnit = await db.configuredDurationDays(product.id, product.countryCode, product.category);
          days = perUnit == null ? null : perUnit * sold.quantity;
        }
      }
      if (days != null) {
        final due = deliveredAt.add(Duration(days: days));
        updated.add(item.copyWith(dueAt: DateTime(due.year, due.month, due.day, 9)));
      }
    }
    await db.saveFollowUps(updated);
    await _reloadCrm();
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

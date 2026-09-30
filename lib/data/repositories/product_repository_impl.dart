import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/product_image_cache_service.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/firestore_product_remote_data_source.dart';
import '../datasources/local_store.dart';
import '../datasources/operational_database.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required LocalStore localStore,
    required FirestoreProductRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
    this.operationalDatabase,
  })  : _localStore = localStore,
        _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService;

  final LocalStore _localStore;
  final FirestoreProductRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;
  OperationalDatabase? operationalDatabase;

  bool get remoteAvailable => _remoteDataSource.isAvailable;

  void attachOperationalDatabase(OperationalDatabase database) {
    operationalDatabase = database;
  }

  @override
  Future<List<Country>> getCountries() async => supportedCountries;

  @override
  Future<String?> getSelectedCountry() async => _localStore.getSelectedCountry();

  @override
  Future<void> saveSelectedCountry(String countryCode) {
    return _localStore.saveSelectedCountry(countryCode);
  }

  @override
  Future<List<Product>> loadProducts(String countryCode) async {
    return _localStore.loadProducts(countryCode);
  }

  Future<List<Product>> loadProductsWithFallback(String countryCode) async {
    var products = await loadProducts(countryCode);
    if (products.isNotEmpty || countryCode == defaultCountryCode) {
      return products;
    }

    await syncProductsIfNeeded(defaultCountryCode, force: true);
    products = await loadProducts(defaultCountryCode);
    return products;
  }

  Future<bool> hasProducts(String countryCode) async {
    if (_localStore.loadProducts(countryCode).isNotEmpty) return true;
    if (!_remoteDataSource.isAvailable) return false;
    if (!await _connectivityService.hasInternet) return false;

    final metadata = await _remoteDataSource.fetchCatalogMetadata(countryCode);
    if (metadata == null || metadata.productsCount <= 0) return false;

    final products = await _remoteDataSource.fetchProducts(countryCode);
    if (products.isEmpty) return false;

    await _localStore.saveProducts(countryCode, products);
    _cacheImagesInBackground(products);
    await _localStore.saveCatalogVersion(countryCode, metadata.version);
    await _localStore.saveLastSync(countryCode, DateTime.now());
    return true;
  }

  @override
  Future<void> syncProductsIfNeeded(String countryCode, {bool force = false}) async {
    if (!_remoteDataSource.isAvailable) return;
    if (!await _connectivityService.hasInternet) return;

    final now = DateTime.now();

    try {
      // Siempre consultamos la metadata al abrir/cambiar pais.
      // Esta lectura es liviana y permite detectar cambios de version
      // sin esperar al dia siguiente. Los productos solo se descargan
      // cuando la version remota cambia o cuando force=true.
      final metadata = await _remoteDataSource.fetchCatalogMetadata(countryCode);
      // El catálogo de Hive es la fuente de respaldo offline. Una respuesta remota
      // vacía, incompleta o temporalmente no disponible nunca debe borrar el
      // último catálogo válido que ya tiene el usuario.
      if (metadata == null || metadata.productsCount <= 0) {
        await _localStore.saveLastSync(countryCode, now);
        return;
      }

      final localVersion = _localStore.getCatalogVersion(countryCode);
      if (force || localVersion != metadata.version) {
        final products = await _remoteDataSource.fetchProducts(countryCode);
        if (products.isNotEmpty) {
          await _localStore.saveProducts(countryCode, products);
          _cacheImagesInBackground(products);
          await _localStore.saveCatalogVersion(countryCode, metadata.version);
        }
        // Si la descarga viene vacía conservamos el catálogo anterior.
      }

      await _localStore.saveLastSync(countryCode, now);
    } catch (error) {
      throw AppException(
        'No se pudo sincronizar el catalogo. Se usaran los datos guardados.',
        cause: error,
      );
    }
  }

  void _cacheImagesInBackground(List<Product> products) {
    unawaited(ProductImageCacheService.cacheProductImagesInBackground(products));
  }

  @override
  Future<void> saveSimulation(Simulation simulation) {
    return _saveSimulation(simulation);
  }

  Future<void> _saveSimulation(Simulation simulation) async {
    await _localStore.saveSimulation(simulation);
    final payload = _localStore.rawOperationalValue('simulations', simulation.countryCode);
    if (payload != null) await operationalDatabase?.writeSnapshot('simulations', simulation.countryCode, payload);
  }

  @override
  Future<List<Simulation>> loadSimulations(String countryCode) async {
    final payload = await operationalDatabase?.readSnapshot('simulations', countryCode);
    if (payload != null) return _localStore.simulationsFromPayload(payload);
    return _localStore.loadSimulations(countryCode);
  }

  @override
  Future<void> deleteSimulation(String countryCode, String simulationId) {
    return _deleteSimulation(countryCode, {simulationId});
  }

  @override
  Future<void> deleteSimulations(String countryCode, Set<String> simulationIds) {
    return _deleteSimulation(countryCode, simulationIds);
  }

  Future<void> _deleteSimulation(String countryCode, Set<String> ids) async {
    await _localStore.deleteSimulations(countryCode, ids);
    final payload = _localStore.rawOperationalValue('simulations', countryCode);
    if (payload != null) await operationalDatabase?.writeSnapshot('simulations', countryCode, payload);
  }

  @override
  Future<List<InventoryItem>> loadInventory(String countryCode) async {
    final db = operationalDatabase;
    if (db != null && await db.isMigrationValidated) {
      final stock = await db.stock(countryCode);
      final products = _localStore.loadProducts(countryCode);
      final items = products
          .where((product) => (stock[product.id] ?? 0) > 0)
          .map((product) => InventoryItem(product: product, quantity: stock[product.id]!))
          .toList();
      return [...items, ..._orphanInventory(countryCode, stock, products)];
    }
    return _localStore.loadInventory(countryCode);
  }

  // ── NUEVO: stock de productos que ya no están en el catálogo ────────────
  // Propósito: conservar el stock de un producto desactivado en Firestore. Sin
  //            esto desaparecía de la lista y el siguiente guardado lo ponía en 0.
  // Depende de: LocalStore.loadInventory (el producto va embebido en Hive).
  // No modifica: el resultado para productos que siguen en el catálogo.
  List<InventoryItem> _orphanInventory(
    String countryCode,
    Map<String, int> stock,
    List<Product> catalog,
  ) {
    final catalogIds = {for (final product in catalog) product.id};
    final missing = stock.entries
        .where((entry) => entry.value > 0 && !catalogIds.contains(entry.key))
        .toList();
    if (missing.isEmpty) return const [];
    final embedded = {
      for (final item in _localStore.loadInventory(countryCode))
        item.product.id: item.product,
    };
    return [
      for (final entry in missing)
        if (embedded[entry.key] != null)
          InventoryItem(product: embedded[entry.key]!, quantity: entry.value),
    ];
  }

  // ── NUEVO: movimientos solo con migración validada ──────────────────────
  // Propósito: mientras la migración Hive→SQLite no está validada, el
  //            inventario se lee de Hive; registrar movimientos en ese estado
  //            duplicaba el saldo inicial en cada reintento de migración.
  // Depende de: OperationalDatabase.isMigrationValidated.
  // No modifica: el comportamiento una vez validada la migración.
  Future<bool> _canRecordMovements(OperationalDatabase db) =>
      db.isMigrationValidated;

  @override
  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
  }) async {
    final inventoryPayload = _localStore.encodeInventoryPayload(inventory);
    final db = operationalDatabase;
    if (db != null) {
      // SQLite primero y en una sola transacción; Hive queda como réplica.
      await db.commitInventoryAndSnapshots(
        countryCode,
        desired: inventory,
        type: movementType,
        recordMovements: await _canRecordMovements(db),
        relatedId: relatedId,
        reason: reason,
        snapshots: {'inventory': inventoryPayload},
      );
    }
    await _localStore.saveRawOperationalValues(
      countryCode,
      inventoryPayload: inventoryPayload,
    );
  }

  @override
  Future<List<Sale>> loadSales(String countryCode) async {
    final payload = await operationalDatabase?.readSnapshot('sales', countryCode);
    if (payload != null) return _localStore.salesFromPayload(payload);
    return _localStore.loadSales(countryCode);
  }

  @override
  Future<void> registerSale(
    String countryCode,
    List<InventoryItem> inventory,
    Sale sale,
  ) {
    return _localStore.registerSale(countryCode, inventory, sale);
  }

  @override
  Future<void> saveSalesAndInventory(
    String countryCode,
    List<InventoryItem> inventory,
    List<Sale> sales, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
    bool recordInventoryMovement = true,
  }) async {
    final salesPayload = _localStore.encodeSalesPayload(sales);
    final inventoryPayload = _localStore.encodeInventoryPayload(inventory);
    final db = operationalDatabase;
    if (db != null) {
      // Movimientos + snapshots de ventas e inventario en una sola transacción:
      // una interrupción ya no deja stock descontado sin su venta.
      await db.commitInventoryAndSnapshots(
        countryCode,
        desired: inventory,
        type: movementType,
        recordMovements:
            recordInventoryMovement && await _canRecordMovements(db),
        relatedId: relatedId,
        reason: reason,
        snapshots: {'sales': salesPayload, 'inventory': inventoryPayload},
      );
    }
    await _localStore.saveRawOperationalValues(
      countryCode,
      inventoryPayload: inventoryPayload,
      salesPayload: salesPayload,
    );
  }
}

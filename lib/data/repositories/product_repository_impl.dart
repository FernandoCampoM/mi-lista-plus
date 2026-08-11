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
      if (metadata == null || metadata.productsCount <= 0) {
        await _localStore.clearProducts(countryCode);
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
        } else {
          await _localStore.clearProducts(countryCode);
        }
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
      return products
          .where((product) => (stock[product.id] ?? 0) > 0)
          .map((product) => InventoryItem(product: product, quantity: stock[product.id]!))
          .toList();
    }
    return _localStore.loadInventory(countryCode);
  }

  @override
  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
  }) async {
    await operationalDatabase?.reconcileInventory(countryCode, inventory, movementType, relatedId: relatedId, reason: reason);
    await _localStore.saveInventory(countryCode, inventory);
    final payload = _localStore.rawOperationalValue('inventory', countryCode);
    if (payload != null) await operationalDatabase?.writeSnapshot('inventory', countryCode, payload);
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
    if (recordInventoryMovement) {
      await operationalDatabase?.reconcileInventory(countryCode, inventory, movementType, relatedId: relatedId, reason: reason);
    }
    await _localStore.saveSalesAndInventory(countryCode, inventory, sales);
    final salesPayload = _localStore.rawOperationalValue('sales', countryCode);
    final inventoryPayload = _localStore.rawOperationalValue('inventory', countryCode);
    if (salesPayload != null) await operationalDatabase?.writeSnapshot('sales', countryCode, salesPayload);
    if (inventoryPayload != null) await operationalDatabase?.writeSnapshot('inventory', countryCode, inventoryPayload);
  }
}

import 'dart:async';

import '../../core/errors/app_exception.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/product_image_cache_service.dart';
import '../../domain/entities/country.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/simulation.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/firestore_product_remote_data_source.dart';
import '../datasources/local_store.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl({
    required LocalStore localStore,
    required FirestoreProductRemoteDataSource remoteDataSource,
    required ConnectivityService connectivityService,
  })  : _localStore = localStore,
        _remoteDataSource = remoteDataSource,
        _connectivityService = connectivityService;

  final LocalStore _localStore;
  final FirestoreProductRemoteDataSource _remoteDataSource;
  final ConnectivityService _connectivityService;

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
    return _localStore.saveSimulation(simulation);
  }

  @override
  Future<List<Simulation>> loadSimulations(String countryCode) async {
    return _localStore.loadSimulations(countryCode);
  }

  @override
  Future<void> deleteSimulation(String countryCode, String simulationId) {
    return _localStore.deleteSimulation(countryCode, simulationId);
  }

  @override
  Future<void> deleteSimulations(String countryCode, Set<String> simulationIds) {
    return _localStore.deleteSimulations(countryCode, simulationIds);
  }
}

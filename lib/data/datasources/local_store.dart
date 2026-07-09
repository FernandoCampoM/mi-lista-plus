import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/simulation.dart';

class LocalStore {
  LocalStore(this._preferences, this._box);

  static const productsBoxName = 'mi_lista_products';
  static const _selectedCountryKey = 'selected_country';
  static const _lastSyncPrefix = 'last_sync_';
  static const _catalogVersionPrefix = 'catalog_version_';
  static const _simulationsPrefix = 'simulations_';

  final SharedPreferences _preferences;
  final Box<String> _box;

  Future<void> saveSelectedCountry(String countryCode) {
    return _preferences.setString(_selectedCountryKey, countryCode);
  }

  String? getSelectedCountry() => _preferences.getString(_selectedCountryKey);

  DateTime? getLastSync(String countryCode) {
    final raw = _preferences.getString('$_lastSyncPrefix$countryCode');
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> saveLastSync(String countryCode, DateTime value) {
    return _preferences.setString(
      '$_lastSyncPrefix$countryCode',
      value.toIso8601String(),
    );
  }

  String? getCatalogVersion(String countryCode) {
    return _preferences.getString('$_catalogVersionPrefix$countryCode');
  }

  Future<void> saveCatalogVersion(String countryCode, String version) {
    return _preferences.setString(
      '$_catalogVersionPrefix$countryCode',
      version,
    );
  }

  Future<void> saveProducts(String countryCode, List<Product> products) async {
    final encoded = products.map((product) => _productToJson(product)).toList();
    await _box.put('products_$countryCode', jsonEncode(encoded));
  }

  List<Product> loadProducts(String countryCode) {
    final raw = _box.get('products_$countryCode');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((value) => _productFromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveSimulation(Simulation simulation) async {
    final current = loadSimulations(simulation.countryCode);
    final next = [simulation, ...current];
    await saveSimulations(simulation.countryCode, next);
  }

  Future<void> saveSimulations(
    String countryCode,
    List<Simulation> simulations,
  ) async {
    final encoded = simulations.map((item) => _simulationToJson(item)).toList();
    await _box.put('$_simulationsPrefix$countryCode', jsonEncode(encoded));
  }

  Future<void> deleteSimulation(String countryCode, String simulationId) async {
    final next = loadSimulations(countryCode)
        .where((simulation) => simulation.id != simulationId)
        .toList();
    await saveSimulations(countryCode, next);
  }

  Future<void> deleteSimulations(
    String countryCode,
    Set<String> simulationIds,
  ) async {
    final next = loadSimulations(countryCode)
        .where((simulation) => !simulationIds.contains(simulation.id))
        .toList();
    await saveSimulations(countryCode, next);
  }

  List<Simulation> loadSimulations(String countryCode) {
    final raw = _box.get('$_simulationsPrefix$countryCode');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((value) => _simulationFromJson(value as Map<String, dynamic>))
        .toList();
  }

  static Map<String, dynamic> _productToJson(Product product) {
    return {
      'id': product.id,
      'countryCode': product.countryCode,
      'name': product.name,
      'code': product.code,
      'category': product.category.name,
      'suggestedPrice': product.suggestedPrice,
      'points': product.points,
      'imageUrl': product.imageUrl,
      'updatedAt': product.updatedAt.toIso8601String(),
      'discountPrices': product.discountPrices.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
      'description': product.description,
    };
  }

  static Product _productFromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      countryCode: json['countryCode'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      category: ProductCategory.values.firstWhere(
        (item) => item.name == json['category'],
        orElse: () => ProductCategory.nutrition,
      ),
      suggestedPrice: (json['suggestedPrice'] as num).toDouble(),
      points: (json['points'] as num).toInt(),
      imageUrl: json['imageUrl'] as String? ?? '',
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      discountPrices: (json['discountPrices'] as Map<String, dynamic>? ?? {})
          .map((key, value) => MapEntry(int.parse(key), (value as num).toDouble())),
      description: json['description'] as String?,
    );
  }

  static Map<String, dynamic> _simulationToJson(Simulation simulation) {
    return {
      'id': simulation.id,
      'countryCode': simulation.countryCode,
      'customerName': simulation.customerName,
      'discountPercent': simulation.discountPercent,
      'createdAt': simulation.createdAt.toIso8601String(),
      'items': simulation.items
          .map(
            (item) => {
              'product': _productToJson(item.product),
              'quantity': item.quantity,
            },
          )
          .toList(),
    };
  }

  static Simulation _simulationFromJson(Map<String, dynamic> json) {
    return Simulation(
      id: json['id'] as String,
      countryCode: json['countryCode'] as String,
      customerName: json['customerName'] as String,
      discountPercent: (json['discountPercent'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => CartItem(
              product: _productFromJson(item['product'] as Map<String, dynamic>),
              quantity: (item['quantity'] as num).toInt(),
            ),
          )
          .toList(),
    );
  }
}


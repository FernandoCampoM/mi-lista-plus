import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/cart_item.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/simulation.dart';

class LocalStore {
  LocalStore(this._preferences, this._box);

  static const productsBoxName = 'mi_lista_products';
  static const _selectedCountryKey = 'selected_country';
  static const _lastSyncPrefix = 'last_sync_';
  static const _catalogVersionPrefix = 'catalog_version_';
  static const _simulationsPrefix = 'simulations_';
  static const _inventoryPrefix = 'inventory_';
  static const _salesPrefix = 'sales_';

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

  Future<void> clearProducts(String countryCode) async {
    await _box.delete('products_$countryCode');
    await _preferences.remove('$_catalogVersionPrefix$countryCode');
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
    final next = [
      simulation,
      ...current.where((item) => item.id != simulation.id),
    ];
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

  List<InventoryItem> loadInventory(String countryCode) {
    final raw = _box.get('$_inventoryPrefix$countryCode');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((value) => _inventoryItemFromJson(value as Map<String, dynamic>))
        .where((item) => item.quantity > 0)
        .toList();
  }

  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory,
  ) {
    final activeItems = inventory.where((item) => item.quantity > 0);
    return _box.put(
      '$_inventoryPrefix$countryCode',
      jsonEncode(activeItems.map(_inventoryItemToJson).toList()),
    );
  }

  List<Sale> loadSales(String countryCode) {
    final raw = _box.get('$_salesPrefix$countryCode');
    if (raw == null) return const [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((value) => _saleFromJson(value as Map<String, dynamic>))
        .toList();
  }

  Future<void> registerSale(
    String countryCode,
    List<InventoryItem> inventory,
    Sale sale,
  ) {
    final sales = [sale, ...loadSales(countryCode)];
    return saveSalesAndInventory(countryCode, inventory, sales);
  }

  Future<void> saveSalesAndInventory(
    String countryCode,
    List<InventoryItem> inventory,
    List<Sale> sales,
  ) {
    final activeInventory = inventory.where((item) => item.quantity > 0);
    return _box.putAll({
      '$_inventoryPrefix$countryCode': jsonEncode(
        activeInventory.map(_inventoryItemToJson).toList(),
      ),
      '$_salesPrefix$countryCode': jsonEncode(sales.map(_saleToJson).toList()),
    });
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

  static Map<String, dynamic> _inventoryItemToJson(InventoryItem item) {
    return {
      'product': _productToJson(item.product),
      'quantity': item.quantity,
    };
  }

  static InventoryItem _inventoryItemFromJson(Map<String, dynamic> json) {
    return InventoryItem(
      product: _productFromJson(json['product'] as Map<String, dynamic>),
      quantity: (json['quantity'] as num).toInt(),
    );
  }

  static Map<String, dynamic> _saleToJson(Sale sale) {
    return {
      'id': sale.id,
      'number': sale.number,
      'countryCode': sale.countryCode,
      'customerName': sale.customerName,
      'soldAt': sale.soldAt.toIso8601String(),
      'status': sale.status.name,
      'receivedAmount': sale.receivedAmount,
      'sourceSimulationId': sale.sourceSimulationId,
      'items': sale.items.map(_saleItemToJson).toList(),
    };
  }

  static Sale _saleFromJson(Map<String, dynamic> json) {
    return Sale(
      id: json['id'] as String,
      number: (json['number'] as num?)?.toInt() ?? 0,
      countryCode: json['countryCode'] as String,
      customerName: json['customerName'] as String? ?? 'Cliente',
      soldAt: DateTime.parse(json['soldAt'] as String),
      status: SaleStatus.values.firstWhere(
        (status) => status.name == json['status'],
        orElse: () => SaleStatus.completed,
      ),
      receivedAmount: (json['receivedAmount'] as num?)?.toDouble(),
      sourceSimulationId: json['sourceSimulationId'] as String?,
      items: (json['items'] as List<dynamic>)
          .map((value) => _saleItemFromJson(value as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _saleItemToJson(SaleItem item) {
    return {
      'productId': item.productId,
      'productName': item.productName,
      'productCode': item.productCode,
      'imageUrl': item.imageUrl,
      'quantity': item.quantity,
      'suggestedUnitPrice': item.suggestedUnitPrice,
      'costUnitPrice': item.costUnitPrice,
      'pointsPerUnit': item.pointsPerUnit,
      'discountPercent': item.discountPercent,
      'isGift': item.isGift,
    };
  }

  static SaleItem _saleItemFromJson(Map<String, dynamic> json) {
    return SaleItem(
      productId: json['productId'] as String,
      productName: json['productName'] as String,
      productCode: json['productCode'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      quantity: (json['quantity'] as num).toInt(),
      suggestedUnitPrice: (json['suggestedUnitPrice'] as num).toDouble(),
      costUnitPrice: (json['costUnitPrice'] as num).toDouble(),
      pointsPerUnit: (json['pointsPerUnit'] as num).toInt(),
      discountPercent: (json['discountPercent'] as num).toInt(),
      isGift: json['isGift'] as bool? ?? false,
    );
  }
}

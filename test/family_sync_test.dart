// ── NUEVO: pruebas de la sincronización familiar (lógica local) ─────────
// Propósito: verificar la unión de ventas remotas, el editor que respeta
//            ventas de otro celular y la conversión de movimientos.
// Depende de: AppState, OperationalDatabase.remoteMovementRow.
// No modifica: pruebas existentes. Firebase no se usa en estas pruebas.
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/data/datasources/operational_database.dart';
import 'package:mi_lista_plus/domain/entities/country.dart';
import 'package:mi_lista_plus/domain/entities/inventory_item.dart';
import 'package:mi_lista_plus/domain/entities/inventory_movement.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';
import 'package:mi_lista_plus/domain/entities/simulation.dart';
import 'package:mi_lista_plus/domain/repositories/product_repository.dart';
import 'package:mi_lista_plus/presentation/state/app_state.dart';

void main() {
  group('mergeRemoteSales', () {
    Sale sale(String id, int day, {String name = 'Ana'}) => Sale(
          id: id,
          number: day,
          countryCode: 'COL',
          customerName: name,
          soldAt: DateTime(2026, 9, day),
          items: const [],
        );

    test('agrega ventas nuevas y ordena de la más reciente a la más antigua', () {
      final merged = AppState.mergeRemoteSales(
        local: [sale('a', 1)],
        remote: [sale('b', 3), sale('c', 2)],
      );
      expect(merged.map((item) => item.id), ['b', 'c', 'a']);
    });

    test('la versión remota reemplaza a la local', () {
      final merged = AppState.mergeRemoteSales(
        local: [sale('a', 1, name: 'Vieja')],
        remote: [sale('a', 1, name: 'Nueva')],
      );
      expect(merged.single.customerName, 'Nueva');
    });

    test('no pisa una venta con cambios locales pendientes de subir', () {
      final merged = AppState.mergeRemoteSales(
        local: [sale('a', 1, name: 'Local')],
        remote: [sale('a', 1, name: 'Remota')],
        deletedIds: const {'a'},
        pendingIds: const {'a'},
      );
      expect(merged.single.customerName, 'Local');
    });

    test('elimina las ventas borradas en otro celular', () {
      final merged = AppState.mergeRemoteSales(
        local: [sale('a', 1), sale('b', 2)],
        remote: const [],
        deletedIds: const {'a'},
      );
      expect(merged.map((item) => item.id), ['b']);
    });
  });

  group('editor de inventario con sincronización', () {
    final first = _product('one');
    final second = _product('two');

    test('sin cambios remotos guarda exactamente lo editado', () async {
      final repository = _Repository(
        products: [first, second],
        inventory: [
          InventoryItem(product: first, quantity: 5),
          InventoryItem(product: second, quantity: 3),
        ],
      );
      final state = AppState(repository);
      await state.bootstrap();

      await state.saveInventoryChanges(
        original: {first.id: 5, second.id: 3},
        edited: {first.id: 8, second.id: 3},
      );

      expect(_stock(repository), {first.id: 8, second.id: 3});
    });

    test('respeta una venta hecha en otro celular mientras estaba abierto', () async {
      final repository = _Repository(
        products: [first, second],
        inventory: [
          InventoryItem(product: first, quantity: 5),
          InventoryItem(product: second, quantity: 3),
        ],
      );
      final state = AppState(repository);
      await state.bootstrap();
      final original = {first.id: 5, second.id: 3};

      // Mientras el editor está abierto se vende 1 de cada producto.
      await state.registerSale(
        customerName: 'Esposa',
        discountPercent: 40,
        quantities: {first.id: 1, second.id: 1},
      );

      // El usuario repone +3 del primero y no toca el segundo.
      await state.saveInventoryChanges(
        original: original,
        edited: {first.id: 8, second.id: 3},
      );

      expect(_stock(repository), {first.id: 7, second.id: 2});
    });

    test('nunca deja cantidades negativas', () async {
      final repository = _Repository(
        products: [first],
        inventory: [InventoryItem(product: first, quantity: 1)],
      );
      final state = AppState(repository);
      await state.bootstrap();
      await state.registerSale(
        customerName: 'Ana',
        discountPercent: 40,
        quantities: {first.id: 1},
      );

      await state.saveInventoryChanges(
        original: {first.id: 5},
        edited: {first.id: 2},
      );

      expect(_stock(repository), isEmpty);
    });
  });

  test('remoteMovementRow conserva solo las columnas de la tabla', () {
    final row = OperationalDatabase.remoteMovementRow({
      'id': 'm1',
      'product_id': 'p1',
      'country_code': 'COL',
      'type': 'sale',
      'quantity_delta': -2.0,
      'occurred_at': '2026-10-02T10:00:00.000',
      'device_id': 'd1',
      'related_id': 's1',
      'reason': 'Venta #1',
      'reverses_movement_id': null,
      'serverUpdatedAt': 'ignorado',
      'synced_at': 'ignorado',
    });
    expect(row.keys, isNot(contains('serverUpdatedAt')));
    expect(row.keys, isNot(contains('synced_at')));
    expect(row['quantity_delta'], -2);
    expect(row['quantity_delta'], isA<int>());
  });
}

Map<String, int> _stock(_Repository repository) => {
      for (final item in repository.inventory) item.product.id: item.quantity,
    };

Product _product(String id) => Product(
      id: id,
      countryCode: 'COL',
      name: 'Producto $id',
      code: id,
      category: ProductCategory.nutrition,
      suggestedPrice: 100,
      points: 10,
      imageUrl: '',
      updatedAt: DateTime(2026, 1, 1),
      discountPrices: const {25: 75, 30: 70, 35: 65, 40: 60},
    );

class _Repository implements ProductRepository {
  _Repository({required this.products, this.inventory = const []});

  final List<Product> products;
  List<InventoryItem> inventory;
  List<Sale> sales = [];

  @override
  Future<List<Country>> getCountries() async => const [
        Country(
          code: 'COL',
          name: 'Colombia',
          currencyCode: 'COP',
          flagEmoji: '',
          locale: 'es_CO',
        ),
      ];

  @override
  Future<String?> getSelectedCountry() async => 'COL';

  @override
  Future<List<Product>> loadProducts(String countryCode) async => List.of(products);

  @override
  Future<List<InventoryItem>> loadInventory(String countryCode) async =>
      List.of(inventory);

  @override
  Future<List<Sale>> loadSales(String countryCode) async => List.of(sales);

  @override
  Future<List<Simulation>> loadSimulations(String countryCode) async => const [];

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
    this.inventory = List.of(inventory);
    this.sales = List.of(sales);
  }

  @override
  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory, {
    InventoryMovementType movementType = InventoryMovementType.manualAdjustment,
    String? relatedId,
    String? reason,
  }) async {
    this.inventory = List.of(inventory);
  }

  @override
  Future<void> registerSale(
    String countryCode,
    List<InventoryItem> inventory,
    Sale sale,
  ) async {}

  @override
  Future<void> saveSelectedCountry(String countryCode) async {}

  @override
  Future<void> saveSimulation(Simulation simulation) async {}

  @override
  Future<void> deleteSimulation(String countryCode, String simulationId) async {}

  @override
  Future<void> deleteSimulations(String countryCode, Set<String> simulationIds) async {}

  @override
  Future<void> syncProductsIfNeeded(String countryCode) async {}
}

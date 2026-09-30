// ── NUEVO: pruebas de estabilidad de AppState ───────────────────────────
// Propósito: cubrir la cola de escrituras, la recarga del catálogo sin perder
//            el carrito, el stock de productos retirados y la carga infinita.
// Depende de: AppState y la interfaz ProductRepository.
// No modifica: las pruebas existentes de app_state_inventory_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/country.dart';
import 'package:mi_lista_plus/domain/entities/inventory_item.dart';
import 'package:mi_lista_plus/domain/entities/inventory_movement.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';
import 'package:mi_lista_plus/domain/entities/simulation.dart';
import 'package:mi_lista_plus/domain/repositories/product_repository.dart';
import 'package:mi_lista_plus/presentation/state/app_state.dart';

void main() {
  final first = _product('one', 'Producto uno', 100);
  final second = _product('two', 'Producto dos', 80);

  test('dos ventas simultáneas se guardan ambas y con números distintos',
      () async {
    final repository = _SlowRepository(
      products: [first],
      inventory: [InventoryItem(product: first, quantity: 5)],
    );
    final state = AppState(repository);
    await state.bootstrap();

    final results = await Future.wait([
      state.registerSale(
        customerName: 'Ana',
        discountPercent: 40,
        quantities: {first.id: 1},
      ),
      state.registerSale(
        customerName: 'Luis',
        discountPercent: 40,
        quantities: {first.id: 2},
      ),
    ]);

    expect(results.map((sale) => sale.number).toSet(), {1, 2});
    expect(repository.sales, hasLength(2));
    expect(repository.inventory.single.quantity, 2);
    expect(state.inventory.single.quantity, 2);
  });

  test('un error en una venta no bloquea la cola de escrituras', () async {
    final repository = _SlowRepository(
      products: [first],
      inventory: [InventoryItem(product: first, quantity: 1)],
    );
    final state = AppState(repository);
    await state.bootstrap();

    await expectLater(
      state.registerSale(
        customerName: 'Ana',
        discountPercent: 40,
        quantities: {first.id: 5},
      ),
      throwsA(isA<StateError>()),
    );
    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {first.id: 1},
    );
    expect(sale.number, 1);
  });

  test('refreshCatalog actualiza productos y conserva el carrito', () async {
    final repository = _SlowRepository(products: [first]);
    final state = AppState(repository);
    await state.bootstrap();
    state.addProduct(first, quantity: 2);
    state.setDiscount(35);

    repository.products = [first, second];
    await state.refreshCatalog(state.selectedCountry!);

    expect(state.products, hasLength(2));
    expect(state.quantityOf(first), 2);
    expect(state.selectedDiscount, 35);
  });

  test('refreshCatalog no hace nada si el país seleccionado cambió', () async {
    final repository = _SlowRepository(products: [first]);
    final state = AppState(repository);
    await state.bootstrap();

    repository.products = [first, second];
    await state.refreshCatalog(
      const Country(
        code: 'ESP',
        name: 'España',
        currencyCode: 'EUR',
        flagEmoji: '',
        locale: 'es_ES',
      ),
    );

    expect(state.products, hasLength(1));
  });

  test('guardar inventario conserva el stock de productos retirados',
      () async {
    final retired = _product('retired', 'Retirado', 50);
    final repository = _SlowRepository(
      products: [first],
      inventory: [InventoryItem(product: retired, quantity: 4)],
    );
    final state = AppState(repository);
    await state.bootstrap();

    await state.saveInventoryQuantities({first.id: 3});

    final byId = {
      for (final item in repository.inventory) item.product.id: item.quantity,
    };
    expect(byId, {first.id: 3, retired.id: 4});
  });

  test('un fallo al leer datos locales no deja la carga infinita', () async {
    final repository = _SlowRepository(products: [first])..failSales = true;
    final state = AppState(repository);

    await expectLater(state.bootstrap(), throwsA(isA<FormatException>()));

    expect(state.isLoading, isFalse);
    expect(state.errorMessage, isNotNull);
  });
}

Product _product(String id, String name, double price) {
  return Product(
    id: id,
    countryCode: 'COL',
    name: name,
    code: id,
    category: ProductCategory.nutrition,
    suggestedPrice: price,
    points: 10,
    imageUrl: '',
    updatedAt: DateTime(2026, 1, 1),
    discountPrices: {25: price * .75, 30: price * .7, 35: price * .65, 40: price * .6},
  );
}

/// Repositorio que tarda en guardar, para que dos operaciones se solapen.
class _SlowRepository implements ProductRepository {
  _SlowRepository({required this.products, this.inventory = const []});

  List<Product> products;
  List<InventoryItem> inventory;
  List<Sale> sales = [];
  bool failSales = false;

  Future<void> _delay() => Future<void>.delayed(const Duration(milliseconds: 5));

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
  Future<List<Product>> loadProducts(String countryCode) async =>
      List.of(products);

  @override
  Future<List<InventoryItem>> loadInventory(String countryCode) async =>
      List.of(inventory);

  @override
  Future<List<Sale>> loadSales(String countryCode) async {
    if (failSales) throw const FormatException('JSON dañado');
    return List.of(sales);
  }

  @override
  Future<List<Simulation>> loadSimulations(String countryCode) async =>
      const [];

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
    await _delay();
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
    await _delay();
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
  Future<void> deleteSimulations(
    String countryCode,
    Set<String> simulationIds,
  ) async {}

  @override
  Future<void> syncProductsIfNeeded(String countryCode) async {}
}

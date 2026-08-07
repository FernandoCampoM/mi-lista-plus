import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/cart_item.dart';
import 'package:mi_lista_plus/domain/entities/country.dart';
import 'package:mi_lista_plus/domain/entities/inventory_item.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';
import 'package:mi_lista_plus/domain/entities/simulation.dart';
import 'package:mi_lista_plus/domain/repositories/product_repository.dart';
import 'package:mi_lista_plus/presentation/state/app_state.dart';

void main() {
  final firstProduct = _product('one', 'Producto uno', 100, 20);
  final secondProduct = _product('two', 'Producto dos', 80, 10);

  test('registrar venta descuenta inventario y conserva valores historicos', () async {
    final repository = _FakeRepository(
      products: [firstProduct, secondProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 3)],
    );
    final state = AppState(repository);
    await state.bootstrap();

    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 2},
    );

    expect(state.inventory.single.quantity, 1);
    expect(sale.items.single.suggestedUnitPrice, 100);
    expect(sale.items.single.costUnitPrice, 60);
    expect(sale.items.single.pointsPerUnit, 20);
    expect(sale.totalSale, 200);
    expect(sale.totalProfit, 80);
  });

  test('no permite vender mas unidades que las disponibles', () async {
    final repository = _FakeRepository(
      products: [firstProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 2)],
    );
    final state = AppState(repository);
    await state.bootstrap();

    await expectLater(
      state.registerSale(
        customerName: 'Ana',
        discountPercent: 40,
        quantities: {firstProduct.id: 3},
      ),
      throwsA(isA<StateError>()),
    );
    expect(state.inventory.single.quantity, 2);
  });

  test('editar una simulacion conserva el id al agregar productos', () async {
    final original = Simulation(
      id: 'simulation-id',
      countryCode: 'COL',
      customerName: 'Cliente',
      discountPercent: 40,
      createdAt: DateTime(2026, 8, 1),
      items: [CartItem(product: firstProduct, quantity: 1)],
    );
    final repository = _FakeRepository(
      products: [firstProduct, secondProduct],
      simulations: [original],
    );
    final state = AppState(repository);
    await state.bootstrap();

    state.loadSimulationIntoCart(original);
    state.addProduct(secondProduct);
    final updated = await state.createSimulation(customerName: 'Editada');

    expect(updated.id, original.id);
    expect(updated.items, hasLength(2));
    expect(repository.simulations, hasLength(1));
    expect(repository.simulations.single.customerName, 'Editada');
  });

  test('editar una venta devuelve la diferencia al inventario', () async {
    final repository = _FakeRepository(
      products: [firstProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 5)],
    );
    final state = AppState(repository);
    await state.bootstrap();
    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 3},
    );

    await state.updateSale(
      originalSale: sale,
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 2},
    );

    expect(state.inventory.single.quantity, 3);
    expect(state.sales.single.items.single.quantity, 2);
  });

  test('cancelar una venta restaura stock y conserva trazabilidad', () async {
    final repository = _FakeRepository(
      products: [firstProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 4)],
    );
    final state = AppState(repository);
    await state.bootstrap();
    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 2},
    );

    final cancelled = await state.cancelSale(sale);

    expect(state.inventory.single.quantity, 4);
    expect(cancelled.status, SaleStatus.cancelled);
    expect(state.sales, hasLength(1));
  });

  test('editar no permite superar inventario restaurado', () async {
    final repository = _FakeRepository(
      products: [firstProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 3)],
    );
    final state = AppState(repository);
    await state.bootstrap();
    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 2},
    );

    await expectLater(
      state.updateSale(
        originalSale: sale,
        customerName: 'Ana',
        discountPercent: 40,
        quantities: {firstProduct.id: 4},
      ),
      throwsA(isA<StateError>()),
    );
    expect(state.inventory.single.quantity, 1);
    expect(state.sales.single.items.single.quantity, 2);
  });

  test('eliminar venta cancelada no devuelve inventario dos veces', () async {
    final repository = _FakeRepository(
      products: [firstProduct],
      inventory: [InventoryItem(product: firstProduct, quantity: 3)],
    );
    final state = AppState(repository);
    await state.bootstrap();
    final sale = await state.registerSale(
      customerName: 'Ana',
      discountPercent: 40,
      quantities: {firstProduct.id: 1},
    );
    final cancelled = await state.cancelSale(sale);

    await state.deleteSale(cancelled);

    expect(state.inventory.single.quantity, 3);
    expect(state.sales, isEmpty);
  });
}

Product _product(
  String id,
  String name,
  double suggestedPrice,
  int points,
) {
  return Product(
    id: id,
    countryCode: 'COL',
    name: name,
    code: id,
    category: ProductCategory.nutrition,
    suggestedPrice: suggestedPrice,
    points: points,
    imageUrl: '',
    updatedAt: DateTime(2026),
    discountPrices: {40: suggestedPrice * .6},
  );
}

class _FakeRepository implements ProductRepository {
  _FakeRepository({
    required this.products,
    this.inventory = const [],
    this.simulations = const [],
  });

  final List<Product> products;
  List<InventoryItem> inventory;
  List<Simulation> simulations;
  List<Sale> sales = [];

  @override
  Future<void> deleteSimulation(String countryCode, String simulationId) async {
    simulations = simulations.where((item) => item.id != simulationId).toList();
  }

  @override
  Future<void> deleteSimulations(
    String countryCode,
    Set<String> simulationIds,
  ) async {
    simulations = simulations
        .where((item) => !simulationIds.contains(item.id))
        .toList();
  }

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
  Future<List<InventoryItem>> loadInventory(String countryCode) async {
    return List.of(inventory);
  }

  @override
  Future<List<Product>> loadProducts(String countryCode) async {
    return List.of(products);
  }

  @override
  Future<List<Sale>> loadSales(String countryCode) async => List.of(sales);

  @override
  Future<List<Simulation>> loadSimulations(String countryCode) async {
    return List.of(simulations);
  }

  @override
  Future<void> registerSale(
    String countryCode,
    List<InventoryItem> inventory,
    Sale sale,
  ) async {
    this.inventory = List.of(inventory);
    sales = [sale, ...sales];
  }

  @override
  Future<void> saveSalesAndInventory(
    String countryCode,
    List<InventoryItem> inventory,
    List<Sale> sales,
  ) async {
    this.inventory = List.of(inventory);
    this.sales = List.of(sales);
  }

  @override
  Future<void> saveInventory(
    String countryCode,
    List<InventoryItem> inventory,
  ) async {
    this.inventory = List.of(inventory);
  }

  @override
  Future<void> saveSelectedCountry(String countryCode) async {}

  @override
  Future<void> saveSimulation(Simulation simulation) async {
    simulations = [
      simulation,
      ...simulations.where((item) => item.id != simulation.id),
    ];
  }

  @override
  Future<void> syncProductsIfNeeded(String countryCode) async {}
}

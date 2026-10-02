// ── NUEVO: pruebas de payloads de LocalStore ────────────────────────────
// Propósito: garantizar que los payloads generados para SQLite son idénticos
//            a lo que Hive guardaba, y que un producto dañado no rompe el
//            catálogo completo.
// Depende de: LocalStore, Hive y SharedPreferences en memoria.
// No modifica: el formato persistido existente.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mi_lista_plus/data/datasources/local_store.dart';
import 'package:mi_lista_plus/domain/entities/inventory_item.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late Box<String> box;
  late LocalStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('mlp_store_test');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('test_${DateTime.now().microsecondsSinceEpoch}');
    SharedPreferences.setMockInitialValues({});
    store = LocalStore(await SharedPreferences.getInstance(), box);
  });

  tearDown(() async {
    await box.deleteFromDisk();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  final product = Product(
    id: 'p1',
    countryCode: 'COL',
    name: 'Producto',
    code: 'P1',
    category: ProductCategory.beauty,
    suggestedPrice: 100,
    points: 5,
    imageUrl: '',
    updatedAt: DateTime(2026, 1, 1),
    discountPrices: const {40: 60},
  );
  final sale = Sale(
    id: 's1',
    number: 1,
    countryCode: 'COL',
    customerName: 'Ana',
    soldAt: DateTime(2026, 2, 1),
    items: const [
      SaleItem(
        productId: 'p1',
        productName: 'Producto',
        productCode: 'P1',
        imageUrl: '',
        quantity: 1,
        suggestedUnitPrice: 100,
        costUnitPrice: 60,
        pointsPerUnit: 5,
        discountPercent: 40,
        isGift: false,
      ),
    ],
  );

  test('los payloads generados coinciden con lo que Hive guarda', () async {
    final inventory = [
      InventoryItem(product: product, quantity: 2),
      InventoryItem(product: product, quantity: 0),
    ];
    await store.saveSalesAndInventory('COL', inventory, [sale]);

    expect(
      store.encodeSalesPayload([sale]),
      store.rawOperationalValue('sales', 'COL'),
    );
    expect(
      store.encodeInventoryPayload(inventory),
      store.rawOperationalValue('inventory', 'COL'),
    );
  });

  test('saveRawOperationalValues escribe solo los módulos indicados', () async {
    await store.saveSalesAndInventory(
      'COL',
      [InventoryItem(product: product, quantity: 2)],
      [sale],
    );
    final previousSales = store.rawOperationalValue('sales', 'COL');

    await store.saveRawOperationalValues('COL', inventoryPayload: '[]');

    expect(store.loadInventory('COL'), isEmpty);
    expect(store.rawOperationalValue('sales', 'COL'), previousSales);
  });

  test('un producto dañado se omite sin perder el resto del catálogo',
      () async {
    await store.saveProducts('COL', [product]);
    final raw = jsonDecode(box.get('products_COL')!) as List<dynamic>;
    await box.put(
      'products_COL',
      jsonEncode([...raw, {'id': 'roto'}]),
    );

    final loaded = store.loadProducts('COL');

    expect(loaded.map((item) => item.id), ['p1']);
  });
}

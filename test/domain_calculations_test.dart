import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/inventory_item.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';

void main() {
  final product = Product(
    id: 'product-1',
    countryCode: 'COL',
    name: 'Producto de prueba',
    code: 'P1',
    category: ProductCategory.nutrition,
    suggestedPrice: 100,
    points: 20,
    imageUrl: '',
    updatedAt: DateTime(2026),
    discountPrices: const {40: 60},
  );

  test('calcula el costo por punto usando el precio con 40 por ciento', () {
    expect(product.costPerPointAt40, 3);
    expect(
      Product(
        id: 'zero',
        countryCode: 'COL',
        name: 'Sin puntos',
        code: 'Z',
        category: ProductCategory.kit,
        suggestedPrice: 50,
        points: 0,
        imageUrl: '',
        updatedAt: DateTime(2026),
      ).costPerPointAt40,
      isNull,
    );
  });

  test('calcula valores del inventario', () {
    final item = InventoryItem(product: product, quantity: 3);
    expect(item.suggestedValue, 300);
    expect(item.discountedValue40, 180);
    expect(item.profit40, 120);
  });

  test('un obsequio registra costo y ganancia negativa', () {
    const item = SaleItem(
      productId: 'product-1',
      productName: 'Producto de prueba',
      quantity: 2,
      suggestedUnitPrice: 100,
      costUnitPrice: 60,
      pointsPerUnit: 20,
      discountPercent: 40,
      isGift: true,
    );
    expect(item.totalSale, 0);
    expect(item.totalCost, 120);
    expect(item.totalProfit, -120);
    expect(item.totalPoints, 40);
  });

  test('venta conserva resumen financiero historico', () {
    final sale = Sale(
      id: 'sale-1',
      number: 1,
      countryCode: 'COL',
      customerName: 'Cliente',
      soldAt: DateTime(2026, 8, 7),
      items: const [
        SaleItem(
          productId: 'product-1',
          productName: 'Producto de prueba',
          quantity: 2,
          suggestedUnitPrice: 100,
          costUnitPrice: 60,
          pointsPerUnit: 20,
          discountPercent: 40,
          isGift: false,
        ),
      ],
    );

    expect(sale.totalSuggested, 200);
    expect(sale.discountAmount, 80);
    expect(sale.totalCost, 120);
    expect(sale.totalProfit, 80);
    expect(sale.totalPoints, 40);
  });

  test('ganancia usa el dinero realmente recibido', () {
    final sale = Sale(
      id: 'sale-2',
      countryCode: 'COL',
      customerName: 'Cliente',
      soldAt: DateTime(2026, 8, 7),
      receivedAmount: 190,
      items: const [
        SaleItem(
          productId: 'product-1',
          productName: 'Producto de prueba',
          quantity: 2,
          suggestedUnitPrice: 100,
          costUnitPrice: 60,
          pointsPerUnit: 20,
          discountPercent: 40,
          isGift: false,
        ),
      ],
    );

    expect(sale.totalSale, 200);
    expect(sale.effectiveReceivedAmount, 190);
    expect(sale.receivedAdjustment, -10);
    expect(sale.totalProfit, 70);
  });
}

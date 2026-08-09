import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/customer.dart';
import 'package:mi_lista_plus/domain/entities/follow_up.dart';
import 'package:mi_lista_plus/domain/entities/sale.dart';
import 'package:mi_lista_plus/domain/entities/product.dart';
import 'package:mi_lista_plus/core/services/encrypted_backup_service.dart';

void main() {
  test('normaliza indicativo y telefono sin guardar formato visual', () {
    final customer = Customer(
      id: 'c1', name: 'Ana', callingCode: '+57', phoneNumber: '300 123-4567',
      consentAt: DateTime(2026), consentScopes: const {ConsentScope.phone},
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );
    expect(customer.normalizedPhone, '+573001234567');
    expect(customer.hasActiveConsent, isTrue);
  });

  test('revocar consentimiento lo deja inactivo sin borrar identidad', () {
    final customer = Customer(
      id: 'c1', name: 'Ana', callingCode: '57', phoneNumber: '3001234567',
      consentAt: DateTime(2026), consentScopes: const {ConsentScope.phone},
      createdAt: DateTime(2026), updatedAt: DateTime(2026),
    );
    final revoked = customer.copyWith(consentRevokedAt: DateTime(2026, 2));
    expect(revoked.hasActiveConsent, isFalse);
    expect(revoked.name, 'Ana');
  });

  test('entrega y estado comercial son independientes', () {
    final sale = Sale(
      id: 's1', countryCode: 'COL', customerName: 'Ana',
      soldAt: DateTime(2026), items: const [],
      deliveryStatus: DeliveryStatus.pending,
    );
    final delivered = sale.copyWith(
      deliveryStatus: DeliveryStatus.delivered,
      deliveredAt: DateTime(2026, 1, 2),
    );
    expect(delivered.isCompleted, isTrue);
    expect(delivered.isDelivered, isTrue);
  });

  test('un seguimiento pausado no se considera vencido', () {
    final item = FollowUp(
      id: 'f1', customerId: 'c1', type: FollowUpType.dayOne,
      status: FollowUpStatus.paused,
      dueAt: DateTime(2020), createdAt: DateTime(2020),
    );
    expect(item.isOverdue, isFalse);
  });

  test('la categoria historica de una venta se conserva al copiar', () {
    const item = SaleItem(
      productId: 'beauty',
      productName: 'Producto belleza',
      quantity: 2,
      suggestedUnitPrice: 100,
      costUnitPrice: 60,
      pointsPerUnit: 20,
      discountPercent: 40,
      isGift: false,
      category: ProductCategory.beauty,
    );
    expect(item.copyWith().category, ProductCategory.beauty);
    expect(item.totalPoints, 40);
  });

  test('el codigo de seis digitos genera una clave interna valida', () {
    expect(
      EncryptedBackupService.transferPassword('123456'),
      'MLP-SYNC-123456',
    );
    expect(
      () => EncryptedBackupService.transferPassword('12345'),
      throwsArgumentError,
    );
  });
}

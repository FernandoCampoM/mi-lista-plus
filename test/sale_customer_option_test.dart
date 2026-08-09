import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/domain/entities/customer.dart';
import 'package:mi_lista_plus/presentation/models/sale_customer_option.dart';

void main() {
  test('edición conserva una sola opción para cliente sin consentimiento', () {
    final active = _customer('active', 'Activa');
    final revoked = _customer(
      'revoked',
      'Revocada',
      revokedAt: DateTime(2026, 2),
    );

    final options = buildSaleCustomerOptions(
      customers: [active, revoked],
      selectedCustomerId: revoked.id,
      preserveHistoricalCustomer: true,
      historicalCustomerName: revoked.name,
    );

    expect(options.where((item) => item.id == revoked.id), hasLength(1));
    expect(options.first.id, revoked.id);
    expect(options.first.statusLabel, 'Sin consentimiento');
    expect(options.first.isEligible, isFalse);
  });

  test('venta nueva excluye clientes revocados y archivados', () {
    final active = _customer('active', 'Activa');
    final revoked = _customer(
      'revoked',
      'Revocada',
      revokedAt: DateTime(2026, 2),
    );
    final archived = _customer(
      'archived',
      'Archivada',
      archivedAt: DateTime(2026, 3),
    );

    final options = buildSaleCustomerOptions(
      customers: [active, revoked, archived],
      selectedCustomerId: null,
      preserveHistoricalCustomer: false,
      historicalCustomerName: '',
    );

    expect(options.map((item) => item.id).toList(), [active.id]);
  });

  test('edición crea opción histórica si el cliente ya no existe', () {
    final options = buildSaleCustomerOptions(
      customers: const [],
      selectedCustomerId: 'missing',
      preserveHistoricalCustomer: true,
      historicalCustomerName: 'Cliente anterior',
    );

    expect(options, hasLength(1));
    expect(options.single.name, 'Cliente anterior');
    expect(options.single.statusLabel, 'Cliente no disponible localmente');
  });
}

Customer _customer(
  String id,
  String name, {
  DateTime? revokedAt,
  DateTime? archivedAt,
}) {
  return Customer(
    id: id,
    name: name,
    callingCode: '57',
    phoneNumber: '3001234567',
    consentAt: DateTime(2026),
    consentScopes: const {ConsentScope.phone},
    consentRevokedAt: revokedAt,
    archivedAt: archivedAt,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

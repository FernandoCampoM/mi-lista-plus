import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/core/services/app_ad_service.dart';

void main() {
  test('declara todas las ubicaciones de banner configurables', () {
    expect(
      BannerPlacement.values.map((placement) => placement.name),
      containsAll(<String>{
        'home',
        'simulations',
        'inventory',
        'sales',
        'customers',
        'followups',
        'deliveries',
        'backup',
        'settings',
      }),
    );
  });

  test('declara las operaciones de negocio como acciones importantes', () {
    expect(
      ImportantAdAction.values.map((action) => action.name),
      containsAll(<String>{
        'backupOpened',
        'backupCreated',
        'backupShared',
        'backupImported',
        'saleRegistered',
        'saleUpdated',
        'saleCancelled',
        'saleDeleted',
        'customerCreated',
        'followUpCompleted',
        'deliveryConfirmed',
        'inventoryUpdated',
      }),
    );
  });
}

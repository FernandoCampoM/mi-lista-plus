import 'package:flutter_test/flutter_test.dart';
import 'package:mi_lista_plus/data/datasources/legacy_migration_validator.dart';

void main() {
  test('acepta una base Hive vacia', () {
    final result = LegacyMigrationValidator.validate({
      'inventory_COL': null,
      'sales_COL': '[]',
    });
    expect(result.recordsByModule['inventory_COL'], 0);
    expect(result.recordsByModule['sales_COL'], 0);
  });

  test('cuenta una base normal antes de migrarla', () {
    final result = LegacyMigrationValidator.validate({
      'inventory_COL': '[{"product":{},"quantity":2}]',
      'sales_COL': '[{"id":"s1"},{"id":"s2"}]',
    });
    expect(result.recordsByModule['inventory_COL'], 1);
    expect(result.recordsByModule['sales_COL'], 2);
  });

  test('rechaza una base parcialmente dañada sin activar SQLite', () {
    expect(
      () => LegacyMigrationValidator.validate({
        'inventory_COL': '[{"quantity":2}]',
        'sales_COL': '{"id":"no-es-lista"}',
      }),
      throwsFormatException,
    );
  });
}

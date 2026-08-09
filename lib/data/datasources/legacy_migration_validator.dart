import 'dart:convert';

class LegacyMigrationSummary {
  const LegacyMigrationSummary({required this.recordsByModule});
  final Map<String, int> recordsByModule;
}

abstract final class LegacyMigrationValidator {
  static LegacyMigrationSummary validate(Map<String, String?> payloads) {
    final counts = <String, int>{};
    for (final entry in payloads.entries) {
      final raw = entry.value;
      if (raw == null || raw.trim().isEmpty) {
        counts[entry.key] = 0;
        continue;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw FormatException('${entry.key} no contiene una lista valida.');
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          throw FormatException('${entry.key} contiene un registro dañado.');
        }
      }
      counts[entry.key] = decoded.length;
    }
    return LegacyMigrationSummary(recordsByModule: counts);
  }
}

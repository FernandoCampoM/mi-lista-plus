import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/country.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/follow_up.dart';
import '../../domain/entities/follow_up_note.dart';
import '../../domain/entities/inventory_item.dart';
import '../../domain/entities/inventory_movement.dart';
import '../../domain/entities/product.dart';
import 'local_store.dart';
import 'legacy_migration_validator.dart';

class OperationalDatabase {
  OperationalDatabase._(this._database, this.deviceId);

  final Database _database;
  final String deviceId;
  static const _uuid = Uuid();

  static Future<OperationalDatabase> open(LocalStore hive) async {
    final root = await getApplicationSupportDirectory();
    final database = await openDatabase(
      p.join(root.path, 'mi_lista_plus_operational.sqlite'),
      version: 3,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        try {
          await db.rawQuery('PRAGMA journal_mode = WAL');
        } catch (_) {
          // WAL es una optimizacion; la base sigue siendo valida sin este modo.
        }
      },
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE metadata(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
        await db.execute('CREATE TABLE snapshots(module TEXT NOT NULL, country_code TEXT NOT NULL, payload TEXT NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(module, country_code))');
        await db.execute('CREATE TABLE inventory_movements(id TEXT PRIMARY KEY, product_id TEXT NOT NULL, country_code TEXT NOT NULL, type TEXT NOT NULL, quantity_delta INTEGER NOT NULL, occurred_at TEXT NOT NULL, device_id TEXT NOT NULL, related_id TEXT, reason TEXT, synced_at TEXT, reverses_movement_id TEXT)');
        await db.execute('CREATE INDEX inventory_product_idx ON inventory_movements(country_code, product_id)');
        await db.execute('CREATE TABLE customers(id TEXT PRIMARY KEY, payload TEXT NOT NULL, normalized_phone TEXT NOT NULL, archived_at TEXT, updated_at TEXT NOT NULL)');
        await db.execute('CREATE INDEX customer_phone_idx ON customers(normalized_phone)');
        await db.execute('CREATE TABLE follow_ups(id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, sale_id TEXT, due_at TEXT NOT NULL, status TEXT NOT NULL, payload TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id))');
        await db.execute('CREATE INDEX follow_up_due_idx ON follow_ups(status, due_at)');
        await db.execute('CREATE TABLE product_follow_up_config(product_id TEXT NOT NULL, country_code TEXT NOT NULL, enabled INTEGER NOT NULL, duration_unit TEXT NOT NULL, duration_value INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(product_id, country_code))');
        await db.execute('CREATE TABLE sync_history(id TEXT PRIMARY KEY, direction TEXT NOT NULL, modules TEXT NOT NULL, mode TEXT NOT NULL, created_at TEXT NOT NULL, status TEXT NOT NULL, details TEXT)');
        await _createNotesTable(db);
        await _createSyncOutboxTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createNotesTable(db);
        // Versión 3: solo AGREGA la cola de sincronización familiar.
        if (oldVersion < 3) await _createSyncOutboxTable(db);
      },
    );
    var id = await _metadata(database, 'device_id');
    id ??= _uuid.v4();
    await database.insert('metadata', {'key': 'device_id', 'value': id}, conflictAlgorithm: ConflictAlgorithm.replace);
    final result = OperationalDatabase._(database, id);
    try {
      await result._migrateFromHive(hive);
      await database.delete('metadata', where: 'key = ?', whereArgs: ['hive_migration_error']);
    } catch (error, stackTrace) {
      // Una migracion heredada defectuosa no debe deshabilitar clientes ni
      // seguimientos. Inventario/ventas continuan en Hive hasta poder reintentar.
      await database.insert(
        'metadata',
        {'key': 'hive_migration_error', 'value': error.toString()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      developer.log(
        'SQLite disponible, pero la migracion desde Hive quedo pendiente.',
        name: 'mi_lista_plus.storage',
        error: error,
        stackTrace: stackTrace,
      );
    }
    await result._migrateLegacyFollowUpNotes();
    return result;
  }

  static Future<void> _createNotesTable(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS follow_up_notes(id TEXT PRIMARY KEY, customer_id TEXT NOT NULL, follow_up_id TEXT, sale_id TEXT, product_id TEXT, created_at TEXT NOT NULL, updated_at TEXT, payload TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(id))');
    await db.execute('CREATE INDEX IF NOT EXISTS note_customer_idx ON follow_up_notes(customer_id, created_at DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS note_follow_up_idx ON follow_up_notes(follow_up_id)');
  }

  // ── NUEVO: tabla de pendientes de la sincronización familiar ────────────
  // Propósito: recordar qué ventas y clientes faltan por subir a la nube.
  // Depende de: nada; es una tabla independiente.
  // No modifica: ninguna tabla existente (migración 2 → 3 solo la crea).
  static Future<void> _createSyncOutboxTable(DatabaseExecutor db) async {
    await db.execute('CREATE TABLE IF NOT EXISTS sync_outbox(entity TEXT NOT NULL, entity_id TEXT NOT NULL, country_code TEXT, queued_at TEXT NOT NULL, PRIMARY KEY(entity, entity_id))');
  }

  static Future<String?> _metadata(Database db, String key) async {
    final rows = await db.query('metadata', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<bool> get isMigrationValidated async =>
      await _metadata(_database, 'hive_migration_validated') == '1';

  Future<String?> get migrationError async =>
      _metadata(_database, 'hive_migration_error');

  // ── NUEVO: clave local para respaldos automáticos ───────────────────────
  // Propósito: cifrar el respaldo previo a una importación con una clave
  //            propia del dispositivo, no con la del archivo entrante.
  // Depende de: tabla metadata (clave local_backup_secret).
  // No modifica: ninguna clave de metadata existente.
  Future<String> localBackupSecret() async {
    final existing = await _metadata(_database, 'local_backup_secret');
    if (existing != null && existing.length >= 8) return existing;
    final secret = '${_uuid.v4()}${_uuid.v4()}';
    await _database.insert(
      'metadata',
      {'key': 'local_backup_secret', 'value': secret},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return secret;
  }

  Future<int> get reminderHour async => int.tryParse(await _metadata(_database, 'reminder_hour') ?? '') ?? 9;

  Future<int> get monthlyPointsGoal async =>
      int.tryParse(await _metadata(_database, 'monthly_points_goal') ?? '') ?? 2500;

  Future<void> setReminderHour(int hour) async {
    if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
    await _database.insert('metadata', {'key': 'reminder_hour', 'value': '$hour'}, conflictAlgorithm: ConflictAlgorithm.replace);
    await _recordChange('settings', 'config');
  }

  Future<void> setMonthlyPointsGoal(int goal) async {
    if (goal < 1) throw ArgumentError.value(goal, 'goal');
    await _database.insert(
      'metadata',
      {'key': 'monthly_points_goal', 'value': '$goal'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordChange('settings', 'config');
  }

  Future<int?> configuredDurationDays(String productId, String countryCode, ProductCategory category) async {
    final rows = await _database.query('product_follow_up_config', where: 'product_id = ? AND country_code = ?', whereArgs: [productId, countryCode], limit: 1);
    if (rows.isEmpty) {
      return switch (category) {
      ProductCategory.nutrition => 10,
      ProductCategory.beauty => 180,
      ProductCategory.kit => 10,
    };
    }
    if ((rows.first['enabled'] as num).toInt() == 0) return null;
    final value = (rows.first['duration_value'] as num).toInt();
    return rows.first['duration_unit'] == 'months' ? value * 30 : value;
  }

  Future<void> saveProductDuration({required String productId, required String countryCode, required bool enabled, required int days}) async {
    if (days < 1) throw ArgumentError('La duracion debe ser mayor que cero.');
    await _database.insert('product_follow_up_config', {
      'product_id': productId, 'country_code': countryCode,
      'enabled': enabled ? 1 : 0, 'duration_unit': 'days',
      'duration_value': days, 'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace,);
    await _recordChange('product_config', productConfigId(countryCode, productId));
  }

  Future<void> _migrateFromHive(LocalStore hive) async {
    if (await isMigrationValidated) return;
    final backup = <String, String?>{};
    for (final country in supportedCountries) {
      for (final module in const ['inventory', 'sales', 'simulations']) {
        backup['${module}_${country.code}'] = hive.rawOperationalValue(module, country.code);
      }
    }
    final root = await getApplicationSupportDirectory();
    final backupFile = File(p.join(root.path, 'hive_before_sqlite_migration.json'));
    await backupFile.writeAsString(jsonEncode(backup), flush: true);
    LegacyMigrationValidator.validate(backup);

    await _database.transaction((txn) async {
      for (final country in supportedCountries) {
        for (final module in const ['inventory', 'sales', 'simulations']) {
          final payload = hive.rawOperationalValue(module, country.code);
          if (payload != null) {
            jsonDecode(payload); // A corrupt payload aborts the whole transaction.
            await txn.insert('snapshots', {
              'module': module, 'country_code': country.code,
              'payload': payload, 'updated_at': DateTime.now().toIso8601String(),
            }, conflictAlgorithm: ConflictAlgorithm.replace,);
          }
        }
        for (final item in hive.loadInventory(country.code)) {
          await txn.insert('inventory_movements', _movementMap(
            InventoryMovement(
              id: _uuid.v4(), productId: item.product.id,
              countryCode: country.code, type: InventoryMovementType.initialBalance,
              quantityDelta: item.quantity, occurredAt: DateTime.now(),
              deviceId: deviceId, reason: 'Migracion inicial desde Hive',
            ),
          ),);
        }
        final migratedStock = await _stockWithExecutor(txn, country.code);
        final hiveStock = {for (final item in hive.loadInventory(country.code)) item.product.id: item.quantity};
        if (!_sameStock(migratedStock, hiveStock)) {
          throw StateError('La validacion del inventario ${country.code} no coincide.');
        }
        final salesPayload = hive.rawOperationalValue('sales', country.code);
        if (salesPayload != null) {
          final source = hive.loadSales(country.code);
          final migrated = hive.salesFromPayload(salesPayload);
          final sourceTotal = source.fold<double>(0, (sum, sale) => sum + sale.effectiveReceivedAmount);
          final migratedTotal = migrated.fold<double>(0, (sum, sale) => sum + sale.effectiveReceivedAmount);
          if (source.length != migrated.length || (sourceTotal - migratedTotal).abs() > .01) {
            throw StateError('La validacion de ventas ${country.code} no coincide.');
          }
        }
        final simulationsPayload = hive.rawOperationalValue('simulations', country.code);
        if (simulationsPayload != null &&
            hive.loadSimulations(country.code).length != hive.simulationsFromPayload(simulationsPayload).length) {
          throw StateError('La validacion de simulaciones ${country.code} no coincide.');
        }
      }
      await txn.insert('metadata', {'key': 'hive_migration_validated', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('metadata', {'key': 'hive_fallback_retained', 'value': '1'}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static bool _sameStock(Map<String, int> left, Map<String, int> right) {
    final cleanLeft = Map.of(left)..removeWhere((_, value) => value == 0);
    final cleanRight = Map.of(right)..removeWhere((_, value) => value == 0);
    if (cleanLeft.length != cleanRight.length) return false;
    return cleanLeft.entries.every((entry) => cleanRight[entry.key] == entry.value);
  }

  Future<String?> readSnapshot(String module, String countryCode) async {
    final rows = await _database.query('snapshots', columns: ['payload'], where: 'module = ? AND country_code = ?', whereArgs: [module, countryCode], limit: 1);
    return rows.isEmpty ? null : rows.first['payload'] as String;
  }

  Future<void> writeSnapshot(String module, String countryCode, String payload) async {
    jsonDecode(payload);
    await _database.insert('snapshots', {
      'module': module, 'country_code': countryCode, 'payload': payload,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace,);
  }

  Future<Map<String, int>> stock(String countryCode) => _stockWithExecutor(_database, countryCode);

  static Future<Map<String, int>> _stockWithExecutor(DatabaseExecutor db, String countryCode) async {
    final rows = await db.rawQuery('SELECT product_id, COALESCE(SUM(quantity_delta), 0) quantity FROM inventory_movements WHERE country_code = ? GROUP BY product_id', [countryCode]);
    return {for (final row in rows) row['product_id'] as String: (row['quantity'] as num).toInt()};
  }

  Future<void> reconcileInventory(String countryCode, List<InventoryItem> desired, InventoryMovementType type, {String? relatedId, String? reason}) async {
    final target = {for (final item in desired) item.product.id: item.quantity};
    await _database.transaction((txn) async {
      final current = await _stockWithExecutor(txn, countryCode);
      final ids = {...current.keys, ...target.keys};
      for (final id in ids) {
        final delta = (target[id] ?? 0) - (current[id] ?? 0);
        if (delta == 0) continue;
        await txn.insert('inventory_movements', _movementMap(InventoryMovement(
          id: _uuid.v4(), productId: id, countryCode: countryCode,
          type: type, quantityDelta: delta, occurredAt: DateTime.now(),
          deviceId: deviceId, relatedId: relatedId, reason: reason,
        ),),);
      }
    });
  }

  // ── NUEVO: guardado atómico de movimientos y snapshots ──────────────────
  // Propósito: registrar los movimientos de inventario y los snapshots de
  //            ventas/inventario en UNA sola transacción, para que una
  //            interrupción no deje stock descontado sin su venta (o al revés).
  // Depende de: tablas inventory_movements y snapshots, _stockWithExecutor,
  //            _movementMap.
  // No modifica: reconcileInventory ni writeSnapshot, que siguen disponibles.
  Future<void> commitInventoryAndSnapshots(
    String countryCode, {
    required List<InventoryItem> desired,
    required InventoryMovementType type,
    required Map<String, String> snapshots,
    bool recordMovements = true,
    String? relatedId,
    String? reason,
  }) async {
    // Se valida antes de abrir la transacción, igual que writeSnapshot.
    for (final payload in snapshots.values) {
      jsonDecode(payload);
    }
    final target = {for (final item in desired) item.product.id: item.quantity};
    await _database.transaction((txn) async {
      if (recordMovements) {
        final current = await _stockWithExecutor(txn, countryCode);
        final ids = {...current.keys, ...target.keys};
        for (final id in ids) {
          final delta = (target[id] ?? 0) - (current[id] ?? 0);
          if (delta == 0) continue;
          await txn.insert('inventory_movements', _movementMap(InventoryMovement(
            id: _uuid.v4(), productId: id, countryCode: countryCode,
            type: type, quantityDelta: delta, occurredAt: DateTime.now(),
            deviceId: deviceId, relatedId: relatedId, reason: reason,
          ),),);
        }
      }
      final updatedAt = DateTime.now().toIso8601String();
      for (final entry in snapshots.entries) {
        await txn.insert('snapshots', {
          'module': entry.key, 'country_code': countryCode,
          'payload': entry.value, 'updated_at': updatedAt,
        }, conflictAlgorithm: ConflictAlgorithm.replace,);
      }
    });
  }

  // ── NUEVO: soporte de la sincronización familiar ────────────────────────
  // Propósito: leer/escribir la configuración de sincronización, la cola de
  //            pendientes y los movimientos de inventario hacia/desde la nube.
  // Depende de: tablas metadata, sync_outbox e inventory_movements.
  // No modifica: reconcileInventory, commitInventoryAndSnapshots ni stock().
  Future<String?> readSetting(String key) => _metadata(_database, key);

  Future<void> writeSetting(String key, String? value) async {
    if (value == null) {
      await _database.delete('metadata', where: 'key = ?', whereArgs: [key]);
      return;
    }
    await _database.insert(
      'metadata',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> enqueueSync(String entity, String entityId, {String? countryCode}) async {
    await _database.insert('sync_outbox', {
      'entity': entity, 'entity_id': entityId, 'country_code': countryCode,
      'queued_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> pendingSync() =>
      _database.query('sync_outbox', orderBy: 'queued_at ASC');

  /// Quita un pendiente solo si no se volvió a encolar mientras se subía.
  Future<void> clearSync(String entity, String entityId, String queuedAt) async {
    await _database.delete(
      'sync_outbox',
      where: 'entity = ? AND entity_id = ? AND queued_at = ?',
      whereArgs: [entity, entityId, queuedAt],
    );
  }

  Future<void> clearAllSync() => _database.delete('sync_outbox');

  Future<List<Map<String, Object?>>> unsyncedMovements() =>
      _database.query('inventory_movements', where: 'synced_at IS NULL');

  Future<void> markMovementsSynced(Iterable<String> ids) async {
    final syncedAt = DateTime.now().toIso8601String();
    await _database.transaction((txn) async {
      for (final id in ids) {
        await txn.update('inventory_movements', {'synced_at': syncedAt},
            where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  /// Inserta movimientos que vienen de otro dispositivo. Un id ya existente
  /// se ignora, así un movimiento nunca se cuenta dos veces.
  Future<int> insertRemoteMovements(Iterable<Map<String, Object?>> rows) async {
    var inserted = 0;
    final syncedAt = DateTime.now().toIso8601String();
    await _database.transaction((txn) async {
      for (final row in rows) {
        final id = await txn.insert(
          'inventory_movements',
          {...remoteMovementRow(row), 'synced_at': syncedAt},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (id > 0) inserted++;
      }
    });
    return inserted;
  }

  /// "El principal manda": reemplaza TODOS los movimientos locales por los de
  /// la nube, en una sola transacción.
  Future<void> replaceAllMovements(Iterable<Map<String, Object?>> rows) async {
    final syncedAt = DateTime.now().toIso8601String();
    await _database.transaction((txn) async {
      await txn.delete('inventory_movements');
      for (final row in rows) {
        await txn.insert(
          'inventory_movements',
          {...remoteMovementRow(row), 'synced_at': syncedAt},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  /// Solo las columnas de inventory_movements, con los tipos que SQLite espera.
  static Map<String, Object?> remoteMovementRow(Map<String, Object?> row) => {
        'id': row['id'] as String,
        'product_id': row['product_id'] as String,
        'country_code': row['country_code'] as String,
        'type': row['type'] as String,
        'quantity_delta': (row['quantity_delta'] as num).toInt(),
        'occurred_at': row['occurred_at'] as String,
        'device_id': row['device_id'] as String,
        'related_id': row['related_id'] as String?,
        'reason': row['reason'] as String?,
        'reverses_movement_id': row['reverses_movement_id'] as String?,
      };


  // ── NUEVO: sincronización familiar Fase 2 (seguimientos y configuración) ─
  // Propósito: marcar como pendientes los seguimientos, notas y configuración
  //            que cambian en este celular, y aplicar los que llegan de la
  //            nube SIN volver a marcarlos (evita un eco infinito).
  // Depende de: sync_outbox, follow_ups, follow_up_notes, metadata y
  //            product_follow_up_config.
  // No modifica: lo que guardan los métodos existentes ni sus firmas.

  // CAMPO NUEVO: recordSyncChanges
  // Motivo: solo se encolan cambios con la sincronización activa.
  // Compatibilidad: false por defecto; sin sincronización nada cambia.
  bool recordSyncChanges = false;

  // CAMPO NUEVO: _syncRecorded
  // Motivo: avisar al servicio de sincronización que hay algo por subir.
  // Compatibilidad: no reemplaza ni altera ningún campo existente.
  final StreamController<void> _syncRecorded = StreamController<void>.broadcast();

  Stream<void> get syncRecorded => _syncRecorded.stream;

  Future<void> _recordChange(String entity, String id) async {
    if (!recordSyncChanges) return;
    await enqueueSync(entity, id);
    _syncRecorded.add(null);
  }

  static String productConfigId(String countryCode, String productId) =>
      '${countryCode}_$productId';

  static Map<String, Object?> _followUpRow(FollowUp item) => {
        'id': item.id, 'customer_id': item.customerId, 'sale_id': item.saleId,
        'due_at': item.dueAt.toIso8601String(), 'status': item.status.name,
        'payload': jsonEncode(item.toJson()),
      };

  static Map<String, Object?> _noteRow(FollowUpNote note) => {
        'id': note.id,
        'customer_id': note.customerId,
        'follow_up_id': note.followUpId,
        'sale_id': note.saleId,
        'product_id': note.productId,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt?.toIso8601String(),
        'payload': jsonEncode(note.toJson()),
      };

  Future<Set<String>> customerIds() async => {
        for (final row in await _database.query('customers', columns: ['id']))
          row['id'] as String,
      };

  /// Seguimientos y notas que llegan de la nube. Los que apuntan a un
  /// cliente inexistente se omiten (se devuelven sus ids de cliente).
  Future<Set<String>> applyRemoteFollowUpData({
    List<FollowUp> followUps = const [],
    List<FollowUpNote> notes = const [],
    Set<String> skipFollowUpIds = const {},
    Set<String> skipNoteIds = const {},
  }) async {
    final known = await customerIds();
    final missing = <String>{};
    await _database.transaction((txn) async {
      for (final item in followUps) {
        if (skipFollowUpIds.contains(item.id)) continue;
        if (!known.contains(item.customerId)) {
          missing.add(item.customerId);
          continue;
        }
        await txn.insert('follow_ups', _followUpRow(item), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      for (final note in notes) {
        if (skipNoteIds.contains(note.id)) continue;
        if (!known.contains(note.customerId)) {
          missing.add(note.customerId);
          continue;
        }
        await txn.insert('follow_up_notes', _noteRow(note), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return missing;
  }

  Future<void> applyRemoteSettings({int? reminderHour, int? monthlyPointsGoal}) async {
    if (reminderHour != null && reminderHour >= 0 && reminderHour <= 23) {
      await _database.insert('metadata', {'key': 'reminder_hour', 'value': '$reminderHour'}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (monthlyPointsGoal != null && monthlyPointsGoal >= 1) {
      await _database.insert('metadata', {'key': 'monthly_points_goal', 'value': '$monthlyPointsGoal'}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, Object?>>> productConfigRows() =>
      _database.query('product_follow_up_config');

  Future<Map<String, Object?>?> productConfigRow(String countryCode, String productId) async {
    final rows = await _database.query('product_follow_up_config',
        where: 'product_id = ? AND country_code = ?', whereArgs: [productId, countryCode], limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> applyRemoteProductConfig(Iterable<Map<String, Object?>> rows) async {
    await _database.transaction((txn) async {
      for (final row in rows) {
        await txn.insert('product_follow_up_config', {
          'product_id': row['product_id'] as String,
          'country_code': row['country_code'] as String,
          'enabled': (row['enabled'] as num).toInt(),
          'duration_unit': row['duration_unit'] as String? ?? 'days',
          'duration_value': (row['duration_value'] as num).toInt(),
          'updated_at': row['updated_at'] as String? ?? DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Importación con la sincronización activa: solo seguimientos, notas,
  /// configuración por producto y simulaciones. Los clientes solo se agregan
  /// si no existen; nada existente se pisa. Inventario y ventas se ignoran
  /// para no mezclar el inventario compartido ni pisar ventas de la nube.
  /// Devuelve los ids nuevos por tipo para subirlos a la nube.
  Future<Map<String, List<String>>> importModulesForSync(Map<String, dynamic> data) async {
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Version de respaldo no compatible.');
    }
    final inserted = <String, List<String>>{
      'customer': [], 'follow_up': [], 'follow_up_note': [], 'product_config': [],
    };
    List<Map<String, Object?>> rowsOf(String key) => [
          for (final raw in ((data[key] as List?) ?? const []).cast<Map>())
            raw.map((k, v) => MapEntry(k.toString(), v)),
        ];
    await _database.transaction((txn) async {
      Future<void> insertMissing(String key, String table, String entity, String Function(Map<String, Object?>) idOf, {Set<String>? requireCustomer}) async {
        for (final row in rowsOf(key)) {
          // Un seguimiento o nota de un cliente inexistente se omite: si no,
          // la llave foránea abortaría toda la importación.
          if (requireCustomer != null && !requireCustomer.contains(row['customer_id'])) continue;
          final result = await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.ignore);
          if (result > 0) inserted[entity]!.add(idOf(row));
        }
      }
      await insertMissing('clients', 'customers', 'customer', (row) => row['id'] as String);
      final known = {
        for (final row in await txn.query('customers', columns: ['id'])) row['id'] as String,
      };
      await insertMissing('followups', 'follow_ups', 'follow_up', (row) => row['id'] as String, requireCustomer: known);
      await insertMissing('notes', 'follow_up_notes', 'follow_up_note', (row) => row['id'] as String, requireCustomer: known);
      await insertMissing('config', 'product_follow_up_config', 'product_config',
          (row) => productConfigId(row['country_code'] as String, row['product_id'] as String));
      // Simulaciones: se unen por id con las actuales (no se reemplazan).
      for (final row in rowsOf('snapshots').where((row) => row['module'] == 'simulations')) {
        final country = row['country_code'] as String;
        final current = await txn.query('snapshots', columns: ['payload'],
            where: 'module = ? AND country_code = ?', whereArgs: ['simulations', country], limit: 1);
        final byId = <String, dynamic>{
          for (final item in (current.isEmpty ? const [] : jsonDecode(current.first['payload'] as String) as List))
            (item as Map)['id'] as String: item,
        };
        for (final item in jsonDecode(row['payload'] as String) as List) {
          byId.putIfAbsent((item as Map)['id'] as String, () => item);
        }
        await txn.insert('snapshots', {
          'module': 'simulations', 'country_code': country,
          'payload': jsonEncode(byId.values.toList()),
          'updated_at': DateTime.now().toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    return inserted;
  }

  static Map<String, Object?> _movementMap(InventoryMovement item) => {
        'id': item.id, 'product_id': item.productId, 'country_code': item.countryCode,
        'type': item.type.name, 'quantity_delta': item.quantityDelta,
        'occurred_at': item.occurredAt.toIso8601String(), 'device_id': item.deviceId,
        'related_id': item.relatedId, 'reason': item.reason,
        'synced_at': item.syncedAt?.toIso8601String(),
        'reverses_movement_id': item.reversesMovementId,
      };

  Future<List<Customer>> loadCustomers({bool includeArchived = false}) async {
    final rows = await _database.query('customers', where: includeArchived ? null : 'archived_at IS NULL', orderBy: 'updated_at DESC');
    return rows.map((row) => Customer.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>)).toList();
  }

  Future<void> saveCustomer(Customer customer) async {
    if (customer.name.trim().isEmpty) throw ArgumentError('El nombre es obligatorio.');
    if (customer.phoneNumber.isNotEmpty && customer.normalizedPhone.length < 8) throw ArgumentError('El telefono no es valido.');
    await _database.insert('customers', {
      'id': customer.id, 'payload': jsonEncode(customer.toJson()),
      'normalized_phone': customer.normalizedPhone,
      'archived_at': customer.archivedAt?.toIso8601String(),
      'updated_at': customer.updatedAt.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace,);
  }

  Future<List<FollowUp>> loadFollowUps() async {
    final rows = await _database.query('follow_ups', orderBy: 'due_at ASC');
    return rows.map((row) => FollowUp.fromJson(jsonDecode(row['payload'] as String) as Map<String, dynamic>)).toList();
  }

  Future<void> saveFollowUp(FollowUp item) async {
    await _database.insert('follow_ups', {
      'id': item.id, 'customer_id': item.customerId, 'sale_id': item.saleId,
      'due_at': item.dueAt.toIso8601String(), 'status': item.status.name,
      'payload': jsonEncode(item.toJson()),
    }, conflictAlgorithm: ConflictAlgorithm.replace,);
    await _recordChange('follow_up', item.id);
  }

  Future<void> saveFollowUps(Iterable<FollowUp> items) async {
    // Se materializa una vez: se recorre al guardar y al marcar pendientes.
    final list = items.toList();
    await _database.transaction((txn) async {
      for (final item in list) {
        await txn.insert('follow_ups', {
          'id': item.id, 'customer_id': item.customerId, 'sale_id': item.saleId,
          'due_at': item.dueAt.toIso8601String(), 'status': item.status.name,
          'payload': jsonEncode(item.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.replace,);
      }
    });
    for (final item in list) {
      await _recordChange('follow_up', item.id);
    }
  }

  Future<List<FollowUpNote>> loadFollowUpNotes({String? customerId}) async {
    final rows = await _database.query(
      'follow_up_notes',
      where: customerId == null ? null : 'customer_id = ?',
      whereArgs: customerId == null ? null : [customerId],
      orderBy: 'created_at DESC',
    );
    return rows
        .map((row) => FollowUpNote.fromJson(
            jsonDecode(row['payload'] as String) as Map<String, dynamic>,),)
        .toList();
  }

  Future<void> saveFollowUpNote(FollowUpNote note) async {
    if (note.text.trim().isEmpty) {
      throw ArgumentError('La nota no puede estar vacia.');
    }
    await _database.insert(
      'follow_up_notes',
      {
        'id': note.id,
        'customer_id': note.customerId,
        'follow_up_id': note.followUpId,
        'sale_id': note.saleId,
        'product_id': note.productId,
        'created_at': note.createdAt.toIso8601String(),
        'updated_at': note.updatedAt?.toIso8601String(),
        'payload': jsonEncode(note.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _recordChange('follow_up_note', note.id);
  }

  Future<void> _migrateLegacyFollowUpNotes() async {
    if (await _metadata(_database, 'follow_up_notes_migrated') == '1') return;
    final followUps = await loadFollowUps();
    await _database.transaction((txn) async {
      for (final item in followUps.where((entry) => entry.notes.trim().isNotEmpty)) {
        final note = FollowUpNote(
          id: 'legacy_${item.id}',
          customerId: item.customerId,
          followUpId: item.id,
          saleId: item.saleId,
          productId: item.productId,
          followUpType: item.type.name,
          text: item.notes.trim(),
          deviceId: deviceId,
          createdAt: item.completedAt ?? item.createdAt,
        );
        await txn.insert('follow_up_notes', {
          'id': note.id,
          'customer_id': note.customerId,
          'follow_up_id': note.followUpId,
          'sale_id': note.saleId,
          'product_id': note.productId,
          'created_at': note.createdAt.toIso8601String(),
          'updated_at': null,
          'payload': jsonEncode(note.toJson()),
        }, conflictAlgorithm: ConflictAlgorithm.ignore,);
      }
      await txn.insert('metadata', {
        'key': 'follow_up_notes_migrated',
        'value': '1',
      }, conflictAlgorithm: ConflictAlgorithm.replace,);
    });
  }

  Future<Map<String, dynamic>> exportModules(Set<String> modules) async {
    final result = <String, dynamic>{
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'deviceId': deviceId,
      'modules': modules.toList()..sort(),
    };
    if (modules.contains('inventory')) {
      result['inventory'] = await _database.query('inventory_movements');
    }
    if (modules.contains('sales') || modules.contains('simulations')) {
      final wanted = <String>[
        if (modules.contains('sales')) 'sales',
        if (modules.contains('simulations')) 'simulations',
      ];
      result['snapshots'] = await _database.query(
        'snapshots', where: 'module IN (${List.filled(wanted.length, '?').join(',')})', whereArgs: wanted,
      );
    }
    if (modules.contains('clients')) result['clients'] = await _database.query('customers');
    if (modules.contains('followups')) {
      result['followups'] = await _database.query('follow_ups');
      result['notes'] = await _database.query('follow_up_notes');
    }
    if (modules.contains('config')) result['config'] = await _database.query('product_follow_up_config');
    return result;
  }

  Future<Map<String, int>> importModules(Map<String, dynamic> data, {required bool replace}) async {
    final schemaVersion = data['schemaVersion'];
    if (schemaVersion != 1 && schemaVersion != 2) {
      throw const FormatException('Version de respaldo no compatible.');
    }
    final counts = <String, int>{};
    await _database.transaction((txn) async {
      final inventoryRows = (data['inventory'] as List?) ?? const [];
      final snapshotRows = (data['snapshots'] as List?) ?? const [];
      final clientRows = (data['clients'] as List?) ?? const [];
      final followUpRows = (data['followups'] as List?) ?? const [];
      final noteRows = (data['notes'] as List?) ?? const [];
      final configRows = (data['config'] as List?) ?? const [];
      if (replace) {
        if (noteRows.isNotEmpty || followUpRows.isNotEmpty || clientRows.isNotEmpty) await txn.delete('follow_up_notes');
        if (followUpRows.isNotEmpty || clientRows.isNotEmpty) await txn.delete('follow_ups');
        if (clientRows.isNotEmpty) await txn.delete('customers');
        if (inventoryRows.isNotEmpty) await txn.delete('inventory_movements');
        if (configRows.isNotEmpty) await txn.delete('product_follow_up_config');
        for (final raw in snapshotRows.cast<Map>()) {
          await txn.delete('snapshots', where: 'module = ? AND country_code = ?', whereArgs: [raw['module'], raw['country_code']]);
        }
      }
      Future<void> apply(String key, String table) async {
        final rows = (data[key] as List?)?.cast<Map>() ?? const <Map>[];
        for (final raw in rows) {
          final row = raw.map((key, value) => MapEntry(key.toString(), value));
          await txn.insert(
            table, row,
            conflictAlgorithm: table == 'inventory_movements'
                ? ConflictAlgorithm.ignore
                : ConflictAlgorithm.replace,
          );
        }
        counts[key] = rows.length;
      }
      await apply('inventory', 'inventory_movements');
      await apply('snapshots', 'snapshots');
      await apply('clients', 'customers');
      await apply('followups', 'follow_ups');
      await apply('notes', 'follow_up_notes');
      await apply('config', 'product_follow_up_config');
      // Consultas dentro de la transaccion fuerzan la validacion de tipos y claves.
      await txn.rawQuery('SELECT COUNT(*) FROM inventory_movements');
    });
    return counts;
  }
}

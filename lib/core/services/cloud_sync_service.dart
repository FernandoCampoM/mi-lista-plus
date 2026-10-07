import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/local_store.dart';
import '../../data/datasources/operational_database.dart';
import '../../domain/entities/customer.dart';
import '../../domain/entities/sale.dart';
import '../../presentation/state/app_state.dart';

// ── NUEVO: sincronización familiar con Firebase ─────────────────────────
// Propósito: compartir el inventario entre todos los celulares del hogar y
//            guardar en la nube las ventas y clientes de cada vendedor.
// Depende de: FirebaseAuth (cuenta del hogar), Firestore, OperationalDatabase
//            (movimientos, sync_outbox, metadata), AppState (aplica cambios
//            remotos dentro de su cola de escrituras) y LocalStore (formato
//            JSON de las ventas).
// No modifica: el funcionamiento local de la app. Si nunca se activa, este
//              servicio no lee ni escribe nada en la nube.
//
// Estructura en Firestore (protegida por las reglas: solo la cuenta del hogar):
//   households/{uid}/inventory_movements/{id}           ← compartido
//   households/{uid}/sellers/{vendedor}/sales/{id}      ← ventas por vendedor
//   households/{uid}/sellers/{vendedor}/customers/{id}  ← clientes por vendedor
//   households/{uid}/meta/state                         ← quién inicializó
class CloudSyncService extends ChangeNotifier {
  CloudSyncService({
    required AppState state,
    required LocalStore localStore,
    required OperationalDatabase database,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _state = state,
        _localStore = localStore,
        _db = database,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  /// Instancia creada en main.dart cuando SQLite y Firebase están listos.
  static CloudSyncService? instance;

  /// Crea la instancia bajo demanda (lo registra main.dart). Lanza el error
  /// real si todavía no se puede crear, para mostrarlo en pantalla.
  static Future<CloudSyncService> Function()? initializer;

  /// Vendedores del hogar: id en la nube → nombre visible.
  static const sellers = {'fernando': 'Fernando', 'esposa': 'Esposa'};

  static const _enabledKey = 'cloud_sync_enabled';
  static const _sellerKey = 'cloud_sync_seller';
  static const _householdKey = 'cloud_sync_household';
  static const _lastSyncKey = 'cloud_sync_last_at';
  static const _cursorPrefix = 'cloud_sync_cursor_';
  static const _batchSize = 400;

  final AppState _state;
  final LocalStore _localStore;
  final OperationalDatabase _db;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _active = false;
  bool _pushing = false;
  bool _pushAgain = false;
  String? _seller;
  String? _householdId;
  DateTime? lastSyncAt;
  String? lastError;
  bool needsSignIn = false;

  bool get isActive => _active;
  String? get seller => _seller;
  String get sellerName => sellers[_seller] ?? (_seller ?? '');

  DocumentReference<Map<String, dynamic>> get _household =>
      _firestore.collection('households').doc(_householdId);

  CollectionReference<Map<String, dynamic>> get _movements =>
      _household.collection('inventory_movements');

  CollectionReference<Map<String, dynamic>> _sellerCollection(String name) =>
      _household.collection('sellers').doc(_seller).collection(name);

  // ── Arranque ────────────────────────────────────────────────────────────

  /// Al abrir la app: reanuda la sincronización si estaba activa.
  Future<void> resume() async {
    if (await _db.readSetting(_enabledKey) != '1') return;
    _seller = await _db.readSetting(_sellerKey);
    _householdId = await _db.readSetting(_householdKey);
    final lastRaw = await _db.readSetting(_lastSyncKey);
    lastSyncAt = lastRaw == null ? null : DateTime.tryParse(lastRaw);
    final user = _auth.currentUser;
    if (user == null || user.uid != _householdId || _seller == null) {
      // La sesión se perdió: hay que volver a escribir la contraseña.
      needsSignIn = true;
      notifyListeners();
      return;
    }
    await _start();
  }

  /// Activa la sincronización en este celular.
  Future<void> activate({
    required String email,
    required String password,
    required String seller,
    void Function(String step)? onProgress,
  }) async {
    if (!sellers.containsKey(seller)) {
      throw ArgumentError.value(seller, 'seller');
    }
    if (!await _db.isMigrationValidated) {
      throw StateError(
        'La base local todavía no terminó de prepararse. Cierra y abre la app e intenta de nuevo.',
      );
    }
    onProgress?.call('Iniciando sesión...');
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    _householdId = credential.user!.uid;
    _seller = seller;

    final metaRef = _household.collection('meta').doc('state');
    final meta = await metaRef.get(const GetOptions(source: Source.server));
    final startedAt = Timestamp.now();

    _state.cloudSyncActive = true;
    if (!meta.exists) {
      // Primer celular del hogar: su inventario es la base.
      onProgress?.call('Subiendo el inventario de este celular...');
      await _enqueueAllLocalSalesAndCustomers();
      await _push(rethrowErrors: true);
      await metaRef.set({
        'initializedAt': FieldValue.serverTimestamp(),
        'initializedBy': _db.deviceId,
      });
    } else {
      // Celular adicional: el inventario de la nube reemplaza al local.
      onProgress?.call('Creando respaldo automático...');
      await _state.backupService.createAutomaticBackup();
      onProgress?.call('Descargando el inventario compartido...');
      final movements = await _movements.get(const GetOptions(source: Source.server));
      await _state.replaceInventoryFromCloud([
        for (final doc in movements.docs) _rowFromDoc(doc.data()),
      ]);
      onProgress?.call('Subiendo las ventas de este celular...');
      await _enqueueAllLocalSalesAndCustomers();
      await _push(rethrowErrors: true);
      onProgress?.call('Descargando las ventas de ${sellers[seller]}...');
      final sales = await _sellerCollection('sales').get(const GetOptions(source: Source.server));
      await _applySaleDocs(sales.docs.map((doc) => doc.data()), skipOwnDevice: false);
      final customers = await _sellerCollection('customers').get(const GetOptions(source: Source.server));
      await _applyCustomerDocs(customers.docs.map((doc) => doc.data()), skipOwnDevice: false);
    }

    await _db.writeSetting(_enabledKey, '1');
    await _db.writeSetting(_sellerKey, seller);
    await _db.writeSetting(_householdKey, _householdId);
    // Un margen hacia atrás es seguro: aplicar dos veces un cambio no duplica
    // nada (los movimientos se insertan por id y las ventas se unen por id).
    final cursor = startedAt.millisecondsSinceEpoch - const Duration(minutes: 2).inMilliseconds;
    for (final name in const ['movements', 'sales', 'customers']) {
      await _db.writeSetting('$_cursorPrefix$name', '$cursor');
    }
    needsSignIn = false;
    onProgress?.call('Sincronización activa.');
    await _start();
  }

  /// Desactiva la sincronización SOLO en este celular. Los datos locales y los
  /// de la nube se conservan.
  Future<void> deactivate() async {
    await _stopListeners();
    _active = false;
    _state.cloudSyncActive = false;
    await _db.writeSetting(_enabledKey, null);
    await _db.clearAllSync();
    try {
      await _auth.signOut();
    } catch (_) {}
    notifyListeners();
  }

  /// Sube ya todo lo pendiente.
  Future<void> syncNow() => _push();

  /// Productos con stock negativo: pasa si dos celulares vendieron la última
  /// unidad sin internet. Se muestran como alerta para corregir el inventario.
  Future<int> negativeStockCount() async {
    var count = 0;
    for (final country in _state.countries) {
      count += (await _db.stock(country.code)).values.where((value) => value < 0).length;
    }
    return count;
  }

  Future<int> pendingCount() async =>
      (await _db.pendingSync()).length + (await _db.unsyncedMovements()).length;

  Future<void> _start() async {
    await _stopListeners();
    _active = true;
    _state.cloudSyncActive = true;
    _subscriptions.add(_state.localChanges.listen((_) => unawaited(_push())));
    await _listen('movements', _movements, (docs) async {
      await _state.applyRemoteMovements([
        for (final data in docs)
          if (data['device_id'] != _db.deviceId) _rowFromDoc(data),
      ]);
    });
    await _listen('sales', _sellerCollection('sales'), (docs) => _applySaleDocs(docs));
    await _listen('customers', _sellerCollection('customers'), (docs) => _applyCustomerDocs(docs));
    notifyListeners();
    unawaited(_push());
  }

  Future<void> _stopListeners() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  Future<void> _listen(
    String name,
    CollectionReference<Map<String, dynamic>> collection,
    Future<void> Function(List<Map<String, dynamic>> docs) apply,
  ) async {
    final cursorRaw = await _db.readSetting('$_cursorPrefix$name');
    final cursor = int.tryParse(cursorRaw ?? '') ?? 0;
    final query = collection.where(
      'serverUpdatedAt',
      isGreaterThan: Timestamp.fromMillisecondsSinceEpoch(cursor),
    );
    _subscriptions.add(query.snapshots().listen(
      (snapshot) async {
        final changed = [
          for (final change in snapshot.docChanges)
            if (change.type != DocumentChangeType.removed &&
                !change.doc.metadata.hasPendingWrites)
              change.doc.data()!,
        ];
        if (changed.isEmpty) return;
        try {
          await apply(changed);
          await _advanceCursor(name, changed);
          await _markSynced();
        } catch (error, stackTrace) {
          _reportError('Aplicando cambios remotos ($name)', error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) =>
          _reportError('Escuchando cambios ($name)', error, stackTrace),
    ));
  }

  Future<void> _advanceCursor(String name, List<Map<String, dynamic>> docs) async {
    final current = int.tryParse(await _db.readSetting('$_cursorPrefix$name') ?? '') ?? 0;
    var max = current;
    for (final data in docs) {
      final value = data['serverUpdatedAt'];
      if (value is Timestamp && value.millisecondsSinceEpoch > max) {
        max = value.millisecondsSinceEpoch;
      }
    }
    if (max > current) await _db.writeSetting('$_cursorPrefix$name', '$max');
  }

  // ── Subida ──────────────────────────────────────────────────────────────

  Future<void> _push({bool rethrowErrors = false}) async {
    if (_householdId == null || _seller == null) return;
    if (_pushing) {
      _pushAgain = true;
      return;
    }
    _pushing = true;
    try {
      do {
        _pushAgain = false;
        await _pushMovements();
        await _pushOutbox();
      } while (_pushAgain);
      lastError = null;
      await _markSynced();
    } catch (error, stackTrace) {
      _reportError('Subiendo cambios', error, stackTrace);
      if (rethrowErrors) rethrow;
    } finally {
      _pushing = false;
    }
  }

  Future<void> _pushMovements() async {
    final rows = await _db.unsyncedMovements();
    for (var start = 0; start < rows.length; start += _batchSize) {
      final chunk = rows.skip(start).take(_batchSize).toList();
      final batch = _firestore.batch();
      for (final row in chunk) {
        batch.set(_movements.doc(row['id'] as String), {
          ...OperationalDatabase.remoteMovementRow(row),
          'serverUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
      await _db.markMovementsSynced(chunk.map((row) => row['id'] as String));
    }
  }

  Future<void> _pushOutbox() async {
    final pending = await _db.pendingSync();
    if (pending.isEmpty) return;
    final customers = {
      for (final customer in await _db.loadCustomers(includeArchived: true))
        customer.id: customer,
    };
    final salesByCountry = <String, Map<String, Sale>>{};
    for (var start = 0; start < pending.length; start += _batchSize) {
      final chunk = pending.skip(start).take(_batchSize).toList();
      final batch = _firestore.batch();
      for (final row in chunk) {
        final id = row['entity_id'] as String;
        if (row['entity'] == 'sale') {
          final country = row['country_code'] as String? ?? '';
          final sales = salesByCountry[country] ??= {
            for (final sale in await _state.salesOfCountry(country)) sale.id: sale,
          };
          final sale = sales[id];
          batch.set(_sellerCollection('sales').doc(id), {
            'saleId': id,
            'countryCode': country,
            'deleted': sale == null,
            if (sale != null) 'payload': _localStore.encodeSalesPayload([sale]),
            'deviceId': _db.deviceId,
            'serverUpdatedAt': FieldValue.serverTimestamp(),
          });
        } else if (row['entity'] == 'customer') {
          final customer = customers[id];
          if (customer == null) continue;
          batch.set(_sellerCollection('customers').doc(id), {
            'payload': jsonEncode(customer.toJson()),
            'deviceId': _db.deviceId,
            'serverUpdatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      await batch.commit();
      for (final row in chunk) {
        await _db.clearSync(
          row['entity'] as String,
          row['entity_id'] as String,
          row['queued_at'] as String,
        );
      }
    }
  }

  Future<void> _enqueueAllLocalSalesAndCustomers() async {
    for (final country in _state.countries) {
      for (final sale in await _state.salesOfCountry(country.code)) {
        await _db.enqueueSync('sale', sale.id, countryCode: country.code);
      }
    }
    for (final customer in await _db.loadCustomers(includeArchived: true)) {
      await _db.enqueueSync('customer', customer.id);
    }
  }

  // ── Aplicar cambios remotos ─────────────────────────────────────────────

  Future<void> _applySaleDocs(
    Iterable<Map<String, dynamic>> docs, {
    bool skipOwnDevice = true,
  }) async {
    final byCountry = <String, List<Sale>>{};
    final deletedByCountry = <String, Set<String>>{};
    for (final data in docs) {
      if (skipOwnDevice && data['deviceId'] == _db.deviceId) continue;
      final country = data['countryCode'] as String? ?? '';
      if (data['deleted'] == true) {
        final id = data['saleId'] as String?;
        if (id != null) (deletedByCountry[country] ??= {}).add(id);
        continue;
      }
      final payload = data['payload'] as String?;
      if (payload == null) continue;
      try {
        (byCountry[country] ??= []).add(_localStore.salesFromPayload(payload).single);
      } catch (error) {
        developer.log('Venta remota inválida omitida', name: 'mi_lista_plus.sync', error: error);
      }
    }
    for (final country in {...byCountry.keys, ...deletedByCountry.keys}) {
      await _state.applyRemoteSales(
        country,
        byCountry[country] ?? const [],
        deletedIds: deletedByCountry[country] ?? const {},
      );
    }
  }

  Future<void> _applyCustomerDocs(
    Iterable<Map<String, dynamic>> docs, {
    bool skipOwnDevice = true,
  }) async {
    final customers = <Customer>[];
    for (final data in docs) {
      if (skipOwnDevice && data['deviceId'] == _db.deviceId) continue;
      final payload = data['payload'] as String?;
      if (payload == null) continue;
      try {
        customers.add(Customer.fromJson(jsonDecode(payload) as Map<String, dynamic>));
      } catch (error) {
        developer.log('Cliente remoto inválido omitido', name: 'mi_lista_plus.sync', error: error);
      }
    }
    await _state.applyRemoteCustomers(customers);
  }

  Map<String, Object?> _rowFromDoc(Map<String, dynamic> data) =>
      OperationalDatabase.remoteMovementRow(data);

  Future<void> _markSynced() async {
    lastSyncAt = DateTime.now();
    await _db.writeSetting(_lastSyncKey, lastSyncAt!.toIso8601String());
    notifyListeners();
  }

  void _reportError(String stage, Object error, StackTrace stackTrace) {
    lastError = '$stage: $error';
    developer.log(stage, name: 'mi_lista_plus.sync', error: error, stackTrace: stackTrace);
    notifyListeners();
  }
}

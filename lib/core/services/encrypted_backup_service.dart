import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/datasources/operational_database.dart';

class BackupPreview {
  const BackupPreview({required this.modules, required this.exportedAt, required this.counts, required this.payload, required String password}) : _password = password;
  final List<String> modules;
  final DateTime exportedAt;
  final Map<String, int> counts;
  final Map<String, dynamic> payload;
  final String _password;
}

class EncryptedBackupService {
  EncryptedBackupService(this.database);
  final OperationalDatabase database;

  static const _magic = 'MLPLUS1';
  final _aes = AesGcm.with256bits();
  final _kdf = Argon2id(memory: 19456, parallelism: 1, iterations: 2, hashLength: 32);

  static String transferPassword(String pairingCode) {
    final normalized = pairingCode.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(normalized)) {
      throw ArgumentError('El código de emparejamiento debe tener 6 dígitos.');
    }
    return 'MLP-SYNC-$normalized';
  }

  Future<void> exportToFile({required Set<String> modules, required String password, required String path}) async {
    final bytes = await generateEncryptedBytes(
      modules: modules,
      password: password,
    );
    await File(path).writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List> generateEncryptedBytes({
    required Set<String> modules,
    required String password,
  }) async {
    final normalizedPassword = password.trim();
    if (normalizedPassword.length < 8) throw ArgumentError('La contraseña debe tener al menos 8 caracteres.');
    final selected = Set<String>.of(modules);
    if (selected.contains('sales')) selected.add('inventory');
    if (selected.contains('followups')) selected.add('clients');
    final payload = await database.exportModules(selected);
    final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
    final random = Random.secure();
    final salt = Uint8List.fromList(List.generate(16, (_) => random.nextInt(256)));
    final nonce = Uint8List.fromList(List.generate(12, (_) => random.nextInt(256)));
    final key = await _kdf.deriveKeyFromPassword(password: normalizedPassword, nonce: salt);
    final box = await _aes.encrypt(compressed, secretKey: key, nonce: nonce);
    final bytes = BytesBuilder(copy: false)
      ..add(ascii.encode(_magic))
      ..add(salt)
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return bytes.takeBytes();
  }

  Future<BackupPreview> preview(String path, String password) async {
    final normalizedPassword = password.trim();
    final bytes = await File(path).readAsBytes();
    if (bytes.length < 51 || ascii.decode(bytes.sublist(0, 7)) != _magic) {
      throw const FormatException('El archivo no es un respaldo de Mi Lista+.');
    }
    final salt = bytes.sublist(7, 23);
    final nonce = bytes.sublist(23, 35);
    final mac = bytes.sublist(35, 51);
    final cipher = bytes.sublist(51);
    try {
      final key = await _kdf.deriveKeyFromPassword(password: normalizedPassword, nonce: salt);
      final clear = await _aes.decrypt(SecretBox(cipher, nonce: nonce, mac: Mac(mac)), secretKey: key);
      final payload = jsonDecode(utf8.decode(gzip.decode(clear))) as Map<String, dynamic>;
      final counts = <String, int>{};
      for (final key in const ['inventory', 'snapshots', 'clients', 'followups', 'config']) {
        if (payload[key] is List) counts[key] = (payload[key] as List).length;
      }
      return BackupPreview(
        modules: (payload['modules'] as List).cast<String>(),
        exportedAt: DateTime.parse(payload['exportedAt'] as String),
        counts: counts, payload: payload, password: normalizedPassword,
      );
    } on SecretBoxAuthenticationError {
      throw StateError('Contraseña incorrecta o archivo alterado. No se modifico ningun dato.');
    }
  }

  Future<Map<String, int>> importPreview(BackupPreview preview, {required bool replace}) async {
    final root = await getApplicationSupportDirectory();
    final path = p.join(root.path, 'automatic_before_import_${DateTime.now().millisecondsSinceEpoch}.mlplus');
    await exportToFile(
      modules: const {'inventory', 'sales', 'clients', 'followups', 'simulations', 'config'},
      password: preview._password,
      path: path,
    );
    return database.importModules(preview.payload, replace: replace);
  }
}

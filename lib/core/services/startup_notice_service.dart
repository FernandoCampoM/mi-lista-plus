import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StartupNotice {
  const StartupNotice({
    required this.id,
    required this.bytes,
    this.linkUrl,
  });
  final String id;
  final Uint8List bytes;
  final Uri? linkUrl;
}

class StartupNoticeService {
  StartupNoticeService(this._remoteConfig, this._preferences);

  static const _maxBytes = 5 * 1024 * 1024;
  static const _maxDimension = 4096;
  final FirebaseRemoteConfig _remoteConfig;
  final SharedPreferences _preferences;
  bool _attemptedThisSession = false;

  Future<StartupNotice?> load({required bool openedFromFollowUp}) async {
    if (_attemptedThisSession || openedFromFollowUp) return null;
    _attemptedThisSession = true;
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((item) => item == ConnectivityResult.none)) return null;
      await _remoteConfig.setDefaults(const {
        'startup_notice_enabled': false,
        'startup_notice_id': '',
        'startup_notice_image_url': '',
        'startup_notice_link_url': '',
      });
      // Remote Config ya fue refrescado al iniciar los servicios remotos.
      // Este servicio solo consume los valores activados para no cambiar el
      // intervalo de fetch ni vincular el aviso a la sincronizacion del catalogo.
      if (!_remoteConfig.getBool('startup_notice_enabled')) return null;
      final id = _remoteConfig.getString('startup_notice_id').trim();
      final uri = Uri.tryParse(_remoteConfig.getString('startup_notice_image_url').trim());
      if (id.isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
      final linkRaw = _remoteConfig.getString('startup_notice_link_url').trim();
      final parsedLink = linkRaw.isEmpty ? null : Uri.tryParse(linkRaw);
      final linkUrl = parsedLink != null &&
              (parsedLink.scheme == 'https' || parsedLink.scheme == 'http') &&
              parsedLink.host.isNotEmpty
          ? parsedLink
          : null;
      if ((_preferences.getInt('startup_notice_views_$id') ?? 0) >= 3) return null;
      final bytes = await _download(uri);
      if (!await _validDimensions(bytes)) return null;
      return StartupNotice(id: id, bytes: bytes, linkUrl: linkUrl);
    } catch (_) {
      return null;
    }
  }

  Future<void> markShown(String id) async {
    final key = 'startup_notice_views_$id';
    final current = _preferences.getInt(key) ?? 0;
    if (current < 3) await _preferences.setInt(key, current + 1);
  }

  Future<Uint8List> _download(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok ||
          (response.contentLength > _maxBytes && response.contentLength != -1)) {
        throw const FormatException('Imagen remota no valida.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 8))) {
        builder.add(chunk);
        if (builder.length > _maxBytes) throw const FormatException('Imagen demasiado grande.');
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> _validDimensions(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    try {
      final frame = await codec.getNextFrame();
      return frame.image.width <= _maxDimension && frame.image.height <= _maxDimension;
    } finally {
      codec.dispose();
    }
  }
}

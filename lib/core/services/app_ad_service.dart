import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_mob_config.dart';

enum ImportantAdAction {
  countryChanged,
  simulationGenerated,
  simulationShared,
  backupOpened,
  backupCreated,
  backupShared,
  backupImported,
  saleRegistered,
  saleUpdated,
  saleCancelled,
  saleDeleted,
  customerCreated,
  followUpCompleted,
  deliveryConfirmed,
  inventoryUpdated,
  returnedHomeAfterSeveralMinutes,
}

enum BannerPlacement {
  home,
  simulations,
  inventory,
  sales,
  customers,
  followups,
  deliveries,
  backup,
  settings,
}

class AppAdService extends ChangeNotifier {
  AppAdService(this._preferences, {FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig;

  static const _importantActionCountKey = 'ads_important_action_count';
  static const _lastImportantActionKey = 'ads_last_important_action';
  static const _lastInterstitialShownAtKey = 'ads_last_interstitial_shown_at';
  static const _lastDisclaimerInterstitialDateKey =
      'ads_last_disclaimer_interstitial_date';
  static const _lastHomeVisibleAtKey = 'ads_last_home_visible_at';
  static const _defaultActionFrequency = 10;
  static const _defaultCooldownSeconds = 180;
  static const _returnHomeMinimumDelay = Duration(minutes: 3);

  final SharedPreferences _preferences;
  FirebaseRemoteConfig? _remoteConfig;
  InterstitialAd? _interstitialAd;
  bool _isInitialized = false;
  bool _isLoadingInterstitial = false;
  bool _isShowingInterstitial = false;
  bool _remoteConfigReady = false;

  int get actionFrequency {
    if (!_remoteConfigReady) return _defaultActionFrequency;
    final configured = _remoteConfig?.getInt(
      'ads_interstitial_action_frequency',
    );
    return configured == null || configured < 1
        ? _defaultActionFrequency
        : configured;
  }

  Duration get interstitialCooldown {
    if (!_remoteConfigReady) {
      return const Duration(seconds: _defaultCooldownSeconds);
    }
    final configured = _remoteConfig?.getInt(
      'ads_interstitial_cooldown_seconds',
    );
    final seconds = configured == null || configured < 0
        ? _defaultCooldownSeconds
        : configured;
    return Duration(seconds: seconds);
  }

  Future<void> initialize() async {
    // Los anuncios no se inicializan hasta que Remote Config haya sido
    // obtenido y activado. Así una instalación nueva/offline nunca cae
    // accidentalmente en IDs de prueba o defaults habilitados.
    if (_isInitialized || !_remoteConfigReady) return;
    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      unawaited(_loadInterstitial());
    } catch (_) {
      _isInitialized = false;
    }
  }

  Future<bool> configureRemoteConfig(FirebaseRemoteConfig remoteConfig) async {
    _remoteConfig = remoteConfig;
    final ready = await _initializeRemoteConfig();
    if (!ready) return false;
    await initialize();
    notifyListeners();
    return true;
  }

  bool bannerEnabled(BannerPlacement placement) {
    if (!_remoteConfigReady) return false;
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return false;

    // Kill switch global opcional. Si no existe en Firebase conserva el
    // comportamiento actual porque su default es true.
    if (!remoteConfig.getBool('ads_enabled')) return false;
    return remoteConfig.getBool('ads_banner_${placement.name}_enabled');
  }

  String bannerUnitId(BannerPlacement placement) {
    if (!_remoteConfigReady) return AdMobConfig.bannerUnitId;
    final platform = _platformKey;
    final placementId = _remoteConfig
            ?.getString('ads_banner_${placement.name}_unit_id_$platform')
            .trim() ??
        '';
    if (placementId.isNotEmpty) return placementId;

    final globalId = _remoteConfig
            ?.getString('ads_banner_unit_id_$platform')
            .trim() ??
        '';
    return globalId.isEmpty ? AdMobConfig.bannerUnitId : globalId;
  }

  Future<void> recordImportantAction(ImportantAdAction action) async {
    try {
      await _recordImportantAction(action);
    } catch (_) {
      // La publicidad nunca debe bloquear ni invalidar una operación de negocio.
    }
  }

  Future<void> _recordImportantAction(ImportantAdAction action) async {
    if (!_isInitialized || !_interstitialEnabled) return;

    final currentCount = _preferences.getInt(_importantActionCountKey) ?? 0;
    final nextCount = currentCount + 1;
    await _preferences.setInt(_importantActionCountKey, nextCount);
    await _preferences.setString(_lastImportantActionKey, action.name);

    if (nextCount < actionFrequency) {
      if (_interstitialAd == null) unawaited(_loadInterstitial());
      return;
    }

    final wasShown = await _showInterstitial();
    if (wasShown) {
      await _preferences.setInt(_importantActionCountKey, 0);
    }
  }

  Future<void> recordHomeVisible() async {
    final now = DateTime.now();
    final previousRaw = _preferences.getString(_lastHomeVisibleAtKey);
    await _preferences.setString(_lastHomeVisibleAtKey, now.toIso8601String());

    final previous = previousRaw == null ? null : DateTime.tryParse(previousRaw);
    if (previous == null || now.difference(previous) < _returnHomeMinimumDelay) {
      return;
    }

    await recordImportantAction(
      ImportantAdAction.returnedHomeAfterSeveralMinutes,
    );
  }

  Future<void> showDisclaimerInterstitialOncePerDay() async {
    if (!_isInitialized || !_interstitialEnabled) return;

    final today = _dateKey(DateTime.now());
    final lastShownDate = _preferences.getString(
      _lastDisclaimerInterstitialDateKey,
    );
    if (lastShownDate == today) return;

    final wasShown = await _showInterstitial();
    if (wasShown) {
      await _preferences.setString(_lastDisclaimerInterstitialDateKey, today);
    }
  }

  Future<bool> _initializeRemoteConfig() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return false;

    _remoteConfigReady = false;
    try {
      await remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          // Los controles de publicidad funcionan también como kill-switch.
          // Un intervalo corto evita mantener anuncios activos durante horas
          // después de deshabilitarlos en Firebase.
          // Remote Config se consulta en cada arranque, independientemente de si
          // el catalogo local ya existe o si Firestore tiene cambios. La llamada
          // ocurre en segundo plano, por lo que no bloquea el inicio local-first.
          minimumFetchInterval: Duration.zero,
        ),
      );
      await remoteConfig.setDefaults({
        'ads_enabled': true,
        'ads_interstitial_enabled': true,
        'ads_interstitial_action_frequency': _defaultActionFrequency,
        'ads_interstitial_cooldown_seconds': _defaultCooldownSeconds,
        'ads_interstitial_unit_id_android': '',
        'ads_interstitial_unit_id_ios': '',
        'ads_banner_unit_id_android': '',
        'ads_banner_unit_id_ios': '',
        for (final placement in BannerPlacement.values)
          'ads_banner_${placement.name}_enabled': false,
        for (final placement in BannerPlacement.values)
          'ads_banner_${placement.name}_unit_id_android': '',
        for (final placement in BannerPlacement.values)
          'ads_banner_${placement.name}_unit_id_ios': '',
      });
      await remoteConfig.fetchAndActivate();
      _remoteConfigReady = true;
      return true;
    } catch (_) {
      // Si Remote Config no está disponible, la publicidad permanece apagada.
      // El catálogo y el resto de la app siguen funcionando offline.
      _remoteConfigReady = false;
      notifyListeners();
      return false;
    }
  }


  bool get _interstitialEnabled {
    if (!_remoteConfigReady) return false;
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) return false;
    return remoteConfig.getBool('ads_enabled') &&
        remoteConfig.getBool('ads_interstitial_enabled') &&
        _interstitialUnitId.trim().isNotEmpty;
  }

  Future<void> _loadInterstitial() async {
    if (!_isInitialized ||
        !_interstitialEnabled ||
        _isLoadingInterstitial ||
        _interstitialAd != null) {
      return;
    }

    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: _interstitialUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          unawaited(ad.setImmersiveMode(true));
          _isLoadingInterstitial = false;
        },
        onAdFailedToLoad: (_) {
          _interstitialAd = null;
          _isLoadingInterstitial = false;
        },
      ),
    );
  }

  Future<bool> _showInterstitial() async {
    if (_isShowingInterstitial || !_cooldownElapsed) return false;

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }

    final completer = Completer<bool>();
    _interstitialAd = null;
    _isShowingInterstitial = true;
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        unawaited(
          _preferences.setString(
            _lastInterstitialShownAtKey,
            DateTime.now().toIso8601String(),
          ),
        );
      },
      onAdDismissedFullScreenContent: (shownAd) {
        shownAd.dispose();
        _isShowingInterstitial = false;
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (shownAd, _) {
        shownAd.dispose();
        _isShowingInterstitial = false;
        unawaited(_loadInterstitial());
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show();
    return completer.future;
  }

  bool get _cooldownElapsed {
    final raw = _preferences.getString(_lastInterstitialShownAtKey);
    final lastShown = raw == null ? null : DateTime.tryParse(raw);
    return lastShown == null ||
        DateTime.now().difference(lastShown) >= interstitialCooldown;
  }

  String get _interstitialUnitId {
    if (!_remoteConfigReady) return AdMobConfig.interstitialUnitId;
    final configured = _remoteConfig
            ?.getString('ads_interstitial_unit_id_$_platformKey')
            .trim() ??
        '';
    return configured.isEmpty ? AdMobConfig.interstitialUnitId : configured;
  }

  String get _platformKey =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

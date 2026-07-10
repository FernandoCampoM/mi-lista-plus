import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_mob_config.dart';

enum ImportantAdAction {
  countryChanged,
  simulationGenerated,
  simulationShared,
  returnedHomeAfterSeveralMinutes,
}

class AppAdService {
  AppAdService(this._preferences);

  static const _importantActionCountKey = 'ads_important_action_count';
  static const _lastImportantActionKey = 'ads_last_important_action';
  static const _lastDisclaimerInterstitialDateKey =
      'ads_last_disclaimer_interstitial_date';
  static const _lastHomeVisibleAtKey = 'ads_last_home_visible_at';
  static const _importantActionsThreshold = 10;
  static const _returnHomeMinimumDelay = Duration(minutes: 3);

  final SharedPreferences _preferences;
  InterstitialAd? _interstitialAd;
  bool _isInitialized = false;
  bool _isLoadingInterstitial = false;
  bool _isShowingInterstitial = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      unawaited(_loadInterstitial());
    } catch (_) {
      _isInitialized = false;
    }
  }

  Future<void> recordImportantAction(ImportantAdAction action) async {
    if (!_isInitialized) return;

    final currentCount = _preferences.getInt(_importantActionCountKey) ?? 0;
    final nextCount = currentCount + 1;
    await _preferences.setInt(_importantActionCountKey, nextCount);
    await _preferences.setString(_lastImportantActionKey, action.name);

    if (nextCount < _importantActionsThreshold) {
      if (_interstitialAd == null) {
        unawaited(_loadInterstitial());
      }
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
    if (previous == null) return;
    if (now.difference(previous) < _returnHomeMinimumDelay) return;

    await recordImportantAction(
      ImportantAdAction.returnedHomeAfterSeveralMinutes,
    );
  }

  Future<void> showDisclaimerInterstitialOncePerDay() async {
    if (!_isInitialized) return;

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

  Future<void> _loadInterstitial() async {
    if (!_isInitialized || _isLoadingInterstitial || _interstitialAd != null) {
      return;
    }

    _isLoadingInterstitial = true;
    InterstitialAd.load(
      adUnitId: AdMobConfig.interstitialUnitId,
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
    if (_isShowingInterstitial) return false;

    final ad = _interstitialAd;
    if (ad == null) {
      unawaited(_loadInterstitial());
      return false;
    }

    final completer = Completer<bool>();
    _interstitialAd = null;
    _isShowingInterstitial = true;

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
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

  String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}

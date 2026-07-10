import 'package:flutter/foundation.dart';

class AdMobConfig {
  const AdMobConfig._();

  static const _androidBannerTestId =
      'ca-app-pub-3940256099942544/6300978111';
  static const _iosBannerTestId = 'ca-app-pub-3940256099942544/2934735716';
  static const _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4411468910';

  static const _androidBannerProductionId = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER_ID',
  );
  static const _iosBannerProductionId = String.fromEnvironment(
    'ADMOB_IOS_BANNER_ID',
  );
  static const _androidInterstitialProductionId = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL_ID',
  );
  static const _iosInterstitialProductionId = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL_ID',
  );

  static String get bannerUnitId {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosBannerProductionId.isEmpty
          ? _iosBannerTestId
          : _iosBannerProductionId,
      TargetPlatform.android => _androidBannerProductionId.isEmpty
          ? _androidBannerTestId
          : _androidBannerProductionId,
      _ => _androidBannerTestId,
    };
  }

  static String get interstitialUnitId {
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => _iosInterstitialProductionId.isEmpty
          ? _iosInterstitialTestId
          : _iosInterstitialProductionId,
      TargetPlatform.android => _androidInterstitialProductionId.isEmpty
          ? _androidInterstitialTestId
          : _androidInterstitialProductionId,
      _ => _androidInterstitialTestId,
    };
  }
}

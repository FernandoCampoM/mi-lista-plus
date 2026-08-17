import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/services/app_ad_service.dart';
import '../state/app_scope.dart';

class AdaptiveBannerAd extends StatefulWidget {
  const AdaptiveBannerAd({
    this.placement = BannerPlacement.home,
    this.margin = EdgeInsets.zero,
    this.maxHeight = 72,
    super.key,
  });

  final BannerPlacement placement;
  final EdgeInsetsGeometry margin;
  final double maxHeight;

  @override
  State<AdaptiveBannerAd> createState() => _AdaptiveBannerAdState();
}

class _AdaptiveBannerAdState extends State<AdaptiveBannerAd> {
  BannerAd? _bannerAd;
  AppAdService? _adService;
  AdSize? _adSize;
  int? _loadedWidth;
  bool _isLoading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = AppScope.adsOf(context);
    if (!identical(_adService, next)) {
      _adService?.removeListener(_onAdConfigChanged);
      _adService = next;
      _adService?.addListener(_onAdConfigChanged);
    }
  }

  void _onAdConfigChanged() {
    if (!mounted) return;
    _bannerAd?.dispose();
    _bannerAd = null;
    _adSize = null;
    _loadedWidth = null;
    _isLoading = false;
    setState(() {});
  }

  @override
  void dispose() {
    _adService?.removeListener(_onAdConfigChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adService = AppScope.adsOf(context);
    final unitId = adService.bannerUnitId(widget.placement).trim();
    if (!adService.bannerEnabled(widget.placement) || unitId.isEmpty) {
      _bannerAd?.dispose();
      _bannerAd = null;
      _adSize = null;
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.truncate();
        if (width > 0 && width != _loadedWidth && !_isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadAd(width);
          });
        }

        final bannerAd = _bannerAd;
        final adSize = _adSize;
        if (bannerAd == null || adSize == null) {
          return const SizedBox.shrink();
        }

        return Container(
          width: double.infinity,
          height: adSize.height.toDouble().clamp(0, widget.maxHeight).toDouble(),
          margin: widget.margin,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
          child: AdWidget(ad: bannerAd),
        );
      },
    );
  }

  Future<void> _loadAd(int width) async {
    _isLoading = true;
    _loadedWidth = width;

    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (!mounted) return;

    if (size == null) {
      _isLoading = false;
      return;
    }

    final bannerAd = BannerAd(
      adUnitId: AppScope.adsOf(context).bannerUnitId(widget.placement).trim(),
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }

          setState(() {
            _bannerAd?.dispose();
            _bannerAd = ad as BannerAd;
            _adSize = size;
            _isLoading = false;
          });
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          if (!mounted) return;

          setState(() {
            _bannerAd = null;
            _adSize = null;
            _isLoading = false;
          });
        },
      ),
    );

    await bannerAd.load();
  }
}

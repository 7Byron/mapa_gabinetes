import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';
import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_logger.dart';
import '../utils/ad_request.dart';
import '../ad_manager.dart';

/// Serviço de anúncios simplificado para iOS
/// Usa o método tradicional testado sem otimizações complexas
class SimpleAdService extends GetxService {
  static SimpleAdService get to => Get.find<SimpleAdService>();

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  BannerAd? _bannerAd;

  bool get isInterstitialLoaded => _interstitialAd != null;
  bool get isRewardedLoaded => _rewardedAd != null;
  bool get isBannerLoaded => _bannerAd != null;

  @override
  void onInit() {
    super.onInit();
    _loadAds();
  }

  /// Carrega todos os tipos de anúncios
  void _loadAds() {
    AdLogger.info('SimpleAd', 'Loading ads for iOS');
    _loadInterstitial();
    _loadRewarded();
    _loadBanner();
  }

  /// Carrega anúncio intersticial
  void _loadInterstitial() {
    InterstitialAd.load(
      adUnitId: LojaEAdmobConstants.interstitialAdUnitId,
      request: AdRequestFactory.build(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          AdLogger.success('SimpleAd', 'Interstitial loaded successfully');

          // Receita paga
          try {
            (_interstitialAd as dynamic).onPaidEvent = (ad, value) {
              final int micros = (value?.valueMicros ?? 0) as int;
              final String currency = (value?.currencyCode ?? '') as String;
              final String? precision = value?.precision?.toString();
              AdLogger.paid(
                adType: 'Interstitial',
                currencyCode: currency,
                valueMicros: micros,
                precision: precision,
              );
            };
          } catch (_) {}

          _interstitialAd!.fullScreenContentCallback =
              FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              // Registra que um anúncio está sendo exibido
              AdManager.to.appOpenService?.recordAdShown();
              AdLogger.success('SimpleAd', 'Interstitial shown successfully');
            },
            onAdDismissedFullScreenContent: (ad) {
              // Registra que um anúncio foi fechado para prevenir App Open Ad
              AdManager.to.appOpenService?.recordAdDismissed();
              ad.dispose();
              _interstitialAd = null;
              _loadInterstitial();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _interstitialAd = null;
              AdLogger.error('SimpleAd', 'Interstitial show failed: $error');
            },
          );
        },
        onAdFailedToLoad: (error) {
          AdLogger.error('SimpleAd', 'Interstitial failed to load: $error');
          Timer(const Duration(seconds: 10), _loadInterstitial);
        },
      ),
    );
  }

  /// Carrega anúncio recompensado
  void _loadRewarded() {
    RewardedAd.load(
      adUnitId: LojaEAdmobConstants.rewardedAdUnitId,
      request: AdRequestFactory.build(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          AdLogger.success('SimpleAd', 'Rewarded loaded successfully');

          // Receita paga
          try {
            (_rewardedAd as dynamic).onPaidEvent = (ad, value) {
              final int micros = (value?.valueMicros ?? 0) as int;
              final String currency = (value?.currencyCode ?? '') as String;
              final String? precision = value?.precision?.toString();
              AdLogger.paid(
                adType: 'Rewarded',
                currencyCode: currency,
                valueMicros: micros,
                precision: precision,
              );
            };
          } catch (_) {}

          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _rewardedAd = null;
              _loadRewarded();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              _rewardedAd = null;
              AdLogger.error('SimpleAd', 'Rewarded show failed: $error');
            },
          );
        },
        onAdFailedToLoad: (error) {
          AdLogger.error('SimpleAd', 'Rewarded failed to load: $error');
          Timer(const Duration(seconds: 10), _loadRewarded);
        },
      ),
    );
  }

  /// Carrega banner
  void _loadBanner() {
    _bannerAd = BannerAd(
      adUnitId: LojaEAdmobConstants.bannerAdUnitId,
      size: AdSize.banner,
      request: AdRequestFactory.build(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          AdLogger.success('SimpleAd', 'Banner loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          _bannerAd = null;
          AdLogger.error('SimpleAd', 'Banner failed to load: $error');
          Timer(const Duration(seconds: 10), _loadBanner);
        },
      ),
    );

    // Receita paga
    try {
      (_bannerAd as dynamic).onPaidEvent = (ad, value) {
        final int micros = (value?.valueMicros ?? 0) as int;
        final String currency = (value?.currencyCode ?? '') as String;
        final String? precision = value?.precision?.toString();
        AdLogger.paid(
          adType: 'Banner',
          currencyCode: currency,
          valueMicros: micros,
          precision: precision,
        );
      };
    } catch (_) {}

    _bannerAd!.load();
  }

  /// Exibe anúncio intersticial
  bool showInterstitial() {
    if (_interstitialAd == null) {
      AdLogger.warning('SimpleAd', 'No interstitial ad available');
      return false;
    }

    // Registra que um anúncio está sendo exibido ANTES de mostrar
    AdManager.to.appOpenService?.recordAdShown();
    _interstitialAd!.show();
    return true;
  }

  /// Exibe anúncio recompensado
  Future<bool> showRewarded() async {
    if (_rewardedAd == null) {
      AdLogger.warning('SimpleAd', 'No rewarded ad available');
      return false;
    }

    final completer = Completer<bool>();
    bool userEarnedReward = false;

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
      userEarnedReward = true;
      AdLogger.success(
          'SimpleAd', 'User earned reward: ${reward.amount} ${reward.type}');
    });

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        // Registra que um anúncio está sendo exibido
        AdManager.to.appOpenService?.recordAdShown();
        AdLogger.success('SimpleAd', 'Rewarded shown successfully');
      },
      onAdDismissedFullScreenContent: (ad) {
        // Registra que um anúncio foi fechado para prevenir App Open Ad
        AdManager.to.appOpenService?.recordAdDismissed();
        ad.dispose();
        _rewardedAd = null;
        _loadRewarded();
        completer.complete(userEarnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        completer.complete(false);
      },
    );

    return completer.future;
  }

  /// Obtém widget do banner
  Widget? getBannerWidget() {
    if (_bannerAd == null) return null;

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }

  /// Force reload de todos os anúncios
  void forceReload() {
    AdLogger.info('SimpleAd', 'Force reloading all ads');
    _dispose();
    _loadAds();
  }

  /// Dispose interno
  void _dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _bannerAd?.dispose();

    _interstitialAd = null;
    _rewardedAd = null;
    _bannerAd = null;
  }

  @override
  void onClose() {
    _dispose();
    super.onClose();
  }

  /// Status do serviço
  Map<String, dynamic> get status => {
        'interstitial_loaded': isInterstitialLoaded,
        'rewarded_loaded': isRewardedLoaded,
        'banner_loaded': isBannerLoaded,
        'platform': Platform.operatingSystem,
      };
}

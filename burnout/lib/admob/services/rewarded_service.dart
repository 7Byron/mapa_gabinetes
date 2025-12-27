// lib/admob/services/rewarded_service.dart
import 'dart:async';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_logger.dart';
import '../utils/ad_request.dart';
import '../ad_manager.dart';

class RewardedService extends GetxController {
  static const int maxFailedLoadAttempts = 3;
  RewardedAd? _rewardedAd;
  int _loadAttempts = 0;

  bool get isRewardedAdLoaded => _rewardedAd != null;

  Future<void> loadRewardedAd() async {
    if (_loadAttempts >= maxFailedLoadAttempts) {
      AdLogger.warning('RewardedService', 'Máximo de tentativas atingido');
      return;
    }

    await RewardedAd.load(
      adUnitId: LojaEAdmobConstants.rewardedAdUnitId,
      request: AdRequestFactory.build(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          AdLogger.success('RewardedService', 'RewardedAd carregado');
          _rewardedAd = ad;
          _loadAttempts = 0;

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
        },
        onAdFailedToLoad: (error) {
          AdLogger.error('RewardedService', 'Falha ao carregar: $error');
          _rewardedAd = null;
          _loadAttempts++;
        },
      ),
    );
  }

  Future<bool> showRewardedAd() async {
    if (_rewardedAd == null) {
      AdLogger.warning('RewardedService', 'RewardedAd is null');
      return false;
    }

    final completer = Completer<bool>();
    bool userEarnedReward = false;

    // Registra que um anúncio está sendo exibido ANTES de mostrar
    AdManager.to.appOpenService?.recordAdShown();

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AdLogger.success('RewardedService', 'Rewarded ad shown successfully');
      },
      onAdDismissedFullScreenContent: (ad) {
        AdLogger.info('RewardedService', 'Fechado');
        // Registra que um anúncio foi fechado para prevenir App Open Ad
        AdManager.to.appOpenService?.recordAdDismissed();
        ad.dispose();
        loadRewardedAd();
        completer.complete(userEarnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        AdLogger.error('RewardedService', 'Falha ao exibir: $error');
        ad.dispose();
        loadRewardedAd();
        completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        userEarnedReward = true;
        AdLogger.success('RewardedService',
            'Usuário ganhou ${reward.amount} (${reward.type})');
      },
    );

    _rewardedAd = null;
    return completer.future;
  }

  @override
  void onClose() {
    _rewardedAd?.dispose();
    super.onClose();
  }
}

import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'services/banner_ad_controller.dart';
import 'services/rewarded_service.dart';
import 'services/app_open_service.dart';
import 'services/ad_pool_service.dart';
import 'services/simple_ad_service.dart';
import 'services/smart_preloading_service.dart';
import 'utils/ad_logger.dart';
import 'dart:async';
import '../funcoes/platform_utils.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/rotas_paginas.dart';
import 'package:get_storage/get_storage.dart';

class AdManager extends GetxService {
  static AdManager get to => Get.find<AdManager>();

  BannerAdController? bannerController;
  RewardedService? rewardedService;
  AppOpenService? appOpenService;
  SmartPreloadingService? smartPreloadingService;
  AdPoolService? adPoolService; // Android
  SimpleAdService? simpleAdService; // iOS

  // Regras de capping por rota (personalizável)
  // Dica: use os mapas abaixo para overrides finos por rota específica
  final Set<String> interstitialBlockedRoutes = {};
  final Set<String> rewardedBlockedRoutes = {};
  final Map<String, Duration> interstitialCooldownByRoute = {
    RotasPaginas.intro: const Duration(seconds: 45),
    RotasPaginas.historico: const Duration(seconds: 45),
    RotasPaginas.conselhos: const Duration(seconds: 45),
  };
  final Map<String, Duration> rewardedCooldownByRoute = {
    RotasPaginas.intro: const Duration(seconds: 70),
  };
  final Map<String, DateTime> _lastInterstitialByRoute = {};
  final Map<String, DateTime> _lastRewardedByRoute = {};
  String? _lastVisitedRoute;

  // Defaults por tipo de rota
  final Duration defaultTestInterstitialCooldown = const Duration(seconds: 35);
  final Duration defaultListInterstitialCooldown = const Duration(seconds: 45);
  final Duration defaultResultInterstitialCooldown =
      const Duration(seconds: 75); // mais raro em resultados
  final Duration defaultTestRewardedCooldown = const Duration(seconds: 70);

  bool _isTestRoute(String route) {
    if (route.startsWith('/teste')) return true;
    if (route == RotasPaginas.testeStressAgravantes) return true;
    return false;
  }

  bool _isResultRoute(String route) {
    const results = {
      RotasPaginas.resultadoDepressao,
      RotasPaginas.resultadoAnsiedade,
      RotasPaginas.resultadoTesteStress,
      RotasPaginas.resultadoTesteRaiva,
      RotasPaginas.resultadoTesteDependencia,
      RotasPaginas.resultadoTesteAtitude,
      RotasPaginas.resultadoTesteFelicidade,
      RotasPaginas.resultadoTestePersonalidade,
      RotasPaginas.resultadoRelacionamento,
      RotasPaginas.resultadoSorriso,
      RotasPaginas.resultadoAutoConfianca,
    };
    if (results.contains(route)) return true;
    if (route.endsWith('_resultado')) return true;
    if (route.contains('resultado')) return true;
    return false;
  }

  bool _isListRoute(String route) {
    return route == RotasPaginas.intro;
  }

  Future<void> initializeAndConfigure() async {
    AdLogger.info('AdManager', 'Initializing unified AdMob services...');

    // Pula toda a inicialização se o usuário removeu anúncios
    if (MyG.to.adsPago) {
      AdLogger.info('AdManager', 'Skipped initialization (adsPago=true)');
      return;
    }

    // Produção: sem registo de test devices
    final List<String> testIds = const <String>[];
    await MobileAds.instance.updateRequestConfiguration(RequestConfiguration(
      maxAdContentRating: MaxAdContentRating.pg,
      tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
      tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      testDeviceIds: testIds,
    ));

    await MobileAds.instance.initialize();
    AdLogger.success('AdManager', 'MobileAds initialized successfully');

    bannerController = Get.put(BannerAdController());
    rewardedService = Get.put(RewardedService());
    appOpenService = Get.put(AppOpenService());
    smartPreloadingService = Get.put(SmartPreloadingService());

    if (platformIsIOS()) {
      simpleAdService = Get.put(SimpleAdService());
      adPoolService = null;
      AdLogger.info('AdManager', 'iOS detected - SimpleAdService');
    } else if (platformIsAndroid()) {
      adPoolService = Get.put(AdPoolService());
      simpleAdService = null;
      AdLogger.info('AdManager', 'Android detected - AdPoolService');
    }

    // Pré-carrega App Open Ad
    try {
      final box = GetStorage();
      final bool isConsentGiven = box.read('isConsentGiven') ?? false;
      // Política: iOS sem tracking → força NPA; Android depende do consentimento
      final bool npa = platformIsIOS() ? true : !isConsentGiven;
      await appOpenService?.loadAd(nonPersonalized: npa, forceLoad: true);
      AdLogger.info('AdManager', 'AppOpen preloaded (NPA=$npa)');
    } catch (e) {
      AdLogger.error('AdManager', 'Failed to preload AppOpen: $e');
    }

    AdLogger.success('AdManager', 'Ad services initialized');
  }

  void onPageVisit(String pageName) {
    if (pageName.isEmpty) return;
    if (MyG.to.adsPago) return;
    try {
      final service = smartPreloadingService ??
          (Get.isRegistered<SmartPreloadingService>()
              ? Get.find<SmartPreloadingService>()
              : null);
      if (service == null) {
        AdLogger.info(
            'AdManager', 'onPageVisit skipped (service not initialized)');
        return;
      }
      service.onPageVisit(pageName);
      AdLogger.info('AdManager', 'Page visit registered: $pageName');

      // Heurística leve: mostrar interstitial na transição natural
      // Resultado/Teste -> Lista (intro), apenas Android (iOS usa SimpleAdService)
      final String? prev = _lastVisitedRoute;
      _lastVisitedRoute = pageName;
      if (platformIsAndroid() && prev != null) {
        final bool fromResultToList =
            _isResultRoute(prev) && _isListRoute(pageName);
        final bool fromTestToList =
            _isTestRoute(prev) && _isListRoute(pageName);
        if (fromResultToList || fromTestToList) {
          // Respeita cooldowns internos
          try {
            showInterstitialAd();
          } catch (_) {}
        }
      }
    } catch (e) {
      AdLogger.error('AdManager', 'Error registering page visit: $e');
    }
  }

  bool get isHealthy {
    try {
      final base = Get.isRegistered<BannerAdController>() &&
          Get.isRegistered<SmartPreloadingService>();
      if (platformIsIOS()) {
        return base && Get.isRegistered<SimpleAdService>();
      } else {
        return base && Get.isRegistered<AdPoolService>();
      }
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> get status {
    final baseStatus = {
      'healthy': isHealthy,
      'banner_loaded': Get.isRegistered<BannerAdController>()
          ? (bannerController?.isLoaded.value ?? false)
          : false,
      'platform': platformOperatingSystem(),
      'timestamp': DateTime.now().toIso8601String(),
      'smart_preloading': smartPreloadingService?.statistics ?? const {},
    };

    if (platformIsIOS() && simpleAdService != null) {
      return {
        ...baseStatus,
        'simple_ad_status': simpleAdService!.status,
        'service_type': 'SimpleAdService',
      };
    } else if (adPoolService != null) {
      return {
        ...baseStatus,
        'pool_status': adPoolService!.poolStatus,
        'pool_performance': adPoolService!.performanceMetrics,
        'service_type': 'AdPoolService',
      };
    }
    return {...baseStatus, 'error': 'No ad service initialized'};
  }

  bool showInterstitialAd({bool ignoreCooldown = false}) {
    // Gate por rota
    final String route = Get.currentRoute;
    // Interstitials: permitir durante o teste, mas com cooldown; bloquear em formulários críticos se necessário
    if (interstitialBlockedRoutes.contains(route)) {
      AdLogger.info('AdManager', 'Interstitial blocked on route: $route');
      return false;
    }

    // Se ignoreCooldown é true, permite mostrar anúncios programados mesmo com cooldown ativo
    if (!ignoreCooldown) {
      Duration? cooldown = interstitialCooldownByRoute[route];
      if (cooldown == null) {
        if (_isTestRoute(route)) {
          cooldown = defaultTestInterstitialCooldown;
        } else if (_isResultRoute(route)) {
          cooldown = defaultResultInterstitialCooldown;
        } else if (_isListRoute(route)) {
          cooldown = defaultListInterstitialCooldown;
        }
      }
      if (cooldown != null) {
        final last = _lastInterstitialByRoute[route];
        if (last != null &&
            DateTime.now().difference(last).compareTo(cooldown) < 0) {
          AdLogger.info('AdManager', 'Interstitial cooldown active on $route');
          return false;
        }
      }
    } else {
      AdLogger.info(
          'AdManager', 'Interstitial cooldown ignored (programmed ad)');
    }

    bool result = false;
    if (platformIsIOS() && simpleAdService != null) {
      result = simpleAdService!.showInterstitial();
    } else if (adPoolService != null) {
      result = adPoolService!.showInterstitialAd();
    }
    if (result) {
      _lastInterstitialByRoute[route] = DateTime.now();
    }
    return result;
  }

  Future<void> loadInterstitialAd() async {
    if (platformIsIOS() && simpleAdService != null) {
      simpleAdService!.forceReload();
    } else if (adPoolService != null) {
      await adPoolService!.forceReload();
    }
  }

  bool get hasInterstitialAd {
    if (platformIsIOS() && simpleAdService != null) {
      return simpleAdService!.isInterstitialLoaded;
    } else if (adPoolService != null) {
      return adPoolService!.poolStatus['interstitial_count'] > 0;
    }
    return false;
  }

  Future<bool> showRewardedAd() async {
    // Gate por rota
    final String route = Get.currentRoute;
    if (rewardedBlockedRoutes.contains(route)) {
      AdLogger.info('AdManager', 'Rewarded blocked on route: $route');
      return false;
    }
    Duration? cooldown = rewardedCooldownByRoute[route];
    if (cooldown == null && _isTestRoute(route)) {
      cooldown = defaultTestRewardedCooldown;
    }
    if (cooldown != null) {
      final last = _lastRewardedByRoute[route];
      if (last != null &&
          DateTime.now().difference(last).compareTo(cooldown) < 0) {
        AdLogger.info('AdManager', 'Rewarded cooldown active on $route');
        return false;
      }
    }

    if (platformIsIOS() && simpleAdService != null) {
      final ok = await simpleAdService!.showRewarded();
      if (ok) _lastRewardedByRoute[route] = DateTime.now();
      return ok;
    } else if (adPoolService != null) {
      var result = await adPoolService!.showRewardedAd();
      if (!result) {
        result =
            await (rewardedService?.showRewardedAd() ?? Future.value(false));
      }
      if (result) _lastRewardedByRoute[route] = DateTime.now();
      return result;
    }
    return false;
  }

  bool get hasRewardedAd {
    if (platformIsIOS() && simpleAdService != null) {
      return simpleAdService!.isRewardedLoaded;
    } else if (adPoolService != null) {
      return adPoolService!.poolStatus['rewarded_count'] > 0;
    } else if (rewardedService != null) {
      return rewardedService!.isRewardedAdLoaded;
    }
    return false;
  }

  Future<void> loadRewardedAd() async {
    if (platformIsIOS() && simpleAdService != null) {
      simpleAdService!.forceReload();
    } else {
      await (rewardedService?.loadRewardedAd() ?? Future.value());
    }
  }

  void resetAdAttempts() {
    if (platformIsIOS() && simpleAdService != null) {
      simpleAdService!.forceReload();
    } else if (adPoolService != null) {
      adPoolService!.resetAttempts();
    }
  }

  Future<void> forceReloadAll() async {
    if (platformIsIOS() && simpleAdService != null) {
      simpleAdService!.forceReload();
    } else if (adPoolService != null) {
      await adPoolService!.forceReload();
    }
  }

  Map<String, dynamic> get performanceMetrics {
    final base = {
      'platform': platformOperatingSystem(),
      'healthy': isHealthy,
      'smart_preloading_stats': smartPreloadingService?.statistics ?? const {},
      'banner_status': Get.isRegistered<BannerAdController>()
          ? (bannerController?.status ?? const {})
          : const {},
    };
    if (platformIsAndroid() && adPoolService != null) {
      base['pool_performance'] = adPoolService!.performanceMetrics;
    }
    return base;
  }

  // No-op helpers para manter API compatível com Web (usados no menu de debug)
  void showBottomBanner() {}
  void removeBottomBanner() {}
}

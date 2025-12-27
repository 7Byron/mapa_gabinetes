import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_logger.dart';
import 'dart:async';
import '../utils/ad_request.dart';

class BannerAdController extends GetxService {
  final Rx<BannerAd?> _bannerAd = Rx<BannerAd?>(null);
  final RxBool isLoaded = false.obs;
  final RxInt bannerKey = 0.obs; // Força a recriação do widget
  final RxString currentPage = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isDisposed = false.obs;

  // Controle de lifecycle melhorado
  Timer? _loadingTimeoutTimer;
  Timer? _retryTimer;
  String? _pendingPageLoad;
  int _retryAttempts = 0;
  static const int maxRetryAttempts = 3;
  static const Duration loadingTimeout = Duration(seconds: 10);
  static const Duration retryDelay = Duration(seconds: 5);

  // Cache de tamanhos para otimizar performance
  final Map<int, AnchoredAdaptiveBannerAdSize> _sizeCache = {};

  BannerAd? get bannerAd => _bannerAd.value;

  @override
  void onInit() {
    super.onInit();
    AdLogger.info('BannerController', 'Controller initialized');
  }

  /// Carrega banner otimizado com melhor gestão de lifecycle
  /// [collapsible] - Se fornecido ("top" ou "bottom"), cria um banner collapsible
  /// Recomendação AdMob: usar "bottom" para banners no bottomNavigationBar
  Future<void> loadBannerAd(
      {required String pageName, String? collapsible}) async {
    if (isDisposed.value) {
      AdLogger.warning(
          'BannerController', 'Controller disposed, ignoring load request');
      return;
    }

    if (isLoading.value) {
      AdLogger.info('BannerController',
          'Already loading banner, queuing request for $pageName');
      _pendingPageLoad = pageName;
      return;
    }

    // Se já temos banner para a mesma página, não recarrega
    if (isLoaded.value &&
        currentPage.value == pageName &&
        _bannerAd.value != null) {
      AdLogger.info('BannerController', 'Banner already loaded for $pageName');
      return;
    }

    isLoading.value = true;
    _pendingPageLoad = null;

    AdLogger.info('BannerController', 'Loading banner for $pageName');

    try {
      // Cancela timers anteriores
      _cancelTimers();

      // Dispose banner anterior de forma segura
      await _safeDisposeBannerAd();

      // Obtém tamanho do banner (com cache)
      final AnchoredAdaptiveBannerAdSize? size = await _getBannerSize();
      if (size == null) {
        AdLogger.error('BannerController', 'Failed to get banner size');
        _handleLoadFailure();
        return;
      }

      // Configura timeout
      _setupLoadingTimeout();

      // Carrega novo banner
      await _loadNewBanner(size, pageName, collapsible: collapsible);
    } catch (e) {
      AdLogger.error('BannerController', 'Exception during banner load: $e');
      _handleLoadFailure();
    }
  }

  /// Obtém tamanho do banner com cache
  Future<AnchoredAdaptiveBannerAdSize?> _getBannerSize() async {
    final int screenWidth = Get.width.truncate();

    // Verifica cache
    if (_sizeCache.containsKey(screenWidth)) {
      return _sizeCache[screenWidth];
    }

    final AnchoredAdaptiveBannerAdSize? size =
        await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
            screenWidth);

    if (size != null) {
      _sizeCache[screenWidth] = size;
      AdLogger.info(
          'BannerController', 'Banner size cached for width $screenWidth');
    }

    return size;
  }

  /// Carrega novo banner
  Future<void> _loadNewBanner(
      AnchoredAdaptiveBannerAdSize size, String pageName,
      {String? collapsible}) async {
    final bannerAd = BannerAd(
      adUnitId: LojaEAdmobConstants.bannerAdUnitId,
      size: size,
      request: AdRequestFactory.build(collapsible: collapsible),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (isDisposed.value) {
            ad.dispose();
            return;
          }

          AdLogger.success(
              'BannerController', 'Banner loaded successfully for $pageName');

          _bannerAd.value = ad as BannerAd;
          isLoaded.value = true;
          currentPage.value = pageName;
          bannerKey.value++;
          _retryAttempts = 0;

          // Receita paga (compatível com versões sem API pública)
          try {
            (ad as dynamic).onPaidEvent = (adObj, value) {
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

          _completeLoading();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          AdLogger.error('BannerController',
              'Banner failed to load for $pageName: ${error.code} - ${error.message}');

          _bannerAd.value = null;
          isLoaded.value = false;
          currentPage.value = '';

          _handleLoadFailure();
        },
        onAdOpened: (ad) {
          AdLogger.info('BannerController', 'Banner opened');
        },
        onAdClosed: (ad) {
          AdLogger.info('BannerController', 'Banner closed');
        },
        onAdImpression: (ad) {
          AdLogger.info('BannerController', 'Banner impression recorded');
        },
      ),
    );

    await bannerAd.load();
  }

  /// Configura timeout para carregamento
  void _setupLoadingTimeout() {
    _loadingTimeoutTimer = Timer(loadingTimeout, () {
      if (isLoading.value && !isLoaded.value) {
        AdLogger.warning('BannerController', 'Banner loading timeout');
        _handleLoadFailure();
      }
    });
  }

  /// Lida com falha no carregamento
  void _handleLoadFailure() {
    _retryAttempts++;

    if (_retryAttempts < maxRetryAttempts) {
      AdLogger.info('BannerController',
          'Scheduling retry ($_retryAttempts/$maxRetryAttempts)');
      _retryTimer = Timer(retryDelay, () {
        if (!isDisposed.value && _pendingPageLoad != null) {
          final pageName = _pendingPageLoad!;
          _pendingPageLoad = null;
          loadBannerAd(pageName: pageName);
        } else if (!isDisposed.value && currentPage.value.isNotEmpty) {
          loadBannerAd(pageName: currentPage.value);
        }
      });
    } else {
      AdLogger.error('BannerController', 'Max retry attempts reached');
      _completeLoading();
    }
  }

  /// Completa processo de carregamento
  void _completeLoading() {
    isLoading.value = false;
    _cancelTimers();

    // Processa pending request se houver
    if (_pendingPageLoad != null) {
      final pageName = _pendingPageLoad!;
      _pendingPageLoad = null;
      Future.delayed(const Duration(milliseconds: 100), () {
        loadBannerAd(pageName: pageName);
      });
    }
  }

  /// Cancela todos os timers
  void _cancelTimers() {
    _loadingTimeoutTimer?.cancel();
    _loadingTimeoutTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Dispose banner de forma segura
  Future<void> _safeDisposeBannerAd() async {
    if (_bannerAd.value != null) {
      try {
        await _bannerAd.value!.dispose();
        AdLogger.info('BannerController', 'Banner disposed safely');
      } catch (e) {
        AdLogger.error('BannerController', 'Error disposing banner: $e');
      }

      _bannerAd.value = null;
      isLoaded.value = false;
      currentPage.value = '';
      bannerKey.value++;
    }
  }

  /// **✅ Remove o Banner antes de carregar outro (otimizado)**
  Future<void> disposeBannerAd() async {
    await _safeDisposeBannerAd();
  }

  /// Força reload do banner atual
  Future<void> reloadCurrentBanner() async {
    if (currentPage.value.isNotEmpty) {
      AdLogger.info(
          'BannerController', 'Reloading banner for ${currentPage.value}');
      await loadBannerAd(pageName: currentPage.value);
    }
  }

  /// Limpa cache de tamanhos
  void clearSizeCache() {
    _sizeCache.clear();
    AdLogger.info('BannerController', 'Size cache cleared');
  }

  /// Verifica se banner está válido
  bool get isBannerValid =>
      isLoaded.value && _bannerAd.value != null && !isDisposed.value;

  /// Status detalhado do controller
  Map<String, dynamic> get status => {
        'is_loaded': isLoaded.value,
        'is_loading': isLoading.value,
        'is_disposed': isDisposed.value,
        'current_page': currentPage.value,
        'banner_key': bannerKey.value,
        'retry_attempts': _retryAttempts,
        'max_retry_attempts': maxRetryAttempts,
        'has_pending_load': _pendingPageLoad != null,
        'pending_page': _pendingPageLoad,
        'cache_size': _sizeCache.length,
        'is_valid': isBannerValid,
        'timestamp': DateTime.now().toIso8601String(),
      };

  @override
  void onClose() {
    AdLogger.info('BannerController', 'Controller closing');
    isDisposed.value = true;
    _cancelTimers();
    _safeDisposeBannerAd();
    clearSizeCache();
    super.onClose();
  }
}

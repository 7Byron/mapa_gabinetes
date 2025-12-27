import 'dart:async';
import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get/get.dart';

import '../../a_config_app/loja_admob_constants.dart';
import '../utils/ad_logger.dart';
import '../utils/ad_request.dart';
import '../ad_manager.dart';

/// Serviço de pool de anúncios otimizado para melhor performance
/// Mantém anúncios pré-carregados com proteções balanceadas entre iOS e Android
class AdPoolService extends GetxService {
  static AdPoolService get to => Get.find<AdPoolService>();

  // Pools para diferentes tipos de anúncios
  final List<InterstitialAd> _interstitialPool = [];
  final List<RewardedAd> _rewardedPool = [];
  // Tracking de quando cada anúncio foi carregado (para expiração)
  final Map<InterstitialAd, DateTime> _interstitialLoadTimes = {};
  final Map<RewardedAd, DateTime> _rewardedLoadTimes = {};
  final Map<String, DateTime> _lastLoadTimes = {};
  final Map<String, DateTime> _lastShowTimes = {};
  final Map<String, int> _loadAttempts = {};
  final Map<String, int> _fillRate = {}; // Novo: tracking de fill rate

  // Configurações do pool otimizadas
  static const int maxInterstitialAds =
      4; // Aumentado para melhor disponibilidade
  static const int maxRewardedAds = 3;
  static const int maxRetryAttempts = 3;
  static const Duration cooldownDuration = Duration(minutes: 1);
  // Recomendação AdMob: anúncios pré-carregados expiram após 1 hora
  static const Duration maxAdCacheDuration = Duration(hours: 1);

  // Configurações específicas para iOS - OTIMIZADAS
  static const int iosMaxRetryAttempts = 4;
  static const Duration iosMinLoadInterval =
      Duration(seconds: 3); // Reduzido de 5s para 3s
  static const Duration iosMinShowInterval =
      Duration(seconds: 5); // Reduzido de 10s para 5s
  static const Duration iosRateLimitCooldown =
      Duration(seconds: 20); // Reduzido de 30s para 20s
  static const Duration iosNetworkRetryCooldown =
      Duration(seconds: 2); // Novo: retry rápido para problemas de rede

  // Propriedades específicas para iOS
  bool get _isIOSSimulator =>
      Platform.isIOS &&
      (Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
          Platform.environment.containsKey('SIMULATOR_ROOT'));

  bool get _isIOS => Platform.isIOS;

  int get _maxAttempts => _isIOS ? iosMaxRetryAttempts : maxRetryAttempts;

  Duration get _cooldownDuration =>
      _isIOS ? iosMinLoadInterval : cooldownDuration;

  @override
  void onInit() {
    super.onInit();
    _initializeMetrics();
    _initializePools();
    // Inicia limpeza periódica de anúncios expirados
    _startExpirationCleanup();
  }

  /// Inicia limpeza periódica de anúncios expirados (a cada 5 minutos)
  void _startExpirationCleanup() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupExpiredAds();
    });
  }

  /// Remove anúncios expirados do pool (recomendação AdMob: 1 hora)
  void _cleanupExpiredAds() {
    final now = DateTime.now();
    int expiredInterstitials = 0;
    int expiredRewarded = 0;

    // Limpa intersticiais expirados
    _interstitialPool.removeWhere((ad) {
      final loadTime = _interstitialLoadTimes[ad];
      if (loadTime != null) {
        final age = now.difference(loadTime);
        if (age > maxAdCacheDuration) {
          expiredInterstitials++;
          ad.dispose();
          _interstitialLoadTimes.remove(ad);
          AdLogger.info('AdPool',
              'Interstitial expired (age: ${age.inMinutes} min), removed from pool');
          return true;
        }
      }
      return false;
    });

    // Limpa recompensados expirados
    _rewardedPool.removeWhere((ad) {
      final loadTime = _rewardedLoadTimes[ad];
      if (loadTime != null) {
        final age = now.difference(loadTime);
        if (age > maxAdCacheDuration) {
          expiredRewarded++;
          ad.dispose();
          _rewardedLoadTimes.remove(ad);
          AdLogger.info('AdPool',
              'Rewarded expired (age: ${age.inMinutes} min), removed from pool');
          return true;
        }
      }
      return false;
    });

    if (expiredInterstitials > 0 || expiredRewarded > 0) {
      AdLogger.info('AdPool',
          'Cleaned up expired ads: $expiredInterstitials interstitials, $expiredRewarded rewarded');
      // Recarrega pools se necessário
      if (_interstitialPool.length < maxInterstitialAds) {
        _fillInterstitialPool();
      }
      if (_rewardedPool.length < maxRewardedAds) {
        _fillRewardedPool();
      }
    }
  }

  /// Inicializa métricas de performance
  void _initializeMetrics() {
    _fillRate['interstitial'] = 0;
    _fillRate['rewarded'] = 0;
    _fillRate['interstitial_successful'] = 0;
    _fillRate['rewarded_successful'] = 0;
    _fillRate['interstitial_total'] = 0;
    _fillRate['rewarded_total'] = 0;

    AdLogger.info('AdPool', 'Performance metrics initialized');
  }

  /// Inicializa os pools carregando anúncios iniciais
  void _initializePools() {
    AdLogger.info('AdPool', 'Initializing optimized ad pools');

    // Log específico para iOS com configurações otimizadas
    if (_isIOS) {
      AdLogger.info('AdPool', 'iOS detected - using optimized settings');
      AdLogger.info('AdPool',
          'iOS optimized: loadInterval=${iosMinLoadInterval.inSeconds}s, showInterval=${iosMinShowInterval.inSeconds}s, maxAttempts=$iosMaxRetryAttempts');
    }

    // Inicializa contadores
    _loadAttempts['interstitial'] = 0;
    _loadAttempts['rewarded'] = 0;

    // Carrega pools iniciais com delay escalonado para evitar throttling
    _fillInterstitialPool();
    Future.delayed(
        const Duration(milliseconds: 500), () => _fillRewardedPool());
  }

  /// Preenche o pool de anúncios intersticiais
  Future<void> _fillInterstitialPool() async {
    while (_interstitialPool.length < maxInterstitialAds) {
      if (_shouldRespectCooldown('interstitial')) {
        AdLogger.info(
            'AdPool', 'Interstitial cooldown active, scheduling retry');
        // Agenda retry automático
        Future.delayed(_cooldownDuration, () => _fillInterstitialPool());
        break;
      }

      if (_hasReachedMaxAttempts('interstitial')) {
        AdLogger.warning(
            'AdPool', 'Interstitial max attempts reached, scheduling reset');
        _scheduleAttemptsReset('interstitial');
        break;
      }

      await _loadInterstitialAd();

      // Pequeno delay entre carregamentos para evitar throttling
      if (_interstitialPool.length < maxInterstitialAds) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Preenche o pool de anúncios recompensados
  Future<void> _fillRewardedPool() async {
    while (_rewardedPool.length < maxRewardedAds) {
      if (_shouldRespectCooldown('rewarded')) {
        AdLogger.info('AdPool', 'Rewarded cooldown active, scheduling retry');
        Future.delayed(_cooldownDuration, () => _fillRewardedPool());
        break;
      }

      if (_hasReachedMaxAttempts('rewarded')) {
        AdLogger.warning(
            'AdPool', 'Rewarded max attempts reached, scheduling reset');
        _scheduleAttemptsReset('rewarded');
        break;
      }

      await _loadRewardedAd();

      // Pequeno delay entre carregamentos
      if (_rewardedPool.length < maxRewardedAds) {
        await Future.delayed(const Duration(milliseconds: 200));
      }
    }
  }

  /// Verifica se deve respeitar o cooldown (otimizado)
  bool _shouldRespectCooldown(String adType) {
    final lastLoad = _lastLoadTimes[adType];
    if (lastLoad == null) return false;

    final timeSinceLastLoad = DateTime.now().difference(lastLoad);
    final shouldCooldown = timeSinceLastLoad < _cooldownDuration;

    // Log otimizado - só em caso de cooldown longo
    if (_isIOS && shouldCooldown && timeSinceLastLoad.inSeconds > 2) {
      AdLogger.info('AdPool',
          'iOS cooldown for $adType: ${timeSinceLastLoad.inSeconds}s remaining');
    }

    return shouldCooldown;
  }

  /// Verifica se pode exibir anúncio (otimizado para iOS)
  bool _canShowAd(String adType) {
    if (!_isIOS) return true;

    final lastShow = _lastShowTimes[adType];
    if (lastShow == null) return true;

    final timeSinceLastShow = DateTime.now().difference(lastShow);
    final canShow = timeSinceLastShow >= iosMinShowInterval;

    // Log otimizado
    if (!canShow && timeSinceLastShow.inSeconds > 2) {
      AdLogger.info('AdPool',
          'iOS show cooldown for $adType: ${iosMinShowInterval.inSeconds - timeSinceLastShow.inSeconds}s remaining');
    }

    return canShow;
  }

  /// Verifica se atingiu o máximo de tentativas
  bool _hasReachedMaxAttempts(String adType) {
    final attempts = _loadAttempts[adType] ?? 0;
    return attempts >= _maxAttempts;
  }

  /// Detecta se é erro de rate limiting do iOS (melhorado)
  bool _isIOSRateLimitError(LoadAdError error) {
    final message = error.message.toLowerCase();
    return message.contains('too many recently failed requests') ||
        message.contains('rate limit') ||
        message.contains('request was throttled') ||
        message.contains('quota exceeded') ||
        (error.code == 0 && message.contains('internal error'));
  }

  /// Detecta se é erro de conectividade (novo)
  bool _isNetworkError(LoadAdError error) {
    final message = error.message.toLowerCase();
    return message.contains('network connection') ||
        message.contains('cannot parse response') ||
        message.contains('no internet') ||
        message.contains('timeout') ||
        message.contains('connection failed');
  }

  /// Atualiza métricas de performance
  void _updateMetrics(String adType, bool successful) {
    _fillRate['${adType}_total'] = (_fillRate['${adType}_total'] ?? 0) + 1;
    if (successful) {
      _fillRate['${adType}_successful'] =
          (_fillRate['${adType}_successful'] ?? 0) + 1;
    }

    final total = _fillRate['${adType}_total'] ?? 1;
    final successfulCount = _fillRate['${adType}_successful'] ?? 0;
    final rate = (successfulCount / total * 100).round();

    _fillRate[adType] = rate;

    if (total % 10 == 0) {
      // Log a cada 10 tentativas
      AdLogger.info(
          'AdPool', '$adType fill rate: $rate% ($successfulCount/$total)');
    }
  }

  /// Carrega um anúncio intersticial para o pool (otimizado)
  Future<void> _loadInterstitialAd() async {
    final completer = Completer<void>();

    void attemptLoad() {
      _loadAttempts['interstitial'] = (_loadAttempts['interstitial'] ?? 0) + 1;
      final currentAttempt = _loadAttempts['interstitial']!;

      AdLogger.info('AdPool',
          'Loading Interstitial (attempt $currentAttempt/$_maxAttempts)');

      InterstitialAd.load(
        adUnitId: LojaEAdmobConstants.interstitialAdUnitId,
        request: AdRequestFactory.build(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            final loadTime = DateTime.now();
            _interstitialPool.add(ad);
            _interstitialLoadTimes[ad] =
                loadTime; // Track load time para expiração
            _lastLoadTimes['interstitial'] = loadTime;
            _loadAttempts['interstitial'] = 0; // Reset attempts on success
            _updateMetrics('interstitial', true);
            AdLogger.success('AdPool',
                'Interstitial loaded successfully (Pool: ${_interstitialPool.length}/$maxInterstitialAds)');
            // Receita paga
            try {
              (ad as dynamic).onPaidEvent = (adObj, value) {
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
            completer.complete();
          },
          onAdFailedToLoad: (error) {
            _updateMetrics('interstitial', false);
            AdLogger.error('AdPool',
                'Interstitial failed (attempt $currentAttempt/$_maxAttempts): ${error.code} - ${error.message}');

            // Tratamento otimizado de erros
            if (_isIOS && _isIOSRateLimitError(error)) {
              AdLogger.warning(
                  'AdPool', 'iOS rate limit detected - backing off');
              _scheduleAttemptsReset('interstitial');
              completer.complete();
              return;
            }

            // Retry rápido para erros de conectividade
            if (_isNetworkError(error) && currentAttempt < _maxAttempts) {
              AdLogger.info('AdPool', 'Network error - fast retry');
              Timer(iosNetworkRetryCooldown, attemptLoad);
              return;
            }

            // Retry normal
            if (currentAttempt < _maxAttempts) {
              final delay = _isIOS
                  ? Duration(seconds: 1 + currentAttempt) // Delay mais rápido
                  : Duration(seconds: currentAttempt * 2);
              AdLogger.info('AdPool', 'Retrying in ${delay.inSeconds}s');
              Timer(delay, attemptLoad);
            } else {
              if (_isIOS) {
                _scheduleAttemptsReset('interstitial');
              }
              completer.complete();
            }
          },
        ),
      );
    }

    attemptLoad();
    return completer.future;
  }

  /// Carrega um anúncio recompensado para o pool (otimizado)
  Future<void> _loadRewardedAd() async {
    final completer = Completer<void>();

    void attemptLoad() {
      _loadAttempts['rewarded'] = (_loadAttempts['rewarded'] ?? 0) + 1;
      final currentAttempt = _loadAttempts['rewarded']!;

      AdLogger.info(
          'AdPool', 'Loading Rewarded (attempt $currentAttempt/$_maxAttempts)');

      RewardedAd.load(
        adUnitId: LojaEAdmobConstants.rewardedAdUnitId,
        request: AdRequestFactory.build(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            final loadTime = DateTime.now();
            _rewardedPool.add(ad);
            _rewardedLoadTimes[ad] = loadTime; // Track load time para expiração
            _lastLoadTimes['rewarded'] = loadTime;
            _loadAttempts['rewarded'] = 0;
            _updateMetrics('rewarded', true);
            AdLogger.success('AdPool',
                'Rewarded loaded successfully (Pool: ${_rewardedPool.length}/$maxRewardedAds)');
            // Receita paga
            try {
              (ad as dynamic).onPaidEvent = (adObj, value) {
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
            completer.complete();
          },
          onAdFailedToLoad: (error) {
            _updateMetrics('rewarded', false);
            AdLogger.error('AdPool',
                'Rewarded failed (attempt $currentAttempt/$_maxAttempts): ${error.code} - ${error.message}');

            // Tratamento similar ao intersticial
            if (_isIOS && _isIOSRateLimitError(error)) {
              AdLogger.warning(
                  'AdPool', 'iOS rate limit detected - backing off');
              _scheduleAttemptsReset('rewarded');
              completer.complete();
              return;
            }

            if (_isNetworkError(error) && currentAttempt < _maxAttempts) {
              AdLogger.info('AdPool', 'Network error - fast retry');
              Timer(iosNetworkRetryCooldown, attemptLoad);
              return;
            }

            if (currentAttempt < _maxAttempts) {
              final delay = _isIOS
                  ? Duration(seconds: 1 + currentAttempt)
                  : Duration(seconds: currentAttempt * 2);
              Timer(delay, attemptLoad);
            } else {
              if (_isIOS) {
                _scheduleAttemptsReset('rewarded');
              }
              completer.complete();
            }
          },
        ),
      );
    }

    attemptLoad();
    return completer.future;
  }

  /// Agenda reset automático de tentativas (otimizado)
  void _scheduleAttemptsReset(String adType) {
    final resetDelay = _isIOS ? iosRateLimitCooldown : cooldownDuration;

    AdLogger.info(
        'AdPool', 'Scheduling $adType reset in ${resetDelay.inSeconds}s');

    Timer(resetDelay, () {
      _loadAttempts[adType] = 0;
      _lastLoadTimes.remove(adType);
      AdLogger.info('AdPool', 'Reset attempts for $adType - resuming loading');

      // Tenta preencher o pool novamente
      if (adType == 'interstitial') {
        _fillInterstitialPool();
      } else if (adType == 'rewarded') {
        _fillRewardedPool();
      }
    });
  }

  /// Obtém um anúncio intersticial do pool
  InterstitialAd? getInterstitialAd() {
    // Remove anúncios expirados antes de verificar disponibilidade
    _cleanupExpiredAds();

    if (_interstitialPool.isEmpty) {
      AdLogger.warning(
          'AdPool', 'Interstitial pool empty - background reload triggered');
      _fillInterstitialPool(); // Recarrega em background
      return null;
    }

    final ad = _interstitialPool.removeAt(0);
    _interstitialLoadTimes.remove(ad); // Remove tracking quando anúncio é usado
    AdLogger.info('AdPool',
        'Interstitial provided (Pool: ${_interstitialPool.length}/$maxInterstitialAds)');

    // Recarrega um novo anúncio em background (respeitando cooldowns)
    Future.delayed(
        const Duration(milliseconds: 100), () => _fillInterstitialPool());

    return ad;
  }

  /// Obtém um anúncio recompensado do pool
  RewardedAd? getRewardedAd() {
    // Remove anúncios expirados antes de verificar disponibilidade
    _cleanupExpiredAds();

    if (_rewardedPool.isEmpty) {
      AdLogger.warning(
          'AdPool', 'Rewarded pool empty - background reload triggered');
      _fillRewardedPool(); // Recarrega em background
      return null;
    }

    final ad = _rewardedPool.removeAt(0);
    _rewardedLoadTimes.remove(ad); // Remove tracking quando anúncio é usado
    AdLogger.info('AdPool',
        'Rewarded provided (Pool: ${_rewardedPool.length}/$maxRewardedAds)');

    // Recarrega um novo anúncio em background
    Future.delayed(
        const Duration(milliseconds: 100), () => _fillRewardedPool());

    return ad;
  }

  /// Exibe um anúncio intersticial do pool (otimizado)
  bool showInterstitialAd() {
    // Verifica cooldown específico para iOS
    if (!_canShowAd('interstitial')) {
      final lastShow = _lastShowTimes['interstitial'];
      if (lastShow != null) {
        final remainingTime =
            iosMinShowInterval - DateTime.now().difference(lastShow);
        if (remainingTime.inSeconds > 1) {
          AdLogger.info('AdPool',
              'iOS show cooldown active. Wait ${remainingTime.inSeconds}s');
        }
      }
      return false;
    }

    final ad = getInterstitialAd();
    if (ad == null) {
      AdLogger.warning('AdPool', 'No interstitial ad available');
      return false;
    }

    _lastShowTimes['interstitial'] = DateTime.now();

    // Registra que um anúncio está sendo exibido ANTES de mostrar
    AdManager.to.appOpenService?.recordAdShown();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AdLogger.success('AdPool', 'Interstitial shown successfully');
      },
      onAdDismissedFullScreenContent: (ad) {
        // Registra que um anúncio foi fechado para prevenir App Open Ad
        AdManager.to.appOpenService?.recordAdDismissed();
        ad.dispose();
        AdLogger.info('AdPool', 'Interstitial dismissed');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        AdLogger.error('AdPool', 'Interstitial show failed: $error');
      },
    );

    ad.show();
    return true;
  }

  /// Exibe um anúncio recompensado do pool (otimizado)
  Future<bool> showRewardedAd() async {
    if (!_canShowAd('rewarded')) {
      final lastShow = _lastShowTimes['rewarded'];
      if (lastShow != null) {
        final remainingTime =
            iosMinShowInterval - DateTime.now().difference(lastShow);
        if (remainingTime.inSeconds > 1) {
          AdLogger.info('AdPool',
              'iOS show cooldown active. Wait ${remainingTime.inSeconds}s');
        }
      }
      return false;
    }

    final ad = getRewardedAd();
    if (ad == null) {
      AdLogger.warning('AdPool', 'No rewarded ad available');
      return false;
    }

    _lastShowTimes['rewarded'] = DateTime.now();

    final completer = Completer<bool>();
    bool userEarnedReward = false;

    // Registra que um anúncio está sendo exibido ANTES de mostrar
    AdManager.to.appOpenService?.recordAdShown();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        AdLogger.success('AdPool', 'Rewarded shown successfully');
      },
      onAdDismissedFullScreenContent: (ad) {
        // Registra que um anúncio foi fechado para prevenir App Open Ad
        AdManager.to.appOpenService?.recordAdDismissed();
        ad.dispose();
        AdLogger.info('AdPool', 'Rewarded dismissed');
        completer.complete(userEarnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        AdLogger.error('AdPool', 'Rewarded show failed: $error');
        completer.complete(false);
      },
    );

    ad.show(onUserEarnedReward: (ad, reward) {
      userEarnedReward = true;
      AdLogger.success(
          'AdPool', 'User earned reward: ${reward.amount} ${reward.type}');
    });

    return completer.future;
  }

  /// Reset manual de tentativas (melhorado)
  void resetAttempts([String? adType]) {
    if (adType != null) {
      _loadAttempts[adType] = 0;
      _lastLoadTimes.remove(adType);
      _lastShowTimes.remove(adType);
      AdLogger.info('AdPool', 'Reset attempts for $adType');
    } else {
      _loadAttempts.clear();
      _lastLoadTimes.clear();
      _lastShowTimes.clear();
      AdLogger.info('AdPool', 'Reset all attempts and timers');
    }
  }

  /// Força recarregamento ignorando cooldowns (otimizado)
  Future<void> forceReload() async {
    AdLogger.info(
        'AdPool', 'Force reload triggered - clearing all restrictions');
    resetAttempts();

    // Limpa pools existentes
    for (final ad in _interstitialPool) {
      ad.dispose();
    }
    for (final ad in _rewardedPool) {
      ad.dispose();
    }
    _interstitialPool.clear();
    _rewardedPool.clear();

    // Recarrega imediatamente
    _initializePools();
  }

  /// Método específico para iOS - força reload quando há problemas de conectividade
  Future<void> forceReloadIOS() async {
    if (!_isIOS) return forceReload();

    AdLogger.info('AdPool', 'iOS emergency reload - clearing all restrictions');

    // Limpa tudo
    resetAttempts();

    // Limpa pools
    for (final ad in _interstitialPool) {
      ad.dispose();
    }
    for (final ad in _rewardedPool) {
      ad.dispose();
    }
    _interstitialPool.clear();
    _rewardedPool.clear();

    // Carrega imediatamente com delay mínimo
    await Future.wait([
      _loadInterstitialAd(),
      Future.delayed(
          const Duration(milliseconds: 300), () => _loadRewardedAd()),
    ]);

    AdLogger.success('AdPool', 'iOS emergency reload completed');
  }

  /// Limpa todos os pools (melhorado)
  void clearPools() {
    AdLogger.info('AdPool', 'Clearing all pools and disposing ads');

    for (final ad in _interstitialPool) {
      ad.dispose();
    }
    for (final ad in _rewardedPool) {
      ad.dispose();
    }

    _interstitialPool.clear();
    _rewardedPool.clear();
    _interstitialLoadTimes.clear();
    _rewardedLoadTimes.clear();
    _lastLoadTimes.clear();
    _lastShowTimes.clear();
    _loadAttempts.clear();

    AdLogger.success('AdPool', 'All pools cleared and ads disposed');
  }

  /// Status detalhado do pool para debug (melhorado)
  Map<String, dynamic> get poolStatus => {
        'interstitial_count': _interstitialPool.length,
        'rewarded_count': _rewardedPool.length,
        'max_interstitial': maxInterstitialAds,
        'max_rewarded': maxRewardedAds,
        'interstitial_attempts': _loadAttempts['interstitial'] ?? 0,
        'rewarded_attempts': _loadAttempts['rewarded'] ?? 0,
        'max_attempts': _maxAttempts,
        'interstitial_fill_rate': _fillRate['interstitial'] ?? 0,
        'rewarded_fill_rate': _fillRate['rewarded'] ?? 0,
        'interstitial_total_requests': _fillRate['interstitial_total'] ?? 0,
        'rewarded_total_requests': _fillRate['rewarded_total'] ?? 0,
        'last_load_times':
            _lastLoadTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
        'last_show_times':
            _lastShowTimes.map((k, v) => MapEntry(k, v.toIso8601String())),
        'can_show_interstitial': _canShowAd('interstitial'),
        'can_show_rewarded': _canShowAd('rewarded'),
        'is_ios': _isIOS,
        'is_ios_simulator': _isIOSSimulator,
        'load_cooldown_ms': _cooldownDuration.inMilliseconds,
        'show_cooldown_ms': _isIOS ? iosMinShowInterval.inMilliseconds : 0,
        'network_retry_cooldown_ms':
            _isIOS ? iosNetworkRetryCooldown.inMilliseconds : 0,
        'rate_limit_cooldown_ms':
            _isIOS ? iosRateLimitCooldown.inMilliseconds : 0,
        'timestamp': DateTime.now().toIso8601String(),
      };

  /// Obter métricas de performance
  Map<String, dynamic> get performanceMetrics => {
        'interstitial_fill_rate': _fillRate['interstitial'] ?? 0,
        'rewarded_fill_rate': _fillRate['rewarded'] ?? 0,
        'interstitial_requests': _fillRate['interstitial_total'] ?? 0,
        'rewarded_requests': _fillRate['rewarded_total'] ?? 0,
        'interstitial_successes': _fillRate['interstitial_successful'] ?? 0,
        'rewarded_successes': _fillRate['rewarded_successful'] ?? 0,
        'pool_efficiency': {
          'interstitial_utilization':
              _interstitialPool.length / maxInterstitialAds,
          'rewarded_utilization': _rewardedPool.length / maxRewardedAds,
        },
        'platform_optimizations': {
          'is_ios': _isIOS,
          'load_interval_seconds': _cooldownDuration.inSeconds,
          'show_interval_seconds': _isIOS ? iosMinShowInterval.inSeconds : 0,
        }
      };

  @override
  void onClose() {
    clearPools();
    super.onClose();
  }
}

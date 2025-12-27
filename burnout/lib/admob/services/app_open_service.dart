// lib/admob/services/app_open_service.dart
import 'package:get/get.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:get_storage/get_storage.dart';
import '../utils/ad_logger.dart';

import '../../a_config_app/loja_admob_constants.dart';
import '../../funcoes/platform_utils.dart';

class AppOpenService extends GetxController with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  DateTime? _loadTime;
  // Recomendação AdMob: anúncios pré-carregados expiram após 1 hora
  final Duration maxCacheDuration = const Duration(hours: 1);
  // Simplificado para produção: sem fallback/test IDs

  // Controlo de frequência de exibição
  DateTime? _lastOpenAdShown;
  // Para facilitar testes, em Debug não aplicamos intervalo mínimo
  static const Duration minimumIntervalBetweenAds = Duration(minutes: 5);
  bool _hasShownAdInThisSession = false;
  bool _isFirstLaunch = true;
  int _userInteractionsCount = 0; // Contador de interações do usuário
  DateTime? _lastPausedTime; // Rastreia quando o app foi para background
  bool _wasInBackground =
      false; // Indica se o app estava realmente em background
  DateTime?
      _lastAdDismissedTime; // Rastreia quando um anúncio (rewarded/interstitial) foi fechado
  static const Duration _cooldownAfterAdDismissed = Duration(
      seconds:
          15); // Cooldown aumentado após anúncio ser fechado (15s para garantir)
  DateTime?
      _lastAdShownTime; // Rastreia quando um anúncio intercalar/rewarded foi mostrado

  bool get isAdAvailable {
    if (_appOpenAd != null && _loadTime != null) {
      final cacheAge = DateTime.now().difference(_loadTime!);
      if (cacheAge > maxCacheDuration) {
        AdLogger.info(
            'AppOpen', 'Ad expirado (${cacheAge.inMinutes} min), descartando');
        _appOpenAd?.dispose();
        _appOpenAd = null;
        return false;
      }
    }
    return _appOpenAd != null && !_isShowingAd;
  }

  @override
  void onInit() {
    super.onInit();
    _isFirstLaunch = true;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> loadAd(
      {bool nonPersonalized = false, bool forceLoad = false}) async {
    // iOS: força sempre NPA para evitar tracking transparency
    final bool effectiveNpa = platformIsIOS() ? true : nonPersonalized;
    // Garante inicialização do SDK antes de pedir AppOpen
    await MobileAds.instance.initialize();
    if (_appOpenAd != null && !forceLoad) {
      AdLogger.info('AppOpen', 'Já existe anúncio carregado (skip)');
      return;
    }

    // Respeita frequência (após primeiro lançamento)
    if (!_isFirstLaunch && !canShowAd() && !forceLoad) {
      AdLogger.info('AppOpen', 'Carregamento bloqueado pela frequência');
      return;
    }

    AdLogger.info('AppOpen', '🔄 Carregando AppOpen (NPA=$effectiveNpa)');

    // Produção: usar sempre o ad unit de produção
    final String adUnitId = LojaEAdmobConstants.aberturaAdsId;
    AdLogger.info('AppOpen', 'AdUnit: $adUnitId');
    await AppOpenAd.load(
      adUnitId: adUnitId,
      request: AdRequest(
        nonPersonalizedAds: effectiveNpa,
      ),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          AdLogger.success('AppOpen', '✅ Carregado');
          _appOpenAd = ad;
          _loadTime = DateTime.now();

          // Tracking de receita paga (recomendação AdMob)
          try {
            (_appOpenAd as dynamic).onPaidEvent = (adObj, value) {
              final int micros = (value?.valueMicros ?? 0) as int;
              final String currency = (value?.currencyCode ?? '') as String;
              final String? precision = value?.precision?.toString();
              AdLogger.paid(
                adType: 'AppOpen',
                currencyCode: currency,
                valueMicros: micros,
                precision: precision,
              );
            };
          } catch (_) {}

          _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              _isShowingAd = true;
              AdLogger.info('AppOpen', 'Exibindo em tela cheia');
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              _isShowingAd = false;
              AdLogger.error('AppOpen', 'Falhou ao mostrar: $error');
              _appOpenAd = null;
            },
            onAdDismissedFullScreenContent: (ad) {
              _isShowingAd = false;
              _appOpenAd = null;
              // Recarrega para próxima oportunidade
              loadAd(nonPersonalized: effectiveNpa);
            },
          );
        },
        onAdFailedToLoad: (error) {
          AdLogger.error('AppOpen', '❌ Falha no load: $error');
          _appOpenAd = null;
        },
      ),
    );
  }

  bool canShowAd({bool isFromBackground = false}) {
    // NUNCA mostrar no primeiro lançamento do app
    // Só mostrar quando o app volta do background
    if (_isFirstLaunch && !isFromBackground) {
      AdLogger.info('AppOpen', 'Bloqueado: primeiro lançamento do app');
      return false;
    }

    final now = DateTime.now();
    // Intervalo mínimo por plataforma: iOS mantém 5m; Android reduz para 3m
    final Duration minInterval = platformIsIOS()
        ? const Duration(minutes: 5)
        : const Duration(minutes: 3);
    final intervalRespected = _lastOpenAdShown == null ||
        now.difference(_lastOpenAdShown!).inMinutes > minInterval.inMinutes;
    final notShownInSession = !_hasShownAdInThisSession;

    // Só mostrar se vier do background E respeitar intervalos
    return isFromBackground && intervalRespected && notShownInSession;
  }

  /// Registra uma interação do usuário (chamado quando usuário navega ou interage)
  void recordUserInteraction() {
    _userInteractionsCount++;
    AdLogger.info(
        'AppOpen', 'User interaction recorded: $_userInteractionsCount');
  }

  /// Registra que um anúncio (rewarded ou interstitial) foi fechado
  /// Isso previne que o App Open Ad apareça imediatamente após
  void recordAdDismissed() {
    _lastAdDismissedTime = DateTime.now();
    // Reseta o flag de background para evitar que seja interpretado como volta do background
    _wasInBackground = false;
    AdLogger.info('AppOpen',
        'Anúncio (rewarded/interstitial) fechado - cooldown ativado por ${_cooldownAfterAdDismissed.inSeconds}s');
  }

  /// Registra que um anúncio (rewarded ou interstitial) foi mostrado
  /// Isso ajuda a rastrear quando anúncios estão sendo exibidos
  void recordAdShown() {
    _lastAdShownTime = DateTime.now();
    AdLogger.info('AppOpen', 'Anúncio (rewarded/interstitial) sendo exibido');
  }

  void showAdIfAvailable({
    required VoidCallback onAdDismissed,
    bool nonPersonalized = false,
    bool isFromBackground = false,
  }) {
    // Verifica disponibilidade
    if (!isAdAvailable) {
      AdLogger.info('AppOpen', 'Nenhum anúncio disponível para exibir');
      // Prepara para próxima vez
      loadAd(nonPersonalized: nonPersonalized);
      return;
    }

    // Regras de frequência - só mostra se vier do background
    if (!canShowAd(isFromBackground: isFromBackground)) {
      AdLogger.info('AppOpen', 'Bloqueado: não é do background ou frequência');
      return;
    }

    _hasShownAdInThisSession = true;
    _lastOpenAdShown = DateTime.now();

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        AdLogger.info('AppOpen', 'Exibindo');
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAd = false;
        _appOpenAd = null;
        // Após fechar, carrega outro para próxima vez
        loadAd(nonPersonalized: nonPersonalized);
        onAdDismissed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAd = false;
        AdLogger.error('AppOpen', 'Falhou ao mostrar: $error');
        _appOpenAd = null;
        loadAd(nonPersonalized: nonPersonalized);
        onAdDismissed();
      },
    );

    _appOpenAd!.show();
    // Após primeira exibição na sessão, não é mais primeiro lançamento
    _isFirstLaunch = false;
  }

  void resetSessionCounter() {
    _hasShownAdInThisSession = false;
    _isFirstLaunch = true;
  }

  @override
  void onClose() {
    _appOpenAd?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        // Só marca como background se não houver anúncio sendo exibido ou fechado recentemente
        // Se um anúncio foi mostrado ou fechado recentemente, não marca como background real
        final bool adRecentlyShown = _lastAdShownTime != null &&
            DateTime.now().difference(_lastAdShownTime!).inSeconds < 30;
        final bool adRecentlyDismissed = _lastAdDismissedTime != null &&
            DateTime.now().difference(_lastAdDismissedTime!).inSeconds <
                _cooldownAfterAdDismissed.inSeconds;

        if (!adRecentlyShown && !adRecentlyDismissed) {
          _lastPausedTime = DateTime.now();
          _wasInBackground = true;
          AdLogger.info('AppOpen', 'App foi para background/inativo');
        } else {
          // Se um anúncio foi mostrado/fechado recentemente, não marca como background
          AdLogger.info('AppOpen',
              'App paused mas anúncio foi mostrado/fechado recentemente - ignorando pause');
        }
        break;

      case AppLifecycleState.resumed:
        // PRIORIDADE 1: Verifica se um anúncio (rewarded/interstitial) foi fechado recentemente
        if (_lastAdDismissedTime != null) {
          final timeSinceAdDismissed =
              DateTime.now().difference(_lastAdDismissedTime!);
          if (timeSinceAdDismissed < _cooldownAfterAdDismissed) {
            _wasInBackground = false;
            _lastPausedTime = null; // Limpa para evitar falsos positivos
            AdLogger.info('AppOpen',
                'App resumed mas anúncio foi fechado há ${timeSinceAdDismissed.inSeconds}s - ignorando (cooldown ativo por mais ${_cooldownAfterAdDismissed.inSeconds - timeSinceAdDismissed.inSeconds}s)');
            return;
          }
          // Se passou o cooldown, limpa o registro
          _lastAdDismissedTime = null;
        }

        // PRIORIDADE 2: Verifica se um anúncio foi mostrado recentemente (dentro dos últimos 30 segundos)
        // Se sim, provavelmente o resume é do anúncio sendo fechado, não do background
        if (_lastAdShownTime != null) {
          final timeSinceAdShown = DateTime.now().difference(_lastAdShownTime!);
          if (timeSinceAdShown.inSeconds < 30) {
            _wasInBackground = false;
            _lastPausedTime = null;
            AdLogger.info('AppOpen',
                'App resumed mas anúncio foi mostrado há ${timeSinceAdShown.inSeconds}s - ignorando (provavelmente fechamento de anúncio)');
            return;
          }
        }

        // PRIORIDADE 3: Verifica se realmente veio do background (não apenas de um anúncio intersticial)
        // Requer que o app tenha estado em background por pelo menos 3 segundos (aumentado de 2)
        final wasActuallyInBackground = _wasInBackground &&
            _lastPausedTime != null &&
            DateTime.now().difference(_lastPausedTime!).inSeconds >=
                3; // Mínimo 3 segundos em background (aumentado para maior segurança)

        if (!wasActuallyInBackground) {
          // Reset do flag se não veio realmente do background
          _wasInBackground = false;
          _lastPausedTime = null;
          AdLogger.info('AppOpen',
              'App resumed mas não veio do background (provavelmente anúncio intersticial/rewarded ou pause muito curto)');
          return;
        }

        // Reset do flag após verificação
        _wasInBackground = false;

        // Mostra AppOpen APENAS quando o app volta do background (não no primeiro lançamento)
        // Marca que não é mais o primeiro lançamento
        if (_isFirstLaunch) {
          _isFirstLaunch = false;
          AdLogger.info('AppOpen',
              'Primeiro lançamento completo - App Open habilitado para próximas vezes');
          // Carrega anúncio para próxima vez que voltar do background
          final box = GetStorage();
          final bool isConsentGiven = box.read('isConsentGiven') ?? false;
          final bool npa = platformIsIOS() ? true : !isConsentGiven;
          loadAd(nonPersonalized: npa);
          return;
        }

        // Só mostra se não for o primeiro lançamento e realmente veio do background
        if (isAdAvailable && !_isShowingAd) {
          AdLogger.info('AppOpen',
              'App voltou do background - tentando mostrar App Open');
          showAdIfAvailable(
            onAdDismissed: () {},
            isFromBackground: true, // Indica que veio do background
          );
        } else if (!isAdAvailable && !_isShowingAd) {
          // Se não tem anúncio disponível, carrega para próxima vez
          final box = GetStorage();
          final bool isConsentGiven = box.read('isConsentGiven') ?? false;
          final bool npa = platformIsIOS() ? true : !isConsentGiven;
          loadAd(nonPersonalized: npa);
        }
        break;

      default:
        break;
    }
  }
}

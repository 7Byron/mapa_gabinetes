import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'
    show AdSize, BannerAd, BannerAdListener, AdWidget; // mobile only
import 'package:get/get.dart';

import '../utils/ad_logger.dart';
import '../../a_config_app/loja_admob_constants.dart';
import 'banner_ad_controller.dart';
import '../utils/ad_request.dart';

class BannerAdWidget extends StatefulWidget {
  final String? pageName;
  final double? fixedHeight;
  final bool
      collapsible; // Se true, usa banner collapsible (recomendação AdMob)

  const BannerAdWidget({
    super.key,
    this.pageName,
    this.fixedHeight,
    this.collapsible = false, // Por padrão não é collapsible
  });

  @override
  BannerAdWidgetState createState() => BannerAdWidgetState();
}

class BannerAdWidgetState extends State<BannerAdWidget>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isDisposed = false;
  double _bannerHeight = 50; // Tamanho padrão
  bool _sizeCalculated = false;
  int _failedAttempts = 0;
  static const int maxFailedAttempts = 3;

  // Controle de lifecycle
  bool _isVisible = true;
  bool _hasInitialized = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeBanner();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isDisposed = true;
    _safeDisposeBanner();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _isVisible = true;
        if (_hasInitialized &&
            !_isLoaded &&
            _failedAttempts < maxFailedAttempts) {
          AdLogger.info(
              'BannerWidget', 'App resumed - attempting to reload banner');
          _loadBannerAd();
        }
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _isVisible = false;
        break;
      case AppLifecycleState.detached:
        _safeDisposeBanner();
        break;
      case AppLifecycleState.hidden:
        _isVisible = false;
        break;
    }
  }

  void _initializeBanner() {
    if (_isDisposed || _hasInitialized) return;

    _hasInitialized = true;

    // Usa o controller compartilhado se disponível
    if (Get.isRegistered<BannerAdController>() && widget.pageName != null) {
      _useSharedController();
    } else {
      _useStandaloneWidget();
    }
  }

  void _useSharedController() {
    final controller = Get.find<BannerAdController>();

    // Observa mudanças no controller
    ever(controller.isLoaded, (bool loaded) {
      if (mounted && controller.currentPage.value == widget.pageName) {
        setState(() {
          _isLoaded = loaded;
          if (loaded && controller.bannerAd != null) {
            _bannerAd = controller.bannerAd;
            _updateBannerHeight();
          }
        });
      }
    });

    // Carrega banner se necessário
    if (widget.pageName != null && !controller.isLoading.value) {
      // Se collapsible está ativado e banner está no bottom, usa "bottom"
      final String? collapsibleParam = widget.collapsible ? 'bottom' : null;
      controller.loadBannerAd(
          pageName: widget.pageName!, collapsible: collapsibleParam);
    }
  }

  void _useStandaloneWidget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isDisposed) {
        _calculateBannerSize();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sizeCalculated && !_hasInitialized) {
      _calculateBannerSize();
    }
  }

  /// Calcula o tamanho do banner de forma otimizada
  void _calculateBannerSize() async {
    if (_isDisposed || !mounted) return;

    if (widget.fixedHeight != null) {
      setState(() {
        _bannerHeight = widget.fixedHeight!;
        _sizeCalculated = true;
      });
      _loadBannerAd();
      return;
    }

    try {
      final size =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(
              MediaQuery.of(context).size.width.truncate());

      if (size != null && mounted && !_isDisposed) {
        setState(() {
          _bannerHeight = size.height.toDouble();
          _sizeCalculated = true;
        });

        // Carrega o anúncio após calcular o tamanho
        _loadBannerAd(size: size);
      } else {
        // Fallback para tamanho padrão
        if (mounted && !_isDisposed) {
          setState(() {
            _bannerHeight = 50.0;
            _sizeCalculated = true;
          });
          AdLogger.warning('BannerWidget', 'Using default banner size');
          _loadBannerAd();
        }
      }
    } catch (e) {
      AdLogger.error('BannerWidget', 'Error calculating banner size: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _bannerHeight = 50.0;
          _sizeCalculated = true;
        });
      }
    }
  }

  void _loadBannerAd({AdSize? size}) {
    if (_isDisposed || !mounted || !_isVisible) return;

    // Se já tem banner carregado, não recarrega
    if (_isLoaded && _bannerAd != null) {
      return;
    }

    // Limita tentativas
    if (_failedAttempts >= maxFailedAttempts) {
      AdLogger.warning('BannerWidget', 'Max failed attempts reached');
      return;
    }

    final bannerSize = size ?? AdSize.banner;

    AdLogger.info('BannerWidget', 'Loading standalone banner');

    // Se collapsible está ativado e banner está no bottom, usa "bottom"
    final String? collapsibleParam = widget.collapsible ? 'bottom' : null;

    _bannerAd = BannerAd(
      adUnitId: LojaEAdmobConstants.bannerAdUnitId,
      size: bannerSize,
      request: AdRequestFactory.build(collapsible: collapsibleParam),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (_isDisposed || !mounted) {
            ad.dispose();
            return;
          }

          AdLogger.success(
              'BannerWidget', 'Standalone banner loaded successfully');

          setState(() {
            _isLoaded = true;
            _failedAttempts = 0;
          });

          _updateBannerHeight();
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();

          if (_isDisposed || !mounted) return;

          _failedAttempts++;
          AdLogger.error('BannerWidget',
              'Standalone banner failed to load (attempt $_failedAttempts): ${error.code} - ${error.message}');

          setState(() {
            _isLoaded = false;
            _bannerAd = null;
          });

          // Retry após delay se não atingiu limite
          if (_failedAttempts < maxFailedAttempts) {
            Future.delayed(const Duration(seconds: 5), () {
              if (mounted && !_isDisposed && _isVisible) {
                _loadBannerAd(size: size);
              }
            });
          }
        },
        onAdOpened: (ad) {
          AdLogger.info('BannerWidget', 'Banner opened');
        },
        onAdClosed: (ad) {
          AdLogger.info('BannerWidget', 'Banner closed');
        },
        onAdImpression: (ad) {
          AdLogger.info('BannerWidget', 'Banner impression recorded');
        },
      ),
    );

    // Regista receita paga (se suportado)
    try {
      // Compatível com versões onde onPaidEvent não existe (usa dynamic)
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

  void _updateBannerHeight() {
    if (_bannerAd != null && mounted && !_isDisposed) {
      final height = _bannerAd!.size.height.toDouble();
      if (height != _bannerHeight) {
        setState(() {
          _bannerHeight = height;
        });
      }
    }
  }

  void _safeDisposeBanner() {
    if (_bannerAd != null) {
      try {
        _bannerAd!.dispose();
        AdLogger.info('BannerWidget', 'Banner disposed safely');
      } catch (e) {
        AdLogger.error('BannerWidget', 'Error disposing banner: $e');
      }
      _bannerAd = null;
    }

    // Web: não remover o container GPT para manter banner ao navegar
  }

  Widget _buildBannerContent() {
    if (_bannerAd != null) {
      return AdWidget(ad: _bannerAd!);
    }

    // Preserva o espaço mas não mostra progress bar durante o carregamento
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      width: double.infinity,
      height: _bannerHeight,
      color: const Color(0xFFFFF8E1),
      child: _buildBannerContent(),
    );
  }
}

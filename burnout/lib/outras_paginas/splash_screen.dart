import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../admob/ad_manager.dart';
import '../admob/services/consent_manager.dart';
import '../a_config_app/lista_testes.dart';

import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/responsive.dart';
import '../funcoes/spacing.dart';
import '../funcoes/platform_utils.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final ConsentManager _consentManager = ConsentManager();
  bool ads = MyG.to.adsPago;
  bool isAdLoaded = false;
  Timer? _navTimer;
  final bool _adShowing = false;

  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _colorController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkConsentAndLoadAds();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Precache de imagens críticas para UX mais suave
      try {
        await Future.wait([
          precacheImage(const AssetImage(RotaImagens.logoDepressao), context),
          precacheImage(const AssetImage(RotaImagens.logoAnsiedade), context),
          precacheImage(const AssetImage(RotaImagens.logoStress), context),
          precacheImage(const AssetImage(RotaImagens.logoRaiva), context),
          precacheImage(const AssetImage(RotaImagens.logoDependencia), context),
          precacheImage(const AssetImage(RotaImagens.logoAtitude), context),
          precacheImage(const AssetImage(RotaImagens.logoFelicidade), context),
          precacheImage(
              const AssetImage(RotaImagens.logoPersonalidade), context),
          precacheImage(const AssetImage(RotaImagens.logoSorriso), context),
          precacheImage(
              const AssetImage(RotaImagens.logoAutoConfianca), context),
        ]);
      } catch (_) {}
      await _calcularMargens();
      _startAnimations();
    });

    // Timeout de segurança: navega se nenhum anúncio for mostrado
    _navTimer = Timer(const Duration(milliseconds: 6000), () {
      if (mounted && !_adShowing) {
        Get.offAllNamed(RotasPaginas.intro);
      }
    });
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(
      begin: Colors.brown,
      end: Colors.amber.shade600,
    ).animate(
      CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
    );
  }

  void _startAnimations() {
    _fadeController.forward();
    _scaleController.forward();
    _colorController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _checkConsentAndLoadAds() async {
    // Se anúncios estão removidos, não inicializa consent/ad
    if (MyG.to.adsPago) {
      return;
    }
    final box = GetStorage();
    // 1) Perguntar ao UMP se é necessário consentimento (forçado EEA em debug)
    final bool consentRequired = await _consentManager.isConsentRequired();
    if (consentRequired) {
      // 2) Mostrar formulário e aguardar conclusão antes de prosseguir
      await _consentManager.showGDPRConsentForm();
    }
    // 3) Decidir NPA com base no consentimento dado (se existir)
    final bool isConsentGiven = box.read('isConsentGiven') ?? false;
    final bool useNpa = platformIsIOS() ? true : !isConsentGiven;
    // 4) Carrega App Open Ad em background (para quando app voltar do background)
    // NÃO mostra no início - apenas quando app volta do segundo plano
    try {
      await AdManager.to.appOpenService
          ?.loadAd(nonPersonalized: useNpa, forceLoad: true);
    } catch (_) {}
    if (mounted) {
      _navTimer?.cancel();
      // Navega diretamente para intro - SEM mostrar App Open Ad
      Get.offAllNamed(RotasPaginas.intro);
    }
  }

  Future<void> _calcularMargens() async {
    final double aspectRatio = Get.width / Get.height;
    final double margemBase = Get.width * 0.055; // Baseado na largura

    // Ajuste para telas extra largas
    double margemCalculada = Get.context!.isPhone
        ? (aspectRatio > 1.8
            ? margemBase * 0.50 // Redução maior para telas extra largas
            : (aspectRatio > 1.6
                ? margemBase * 0.75 // Redução intermediária
                : margemBase))
        : 26; // Tablet mantém fixo

    // 🔥 Redução extra para telas muito baixas
    if (Get.height < 650) {
      margemCalculada *= 0.75; // Reduz mais 25% para telas muito baixas
    } else if (Get.height < 750) {
      margemCalculada *= 0.85; // Reduz mais 15% se for um pouco baixa
    }

    MyG.to.calcularMargens(double.parse(margemCalculada.toStringAsFixed(0)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Imagem
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    ListaTeste.iconApp,
                    width: 140,
                    height: 140,
                  ),
                ),

                Spacing.vl,

                // Texto animado
                AnimatedBuilder(
                  animation: Listenable.merge([
                    _fadeAnimation,
                    _scaleAnimation,
                    _colorAnimation,
                  ]),
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: ScaleTransition(
                        scale: _scaleAnimation,
                        child: Text(
                          "Byron System Developer",
                          style: TextStyle(
                            fontSize: ResponsiveConfig.of(context).clampFont(
                                ResponsiveConfig.of(context).font(18)),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.0,
                            color: _colorAnimation.value,
                            shadows: const [
                              Shadow(
                                blurRadius: 10.0,
                                color: Colors.black26,
                                offset: Offset(2.0, 2.0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (isAdLoaded)
            Positioned.fill(
              child: Container(
                color: Colors.transparent,
              ),
            ),
        ],
      ),
    );
  }
}

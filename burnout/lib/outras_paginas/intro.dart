import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'dart:math' as math;
import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../controllers/internet_checker.dart';
import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../paginas_testes/test_info.dart';
import '../widgets/botao_icon.dart';
import '../widgets/botao_imagem.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/lista_teste_unificada.dart';
import '../widgets/my_app_bar_inicial.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/typewriter_text.dart';
import '../funcoes/responsive.dart';

enum PageState { intro, testList, testPrep }

class Intro extends StatefulWidget {
  const Intro({super.key});

  @override
  State<Intro> createState() => _IntroState();
}

class _IntroState extends State<Intro> {
  final box = GetStorage();
  late bool allApps;
  late bool ads;
  PageState _currentState = PageState.intro;

  // PageController para transições suaves
  late PageController _pageController;

  // Controle dos textos animados
  bool _showIntroText = false;
  bool _showTestText = false;

  // Controle dos botões dos testes
  bool _showButton1 = false;
  bool _showButton2 = false;

  // Variáveis para o teste selecionado
  String _testeEscolhido = "";
  String _tituloTesteEscolhido = "";
  String _imagemTesteEscolhido = "";
  String _rotaPaginaTeste = "";
  String _introTeste = "";

  // Serviço de anúncios
  bool adViewedSuccessfully = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // Sincroniza com as variáveis globais
    allApps = MyG.to.allApps;
    ads = MyG.to.adsPago;

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _currentState == PageState.intro) {
        setState(() {
          _showIntroText = true;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!Get.isRegistered<RealNetworkController>() && !MyG.to.adsPago) {
        Get.put(RealNetworkController(), permanent: true);
      }

      final arguments = Get.arguments;

      if (arguments != null && arguments is List && arguments.length >= 2) {
        if (arguments[0] == 'testPrep') {
          Future.delayed(const Duration(milliseconds: 100), () {
            _goToTestPrep(arguments[1]);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTestList() {
    setState(() {
      _currentState = PageState.testList;
      _showTestText = false;
      _showButton1 = false;
      _showButton2 = false;
    });
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  void _goToTestPrep(String testId) {
    setState(() {
      _currentState = PageState.testPrep;
      _showIntroText = false;
      _showTestText = false;
      _showButton1 = false;
      _showButton2 = false;
      _testeEscolhido = testId;

      final testeData = getTestInfo(testId);
      _tituloTesteEscolhido = testeData["titulo"]!.tr;
      _imagemTesteEscolhido = testeData["imagem"]!;
      _rotaPaginaTeste = testeData["rota"]!;
      _introTeste = testeData["intro"]!.tr;
    });

    _pageController
        .animateToPage(
      2,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentState == PageState.testPrep) {
          setState(() {
            _showTestText = true;
          });
        }

        const baseDelay = 2500;

        Future.delayed(const Duration(milliseconds: baseDelay), () {
          if (mounted && _currentState == PageState.testPrep) {
            setState(() {
              _showButton1 = true;
            });
          }
        });

        Future.delayed(const Duration(milliseconds: baseDelay + 1000), () {
          if (mounted && _currentState == PageState.testPrep) {
            setState(() {
              _showButton2 = true;
            });
          }
        });
      });
    });
  }

  void _goToIntro() {
    setState(() {
      _currentState = PageState.intro;
      _showIntroText = false;
      _showTestText = false;
      _showButton1 = false;
      _showButton2 = false;
    });
    _pageController
        .animateToPage(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    )
        .then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _currentState == PageState.intro) {
          setState(() {
            _showIntroText = true;
          });
        }
      });
    });
  }

  VoidCallback? _getHomeCallback() {
    switch (_currentState) {
      case PageState.intro:
        return null; // Comportamento padrão
      case PageState.testList:
        return _goToIntro;
      case PageState.testPrep:
        return _goToIntro;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomScaffold(
          appBar: _buildDynamicAppBar(),
          drawer: MyDrawer(
            onHomePressed: _getHomeCallback(),
          ),
          body: PageView(
            controller: _pageController,
            physics:
                const NeverScrollableScrollPhysics(), // Desabilita scroll manual
            children: [
              _buildIntroBody(),
              _buildTestListBody(),
              _buildTestPrepBody(),
            ],
          ),
          bottomNavigationBar: GetBuilder<MyG>(
            id: 'compras',
            builder: (myG) => (myG.adsPago)
                ? Reuse.myHeigthBox1_5
                : const BannerAdWidget(
                    collapsible:
                        true, // Banner collapsible no ecrã inicial (recomendação AdMob)
                  ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildDynamicAppBar() {
    switch (_currentState) {
      case PageState.intro:
      case PageState.testList:
        return const AppBarInitial();
      case PageState.testPrep:
        return AppBarSecondary(
          image: _imagemTesteEscolhido,
          titulo: _tituloTesteEscolhido,
        );
    }
  }

  // Corpo da página - modo introdução
  Widget _buildIntroBody() {
    final r = ResponsiveConfig.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final double baseHeight = 720;
      final double scale =
          (constraints.maxHeight / baseHeight).clamp(0.75, 1.0);
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(MyG.to.ensureMargem(context),
              r.spacingMedium, MyG.to.ensureMargem(context), 0),
          child: SizedBox(
            width: r.contentMaxWidth,
            height: double.infinity,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox(height: r.spacingMedium),
                      Transform.scale(
                        scale: scale,
                        alignment: Alignment.topCenter,
                        child: WidgetAnimator(
                          atRestEffect: WidgetRestingEffects.wave(
                            effectStrength: 0.3,
                            duration: const Duration(seconds: 24),
                          ),
                          child: SizedBox(
                            height: r.logoHeight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 180),
                              child: Image.asset(RotaImagens.logoApp,
                                  fit: BoxFit.contain,
                                  cacheWidth: math.max(
                                      1,
                                      (r.logoHeight *
                                              MediaQuery.of(context)
                                                  .devicePixelRatio)
                                          .round())),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: r.spacingLarge),
                      _buildLanguageChangeButton(context),
                      SizedBox(height: r.spacingLarge),
                      _buildIntroText(),
                      SizedBox(height: r.spacingLarge),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GetBuilder<MyG>(
                        id: 'compras',
                        builder: (myG) => Visibility(
                          visible: !myG.adsPago &&
                              (GetPlatform.isAndroid || GetPlatform.isIOS),
                          child: Padding(
                            padding: EdgeInsets.only(bottom: r.spacingSmall),
                            child: MyBotaoImagem(
                              onPressed: () {
                                Get.toNamed(RotasPaginas.pay);
                              },
                              titulo: "removerAds".tr,
                              imagem: RotaImagens.adsOff,
                            ),
                          ),
                        ),
                      ),
                      MyBotaoIcon(
                        onPressed: _goToTestList,
                        linhas: 1,
                        myIcon: Icons.grid_view_rounded,
                        titulo: '_listaTestes'.tr,
                        verticalPadding: r.spacingSmall,
                        height: r.factor < 0.8 ? r.height(44) : r.height(56),
                      ),
                      SizedBox(height: r.spacingSmall / 2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  // Corpo da página - modo lista de testes
  Widget _buildTestListBody() {
    final r = ResponsiveConfig.of(context);
    return SingleChildScrollView(
      child: Center(
        child: SizedBox(
          width: MyG.to.ensureMargens(context)['margem22']!,
          child: Padding(
            padding: EdgeInsets.all(r.spacingMedium),
            child: Column(
              children: [
                SizedBox(height: r.spacingLarge),

                // Lista de testes usando widget reutilizável com callback
                ListaTesteUnificada(
                  isIntroMode: true,
                  onTestSelected: _goToTestPrep,
                ),

                SizedBox(height: r.spacingLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Corpo da página - modo preparação do teste (inicio_testes.dart)
  Widget _buildTestPrepBody() {
    final r = ResponsiveConfig.of(context);
    final bool isSmall = r.factor <= 0.8;
    final double gapSmall = isSmall ? r.spacingSmall * 0.5 : r.spacingSmall;
    final double gapLarge = isSmall ? r.spacingMedium : r.spacingLarge;
    return Center(
      child: SizedBox(
        width: MyG.to.ensureMargens(context)['margem22']!,
        height: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MyG.to.ensureMargens(context)['margem1']!,
            r.spacingMedium,
            MyG.to.ensureMargens(context)['margem1']!,
            r.spacingMedium,
          ),
          child: Column(
            children: [
              SizedBox(height: gapSmall),
              WidgetAnimator(
                atRestEffect: WidgetRestingEffects.wave(
                  effectStrength: 0.3,
                  duration: const Duration(seconds: 24),
                ),
                child: SizedBox(
                  height: MyG.to.ensureMargens(context)['margem3']! *
                      r.buttonHeightScale,
                  child: Builder(builder: (context) {
                    final int targetWidth = math.max(
                        1,
                        (MyG.to.ensureMargens(context)['margem3']! *
                                r.buttonHeightScale *
                                MediaQuery.of(context).devicePixelRatio)
                            .round());
                    return Image.asset(
                      _imagemTesteEscolhido,
                      cacheWidth: targetWidth,
                    );
                  }),
                ),
              ),
              SizedBox(height: gapSmall),
              Text(
                _tituloTesteEscolhido,
                maxLines: 1,
                style: Reuse.myTitulo,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: gapLarge),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: _showTestText
                        ? FadeText(
                            text: _introTeste,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  fontSize: r.clampFont(
                                    MyG.to.ensureMargens(
                                            context)['margem085']! *
                                        r.textScale,
                                  ),
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.brown
                                      : Colors.white,
                                  height: 1.5, // 50% mais espaço entre linhas
                                ),
                            startDelay: const Duration(milliseconds: 800),
                          )
                        : Text(
                            '', // Texto vazio enquanto não mostra
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                                  fontSize: r.clampFont(
                                    MyG.to.ensureMargens(
                                            context)['margem085']! *
                                        r.textScale,
                                  ),
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.brown
                                      : Colors.white,
                                ),
                          ),
                  ),
                ),
              ),
              Column(
                children: [
                  // Botão único para testes simples
                  if (_testeEscolhido != "emo" && _testeEscolhido != "dep")
                    _buildAnimatedButton(
                      show: _showButton1,
                      argument: null,
                      titulo: '_iniciarTeste'.tr,
                      isSmall: isSmall,
                    ),

                  // Botões para teste de dependência emocional
                  if (_testeEscolhido == "emo") ...[
                    _buildAnimatedButton(
                      show: _showButton1,
                      argument: 90,
                      titulo: '90_titulo'.tr,
                      isSmall: isSmall,
                    ),
                    _buildAnimatedButton(
                      show: _showButton2,
                      argument: 20,
                      titulo: '20_titulo'.tr,
                      isSmall: isSmall,
                    ),
                  ],

                  // Botões para teste de depressão
                  if (_testeEscolhido == "dep") ...[
                    _buildAnimatedButton(
                      show: _showButton1,
                      argument: 1,
                      titulo: '_tDepBeck'.tr,
                      isSmall: isSmall,
                    ),
                    _buildAnimatedButton(
                      show: _showButton2,
                      argument: 2,
                      titulo: '_tDepGoldberg'.tr,
                      isSmall: isSmall,
                    ),
                  ],
                ],
              ),
              GetBuilder<MyG>(
                id: 'compras',
                builder: (myG) =>
                    !myG.adsPago && (GetPlatform.isAndroid || GetPlatform.isIOS)
                        ? MyBotaoImagem(
                            onPressed: () {
                              Get.toNamed(RotasPaginas.pay);
                            },
                            titulo: "removerAds".tr,
                            imagem: RotaImagens.adsOff,
                          )
                        : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedButton({
    required bool show,
    required dynamic argument,
    required String titulo,
    required bool isSmall,
  }) {
    final r = ResponsiveConfig.of(context);
    return AnimatedOpacity(
      opacity: show ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 1000),
      curve: Curves.easeInOut,
      child: MyBotaoIcon(
        onPressed: () async {
          // Mostra anúncio intersticial ANTES de iniciar qualquer teste
          // (Os anúncios DURANTE o teste foram removidos apenas para Depressão e Ansiedade)
          if (!MyG.to.adsPago) {
            // Verifica se há anúncio disponível antes de tentar mostrar
            if (AdManager.to.hasInterstitialAd) {
              AdManager.to.showInterstitialAd();
            } else {
              // Se não há anúncio disponível, tenta carregar e aguardar
              await AdManager.to.loadInterstitialAd();
              // Aguarda até 2 segundos para o anúncio carregar
              int attempts = 0;
              while (!AdManager.to.hasInterstitialAd && attempts < 20) {
                await Future.delayed(const Duration(milliseconds: 100));
                attempts++;
              }
              if (AdManager.to.hasInterstitialAd) {
                AdManager.to.showInterstitialAd();
              }
            }
            // Aguarda um pouco para garantir que o anúncio foi mostrado
            await Future.delayed(const Duration(milliseconds: 500));
          }

          // Navega para o teste
          Get.offNamed(_rotaPaginaTeste, arguments: argument);
        },
        linhas: 1,
        myIcon: Icons.directions_run_outlined,
        titulo: titulo,
        height: isSmall ? r.height(44) : r.height(56),
        verticalPadding: isSmall ? r.spacingSmall * 0.5 : r.spacingSmall,
      ),
    );
  }

  Widget _buildLanguageChangeButton(BuildContext context) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Scaffold.of(context).openDrawer();
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Builder(builder: (context) {
              final r = ResponsiveConfig.of(context);
              return Icon(Icons.language_outlined,
                  size: MyG.to.ensureMargem(context) * r.textScale,
                  color: Colors.brown);
            }),
            SizedBox(width: ResponsiveConfig.of(context).spacingSmall),
            Builder(builder: (context) {
              final r = ResponsiveConfig.of(context);
              final double tituloFS = r.clampFont(r.font(12));
              return Text("_mudarIdioma".tr,
                  maxLines: 1,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: tituloFS,
                  ));
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroText() {
    final r = ResponsiveConfig.of(context);
    // Igualar ao tamanho usado na introdução dos testes
    final double bodyFS = r.clampFont(
      MyG.to.ensureMargens(context)['margem085']! * r.textScale,
    );
    return DefaultTextStyle(
      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: bodyFS,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.brown
                : Colors.white,
          ),
      child: _showIntroText
          ? FadeText(
              text: '_introGeral'.tr,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: bodyFS,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.brown
                        : Colors.white,
                    height: 1.5, // 50% mais espaço entre linhas
                  ),
              startDelay: const Duration(milliseconds: 800),
            )
          : const Text(
              '', // Texto vazio enquanto não mostra
              textAlign: TextAlign.center,
            ),
    );
  }
}

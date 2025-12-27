import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/escala_6.dart';
import '../opcoes_resposta_testes/hipoteses_4_respostas.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../funcoes/responsive.dart';
import '../widgets/question_metrics_row.dart';
import '../widgets/question_header.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class PaginaTesteDepressao extends StatefulWidget {
  const PaginaTesteDepressao({super.key});

  @override
  State<PaginaTesteDepressao> createState() => _PaginaTesteDepressaoState();
}

class _PaginaTesteDepressaoState extends State<PaginaTesteDepressao> {
  // ✅ CORRIGIDO: Usa 1 como padrão (Beck) se não houver argumentos
  final int _whichTest = Get.arguments != null ? Get.arguments as int : 1;
  final bool ads = MyG.to.adsPago;
  int _scoreSum = 0;
  int _currentQuestion = 1;
  bool _canGoBack = false;
  int _lastAnswerValue = 0;
  int _valorResposta = 0;
  late double _percent = 0.0;
  late double altura = Get.height * 0.055;

  @override
  void initState() {
    super.initState();
    _percent = _whichTest == 1 ? 0 : 100;
  }

  Future<void> _handleAnswerT1(int answerValue) async {
    _lastAnswerValue = answerValue;

    if (_currentQuestion <= 21) {
      _scoreSum += answerValue;
    }

    if (_currentQuestion == 21) {
      await _finishTest("dep");
    }

    _updatePercent();

    setState(() {
      _currentQuestion++;
      _canGoBack = true;
    });
  }

  Future<void> _handleAnswerT2() async {
    _lastAnswerValue = _valorResposta;

    _scoreSum += _valorResposta;
    _updatePercent();

    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 9, antes de ir para 10)
    // Carrega em background sem bloquear
    if (!ads && _currentQuestion == 9) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    setState(() {
      _currentQuestion++;
      _canGoBack = true;
    });

    if (_currentQuestion == 19) {
      await _finishTest("dep2");
    }
  }

  void _updatePercent() {
    setState(() {
      if (_whichTest == 1) {
        _percent = (_scoreSum * 100) / 63;
      } else {
        _percent = 90 - ((_scoreSum * 100) / 90);
      }
    });
  }

  Future<void> _finishTest(String tipoTeste) async {
    _gravarHistorico(tipoTeste);

    if (ads) {
      Get.offNamed(RotasPaginas.resultadoDepressao,
          arguments: [_scoreSum.toDouble(), _whichTest]);
    } else {
      // Se o anúncio não estiver carregado, tenta carregar e aguarda um pouco
      if (!AdManager.to.hasRewardedAd) {
        await AdManager.to.loadRewardedAd();
        // Aguarda até 2 segundos para o anúncio carregar
        int attempts = 0;
        while (!AdManager.to.hasRewardedAd && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      showVideoResultadoDialog(
        () {
          Get.back();
          Get.offNamed(RotasPaginas.resultadoDepressao,
              arguments: [0.0, _whichTest]);
        },
        () async {
          Get.back();
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          Get.offNamed(RotasPaginas.resultadoDepressao,
              arguments: [_scoreSum.toDouble(), _whichTest]);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _gravarHistorico(String tipoTeste) {
    HistoricOperator().gravarHistorico(tipoTeste, _scoreSum);
  }

  void _voltarPerguntaAnterior() {
    _scoreSum -= _lastAnswerValue;
    _updatePercent();
    setState(() {
      _currentQuestion--;
      _canGoBack = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double tamImagem = MyG.to.margens['margem22']!;

    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoDepressao,
        titulo: "_tDepressao".tr,
      ),
      body: _whichTest == 1 ? _buildTest1Body() : _buildTest2Body(tamImagem),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Widget _buildTest1Body() {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800; // considerar mais casos
    final bool hasBanner = !MyG.to.adsPago;
    // Com Responsive Framework ativo, evitamos escalas agressivas aqui
    final double scale = 1.0;
    final double topGap = (isShortScreen ? Spacing.xs * 0.5 : Spacing.m * 0.6) *
        (hasBanner ? 0.6 : 0.7);
    final int topFlex =
        (isShortScreen && hasBanner) ? 2 : (isShortScreen ? 3 : 4);
    final int bottomFlex =
        (isShortScreen && hasBanner) ? 8 : (isShortScreen ? 7 : 6);
    final double cardVerticalPadFactor = hasBanner ? 0.5 : 0.6;
    return Center(
      child: SizedBox(
        width: r.contentMaxWidth,
        height: double.maxFinite,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: hasBanner ? MyG.to.margens['margem05']! : 0,
            ),
            child: Column(
              children: <Widget>[
                SizedBox(height: topGap),
                Flexible(
                  flex: topFlex,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        vertical: (isShortScreen
                                ? MyG.to.margens['margem01']!
                                : MyG.to.margens['margem025']!) *
                            cardVerticalPadFactor),
                    child: TestCardContainer(
                      innerPadding: EdgeInsets.zero,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isWide = constraints.maxWidth >= 900;
                          final double topSpacing = isShortScreen
                              ? MyG.to.margens['margem005']!
                              : MyG.to.margens['margem01']!;
                          return Column(
                            children: [
                              SizedBox(height: topSpacing),
                              QuestionHeader(
                                current: _currentQuestion,
                                total: 21,
                                canGoBack: _canGoBack,
                                onBack: _voltarPerguntaAnterior,
                              ),
                              Expanded(
                                child: Center(
                                  child: _buildImageRowTest1(
                                    isWide: isWide,
                                    shortScreen: isShortScreen,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(
                    height:
                        (isShortScreen ? Spacing.xs * 0.2 : Spacing.m * 0.25) *
                            (hasBanner ? 0.2 : 0.25)),
                Flexible(
                  flex: bottomFlex,
                  fit: FlexFit.tight,
                  child: _buildBotoesRespostas(
                    _handleAnswerT1,
                    isWide: MediaQuery.of(context).size.width >= 1024,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageRowTest1({bool isWide = false, bool shortScreen = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MyG.to.margens['margem025']!,
        0,
        MyG.to.margens['margem025']!,
        MyG.to.margens['margem025']!,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QuestionMetricsRow(
              perct: _percent,
              desiredUnits: isWide ? 25 : 12,
              barHeight: MyG.to.margens['margem1_25']!,
              imageHeight: shortScreen
                  ? MyG.to.margens['margem2_5']!
                  : MyG.to.margens['margem3']!,
              valueImages: [
                ...ImageThresholds.depressaoT1,
              ],
              percentColors: PercentPalettes.depressaoT1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotoesRespostas(Function(int) obterDados,
      {bool isWide = false}) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    final bool hasBanner = !MyG.to.adsPago;
    final double baseSpacing = isShortScreen
        ? 6.0
        : r.spacingSmall *
            0.8; // aumentado para melhor espaçamento entre botões
    final double spacing = baseSpacing *
        (hasBanner ? 0.9 : 1.0); // mantém bom espaçamento mesmo com banner

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calcula o espaço necessário para os botões
        final double buttonHeight = isShortScreen ? 64.0 : 76.0;
        final double totalButtonHeight = buttonHeight * 4;
        final double totalSpacing = spacing * 3; // 3 espaços entre 4 botões
        final double totalNeeded = totalButtonHeight + totalSpacing;

        // Se o espaço necessário for maior que o disponível, ajusta o espaçamento
        // Mas mantém um mínimo razoável para não ficar muito apertado
        final double minSpacing = isShortScreen ? 4.0 : 6.0;
        final double adjustedSpacing = totalNeeded > constraints.maxHeight
            ? ((constraints.maxHeight - totalButtonHeight) / 3)
                .clamp(minSpacing, spacing)
            : spacing;

        return SingleChildScrollView(
          physics:
              const NeverScrollableScrollPhysics(), // Evita scroll, mas permite ajuste
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Botoes4respostas(
                  valSomar: 0,
                  pergunta: '${_currentQuestion}a'.tr,
                  letter: 'a',
                  obterDados: obterDados,
                  heightOverride: isShortScreen ? 64 : 76,
                  fontScaleFactor: isShortScreen ? 0.85 : 0.9,
                ),
                SizedBox(height: adjustedSpacing),
                Botoes4respostas(
                  valSomar: 1,
                  pergunta: '${_currentQuestion}b'.tr,
                  letter: 'b',
                  obterDados: obterDados,
                  heightOverride: isShortScreen ? 64 : 76,
                  fontScaleFactor: isShortScreen ? 0.85 : 0.9,
                ),
                SizedBox(height: adjustedSpacing),
                Botoes4respostas(
                  valSomar: 2,
                  pergunta: '${_currentQuestion}c'.tr,
                  letter: 'c',
                  obterDados: obterDados,
                  heightOverride: isShortScreen ? 64 : 76,
                  fontScaleFactor: isShortScreen ? 0.85 : 0.9,
                ),
                SizedBox(height: adjustedSpacing),
                Botoes4respostas(
                  valSomar: 3,
                  pergunta: '${_currentQuestion}d'.tr,
                  letter: 'd',
                  obterDados: obterDados,
                  heightOverride: isShortScreen ? 64 : 76,
                  fontScaleFactor: isShortScreen ? 0.85 : 0.9,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTest2Body(double tamImagem) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    final double betweenGap = isShortScreen ? Spacing.s : Spacing.l;
    return Center(
      child: SizedBox(
        width: r.contentMaxWidth,
        height: double.maxFinite,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            SizedBox(height: isShortScreen ? Spacing.s : Spacing.l),
            Flexible(
              flex: isShortScreen ? 6 : 7,
              child: Padding(
                // Largura do card igual à dos botões: remover padding horizontal
                padding: const EdgeInsets.symmetric(),
                child: TestCardContainer(
                  innerPadding: EdgeInsets.zero,
                  child: LayoutBuilder(builder: (context, constraints) {
                    final double baseInner = 520;
                    final double innerScale =
                        (constraints.maxHeight / baseInner).clamp(0.8, 1.0);
                    final bool isWide = constraints.maxWidth >= 900;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        MyG.to.margem,
                        MyG.to.margens['margem05']!,
                        MyG.to.margem,
                        MyG.to.margens['margem025']!,
                      ),
                      child: Transform.scale(
                        scale: innerScale,
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          children: [
                            const SizedBox.shrink(),
                            QuestionHeader(
                              current: _currentQuestion,
                              total: 18,
                              canGoBack: _canGoBack,
                              onBack: _voltarPerguntaAnterior,
                              fontSizeOverride: 22,
                              heightOverride: MyG.to.margens['margem1']!,
                              spacingBeforeDivider:
                                  MyG.to.margens['margem025']!,
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: Center(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: isShortScreen
                                              ? MyG.to.margens['margem025']!
                                              : MyG.to.margens['margem05']!,
                                        ),
                                        child: TextoPergunta(
                                          questionText:
                                              'dep2_$_currentQuestion'.tr,
                                          questionIndex: _currentQuestion,
                                          numeroLinhas: isShortScreen ? 3 : 4,
                                          fontSizeOverride: 22,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        top: MyG.to.margens['margem05']!,
                                        bottom: MyG.to.margens['margem025']!,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Expanded(
                                            child: QuestionMetricsRow(
                                              perct: _percent,
                                              desiredUnits: isWide ? 25 : 12,
                                              barHeight:
                                                  MyG.to.margens['margem1_25']!,
                                              imageWidth: 100,
                                              imageOnRight: true,
                                              valueImages: [
                                                ...ImageThresholds.depressaoT2,
                                              ],
                                              percentColors:
                                                  PercentPalettes.depressaoT2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Espaço entre caixa e botões
            SizedBox(height: betweenGap),
            Botoes6Resposta(
              onSelectedResponse: (value) {
                _valorResposta = value;
                _handleAnswerT2();
              },
              crescente: false,
            ),
          ],
        ),
      ),
    );
  }
}

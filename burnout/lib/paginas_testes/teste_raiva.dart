import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math' as math;

import '../admob/ad_manager.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../opcoes_resposta_testes/escala_5.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets_pagina_testes/grafico_percentagem_horizontal.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets_pagina_testes/imagem_teste.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/status_row_raiva.dart';
import '../widgets_pagina_testes/valor_percentagem.dart';
import '../funcoes/responsive.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';
import '../widgets/question_header.dart';

class TesteRaiva extends StatefulWidget {
  const TesteRaiva({super.key});

  @override
  State<TesteRaiva> createState() => _TesteRaivaState();
}

class _TesteRaivaState extends State<TesteRaiva> {
  bool ads = MyG.to.adsPago;
  int _indicePerguntaAtual = 1;
  int _opcaoSelecionada = 0;
  int _valorPontuacao = 0;
  int _toAdsCount = 0;
  bool _habilitarVoltar = false;
  double _percentualConcluido = 0;
  int _grupo = 0;
  static const int totalPerguntas = 47;
  static const int pontuacaoMaxima = 188;

  Map<String, int> valores = {
    "valAc": 0,
    "valG1": 0,
    "valG2": 0,
    "valG3": 0,
    "valG4": 0,
    "valG5": 0,
    "valG6": 0,
    "prespectivaHostil": 0,
    "raivaInterna": 0,
    "raivaExterna": 0,
    "totalOpcao": 0,
    "valAcAnt": 0,
    "valG1Ant": 0,
    "valG2Ant": 0,
    "valG3Ant": 0,
    "valG4Ant": 0,
    "valG5Ant": 0,
    "valG6Ant": 0,
    "prespectivaHostilAnt": 0,
    "raivaInternaAnt": 0,
    "raivaExternaAnt": 0,
    "totalOpcaoAnt": 0,
  };

  Future<void> _obterDados() async {
    setState(() {
      valores.forEach((key, value) {
        if (key.endsWith("Ant")) {
          valores[key] = valores[key.replaceFirst("Ant", "")]!;
        }
      });

      _valorPontuacao =
          _obterValor(_isCrescente(_indicePerguntaAtual), _opcaoSelecionada);
      _grupo = _obterGrupo(_indicePerguntaAtual);

      valores["prespectivaHostil"] = _acumularPontuacao(
        _indicePerguntaAtual,
        [10, 12, 16, 17, 22, 33, 38, 40, 41],
        valores["prespectivaHostil"]!,
        _valorPontuacao,
      );
      valores["raivaExterna"] = _acumularPontuacao(
        _indicePerguntaAtual,
        [7, 8, 9, 10, 15, 23, 24, 28, 30, 32, 35],
        valores["raivaExterna"]!,
        _valorPontuacao,
      );
      valores["raivaInterna"] = _acumularPontuacao(
        _indicePerguntaAtual,
        [
          1,
          2,
          4,
          5,
          6,
          11,
          12,
          18,
          19,
          20,
          21,
          22,
          25,
          29,
          31,
          37,
          38,
          40,
          41,
          43,
          44,
          45,
          46
        ],
        valores["raivaInterna"]!,
        _valorPontuacao,
      );

      valores["valAc"] = valores["valAc"]! + _valorPontuacao;
      valores["totalOpcao"] = valores["totalOpcao"]! + _valorPontuacao;
      _percentualConcluido = (valores["totalOpcao"]! * 100) / pontuacaoMaxima;
      if (!ads) _toAdsCount = _calcularAdsCount(_indicePerguntaAtual);

      switch (_grupo) {
        case 1:
          valores["valG1"] = valores["valG1"]! + _valorPontuacao;
          break;
        case 2:
          valores["valG2"] = valores["valG2"]! + _valorPontuacao;
          break;
        case 3:
          valores["valG3"] = valores["valG3"]! + _valorPontuacao;
          break;
        case 4:
          valores["valG4"] = valores["valG4"]! + _valorPontuacao;
          break;
        case 5:
          valores["valG5"] = valores["valG5"]! + _valorPontuacao;
          break;
        case 6:
          valores["valG6"] = valores["valG6"]! + _valorPontuacao;
          break;
      }
      if (!ads) _exibirAnuncioIntermediario(_indicePerguntaAtual);

      _indicePerguntaAtual++;
      _habilitarVoltar = true;
    });

    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 44, antes de ir para 45)
    // Carrega em background sem bloquear
    if (!ads && _indicePerguntaAtual == 44) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    if (_indicePerguntaAtual > totalPerguntas) _navegarParaResultado();
  }

  static const Set<int> _nonCrescenteQuestions = {
    2,
    3,
    5,
    8,
    10,
    11,
    13,
    14,
    21,
    24,
    25,
    26,
    28,
    42,
    44
  };

  bool _isCrescente(int value) {
    return !_nonCrescenteQuestions.contains(value);
  }

  static const List<Map<String, int>> _grupoRanges = [
    {'start': 1, 'end': 4, 'group': 1},
    {'start': 5, 'end': 12, 'group': 2},
    {'start': 13, 'end': 19, 'group': 3},
    {'start': 20, 'end': 22, 'group': 4},
    {'start': 23, 'end': 43, 'group': 5},
    {'start': 44, 'end': 46, 'group': 6},
  ];

  int _obterGrupo(int value) {
    return _grupoRanges.firstWhere(
        (range) => value >= range['start']! && value <= range['end']!,
        orElse: () => {'group': 0})['group']!;
  }

  int _obterValor(bool crescente, int opcao) {
    return crescente ? opcao : 4 - opcao;
  }

  int _acumularPontuacao(
      int value, List<int> cases, int acumulador, int valor) {
    return cases.contains(value) ? acumulador + valor : acumulador;
  }

  int _calcularAdsCount(int value) {
    // Avisos 3 perguntas antes dos anúncios nas perguntas 15 e 30
    // Pergunta 15: avisos nas 12, 13, 14
    // Pergunta 30: avisos nas 27, 28, 29
    // Carregamos na pergunta 26 (4 perguntas antes) para garantir disponibilidade
    if (value == 12 || value == 27) return 3;
    if (value == 13 || value == 28) return 2;
    if (value == 14 || value == 29) return 1;
    return 0;
  }

  void _exibirAnuncioIntermediario(int value) {
    // Carregar anúncio 4 perguntas antes (perguntas 11 e 26) para garantir disponibilidade
    // Carrega em background sem bloquear
    if (value == 11 || value == 26) {
      AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
    }
    // Carregar também 3 perguntas antes como backup (perguntas 12 e 27)
    else if (value == 12 || value == 27) {
      // Se ainda não há anúncio disponível, tenta carregar novamente
      if (!AdManager.to.hasInterstitialAd) {
        AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
      }
    }
    // Mostrar anúncios nas perguntas 15 e 30
    else if (value == 15 || value == 30) {
      // Verifica se há anúncio disponível antes de tentar mostrar
      if (AdManager.to.hasInterstitialAd) {
        // Ignora cooldown para anúncios programados durante o teste
        AdManager.to.showInterstitialAd(ignoreCooldown: true);
      }
      // Se não está carregado, não bloqueia - simplesmente não mostra
      // (já foi tentado carregar nas perguntas anteriores)
    }
  }

  void _gravarHistorico() {
    final dataERegisto = ":${valores["valAc"]}"
        "G1${valores["valG1"]}"
        "G2${valores["valG2"]}"
        "G3${valores["valG3"]}"
        "G4${valores["valG4"]}"
        "G5${valores["valG5"]}"
        "G6${valores["valG6"]}"
        "Int${valores["raivaInterna"]}"
        "Ext${valores["raivaExterna"]}"
        "Hos${valores["prespectivaHostil"]}"
        "End";
    HistoricOperator().gravarHistorico("rai", dataERegisto);
  }

  Future<void> _navegarParaResultado() async {
    _gravarHistorico();
    if (ads) {
      Get.offNamed(RotasPaginas.resultadoTesteRaiva, arguments: [
        valores["valAc"],
        valores["valG1"],
        valores["valG2"],
        valores["valG3"],
        valores["valG4"],
        valores["valG5"],
        valores["valG6"],
        valores["prespectivaHostil"],
        valores["raivaInterna"],
        valores["raivaExterna"],
        false,
      ]);
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
          Get.offNamed(RotasPaginas.resultadoTesteRaiva,
              arguments: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, true]);
        },
        () async {
          Get.back();
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          Get.offNamed(RotasPaginas.resultadoTesteRaiva, arguments: [
            valores["valAc"],
            valores["valG1"],
            valores["valG2"],
            valores["valG3"],
            valores["valG4"],
            valores["valG5"],
            valores["valG6"],
            valores["prespectivaHostil"],
            valores["raivaInterna"],
            valores["raivaExterna"],
            false,
          ]);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _voltarPerguntaFunc() {
    setState(() {
      valores.forEach((key, value) {
        if (key.endsWith("Ant")) {
          valores[key.replaceFirst("Ant", "")] = value;
        }
      });
      _percentualConcluido = (valores["totalOpcao"]! * 100) / pontuacaoMaxima;
      _indicePerguntaAtual--;
      _habilitarVoltar = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    final bool isVeryShort = screenH < 720;
    final bool isUltraShort = screenH < 630;
    final double cardMaxHeight = screenH *
        (isUltraShort
            ? 0.55
            : (isVeryShort
                ? 0.60
                : (isShortScreen
                    ? 0.64
                    : 0.68))); // limita altura do cartão para abrir espaço aos botões
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoRaiva,
        titulo: "_tRaiva".tr,
      ),
      drawer: const MyDrawer(),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: MyG.to.margens['margem22']!,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      isShortScreen ? Spacing.xs : Spacing.s,
                      Spacing.s,
                      isShortScreen ? Spacing.xs : Spacing.s,
                      0),
                  child: Center(
                    child: Column(
                      children: <Widget>[
                        Flexible(
                          child: SizedBox(
                            height: cardMaxHeight,
                            child: TestCardContainer(
                              innerPadding: EdgeInsets.zero,
                              child: LayoutBuilder(
                                  builder: (context, constraints) {
                                final double pad = MyG.to.margens['margem035']!;
                                final bool isShort =
                                    constraints.maxHeight < 560;
                                final double spacing = isUltraShort
                                    ? pad * 0.4
                                    : (isVeryShort
                                        ? pad * 0.45
                                        : (isShort ? pad * 0.5 : pad * 0.85));
                                // Altura dinâmica segura para a imagem no bloco inferior
                                final double imgFactor = isUltraShort
                                    ? 0.6
                                    : (isVeryShort
                                        ? 0.7
                                        : (isShortScreen ? 0.8 : 0.9));
                                final double capByMargin =
                                    MyG.to.margens['margem3']! * imgFactor;
                                final double capByHeight = constraints
                                        .maxHeight *
                                    (isUltraShort
                                        ? 0.12
                                        : (isVeryShort
                                            ? 0.14
                                            : (isShortScreen ? 0.16 : 0.18)));
                                final double safeImageHeight =
                                    math.min(capByMargin, capByHeight);
                                return Padding(
                                  padding: EdgeInsets.all(pad),
                                  child: SingleChildScrollView(
                                    physics: isShort
                                        ? const ClampingScrollPhysics()
                                        : const NeverScrollableScrollPhysics(),
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight:
                                            constraints.maxHeight - (pad * 2),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          QuestionHeader(
                                            current: _indicePerguntaAtual,
                                            total: totalPerguntas,
                                            canGoBack: _habilitarVoltar,
                                            showAdsIcon:
                                                !ads && _toAdsCount != 0,
                                            adsCount: _toAdsCount,
                                            onBack: _voltarPerguntaFunc,
                                          ),
                                          SizedBox(height: spacing),
                                          TextoPergunta(
                                            questionText:
                                                'r$_indicePerguntaAtual'.tr,
                                            questionIndex: _indicePerguntaAtual,
                                            numeroLinhas: 2,
                                            fontSizeOverride: isUltraShort
                                                ? 15
                                                : (isVeryShort
                                                    ? 16
                                                    : (isShortScreen
                                                        ? 17
                                                        : 18)),
                                          ),
                                          SizedBox(height: spacing),
                                          Transform.scale(
                                            scale: isUltraShort
                                                ? 0.82
                                                : (isVeryShort
                                                    ? 0.86
                                                    : (isShortScreen
                                                        ? 0.9
                                                        : 0.95)),
                                            child: StatusRow(
                                              valores: valores,
                                              grupo: _grupo,
                                            ),
                                          ),
                                          SizedBox(height: spacing),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  GraficoPercentagemHorizontal(
                                                    perct: _percentualConcluido,
                                                    tamanhografico:
                                                        (isUltraShort
                                                            ? 6
                                                            : (isShortScreen
                                                                ? 8
                                                                : 10)),
                                                    heightOverride: isUltraShort
                                                        ? MyG.to.margens[
                                                            'margem025']!
                                                        : (isVeryShort
                                                            ? MyG.to.margens[
                                                                'margem05']!
                                                            : MyG.to.margens[
                                                                'margem075']!),
                                                    percentColors:
                                                        PercentPalettes.raiva,
                                                  ),
                                                  isUltraShort
                                                      ? Reuse.myHeigthBox025
                                                      : Reuse.myHeigthBox050,
                                                  ValorPercentagem(
                                                      perct:
                                                          _percentualConcluido),
                                                ],
                                              ),
                                              Reuse.myWidthBox1,
                                              ImageForValues(
                                                percentual: _percentualConcluido
                                                    .toDouble(),
                                                alturaImagem: safeImageHeight,
                                                valueImages:
                                                    ImageThresholds.raiva,
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Botões em largura total do ecrã
          Padding(
            padding: EdgeInsets.fromLTRB(
                0, isUltraShort ? r.spacingSmall * 0.05 : Spacing.xs, 0, 0),
            child: Botoes5Resposta(
              onSelectedResponse: (int opcao) {
                _opcaoSelecionada = opcao;
                setState(() {
                  _obterDados();
                });
              },
            ),
          ),
          SizedBox(height: isShortScreen ? 0 : MyG.to.margens['margem01']!),
        ],
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }
}

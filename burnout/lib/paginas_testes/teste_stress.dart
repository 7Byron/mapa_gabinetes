import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/escala_4.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/question_header.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_metrics_row.dart';
import '../widgets/section_title.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/spacing.dart';
import '../funcoes/image_value_thresholds.dart';

class PaginaTesteStress extends StatefulWidget {
  const PaginaTesteStress({super.key});

  @override
  State<PaginaTesteStress> createState() => _PaginaTesteStressState();
}

class _PaginaTesteStressState extends State<PaginaTesteStress> {
  final bool ads = MyG.to.adsPago;
  final RxInt _sumValores = 0.obs;
  final RxInt _pedeP = 1.obs;
  final RxDouble _perct = 0.0.obs;
  final RxBool _voltarPergunta = false.obs;
  final RxList<int> grupos = <int>[0, 0, 0, 0, 0, 0].obs;
  int _valAnteriorInt = 0;
  final RxString _tituloGrupo = "gr_estilo_vida".tr.obs;
  final RxString _imagemGrupo = RotaImagens.estilovida.obs;
  final List<int> perguntasInicioGrupo = [1, 17, 33, 49, 65, 81];
  final RxInt _toAdsCount = 0.obs;

  void _gerenciarAnuncio() {
    final proximosAnuncios = [17, 33, 49, 65, 81, 97];

    if (proximosAnuncios.contains(_pedeP.value + 3)) {
      _toAdsCount.value = 3;
    } else if (_toAdsCount.value > 0) {
      _toAdsCount.value--;
    }
  }

  void _obterDados(String valorBotao) {
    _updateValues(valorBotao);

    if (_pedeP.value >= 96) {
      if (!ads) {
        // Verifica se há anúncio disponível antes de tentar mostrar
        if (AdManager.to.hasInterstitialAd) {
          AdManager.to.showInterstitialAd();
        }
        // Se não está carregado, não bloqueia - simplesmente não mostra
      }
      _updateGroup();
      Get.offNamed(
        RotasPaginas.testeStressAgravantes,
        arguments: [_sumValores.value.toDouble(), grupos],
      );
      return;
    }

    // Carregar intersticial ANTES de incrementar (quando está na pergunta 1, 18, 34, 50, 66, 82)
    // Carrega em background sem bloquear
    if (!ads && [1, 18, 34, 50, 66, 82].contains(_pedeP.value)) {
      AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
    }

    _pedeP.value++;

    // Mostrar intersticiais nas perguntas 17, 33, 49, 65, 81, 97
    if (!ads && [17, 33, 49, 65, 81, 97].contains(_pedeP.value)) {
      // Verifica se há anúncio disponível antes de tentar mostrar
      if (AdManager.to.hasInterstitialAd) {
        AdManager.to.showInterstitialAd(ignoreCooldown: true);
      }
      // Se não está carregado, não bloqueia - simplesmente não mostra
      // (já foi tentado carregar nas perguntas anteriores)
      _toAdsCount.value = 0;
    }

    if (!ads) {
      _gerenciarAnuncio();
    }

    _updateGroup();
    _perct.value = (_sumValores.value * 100) / 303;
    _voltarPergunta.value = !perguntasInicioGrupo.contains(_pedeP.value);
  }

  void _voltarPerguntaAcao() {
    if (_pedeP.value > 1) {
      _pedeP.value--;
      _sumValores.value -= _valAnteriorInt;
      _perct.value = (_sumValores.value * 100) / 303;
      _updateGroup();
      _voltarPergunta.value = false;
    }
  }

  void _updateValues(String valorBotao) {
    final valores = obterValoresPorResposta(_pedeP.value);
    _valAnteriorInt = valores[valorBotao] ?? 0;
    _sumValores.value += _valAnteriorInt;
  }

  Map<String, int> obterValoresPorResposta(int perguntaAtual) {
    final perguntasInvertidas = [
      1,
      2,
      5,
      8,
      9,
      11,
      15,
      16,
      19,
      20,
      23,
      24,
      27,
      28,
      31,
      32,
      35,
      36,
      42,
      43,
      51,
      52,
      55,
      56,
      59,
      60,
      63,
      64,
      65,
      66,
      69,
      70,
      73,
      74,
      81,
      82,
      85,
      86,
      89,
      90
    ];

    if (perguntasInvertidas.contains(perguntaAtual)) {
      return {"N": 3, "R": 2, "H": 1, "S": 0};
    } else {
      return {"N": 0, "R": 1, "H": 2, "S": 3};
    }
  }

  void _updateGroup() {
    final gruposLimites = [17, 33, 49, 65, 81, 96];
    final titulosGrupos = [
      "gr_estilo_vida".tr,
      "gr_ambiente".tr,
      "gr_sintomas".tr,
      "gr_emprego_ocupacao".tr,
      "gr_relacionamentos".tr,
      "gr_personalidade".tr
    ];
    final imagensGrupos = [
      RotaImagens.estilovida,
      RotaImagens.ambiente,
      RotaImagens.sintomas,
      RotaImagens.emprego,
      RotaImagens.relacionamento,
      RotaImagens.personalidade
    ];

    for (int i = 0; i < gruposLimites.length; i++) {
      if (_pedeP.value == gruposLimites[i]) {
        _tituloGrupo.value = titulosGrupos[i];
        _imagemGrupo.value = imagensGrupos[i];
        if (i == 0) {
          grupos[i] = _sumValores.value;
        } else {
          grupos[i] = _sumValores.value -
              grupos.sublist(0, i).fold(0, (prev, element) => prev + element);
        }
        return;
      }
    }

    if (_pedeP.value >= 96) {
      grupos[5] = _sumValores.value -
          grupos.sublist(0, 5).fold(0, (prev, element) => prev + element);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoStress,
        titulo: "_tStress".tr,
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            child: Obx(
              () => Column(
                children: <Widget>[
                  SizedBox(height: Spacing.xs),
                  SectionTitle(title: _tituloGrupo.value),
                  SizedBox(height: Spacing.xs),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: MyG.to.margens['margem3']!,
                    ),
                    child: Material(
                      elevation: 4.0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.15,
                        ),
                        child: Image(
                          image: AssetImage(_imagemGrupo.value),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: Spacing.xs),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(Spacing.s),
                      child: TestCardContainer(
                        child: Column(
                          children: [
                            QuestionHeader(
                              current: _pedeP.value,
                              total: 96,
                              canGoBack: _voltarPergunta.value,
                              showAdsIcon: !ads && _toAdsCount.value != 0,
                              adsCount: _toAdsCount.value,
                              onBack: _voltarPerguntaAcao,
                              spacingBeforeDivider: Spacing.xs,
                              thinDivider: true,
                            ),
                            Expanded(
                              flex: 2,
                              child: Center(
                                child: TextoPergunta(
                                  questionText: 'P${_pedeP.value}'.tr,
                                  questionIndex: _pedeP.value,
                                  numeroLinhas: 5,
                                ),
                              ),
                            ),
                            SizedBox(height: Spacing.xs),
                            Expanded(
                              child: QuestionMetricsRow(
                                perct: _perct.value,
                                desiredUnits: 10,
                                barHeight:
                                    Spacing.l, // aumenta a altura do gráfico
                                valueImages: ImageThresholds.stress,
                                percentColors: PercentPalettes.stress,
                              ),
                            ),
                            SizedBox(height: Spacing.xs),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Botoes4Resposta(
                    onRespostaSelecionada: (resposta) {
                      _obterDados(resposta);
                    },
                  ),
                  SizedBox(height: Spacing.xs),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }
}

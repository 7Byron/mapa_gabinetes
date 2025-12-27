import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/escala_4.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_metrics_vertical_row.dart';
import '../widgets/question_header.dart';
import '../funcoes/graph_palettes_vertical.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class TesteAutoConfianca extends StatefulWidget {
  const TesteAutoConfianca({super.key});

  @override
  State<TesteAutoConfianca> createState() => _TesteAutoConfiancaState();
}

class _TesteAutoConfiancaState extends State<TesteAutoConfianca> {
  bool ads = MyG.to.adsPago;
  double _sumValores = 0;
  int _pedeP = 1;
  double _perct = 0;
  bool _voltarPergunta = false;
  int _valAnteriorInt = 0;

  @override
  void initState() {
    super.initState();
    _valAnteriorInt = 0;
  }

  Future<void> _obterDados(String opcao) async {
    _valAnteriorInt = 0;
    await Future.delayed(const Duration(milliseconds: 450));

    final int valorResposta = _calcularValorResposta(_pedeP, opcao);
    _sumValores += valorResposta;
    _valAnteriorInt = valorResposta;

    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 13, antes de ir para 14)
    // Carrega em background sem bloquear
    if (!ads && _pedeP == 13) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    setState(() {
      _pedeP++;
      _perct = (_sumValores * 100) / 45;
      _voltarPergunta = true;
    });

    if (_pedeP == 16) {
      _finalizeTest();
    }
  }

  int _calcularValorResposta(int pergunta, String opcao) {
    final valores = {
      'N': [3, 2, 1, 0],
      'R': [2, 1, 2, 1],
      'H': [1, 0, 3, 2],
      'S': [0, 3, 0, 3]
    };

    final indices = [2, 4, 5, 10, 13, 14].contains(pergunta) ? 0 : 1;

    return valores[opcao]?[indices] ?? 0;
  }

  Future<void> _finalizeTest() async {
    _sumValores = _sumValores.clamp(0, 45); // Evita valores inválidos

    HistoricOperator().gravarHistorico("aut", _sumValores);

    if (ads) {
      Get.toNamed(RotasPaginas.resultadoAutoConfianca,
          arguments: [_sumValores]);
    } else {
      await _exibirVideoAnuncio();
    }
  }

  Future<void> _exibirVideoAnuncio() async {
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
        Get.toNamed(RotasPaginas.resultadoAutoConfianca, arguments: [0.0]);
      },
      () async {
        Get.back();
        // Navega imediatamente para o resultado (em background)
        // Quando o usuário fechar o anúncio, já estará na página de resultado
        Get.toNamed(RotasPaginas.resultadoAutoConfianca,
            arguments: [_sumValores]);
        // Inicia o anúncio após navegar (não bloqueia a navegação)
        AdManager.to.showRewardedAd();
      },
    );
  }

  void _onBackPressed() {
    setState(() {
      _sumValores = (_sumValores - _valAnteriorInt).clamp(0, 45);
      _pedeP--;
      _perct = (_sumValores * 100) / 45;
      _voltarPergunta = false;
      _valAnteriorInt = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoAutoConfianca,
        titulo: "_tAutoConfianca".tr,
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            child: Column(
              children: <Widget>[
                Reuse.myHeigthBox050,
                _buildCardPergunta(),
                Reuse.myHeigthBox050,
                Flexible(
                  child: Botoes4Resposta(onRespostaSelecionada: _obterDados),
                ),
                Reuse.myHeigthBox050,
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Widget _buildCardPergunta() {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: EdgeInsets.all(Spacing.s),
        child: Container(
          decoration: Reuse.mySombraContainer,
          child: Card(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool isShort = constraints.maxHeight < 420;
                final double pad = Spacing.s;
                final double spacing = isShort ? pad / 2 : pad;

                return Padding(
                  padding: EdgeInsets.all(pad),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          QuestionHeader(
                            current: _pedeP,
                            total: 15,
                            canGoBack: _voltarPergunta,
                            onBack: _onBackPressed,
                            spacingBeforeDivider: spacing / 2,
                          ),
                          SizedBox(height: spacing / 2),
                          Center(
                            child: TextoPergunta(
                              questionText: 'aut_$_pedeP'.tr,
                              questionIndex: _pedeP,
                              numeroLinhas: isShort ? 3 : 4,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: spacing / 3),
                          _buildGraficoResultados(constraints),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGraficoResultados(BoxConstraints constraints) {
    final int graphUnits = constraints.maxHeight < 420 ? 6 : 7;
    final double graphPixelHeight = MyG.to.margem * graphUnits;
    return QuestionMetricsVerticalRow(
      perct: _perct,
      graphUnits: graphUnits,
      imageHeight: graphPixelHeight,
      valueImages: ImageThresholds.autoConfianca,
      percentColors: PercentPalettesV.autoConfianca,
    );
  }
}

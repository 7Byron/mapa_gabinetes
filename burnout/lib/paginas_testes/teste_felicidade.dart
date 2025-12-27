import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/likert_5.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_metrics_row.dart';
import '../widgets/question_header.dart';
import '../widgets/section_title.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/spacing.dart';
import '../funcoes/image_value_thresholds.dart';

class PaginaTesteFelicidade extends StatefulWidget {
  const PaginaTesteFelicidade({super.key});

  @override
  State<PaginaTesteFelicidade> createState() => _PaginaTesteFelicidadeState();
}

class _PaginaTesteFelicidadeState extends State<PaginaTesteFelicidade> {
  final bool ads = MyG.to.adsPago;
  int _sumValTeste = 0;
  int _pedeP = 1;
  double _perct = 0;
  bool _voltarPergunta = false;
  int _valAnteriorInt = 0;
  int _toAdsCount = 0;

  final int rewardAdPoint = 14;

  void _gravarHistorico() {
    HistoricOperator().gravarHistorico("fel", _sumValTeste);
  }

  double _calculatePercentage(int sum) {
    return ((sum * 100) / 128).clamp(0, 100);
  }

  Future<void> _obterDados(int opcaoSelecionada) async {
    if (_pedeP >= 33) {
      _navigateToResult();
      return;
    }

    // Carregar intersticial ANTES de incrementar (quando está na pergunta 11, antes de ir para 12)
    // Carrega em background sem bloquear a interface
    if (!ads && _pedeP == 11) {
      AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
    }

    setState(() {
      _sumValTeste += opcaoSelecionada;
      _valAnteriorInt = opcaoSelecionada;
      _perct = _calculatePercentage(_sumValTeste);
      _pedeP++;
      _voltarPergunta = true;
    });

    _updateAdsCount();
    _handleAdsAndNavigation(); // Sem await - não bloqueia
  }

  void _updateAdsCount() {
    // Avisos 3 perguntas antes do anúncio na pergunta 16
    // Pergunta 13 → ícone "3"
    // Pergunta 14 → ícone "2"
    // Pergunta 15 → ícone "1"
    if (_pedeP == 13) {
      _toAdsCount = 3;
    } else if (_pedeP == 14) {
      _toAdsCount = 2;
    } else if (_pedeP == 15) {
      _toAdsCount = 1;
    } else {
      _toAdsCount = 0;
    }
  }

  void _handleAdsAndNavigation() {
    if (ads) return;

    // Carregar também 3 perguntas antes (12) como backup (já carregamos na 11)
    if (_pedeP == 12) {
      if (!AdManager.to.hasInterstitialAd) {
        AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
      }
    }
    // Mostrar anúncio na pergunta 15 (antes de incrementar para 16)
    else if (_pedeP == 15) {
      // Verifica se há anúncio disponível antes de tentar mostrar
      if (AdManager.to.hasInterstitialAd) {
        // Ignora cooldown para anúncios programados durante o teste
        AdManager.to.showInterstitialAd(ignoreCooldown: true);
      }
      // Se não está carregado, não bloqueia - simplesmente não mostra
      // (já foi tentado carregar nas perguntas anteriores)
    }
    // Carregar rewarded ad na pergunta 13 (antes de incrementar para 14)
    // Carrega em background sem bloquear
    else if (_pedeP == 13) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }
  }

  Future<void> _navigateToResult() async {
    _gravarHistorico();
    if (ads) {
      Get.offNamed(
        RotasPaginas.resultadoTesteFelicidade,
        arguments: _sumValTeste,
      );
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
          Get.offNamed(RotasPaginas.resultadoTesteFelicidade, arguments: 0);
        },
        () async {
          Get.back();
          await AdManager.to.showRewardedAd();
          Get.offNamed(
            RotasPaginas.resultadoTesteFelicidade,
            arguments: _sumValTeste,
          );
        },
      );
    }
  }

  void _onBackPressed() {
    if (_pedeP > 1) {
      setState(() {
        _sumValTeste -= _valAnteriorInt;
        _pedeP--;
        _perct = _calculatePercentage(_sumValTeste);
        _voltarPergunta = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoFelicidade,
        titulo: "_tFelicidade".tr,
      ),
      drawer: const MyDrawer(),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          child: Column(
            children: <Widget>[
              _buildQuestionCard(),
              Reuse.myHeigthBox050,
              Likert5Respostas(
                onOptionSelected: _obterDados,
              ),
              Reuse.myHeigthBox050,
            ],
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Expanded _buildQuestionCard() {
    return Expanded(
      flex: 3,
      child: SizedBox(
        width: MyG.to.margens['margem22']!,
        height: double.maxFinite,
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: TestCardContainer(
            innerPadding: EdgeInsets.all(MyG.to.margens['margem075']!),
            child: Column(
              children: [
                QuestionHeader(
                  current: _pedeP,
                  total: 32,
                  canGoBack: _voltarPergunta,
                  showAdsIcon: !ads && _toAdsCount != 0,
                  adsCount: _toAdsCount,
                  onBack: _onBackPressed,
                ),
                SizedBox(height: Spacing.xs),
                SectionTitle(title: "titulofrequecia".tr),
                Expanded(
                  child: Center(
                    child: TextoPergunta(
                      questionText: 'fp$_pedeP'.tr,
                      questionIndex: _pedeP,
                      numeroLinhas: 3,
                    ),
                  ),
                ),
                QuestionMetricsRow(
                  perct: _perct,
                  desiredUnits: 12,
                  barHeight: Spacing.m,
                  imageWidth: 110,
                  imageOnRight: true,
                  valueImages: ImageThresholds.felicidade,
                  percentColors: PercentPalettes.felicidade,
                ),
                SizedBox(height: Spacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

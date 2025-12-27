import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../admob/ad_manager.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/question_header.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../admob/services/banner_ad_widget.dart';
import '../funcoes/custom_scaffold.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../opcoes_resposta_testes/yes_no_concordo_discordo.dart';
import '../relatorios_teste_reutilizaveis/relatorio_teste_atitude.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets/buttons_row.dart';
import '../funcoes/spacing.dart';

class PaginaTesteAtitude extends StatefulWidget {
  const PaginaTesteAtitude({super.key});

  @override
  State<PaginaTesteAtitude> createState() => _PaginaTesteAtitudeState();
}

class _PaginaTesteAtitudeState extends State<PaginaTesteAtitude> {
  bool ads = MyG.to.adsPago;
  int _valorResposta = 0;
  int _sumPassiva = 0;
  int _sumAgressiva = 0;
  int _sumManipuladora = 0;
  int _sumAssertiva = 0;
  int _pedeP = 1;
  bool _voltarPergunta = false;
  int _toAdsCount = 0;

  final Map<String, Set<int>> categorySets = {
    "passiva": {1, 7, 15, 16, 17, 25, 26, 35, 36, 37, 50, 51, 52, 59, 60},
    "agressiva": {4, 6, 10, 11, 20, 21, 28, 29, 30, 39, 40, 48, 49, 55, 56},
    "manipuladora": {3, 5, 9, 12, 13, 19, 22, 31, 32, 41, 42, 46, 47, 54, 57},
    "assertiva": {2, 8, 14, 18, 23, 24, 27, 33, 34, 38, 43, 44, 45, 53, 58},
  };

  Future<void> _obterDados() async {
    if (_pedeP == 60) {
      _navigateToResult();
    }
    _updateCategorySum(_valorResposta);
    _handleAdDisplay();

    if (_pedeP < 62) {
      setState(() {
        _pedeP++;
        _voltarPergunta = true;
      });
    }
  }

  void _updateCategorySum(int valor) {
    for (var category in categorySets.entries) {
      if (category.value.contains(_pedeP)) {
        switch (category.key) {
          case 'passiva':
            _sumPassiva += valor;
            break;
          case 'agressiva':
            _sumAgressiva += valor;
            break;
          case 'manipuladora':
            _sumManipuladora += valor;
            break;
          case 'assertiva':
            _sumAssertiva += valor;
            break;
        }
      }
    }
  }

  void _handleAdDisplay() {
    if (ads) return;

    // Avisos 3 perguntas antes dos anúncios nas perguntas 15, 30, 45
    _toAdsCount = _getToAdsCount(_pedeP);

    // Carregar anúncio 4 perguntas antes (11, 26, 41) para garantir disponibilidade
    // Carrega em background sem bloquear
    if (_pedeP == 11 || _pedeP == 26 || _pedeP == 41) {
      AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
    }
    // Carregar também 3 perguntas antes (12, 27, 42) como backup
    else if (_pedeP == 12 || _pedeP == 27 || _pedeP == 42) {
      if (!AdManager.to.hasInterstitialAd) {
        AdManager.to.loadInterstitialAd(); // Sem await - carrega em background
      }
    }
    // Mostrar anúncios nas perguntas 15, 30, 45
    else if (_pedeP == 15 || _pedeP == 30 || _pedeP == 45) {
      // Verifica se há anúncio disponível antes de tentar mostrar
      if (AdManager.to.hasInterstitialAd) {
        // Ignora cooldown para anúncios programados durante o teste
        AdManager.to.showInterstitialAd(ignoreCooldown: true);
      }
      // Se não está carregado, não bloqueia - simplesmente não mostra
      // (já foi tentado carregar nas perguntas anteriores)
    }
    // Carregar rewarded ad na pergunta 39 (antes de incrementar para 40)
    // Carrega em background sem bloquear
    else if (_pedeP == 39) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }
  }

  int _getToAdsCount(int pedeP) {
    // Avisos 3 perguntas antes dos anúncios nas perguntas 15, 30, 45
    // Pergunta 15: avisos nas 12, 13, 14
    // Pergunta 30: avisos nas 27, 28, 29
    // Pergunta 45: avisos nas 42, 43, 44
    if (pedeP == 12 || pedeP == 27 || pedeP == 42) {
      return 3;
    } else if (pedeP == 13 || pedeP == 28 || pedeP == 43) {
      return 2;
    } else if (pedeP == 14 || pedeP == 29 || pedeP == 44) {
      return 1;
    } else {
      return 0;
    }
  }

  void _gravarHistorico() {
    String formatPercent(int value) => ((value * 100) / 15).toStringAsFixed(0);
    HistoricOperator().gravarHistorico(
      "ati",
      "${formatPercent(_sumPassiva)}a${formatPercent(_sumAgressiva)}b"
          "${formatPercent(_sumManipuladora)}c${formatPercent(_sumAssertiva)}d",
    );
  }

  Future<void> _navigateToResult() async {
    _gravarHistorico();
    if (ads) {
      Get.offNamed(RotasPaginas.resultadoTesteAtitude, arguments: [
        _sumPassiva,
        _sumAgressiva,
        _sumManipuladora,
        _sumAssertiva
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
          Get.offNamed(RotasPaginas.resultadoTesteAtitude,
              arguments: [0, 0, 0, 0]);
        },
        () async {
          Get.back();
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          Get.offNamed(RotasPaginas.resultadoTesteAtitude, arguments: [
            _sumPassiva,
            _sumAgressiva,
            _sumManipuladora,
            _sumAssertiva
          ]);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoAtitude,
        titulo: "_tAtitude".tr,
      ),
      drawer: const MyDrawer(),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          child: Padding(
            padding: EdgeInsets.all(Spacing.xs),
            child: Column(
              children: <Widget>[
                SizedBox(height: Spacing.xs),
                _buildCardContent(),
                SizedBox(height: Spacing.s),
                _buildResponseButtons(),
                SizedBox(height: Spacing.xs),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Expanded _buildCardContent() {
    return Expanded(
      flex: 14,
      child: Container(
        decoration: Reuse.mySombraContainer,
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(Spacing.xs),
            child: Column(
              children: [
                QuestionHeader(
                  current: _pedeP,
                  total: 60,
                  canGoBack: _voltarPergunta,
                  showAdsIcon: !ads && _toAdsCount != 0,
                  adsCount: _toAdsCount,
                  onBack: _onBackPressed,
                  spacingBeforeDivider: MyG.to.margens['margem025']!,
                  thinDivider: true,
                ),
                SizedBox(height: Spacing.xs),
                const Spacer(),
                TextoPergunta(
                    questionText: '$_pedeP' 'p'.tr,
                    questionIndex: _pedeP,
                    numeroLinhas: 5),
                const Spacer(),
                GraficoAtitude(
                  sumPassiva: _sumPassiva,
                  sumAgressiva: _sumAgressiva,
                  sumManipuladora: _sumManipuladora,
                  sumAssertiva: _sumAssertiva,
                ),
                SizedBox(height: Spacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResponseButtons() {
    final List<Map<String, dynamic>> buttons = [
      {
        "gradientStart": Colors.red,
        "gradientEnd": Colors.red.shade100,
        "imagePath": RotaImagens.discordo,
        "label": "discordo",
        "responseValue": 0,
      },
      {
        "gradientStart": Colors.green,
        "gradientEnd": Colors.green.shade100,
        "imagePath": RotaImagens.concordo,
        "label": "concordo",
        "responseValue": 1,
      }
    ];

    return ButtonsRow(
      children: buttons
          .map((btn) => _buildResponseButton(
                gradientStart: btn["gradientStart"],
                gradientEnd: btn["gradientEnd"],
                imagePath: btn["imagePath"],
                label: btn["label"],
                responseValue: btn["responseValue"],
              ))
          .toList(),
    );
  }

  Widget _buildResponseButton({
    required Color gradientStart,
    required Color gradientEnd,
    required String imagePath,
    required String label,
    required int responseValue,
  }) {
    return YesNoDiscordoConcordo(
      gradientStart: gradientStart,
      gradientEnd: gradientEnd,
      imagePath: imagePath,
      label: label,
      responseValue: responseValue,
      onPressed: () => _onResponseSelected(responseValue),
    );
  }

  void _onResponseSelected(int valorResposta) {
    _valorResposta = valorResposta;
    _obterDados();
  }

  void _onBackPressed() {
    if (_pedeP > 1) {
      setState(() {
        _pedeP--;
        _voltarPergunta = _pedeP > 1;
        _updateCategorySum(-_valorResposta);
      });
    }
  }
}

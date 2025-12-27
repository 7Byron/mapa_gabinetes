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
import '../opcoes_resposta_testes/escala_3.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_metrics_row.dart';
import '../widgets/buttons_row.dart';
import '../widgets/question_header.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class TesteSorriso extends StatefulWidget {
  const TesteSorriso({super.key});

  @override
  State<TesteSorriso> createState() => _TesteSorrisoState();
}

class _TesteSorrisoState extends State<TesteSorriso> {
  bool voltarPergunta = false;
  bool ads = MyG.to.adsPago;
  double _sumValores = 0;
  int _pedeP = 1;
  double _valAnteriorInt = 0;
  final Map<ButtonResponseType, bool> _buttonStates = {
    ButtonResponseType.nunca: false,
    ButtonResponseType.raro: false,
    ButtonResponseType.sempre: false,
  };

  double get _perct => (_sumValores * 100) / 13;

  Future<void> _obterDados(ButtonResponseType respostaTipo) async {
    await Future.delayed(const Duration(milliseconds: 450));
    _calcularResposta(respostaTipo);
    _verificarAds(); // Sem await - não bloqueia

    setState(() {
      _pedeP++;
      _resetButtonStates();
      voltarPergunta = true;
    });
  }

  void _verificarAds() {
    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 3, antes de ir para 4)
    // Carrega em background sem bloquear
    if (!ads && _pedeP == 3) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }
    if (_pedeP == 13) {
      _handleFinalQuestion(); // Chama sem await - executa em background
    }
  }

  void _calcularResposta(ButtonResponseType tipo) {
    final Map<ButtonResponseType, double> pesoResposta = {
      ButtonResponseType.nunca: [6, 7, 9, 10].contains(_pedeP) ? 1 : 0,
      ButtonResponseType.raro: 0.5,
      ButtonResponseType.sempre:
          [1, 2, 3, 4, 5, 8, 11, 12, 13].contains(_pedeP) ? 1 : 0,
    };

    _sumValores += pesoResposta[tipo] ?? 0;
    _valAnteriorInt = pesoResposta[tipo] ?? 0;
  }

  Future<void> _handleFinalQuestion() async {
    _sumValores = _sumValores.clamp(0, 13);
    HistoricOperator().gravarHistorico("sor", _sumValores);
    void navegarParaResultado(double resultado) {
      Get.toNamed(RotasPaginas.resultadoSorriso, arguments: [resultado]);
    }

    if (ads) {
      navegarParaResultado(_sumValores);
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
        () => navegarParaResultado(0.0),
        () async {
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          navegarParaResultado(_sumValores);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _onBackPressed() {
    setState(() {
      _sumValores -= _valAnteriorInt;
      _pedeP--;
      voltarPergunta = false;
    });
  }

  void _resetButtonStates() {
    _buttonStates.updateAll((_, __) => false);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoSorriso,
        titulo: "_tSorriso".tr,
      ),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            child: Column(
              children: <Widget>[
                Reuse.myHeigthBox050,
                _buildCardContent(),
                Reuse.myHeigthBox1,
                buildResponseButtons(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Widget _buildCardContent() {
    return Expanded(
      flex: 5,
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margens['margem05']!),
        child: TestCardContainer(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isShort = constraints.maxHeight < 420;
              final double pad = MyG.to.margens['margem05']!;
              final double spacing = isShort ? pad / 2 : pad;

              return Padding(
                padding: EdgeInsets.all(pad),
                child: SingleChildScrollView(
                  physics: isShort
                      ? const ClampingScrollPhysics()
                      : const NeverScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // Garantir que ocupa no mínimo toda a altura disponível do card
                      minHeight: constraints.maxHeight - (pad * 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        QuestionHeader(
                          current: _pedeP,
                          total: 13,
                          canGoBack: voltarPergunta,
                          onBack: _onBackPressed,
                        ),
                        SizedBox(height: spacing),
                        TextoPergunta(
                          questionText: 'sor.$_pedeP'.tr,
                          questionIndex: _pedeP,
                          numeroLinhas: isShort ? 3 : 5,
                        ),
                        SizedBox(height: spacing),
                        QuestionMetricsRow(
                          perct: _perct,
                          desiredUnits: 8,
                          barHeight: MyG.to.margens['margem1']!,
                          imageWidth: 100,
                          imageOnRight: true,
                          valueImages: ImageThresholds.sorriso,
                          percentColors: PercentPalettes.sorriso,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  LayoutBuilder buildResponseButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double spacing = Spacing.s / 2;
        final double buttonWidth =
            ((constraints.maxWidth - spacing * 2) / 3).clamp(110.0, 260.0);
        return ButtonsRow(
          children: ButtonResponseType.values
              .map((tipo) => _buildBotaoResposta(tipo, buttonWidth))
              .toList(),
        );
      },
    );
  }

  Widget _buildBotaoResposta(ButtonResponseType tipo, double width) {
    return Botoes3Respostas(
      pressed: _buttonStates[tipo] ?? false,
      responseType: tipo,
      onTap: () {
        setState(() {
          _resetButtonStates();
          _buttonStates[tipo] = true;
        });
        _obterDados(tipo);
      },
      width: width,
    );
  }
}

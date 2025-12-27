import 'dart:async';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

import '../admob/ad_manager.dart';
import '../admob/services/banner_ad_widget.dart';

import '../funcoes/custom_scaffold.dart';
import '../funcoes/gravar_ler_historico.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
import '../widgets_pagina_testes/imagem_teste.dart';
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../funcoes/responsive.dart';
import '../widgets/question_metrics_row.dart';
import '../widgets/question_header.dart';
import '../widgets/test_card_container.dart';
import '../funcoes/graph_palettes.dart';

class PaginaTesteAnsiedade extends StatefulWidget {
  const PaginaTesteAnsiedade({super.key});

  @override
  State<PaginaTesteAnsiedade> createState() => _PaginaTesteAnsiedadeState();
}

class _PaginaTesteAnsiedadeState extends State<PaginaTesteAnsiedade> {
  final box = GetStorage();
  final int totalPerguntas = 21;

  List<int> respostas = List.filled(21, 0);
  List<bool> buttonStates = [false, false, false, false];

  List<String> respostasTexto = ["r0".tr, "ra".tr, "rb".tr, "rc".tr];
  List<Color> respostasCores = [
    Colors.amber[100]!,
    Colors.amber[200]!,
    Colors.amber[300]!,
    Colors.amber[500]!
  ];

  bool ads = MyG.to.adsPago;
  int sumValores = 0;
  int perguntaAtual = 1;
  bool voltarPergunta = false;
  bool _isProcessing = false;
  double perct = 0;
  int _valorPerguntaAnt = 0;

  Future<void> _obterDados(int valorOpcao) async {
    _valorPerguntaAnt = valorOpcao;
    if (_isProcessing) return;
    _isProcessing = true;
    respostas[perguntaAtual - 1] = valorOpcao;
    sumValores = respostas.reduce((value, element) => value + element);
    await Future.delayed(const Duration(milliseconds: 500));

    // Carregar rewarded ad ANTES de incrementar (quando está na pergunta 18, antes de ir para 19)
    // Carrega em background sem bloquear
    if (!ads && perguntaAtual == 18) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }

    setState(() {
      perguntaAtual++;
      voltarPergunta = true;
      _resetButtonStates();
      perct = (sumValores * 100) / 63;
    });

    if (perguntaAtual > totalPerguntas) {
      sumValores = sumValores > 63 ? 63 : sumValores;
      HistoricOperator().gravarHistorico("ans", sumValores.toString());
      if (ads) {
        Get.offNamed(RotasPaginas.resultadoAnsiedade, arguments: sumValores);
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
            Get.offNamed(RotasPaginas.resultadoAnsiedade, arguments: 0);
          },
          () async {
            Get.back();
            // Navega imediatamente para o resultado (em background)
            // Quando o usuário fechar o anúncio, já estará na página de resultado
            Get.offNamed(RotasPaginas.resultadoAnsiedade,
                arguments: sumValores);
            // Inicia o anúncio após navegar (não bloqueia a navegação)
            AdManager.to.showRewardedAd();
          },
        );
      }
    }

    _isProcessing = false;
  }

  void _resetButtonStates() {
    buttonStates = [false, false, false, false];
  }

  void _voltarPerguntaAnterior() {
    setState(() {
      perguntaAtual--;
      sumValores -= _valorPerguntaAnt;
      perct = (sumValores * 100) / 63;
      voltarPergunta = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    // Altura adaptativa e limitada para evitar overflow em diferentes ecrãs
    final double buttonHeight = (screenH * 0.07).clamp(48.0, 62.0);
    return CustomScaffold(
      drawer: const MyDrawer(),
      appBar: AppBarSecondary(
        image: RotaImagens.logoAnsiedade,
        titulo: "_tAnsiedade".tr,
      ),
      body: Center(
        child: SizedBox(
          width: MyG.to.margens['margem22']!,
          height: double.maxFinite,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              SizedBox(height: r.spacingSmall * 0.6),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MyG.to.margens['margem05']!),
                child: TestCardContainer(
                  child: LayoutBuilder(builder: (context, constraints) {
                    final double baseInner = 520;
                    final double innerScale =
                        (constraints.maxHeight / baseInner).clamp(0.8, 1.0);
                    final bool isWide = constraints.maxWidth >= 900;
                    // Largura central será deduzida dinamicamente
                    final int desiredUnits = isWide ? 25 : 12;
                    // largura real do gráfico será calculada no LayoutBuilder do centro
                    return Padding(
                      padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                      child: Transform.scale(
                        scale: innerScale,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            QuestionHeader(
                              current: perguntaAtual,
                              total: totalPerguntas,
                              canGoBack: voltarPergunta,
                              onBack: _voltarPerguntaAnterior,
                            ),
                            // Linhas separadas: 1) pergunta 2) imagem + gráfico + %
                            Reuse.myHeigthBox025,
                            Center(
                              child: TextoPergunta(
                                questionText: 'p$perguntaAtual'.tr,
                                questionIndex: perguntaAtual,
                                numeroLinhas: isShortScreen ? 2 : 3,
                              ),
                            ),
                            isShortScreen
                                ? Reuse.myHeigthBox050
                                : Reuse.myHeigthBox1,
                            QuestionMetricsRow(
                              perct: perct,
                              desiredUnits: desiredUnits,
                              barHeight: MyG.to.margens['margem1_25']!,
                              imageWidth: 100,
                              valueImages: [
                                ValueImage(
                                    limit: 11, imagePath: RotaImagens.ans1),
                                ValueImage(
                                    limit: 24, imagePath: RotaImagens.ans2),
                                ValueImage(
                                    limit: 40,
                                    imagePath: RotaImagens.logoAnsiedade),
                                ValueImage(
                                    limit: 0, imagePath: RotaImagens.ans4),
                              ],
                              percentColors: PercentPalettes.ansiedade,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: r.spacingSmall * 0.6),
              Column(
                children: List.generate(4, (index) {
                  return Column(
                    children: [
                      _buildAnswerButton(
                        index + 1,
                        respostasTexto[index],
                        respostasCores[index],
                        buttonHeight,
                        () {
                          setState(() {
                            buttonStates[index] = !buttonStates[index];
                          });
                          _obterDados(index);
                        },
                      ),
                      SizedBox(
                          height: isShortScreen
                              ? r.spacingSmall * 0.4
                              : r.spacingSmall * 0.6),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  Widget _buildAnswerButton(int index, String text, Color color,
      double buttonHeight, VoidCallback onPressed) {
    return Container(
      width: buttonStates[index - 1]
          ? Get.width - MyG.to.margem - 10
          : Get.width - MyG.to.margem,
      decoration: buttonStates[index - 1] ? null : Reuse.mySombraContainer,
      child: Card(
        color: color,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
            child: SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: Center(
                child: AutoSizeText(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: TextStyle(
                    color: _isAnyOtherButtonPressed(index)
                        ? Colors.grey
                        : Colors.brown,
                    fontSize: MyG.to.margens['margem075']! * 0.9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isAnyOtherButtonPressed(int index) {
    for (int i = 0; i < buttonStates.length; i++) {
      if (i != index - 1 && buttonStates[i]) return true;
    }
    return false;
  }
}

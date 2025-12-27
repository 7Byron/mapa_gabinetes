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
import '../opcoes_resposta_testes/escala_5.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_app_bar_secundary.dart';
import '../widgets/my_drawer.dart';
import '../widgets/video_pre_resultado.dart';
// Import não necessário diretamente aqui
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_header.dart';
import '../widgets/question_metrics_vertical_row.dart';
import '../funcoes/graph_palettes_vertical.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class TesteRelacionamentos extends StatefulWidget {
  const TesteRelacionamentos({super.key});

  @override
  State<TesteRelacionamentos> createState() => _TesteRelacionamentosState();
}

class _TesteRelacionamentosState extends State<TesteRelacionamentos> {
  bool ads = MyG.to.adsPago;
  bool _voltarPergunta = false;
  int valAnteriorInt = 0;
  int opcao = 0;
  double valor = 0;
  int nperg = 1;

  Future<void> obterDados() async {
    setState(() {
      _voltarPergunta = true;
      valAnteriorInt = _updateValor(opcao);
      valor += valAnteriorInt; // Agora soma corretamente o valor acumulado
      _carregarRewardedAdSeNecessario();
      nperg++;
      if (nperg >= 21) {
        _finalizarTeste();
      }
    });
  }

  final Map<int, int> valoresRespostas = {
    1: 5,
    2: 4,
    3: 3,
    4: 2,
    5: 1,
  };

  int _updateValor(int opcao) {
    return valoresRespostas.containsKey(opcao) ? valoresRespostas[opcao]! : 0;
  }

  Future<void> _finalizarTeste() async {
    HistoricOperator().gravarHistorico("rel", valor);
    if (ads) {
      _navegarParaResultado(valor);
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
        () => _navegarParaResultado(0.0),
        () async {
          // Navega imediatamente para o resultado (em background)
          // Quando o usuário fechar o anúncio, já estará na página de resultado
          _navegarParaResultado(valor);
          // Inicia o anúncio após navegar (não bloqueia a navegação)
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _navegarParaResultado(double resultado) {
    Get.offNamed(RotasPaginas.resultadoRelacionamento, arguments: resultado);
  }

  void _carregarRewardedAdSeNecessario() {
    // Carregar rewarded ad na pergunta 15 (antes de incrementar para 16)
    // Carrega em background sem bloquear
    if (nperg == 15 && !ads) {
      AdManager.to.loadRewardedAd(); // Sem await - carrega em background
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoRelacionamentos,
        titulo: "_tRelacionamentos".tr,
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            height: double.maxFinite,
            child: Padding(
              padding: EdgeInsets.fromLTRB(MyG.to.margens['margem05']!,
                  MyG.to.margens['margem05']!, MyG.to.margens['margem05']!, 0),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                        child: Container(
                          decoration: Reuse.mySombraContainer,
                          child: Card(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final bool isShort =
                                    constraints.maxHeight < 420;
                                final double pad = MyG.to.margens['margem05']!;
                                final double spacing = isShort ? pad / 2 : pad;
                                final double targetBarH =
                                    constraints.maxHeight * 0.20;
                                final int graphUnits =
                                    (targetBarH / MyG.to.margem)
                                        .clamp(5, 7)
                                        .floor();
                                final double graphPixelHeight =
                                    (MyG.to.margem * graphUnits) -
                                        2; // margem de segurança

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
                                            current: nperg,
                                            total: 20,
                                            canGoBack: _voltarPergunta,
                                            onBack: _onBackPressed,
                                            spacingBeforeDivider: spacing,
                                          ),
                                          SizedBox(height: spacing / 2),
                                          TextoPergunta(
                                            questionText: 'rel.$nperg'.tr,
                                            questionIndex: nperg,
                                            numeroLinhas: isShort ? 3 : 5,
                                          ),
                                          SizedBox(height: spacing / 2),
                                          Center(
                                            child: QuestionMetricsVerticalRow(
                                              perct: valor,
                                              graphUnits: graphUnits,
                                              imageHeight: graphPixelHeight,
                                              valueImages: ImageThresholds
                                                  .relacionamento,
                                              percentColors: PercentPalettesV
                                                  .relacionamento,
                                            ),
                                          ),
                                          SizedBox(height: spacing / 2),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                        height: Get.width * 2 < Get.height
                            ? Spacing.l
                            : Spacing.xs),
                    Botoes5Resposta(
                      onSelectedResponse: (selectedOption) {
                        opcao = selectedOption + 1;
                        obterDados();
                      },
                    ),
                    SizedBox(
                        height: Get.width * 2 < Get.height
                            ? MyG.to.margem
                            : Spacing.xs),
                    Reuse.myHeigthBox1,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: ads ? Reuse.myHeigthBox1_5 : const BannerAdWidget(),
    );
  }

  void _onBackPressed() {
    if (nperg > 1) {
      setState(() {
        valor = (valor - valAnteriorInt).clamp(0, double.infinity);
        valAnteriorInt = 0;
        nperg--;
        _voltarPergunta = false;
      });
    }
  }
}

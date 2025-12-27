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
import '../widgets_pagina_testes/pergunta_texto.dart';
import '../widgets/question_header.dart';
import '../widgets/question_metrics_vertical_row.dart';
import '../funcoes/graph_palettes_vertical.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';

class TesteBurnout extends StatefulWidget {
  const TesteBurnout({super.key});

  @override
  State<TesteBurnout> createState() => _TesteBurnoutState();
}

class _TesteBurnoutState extends State<TesteBurnout> {
  bool ads = MyG.to.adsPago;

  int opcao = 0; // 1..5
  int nperg = 1; // 1..18

  final Map<int, int> _pointsByQuestion = {};

  int sumEx = 0;   // 1..6
  int sumDis = 0;  // 7..12
  int sumReal = 0; // 13..18 (bruto)

  final Map<int, int> valoresRespostas = const {
    1: 0, // Nunca
    2: 1, // Raramente
    3: 2, // Às vezes
    4: 3, // Frequentemente
    5: 4, // Sempre
  };

  int _pointsFromOpcao(int opcao) => valoresRespostas[opcao] ?? 0;

  static const int _maxPerQuestion = 4;
  static const int _totalQuestions = 18;
  static const int _questionsPerDim = 6;

  static const int _maxDim = _questionsPerDim * _maxPerQuestion; // 24
  static const int _maxTotal = _totalQuestions * _maxPerQuestion; // 72

  String _dimTitleForQuestion(int q) {
    if (q >= 1 && q <= 6) return "burn_dim_ex_title".tr;
    if (q >= 7 && q <= 12) return "burn_dim_dis_title".tr;
    return "burn_dim_real_title".tr;
  }

  bool _isRealDim(int q) => q >= 13 && q <= 18;

  int get _realAnsweredCount =>
      _pointsByQuestion.keys.where((q) => _isRealDim(q)).length;

  int get _maxRealSoFar => _realAnsweredCount * _maxPerQuestion;

  double get burnoutPartialPoints =>
      (sumEx + sumDis + (_maxRealSoFar - sumReal)).toDouble();

  double get burnoutPercentUi => (burnoutPartialPoints / _maxTotal) * 100.0;

  double get burnoutTotal =>
      (sumEx + sumDis + (_maxDim - sumReal)).toDouble(); // 0..72

  void _applyAnswer(int question, int newPoints) {
    final int oldPoints = _pointsByQuestion[question] ?? 0;

    if (question <= 6) {
      sumEx -= oldPoints;
    } else if (question <= 12) {
      sumDis -= oldPoints;
    } else {
      sumReal -= oldPoints;
    }

    _pointsByQuestion[question] = newPoints;

    if (question <= 6) {
      sumEx += newPoints;
    } else if (question <= 12) {
      sumDis += newPoints;
    } else {
      sumReal += newPoints;
    }
  }

  Future<void> obterDados() async {
    setState(() {
      final int pts = _pointsFromOpcao(opcao);
      _applyAnswer(nperg, pts);

      _carregarRewardedAdSeNecessario();

      nperg++;
      if (nperg >= 19) {
        _finalizarTeste();
      }
    });
  }

  Future<void> _finalizarTeste() async {
    final double total = burnoutTotal;

    final Map<String, dynamic> payload = {
      "total": total,                         // 0..72
      "ex": sumEx.toDouble(),                 // 0..24
      "dis": sumDis.toDouble(),               // 0..24
      "real": sumReal.toDouble(),             // 0..24 (bruto)
      "realInv": (_maxDim - sumReal).toDouble(), // 0..24 (invertido)
      "percent": ((total / _maxTotal) * 100).round(), // 0..100
    };

    final h = HistoricOperator();

// ✅ payload em texto (robusto no GetStorage e fácil de ler nos cards)
    final String histPayload =
        "t=${total.toStringAsFixed(0)};"
        "ex=${sumEx.toDouble().toStringAsFixed(0)};"
        "dis=${sumDis.toDouble().toStringAsFixed(0)};"
        "real=${sumReal.toDouble().toStringAsFixed(0)};"
        "realInv=${(_maxDim - sumReal).toDouble().toStringAsFixed(0)};"
        "pct=${((total / _maxTotal) * 100).round()}";

// ✅ grava 4 séries (para teres cards separados se quiseres)
    h.gravarHistorico("bur", histPayload);
    h.gravarHistorico("bur_ex", histPayload);
    h.gravarHistorico("bur_dis", histPayload);
    h.gravarHistorico("bur_real", histPayload);


    if (ads) {
      _navegarParaResultado(payload);
    } else {
      if (!AdManager.to.hasRewardedAd) {
        await AdManager.to.loadRewardedAd();
        int attempts = 0;
        while (!AdManager.to.hasRewardedAd && attempts < 20) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }
      }

      showVideoResultadoDialog(
            () => _navegarParaResultado({
          "total": 0.0,
          "ex": 0.0,
          "dis": 0.0,
          "real": 0.0,
          "realInv": 0.0,
          "percent": 0,
        }),
            () async {
          _navegarParaResultado(payload);
          AdManager.to.showRewardedAd();
        },
      );
    }
  }

  void _navegarParaResultado(Map<String, dynamic> payload) {
    Get.offNamed(RotasPaginas.resultadoBournt, arguments: payload);
  }

  void _carregarRewardedAdSeNecessario() {
    if (nperg == 15 && !ads) {
      AdManager.to.loadRewardedAd();
    }
  }

  void _onBackPressed() {
    if (nperg > 1) {
      setState(() {
        nperg--;
        final int oldPoints = _pointsByQuestion.remove(nperg) ?? 0;

        if (nperg <= 6) {
          sumEx -= oldPoints;
        } else if (nperg <= 12) {
          sumDis -= oldPoints;
        } else {
          sumReal -= oldPoints;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScaffold(
      appBar: AppBarSecondary(
        image: RotaImagens.logoRelacionamentos,
        titulo: "_tBurnout".tr,
      ),
      drawer: const MyDrawer(),
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: MyG.to.margens['margem22']!,
            height: double.maxFinite,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                MyG.to.margens['margem05']!,
                MyG.to.margens['margem05']!,
                MyG.to.margens['margem05']!,
                0,
              ),
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
                                final double pad =
                                MyG.to.margens['margem05']!;
                                final double spacing =
                                isShort ? pad / 2 : pad;
                                final double targetBarH =
                                    constraints.maxHeight * 0.35;
                                final int graphUnits =
                                (targetBarH / MyG.to.margem)
                                    .clamp(5, 7)
                                    .floor();
                                final double graphPixelHeight =
                                    (MyG.to.margem * graphUnits) - 2;

                                return Padding(
                                  padding: EdgeInsets.fromLTRB(pad, pad, pad, pad * 2),
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          QuestionHeader(
                                            current: nperg,
                                            total: _totalQuestions,
                                            canGoBack: nperg > 1,
                                            onBack: _onBackPressed,
                                            spacingBeforeDivider: spacing,
                                          ),
                                          SizedBox(height: spacing / 2),
                                          Text(
                                            _dimTitleForQuestion(nperg),
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: pad),
                                            child: TextoPergunta(
                                              questionText: 'burn_$nperg'.tr,
                                              questionIndex: nperg,
                                              numeroLinhas: isShort ? 3 : 5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Center(
                                        child:
                                        QuestionMetricsVerticalRow(
                                          perct: burnoutPercentUi
                                              .clamp(0.0, 100.0),
                                          graphUnits: graphUnits,
                                          imageHeight: graphPixelHeight,
                                          valueImages:
                                          ImageThresholds.burnout,
                                          percentColors:
                                          PercentPalettesV.burnout,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MyG.to.margens['margem05']! * 2,
                    ),
                    Botoes5Resposta(
                      onSelectedResponse: (selectedOption) {
                        opcao = selectedOption + 1; // 1..5
                        obterDados();
                      },
                    ),
                    SizedBox(
                      height: Get.width * 2 < Get.height
                          ? MyG.to.margem
                          : Spacing.xs,
                    ),
                    const BannerAdWidget(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

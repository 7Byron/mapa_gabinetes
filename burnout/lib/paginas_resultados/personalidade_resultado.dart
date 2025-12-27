import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pie_chart/pie_chart.dart';
import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/expanded_title.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/info_card_template.dart';
import '../funcoes/responsive.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';

class ResultadoPersonalidade extends StatefulWidget {
  const ResultadoPersonalidade({super.key});

  @override
  State<ResultadoPersonalidade> createState() => _ResultadoPersonalidadeState();
}

class _ResultadoPersonalidadeState extends State<ResultadoPersonalidade> {
  final String _valEscolha = Get.arguments[0];
  final int _sumExtroversao = Get.arguments[1];
  final int _sumAmabilidade = Get.arguments[2];
  final int _sumConsciencioso = Get.arguments[3];
  final int _sumNeuroticismo = Get.arguments[4];
  final int _sumAberto = Get.arguments[5];
  final bool ads = MyG.to.adsPago;

  late String _maiorTraco;
  late String _resposta;
  late double _barra100;
  final List<Color> colorList = [
    Colors.cyan,
    Colors.green,
    Colors.yellow,
    Colors.orange,
    Colors.brown,
  ];

  @override
  void initState() {
    super.initState();
    _maiorTraco = "";
    _resposta = "";

    if (_valEscolha != "NA") {
      _maiorTraco = getMaiorTraco();
      _resposta = getResposta();
    }
  }

  String getMaiorTraco() {
    final List<int> traits = [
      _sumExtroversao,
      _sumAmabilidade,
      _sumConsciencioso,
      _sumNeuroticismo,
      _sumAberto,
    ];

    final int maxIndex = traits.indexOf(traits.reduce(max));

    return ["5_e".tr, "5_a".tr, "5_c".tr, "5_n".tr, "5_o".tr][maxIndex];
  }

  String getResposta() => _maiorTraco == _valEscolha
      ? "${'pR1'.tr} $_valEscolha"
      : "$_valEscolha ${'pR2'.tr} $_maiorTraco";

  @override
  Widget build(BuildContext context) {
    _barra100 = Get.width - MyG.to.margens['margem4']!;

    final Map<String, double> dataMap = {
      '5_e'.tr: _sumExtroversao.toDouble(),
      '5_a'.tr: _sumAmabilidade.toDouble(),
      '5_c'.tr: _sumConsciencioso.toDouble(),
      '5_n'.tr: _sumNeuroticismo.toDouble(),
      '5_o'.tr: _sumAberto.toDouble(),
    };

    return ResultPageTemplate(
      appBarTitle: "_tPersonalidade".tr,
      appBarImage: RotaImagens.logoPersonalidade,
      buildResultCard: (context) => buildGlobalAnalysisCard(dataMap),
      buildInfoCard: (context) => buildInfoCard(),
      middleWidgets: [
        Reuse.myHeigthBox050,
        buildTraitsAnalysisCard(),
        CartaoHelpMe(),
      ],
    );
  }

  Widget buildGlobalAnalysisCard(Map<String, double> dataMap) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            ThemeTokens.radiusLarge), // Bordas arredondadas
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    "T1".tr,
                    style: textoDescricao(),
                  ),
                  Image.asset(
                      _maiorTraco == '5_e'.tr
                          ? RotaImagens.per3E
                          : _maiorTraco == '5_a'.tr
                              ? RotaImagens.per4N
                              : _maiorTraco == '5_c'.tr
                                  ? RotaImagens.per2C
                                  : _maiorTraco == '5_n'.tr
                                      ? RotaImagens.per5A
                                      : RotaImagens.per1A,
                      height: MyG.to.margens['margem3']!)
                ],
              ),
              Reuse.myDivider,
              Text(
                _resposta,
                style: TextStyle(
                  fontSize: MyG.to.margens['margem075']!,
                  //color: Colors.brown,
                ),
              ),
              // Espaço extra para evitar aproximação do donut ao texto
              SizedBox(height: Spacing.xxl),
              LayoutBuilder(builder: (context, constraints) {
                final double maxW = constraints.maxWidth;
                final double radius = (maxW * 0.30).clamp(120.0, 200.0);
                return RepaintBoundary(
                  child: PieChart(
                    dataMap: dataMap,
                    animationDuration: const Duration(milliseconds: 5000),
                    chartLegendSpacing: MyG.to.margens['margem2']!,
                    chartRadius: radius,
                    colorList: colorList,
                    initialAngleInDegree: 0,
                    chartType: ChartType.ring,
                    ringStrokeWidth: MyG.to.margens['margem3']!,
                    legendOptions: LegendOptions(
                      showLegendsInRow: true,
                      legendPosition: LegendPosition.bottom,
                      legendTextStyle: TextStyle(
                        fontSize: MyG.to.margens['margem065']!,
                      ),
                    ),
                    chartValuesOptions: const ChartValuesOptions(
                      showChartValueBackground: false,
                      showChartValuesInPercentage: true,
                      showChartValuesOutside: true,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTraitsAnalysisCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            ThemeTokens.radiusLarge), // Bordas arredondadas
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(
            children: [
              Text(
                "T2".tr,
                style: textoDescricao(),
              ),
              Reuse.myDivider,
              buildTraitBar(
                  context,
                  Colors.cyan,
                  Colors.cyan.shade100,
                  Colors.cyan.shade900,
                  _sumExtroversao,
                  "5_e".tr,
                  RotaImagens.per3E),
              buildTraitBar(
                  context,
                  Colors.green,
                  Colors.green.shade100,
                  Colors.green.shade900,
                  _sumAmabilidade,
                  "5_a".tr,
                  RotaImagens.per4N),
              buildTraitBar(
                  context,
                  Colors.yellow,
                  Colors.yellow.shade100,
                  Colors.yellow.shade900,
                  _sumConsciencioso,
                  "5_c".tr,
                  RotaImagens.per2C),
              buildTraitBar(
                  context,
                  Colors.orange,
                  Colors.orange.shade100,
                  Colors.orange.shade900,
                  _sumNeuroticismo,
                  "5_n".tr,
                  RotaImagens.per5A),
              buildTraitBar(
                  context,
                  Colors.brown,
                  Colors.brown.shade100,
                  Colors.brown.shade900,
                  _sumAberto,
                  "5_o".tr,
                  RotaImagens.per1A),
              SizedBox(height: MyG.to.margem),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTraitBar(
      BuildContext context,
      Color barColor,
      Color backgroundColor,
      Color borderColor,
      int traitValue,
      String traitName,
      String icon) {
    final double containerWidth = min(
        _barra100,
        ResponsiveConfig.of(context).contentMaxWidth -
            MyG.to.margens['margem2']!);
    final double barWidth = max(0, traitValue * containerWidth / 100);

    return Column(
      children: [
        Reuse.myHeigthBox050,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: MyG.to.margens['margem2']!,
              width: containerWidth,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(color: backgroundColor),
                borderRadius: BorderRadius.circular(ThemeTokens.radiusMedium),
              ),
              child: Stack(
                children: [
                  Container(
                    height: MyG.to.margens['margem2']!,
                    width: barWidth,
                    decoration: BoxDecoration(
                      color: barColor,
                      border: Border.all(color: borderColor),
                      borderRadius:
                          BorderRadius.circular(ThemeTokens.radiusMedium),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                    child: Row(
                      children: [
                        Text(
                          "$traitName ${traitValue.toStringAsFixed(0)}%",
                          style: TextStyle(
                            fontSize: MyG.to.margens['margem065']!,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black54
                                    : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Opacity(
                          opacity: (barWidth / _barra100).clamp(0, 1),
                          child: Image.asset(
                            icon,
                            width: MyG.to.margens['margem1_5']!,
                            height: MyG.to.margens['margem1_5']!,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildInfoCard() {
    return InfoCardTemplate(
      title: "_SobreTipoPersonalidade".tr,
      children: [
        MyTitleExpanded(
          titulo: "SSt".tr,
          texto: "SS".tr,
        ),
        MyTitleExpanded(
          titulo: "5_e".tr,
          texto: "${"SE".tr}\n\n${"SELL".tr}\n\n${"SEHL".tr}",
        ),
        MyTitleExpanded(
          titulo: "5_a".tr,
          texto: "${"SA".tr}\n\n${"SALL".tr}\n\n${"SAHL".tr}",
        ),
        MyTitleExpanded(
          titulo: "5_c".tr,
          texto: "${"SC".tr}\n\n${"SCLL".tr}\n\n${"SCHL".tr}",
        ),
        MyTitleExpanded(
          titulo: "5_n".tr,
          texto: "${"SN".tr}\n\n${"SNLL".tr}\n\n${"SNHL".tr}",
        ),
        MyTitleExpanded(
          titulo: "5_o".tr,
          texto: "${"SO".tr}\n\n${"SOLL".tr}\n\n${"SOHL".tr}",
        ),
        Reuse.myHeigthBox1,
      ],
    );
  }

  TextStyle textoDescricao() {
    return TextStyle(
      fontSize: MyG.to.margens['margem085']!,
      //color: Colors.brown,
      fontWeight: FontWeight.bold,
    );
  }
}

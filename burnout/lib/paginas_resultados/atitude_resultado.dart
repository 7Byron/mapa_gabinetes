import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pie_chart/pie_chart.dart';

import '../relatorios_teste_reutilizaveis/relatorio_teste_atitude.dart';
import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/expanded_title.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/section_title.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';

class ResultadoTesteAtitude extends StatefulWidget {
  const ResultadoTesteAtitude({super.key});

  @override
  State<ResultadoTesteAtitude> createState() => _ResultadoTesteAtitudeState();
}

class _ResultadoTesteAtitudeState extends State<ResultadoTesteAtitude> {
  final int _sumPassiva = Get.arguments[0];
  final int _sumAgressiva = Get.arguments[1];
  final int _sumManipuladora = Get.arguments[2];
  final int _sumAssertiva = Get.arguments[3];
  late int maiorValor = 0;
  late String nomeVariavel = "";

  @override
  void initState() {
    super.initState();
    comparaVariaveis();
    setState(() {});
  }

  void comparaVariaveis() {
    final valores = {
      RotaImagens.atitude1: _sumPassiva,
      RotaImagens.atitude2: _sumAgressiva,
      RotaImagens.atitude3: _sumManipuladora,
      RotaImagens.atitude4: _sumAssertiva,
    };
    final entry = valores.entries.reduce((a, b) => a.value > b.value ? a : b);
    maiorValor = entry.value;
    nomeVariavel = entry.key;
  }

  static const List<Color> _colorList = [
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final Map<String, double> dataMap = {
      "passiva_titulo".tr: _sumPassiva.toDouble(),
      "agressiva_titulo".tr: _sumAgressiva.toDouble(),
      "manipuladora_titulo".tr: _sumManipuladora.toDouble(),
      "assertiva_titulo".tr: _sumAssertiva.toDouble(),
    };

    return ResultPageTemplate(
      appBarTitle: "_tAtitude".tr,
      appBarImage: RotaImagens.logoAtitude,
      buildResultCard: (context) => _buildBarChart(),
      buildInfoCard: (context) => _buildAtitudeCards(),
      middleWidgets: [
        Reuse.myHeigthBox050,
        _buildPieChart(context, dataMap),
        CartaoHelpMe(),
      ],
    );
  }

  Widget _buildBarChart() {
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
              Reuse.myHeigthBox050,
              SectionTitle(title: "analise1".tr),
              GraficoAtitude(
                  sumPassiva: _sumPassiva,
                  sumAgressiva: _sumAgressiva,
                  sumManipuladora: _sumManipuladora,
                  sumAssertiva: _sumAssertiva),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, Map<String, double> dataMap) {
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
          padding: EdgeInsets.all(MyG.to.margens['margem01']!),
          child: LayoutBuilder(builder: (context, constraints) {
            final double maxW = constraints.maxWidth;
            final double radius = (maxW * 0.38).clamp(140.0, 220.0);
            return Column(
              children: [
                Reuse.myHeigthBox050,
                SectionTitle(
                  title: "analise2".tr,
                  trailing: SizedBox(
                    height: MyG.to.margens['margem2_5']!,
                    child: Image.asset(nomeVariavel),
                  ),
                ),
                SizedBox(height: Spacing.xxl),
                RepaintBoundary(
                  child: PieChart(
                    dataMap: dataMap,
                    animationDuration: const Duration(milliseconds: 5000),
                    chartLegendSpacing: 32,
                    chartRadius: radius,
                    colorList: _colorList,
                    initialAngleInDegree: 0,
                    chartType: ChartType.ring,
                    ringStrokeWidth: 64,
                    legendOptions: LegendOptions(
                      showLegendsInRow: true,
                      legendPosition: LegendPosition.bottom,
                      legendTextStyle: Reuse.myFontSize075,
                    ),
                    chartValuesOptions: const ChartValuesOptions(
                      showChartValueBackground: false,
                      showChartValuesInPercentage: true,
                      showChartValuesOutside: true,
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAtitudeCards() {
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
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.amber.shade50
            : Colors.black26,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem1']!),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: MyG.to.margens['margem1']!),
                child: const SizedBox.shrink(),
              ),
              SectionTitle(title: "tipos_atitudes_titulo".tr),
              MyTitleExpanded(
                  titulo: "passiva_titulo".tr, texto: "passiva_descricao".tr),
              MyTitleExpanded(
                  titulo: "agressiva_titulo".tr,
                  texto: "agressiva_descricao".tr),
              MyTitleExpanded(
                  titulo: "manipuladora_titulo".tr,
                  texto: "manipuladora_descricao".tr),
              MyTitleExpanded(
                  titulo: "assertiva_titulo".tr,
                  texto: "assertiva_descricao".tr),
              MyTitleExpanded(
                  titulo: "Mudar_atitude_titulo".tr,
                  texto: "mudar_atitude_texto".tr),
              Reuse.myHeigthBox1,
            ],
          ),
        ),
      ),
    );
  }
}

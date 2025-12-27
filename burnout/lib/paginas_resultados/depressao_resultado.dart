import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/common_text_style.dart';
import '../widgets/disclamer.dart';
import '../widgets/expanded_title.dart';
import '../widgets/internet_site_mail.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/help_info_button.dart';
import '../widgets/info_card_template.dart';
import '../widgets/result_header.dart';
import '../funcoes/theme_tokens.dart';

class ResultadoDepressao extends StatefulWidget {
  const ResultadoDepressao({super.key});

  @override
  State<ResultadoDepressao> createState() => _ResultadoDepressaoState();
}

class _ResultadoDepressaoState extends State<ResultadoDepressao> {
  late final double resultado;
  late final int teste;
  late int resultPercent;
  late String textDescricao;
  late String textTitulo;
  late AssetImage imgTeste;
  late Color cordoCard;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is List) {
      final num res = (args.isNotEmpty && args[0] is num) ? args[0] as num : 0;
      final num tst = (args.length > 1 && args[1] is num) ? args[1] as num : 1;
      resultado = res.toDouble();
      teste = tst.toInt();
    } else {
      resultado = 0.0;
      teste = 1;
    }
    setResultValues();
  }

  List<Map<String, dynamic>> getTestConditions() {
    return teste == 1
        ? [
            {
              'limite': 22.0,
              'imagem': RotaImagens.dep1,
              'titulo': "-10r",
              'descricao': "-10",
              'cor': Colors.amber.shade50
            },
            {
              'limite': 32.0,
              'imagem': RotaImagens.dep2,
              'titulo': "11-18r",
              'descricao': "11-18",
              'cor': Colors.amber.shade200
            },
            {
              'limite': 46.0,
              'imagem': RotaImagens.logoDepressao,
              'titulo': "19-25r",
              'descricao': "19-25",
              'cor': Colors.amber.shade300
            },
            {
              'limite': double.infinity,
              'imagem': RotaImagens.dep4,
              'titulo': "+26r",
              'descricao': "+26",
              'cor': Colors.amber.shade500
            },
          ]
        : [
            {
              'limite': 11.0,
              'imagem': RotaImagens.dep1,
              'titulo': "_depR1",
              'descricao': "_depR1C",
              'cor': Colors.amber.shade50
            },
            {
              'limite': 20.0,
              'imagem': RotaImagens.dep1,
              'titulo': "_depR2",
              'descricao': "_depR2C",
              'cor': Colors.amber.shade200
            },
            {
              'limite': 24.0,
              'imagem': RotaImagens.dep2,
              'titulo': "_depR3",
              'descricao': "_depR3C",
              'cor': Colors.amber.shade300
            },
            {
              'limite': 40.0,
              'imagem': RotaImagens.dep2,
              'titulo': "_depR4",
              'descricao': "_depR4C",
              'cor': Colors.amber.shade400
            },
            {
              'limite': 60.0,
              'imagem': RotaImagens.logoDepressao,
              'titulo': "_depR5",
              'descricao': "_depR5C",
              'cor': Colors.amber.shade500
            },
            {
              'limite': double.infinity,
              'imagem': RotaImagens.dep4,
              'titulo': "_depR6",
              'descricao': "_depR6C",
              'cor': Colors.amber.shade600
            },
          ];
  }

  void setResultValues() {
    resultPercent = calculateResultPercent();
    for (var condition in getTestConditions()) {
      if (resultPercent <= (condition['limite'] as double)) {
        imgTeste = AssetImage(condition['imagem'] as String);
        textTitulo = condition['titulo'] as String;
        textDescricao = condition['descricao'] as String;
        cordoCard = condition['cor'] as Color;
        break;
      }
    }
  }

  int calculateResultPercent() =>
      teste == 1 ? (resultado * 100 ~/ 63) : 100 - (resultado * 100 ~/ 90);

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tDepressao".tr,
      appBarImage: RotaImagens.logoDepressao,
      buildResultCard: (context) => buildResultCard(),
      buildInfoCard: (context) => buildDepressionInfo(),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget buildResultCard() {
    final bool isWide = MediaQuery.of(context).size.width >= 1024;
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
        color: cordoCard,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MyG.to.margens['margem05']!,
            isWide ? MyG.to.margens['margem05']! : MyG.to.margens['margem1']!,
            MyG.to.margens['margem05']!,
            0,
          ),
          child: Column(
            children: [
              buildResultRow(),
              Reuse.myHeigthBox050,
              buildTitleRow(),
              SizedBox(
                  height: isWide
                      ? MyG.to.margens['margem05']!
                      : MyG.to.margens['margem1']!),
              MyCustomText(
                text: textDescricao.tr,
                color: Colors.brown,
                fontSize: isWide
                    ? MyG.to.margens['margem085']!
                    : MyG.to.margens['margem075']!,
                fontWeight: FontWeight.normal,
                textAlign: TextAlign.center,
              ),
              Reuse.myHeigthBox050,
              if (teste == 1) buildBeckInfoLink(),
              disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildResultRow() {
    return ResultHeader(
      image: imgTeste,
      percentText: "$resultPercent%",
    );
  }

  Widget buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: MyCustomText(
            text: textTitulo.tr,
            color: Colors.brown,
            fontSize: MyG.to.margens['margem085']!,
            fontWeight: FontWeight.bold,
            textAlign: TextAlign.center,
          ),
        ),
        SizedBox(width: MyG.to.margens['margem05']!),
        HelpInfoButton(
          title: "_tDepressao".tr,
          text:
              "${"_Dep2Escala".tr}\n\n< 36 (61%)\n${"_depR6".tr}\n\n36 (60%) - 54 (40%)\n${"_depR5".tr}\n\n54 (40%) - 67 (25%)\n${"_depR4".tr}\n\n67 (25%) - 72 (20%)\n${"_depR3".tr}\n\n72 (20%) - 80 (11%)\n${"_depR2".tr}\n\n> 81 (10%)\n${"_depR1".tr}",
        ),
      ],
    );
  }

  Widget buildBeckInfoLink() {
    return GestureDetector(
      onTap: () {
        SiteMail().siteEmail(Variaveis.depressionWiki);
      },
      child: MyCustomText(
        text: "About Beck Depression Inventory",
        color: Colors.blue,
        fontSize: MyG.to.margens['margem065']!,
        fontWeight: FontWeight.normal,
        decoration: TextDecoration.underline,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget buildDepressionInfo() {
    return InfoCardTemplate(
      title: "VerAnsiedade".tr,
      topPadding: MyG.to.margens['margem1']!,
      children: [
        MyTitleExpanded(
          titulo: "cau_dep".tr,
          texto:
              "${"cau_dep1".tr}\n\n${"cau_dep2".tr}\n\n${"cau_dep3".tr}\n\n${"cau_dep4".tr}\n\n${"cau_dep5".tr}\n\n${"cau_dep6".tr}\n\n${"cau_dep7".tr}\n\n${"cau_dep8".tr}\n\n${"cau_dep9".tr}\n\n${"cau_dep10".tr}\n\n${"cau_dep11".tr}",
        ),
        MyTitleExpanded(
          titulo: "Sintt".tr,
          texto:
              "${"Sint".tr}\n\n${"Sinta".tr}\n${"Sintb".tr}\n${"Sintc".tr}\n${"Sintd".tr}\n${"Sinte".tr}\n${"Sintf".tr}\n${"Sintg".tr}",
        ),
        MyTitleExpanded(
          titulo: "Trat".tr,
          texto: "Tra".tr,
        ),
        Reuse.myHeigthBox1,
      ],
    );
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/result_template.dart';

import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/disclamer.dart';
import '../widgets/expanded_title.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/info_card_template.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/responsive.dart';

const int pontuacaoMaxima = 188;
const int pontuacaoG1Maxima = 16;
const int pontuacaoG2Maxima = 32;
const int pontuacaoG3Maxima = 28;
const int pontuacaoG4Maxima = 12;
const int pontuacaoG5Maxima = 84;
const int pontuacaoG6Maxima = 12;
const int pontuacaoRaviaInternaMaxima = 92;
const int pontuacaoRaivaExternaMaxima = 44;
const int pontuacaoPrespectivaHostilMaxima = 36;

class TesteRaivaResultado extends StatefulWidget {
  const TesteRaivaResultado({super.key});

  @override
  State<TesteRaivaResultado> createState() => _TesteRaivaResultadoState();
}

class _TesteRaivaResultadoState extends State<TesteRaivaResultado> {
  final int _pontuacaoTotal = Get.arguments[0];
  final int _pontuacaoG1 = Get.arguments[1];
  final int _pontuacaoG2 = Get.arguments[2];
  final int _pontuacaoG3 = Get.arguments[3];
  final int _pontuacaoG4 = Get.arguments[4];
  final int _pontuacaoG5 = Get.arguments[5];
  final int _pontuacaoG6 = Get.arguments[6];
  final int _perspectivaHostil = Get.arguments[7];
  final int _raivaInterna = Get.arguments[8];
  final int _raivaExterna = Get.arguments[9];

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tRaiva".tr,
      appBarImage: RotaImagens.logoRaiva,
      buildResultCard: (context) => _buildResultCard(context),
      buildInfoCard: (context) => _buildInfoCard(context),
      middleWidgets: [
        Reuse.myHeigthBox050,
        _buildAnalysisCard(context),
        Reuse.myHeigthBox050,
        CartaoHelpMe(),
      ],
    );
  }

  Widget _buildResultCard(BuildContext context) {
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
          padding:
              EdgeInsets.symmetric(horizontal: MyG.to.margens['margem05']!),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: MyG.to.margens['margem1']!),
                child: Column(
                  children: [
                    ResultItem(
                      title: "TotalRaiva".tr,
                      isGeneral: true,
                      value: (_pontuacaoTotal * 100) / pontuacaoMaxima,
                    ),
                    ResultItem(
                      title: "RaivaInterna".tr,
                      isGeneral: false,
                      value:
                          (_raivaInterna * 100) / pontuacaoRaviaInternaMaxima,
                    ),
                    ResultItem(
                      title: "RaivaExterna".tr,
                      isGeneral: false,
                      value:
                          (_raivaExterna * 100) / pontuacaoRaivaExternaMaxima,
                    ),
                    ResultItem(
                      title: "PH".tr,
                      isGeneral: false,
                      value: (_perspectivaHostil * 100) /
                          pontuacaoPrespectivaHostilMaxima,
                    ),
                    disclaimer(),
                  ],
                ),
              ),
              Reuse.myHeigthBox1,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard(BuildContext context) {
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
            : Colors.black38,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: MyG.to.margens['margem05']!),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: MyG.to.margens['margem1']!),
                child: Column(
                  children: [
                    Text(
                      "Analize".tr,
                      style: myTextTitulo(context),
                    ),
                    AutoSizeText(
                      "* Semaphore vectors from Faisal Agung in Vecteezy.com",
                      maxLines: 1,
                      style: Reuse.myFontSize050,
                    ),
                    const Divider(),
                    AdviceCard(
                      adviceNumber: 1,
                      value: (_pontuacaoG1 * 100) / pontuacaoG1Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 2,
                      value: (_pontuacaoG2 * 100) / pontuacaoG2Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 3,
                      value: (_pontuacaoG3 * 100) / pontuacaoG3Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 4,
                      value: (_pontuacaoG4 * 100) / pontuacaoG4Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 5,
                      value: (_pontuacaoG5 * 100) / pontuacaoG5Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 6,
                      value: (_pontuacaoG6 * 100) / pontuacaoG6Maxima,
                    ),
                    AdviceCard(
                      adviceNumber: 7,
                      value:
                          (_raivaInterna * 100) / pontuacaoRaviaInternaMaxima,
                    ),
                    AdviceCard(
                      adviceNumber: 8,
                      value:
                          (_raivaExterna * 100) / pontuacaoRaivaExternaMaxima,
                    ),
                    AdviceCard(
                      adviceNumber: 9,
                      value: (_perspectivaHostil * 100) /
                          pontuacaoPrespectivaHostilMaxima,
                    ),
                    Reuse.myHeigthBox050,
                  ],
                ),
              ),
              Reuse.myHeigthBox1,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return InfoCardTemplate(
      title: "sobreRaiva".tr,
      children: [
        MyTitleExpanded(
          titulo: "A".tr,
          texto: "${"A1".tr}\n\n${"A2".tr}\n\n${"A3".tr}",
        ),
        MyTitleExpanded(
          titulo: "B".tr,
          texto:
              "${"B1".tr}\n\n${"B2".tr}\n\n${"B3".tr}\n\n${"B4".tr}\n\n${"B5".tr}",
        ),
        MyTitleExpanded(
          titulo: "rC".tr,
          texto: "rC1".tr,
        ),
        MyTitleExpanded(
          titulo: "D".tr,
          texto: "D1".tr,
        ),
        MyTitleExpanded(
          titulo: "F".tr,
          texto: "${"F1".tr}\n\n${"F2".tr}\n\n${"F3".tr}",
        ),
        MyTitleExpanded(
          titulo: "G".tr,
          texto: "G1".tr,
        ),
        MyTitleExpanded(
          titulo: "H".tr,
          texto:
              "${"H1".tr}\n\n${"H2".tr}\n\n${"H3".tr}\n\n${"H4".tr}\n\n${"H5".tr}"
              "\n\n${"H6".tr}\n\n${"H7".tr}\n\n${"H8".tr}\n\n${"H9".tr}\n\n${"H10".tr}"
              "\n\n${"H11".tr}\n\n${"H12".tr}\n\n${"H13".tr}\n\n${"H14".tr}\n\n${"H15".tr}",
        ),
        MyTitleExpanded(
          titulo: "I".tr,
          texto:
              "${"I1".tr}\n\n${"I2".tr}\n\n${"I3".tr}\n\n${"I4".tr}\n\n${"I5".tr}"
              "\n\n${"I6".tr}\n\n${"I7".tr}",
        ),
        MyTitleExpanded(
          titulo: "J".tr,
          texto: "${"J1".tr}\n\n${"J2".tr}",
        ),
        Reuse.myHeigthBox1,
      ],
    );
  }

  TextStyle myTextTitulo(BuildContext context) => TextStyle(
        fontSize: ResponsiveConfig.of(context).clampFont(MyG.to.margem),
        color: Colors.brown,
        fontWeight: FontWeight.bold,
      );
}

class ResultItem extends StatelessWidget {
  final String title;
  final bool isGeneral;
  final double value;

  const ResultItem({
    super.key,
    required this.title,
    required this.isGeneral,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final String image = _getImage(value);
    final String text = _getText(value);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            ThemeTokens.radiusLarge), // Bordas arredondadas
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        color: isGeneral
            ? Colors.amberAccent
            : (Theme.of(context).brightness == Brightness.light
                ? Colors.white
                : Colors.black26),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem035']!,
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem035']!,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      title,
                      style: Reuse.myFontSize085.copyWith(color: Colors.brown),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      "${value.toInt()}%",
                      style: TextStyle(
                        fontSize: MyG.to.margens['margem085']!,
                        fontWeight: FontWeight.bold,
                        color: Colors.brown,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Image.asset(
                      image,
                      height: MyG.to.margens['margem3']!,
                    ),
                  ),
                ],
              ),
              if (isGeneral) const Divider(),
              if (isGeneral && text.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(
                      vertical: MyG.to.margens['margem075']!),
                  child: Text(
                    text,
                    style: Reuse.myFontSize075.copyWith(color: Colors.brown),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _getImage(double valor) {
    if (valor < 10) {
      return RotaImagens.raiva1;
    } else if (valor < 30) {
      return RotaImagens.raiva2;
    } else if (valor < 73) {
      return RotaImagens.logoRaiva;
    } else {
      return RotaImagens.raiva4;
    }
  }

  String _getText(double valor) {
    if (valor < 30) {
      return 'semRaiva'.tr;
    } else if (valor < 73) {
      return 'raivaMedio'.tr;
    } else {
      return 'raivaMau'.tr;
    }
  }
}

class AdviceCard extends StatelessWidget {
  final int adviceNumber;
  final double value;

  const AdviceCard({
    super.key,
    required this.adviceNumber,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLowValue = value < 30;
    final bool isMediumValue = value < 73;
    final String text = isLowValue
        ? 'Fort$adviceNumber'.tr
        : isMediumValue
            ? 'Med$adviceNumber'.tr
            : 'Frac$adviceNumber'.tr;
    final String image = isLowValue
        ? RotaImagens.verde
        : isMediumValue
            ? RotaImagens.amarelo
            : RotaImagens.vermelho;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(
            ThemeTokens.radiusLarge), // Bordas arredondadas
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 10.0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.white
            : Colors.black38,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem035']!,
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem035']!,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: MyG.to.margens['margem075']!,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Image.asset(
                  image,
                  height: MyG.to.margens['margem4']!,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

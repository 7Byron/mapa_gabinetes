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
import '../widgets/help_info_button.dart';
import '../widgets/info_card_template.dart';
import '../widgets/result_header.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';

class TesteSorrisoResultado extends StatefulWidget {
  const TesteSorrisoResultado({super.key});

  @override
  State<TesteSorrisoResultado> createState() => _TesteSorrisoResultadoState();
}

class _TesteSorrisoResultadoState extends State<TesteSorrisoResultado> {
  final double _resultado = Get.arguments[0];
  late int resultPercent;
  late String textDestricao;
  late String textTitulo;
  late AssetImage imgTeste;
  late Color cordoCard;

  @override
  void initState() {
    super.initState();
    _calculateResult();
  }

  void _calculateResult() {
    if (_resultado <= 7) {
      imgTeste = const AssetImage(RotaImagens.sorriso1);
      textTitulo = "sor.sorri1".tr;
      textDestricao = "sor.escala.3".tr;
      cordoCard = Colors.amber.shade500;
    } else if (_resultado <= 10) {
      imgTeste = const AssetImage(RotaImagens.sorriso2);
      textTitulo = "sor.sorri2".tr;
      textDestricao = "sor.escala.2".tr;
      cordoCard = Colors.amber.shade200;
    } else {
      imgTeste = const AssetImage(RotaImagens.logoSorriso);
      textTitulo = "sor.sorri3".tr;
      textDestricao = "sor.escala.1".tr;
      cordoCard = Colors.amber.shade50;
    }
    resultPercent = (_resultado * 100 ~/ 13).toInt();
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tSorriso".tr,
      appBarImage: RotaImagens.logoSorriso,
      buildResultCard: (context) => _buildResultCard(),
      buildInfoCard: (context) => _buildInfoCard(context),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget _buildResultCard() {
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
          padding:
              EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.xs),
          child: Column(
            children: [
              _buildResultHeader(),
              Reuse.myHeigthBox050,
              _buildTitleRow(),
              Reuse.myHeigthBox050,
              _buildDescription(),
              Reuse.myHeigthBox025,
              disclaimer(),
              Reuse.myHeigthBox050,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    return ResultHeader(image: imgTeste, percentText: "$resultPercent%");
  }

  Widget _buildTitleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AutoSizeText(
            textTitulo,
            style: Reuse.myTitulo.copyWith(color: Colors.brown),
            maxLines: 1,
            textAlign: TextAlign.center,
          ),
        ),
        Reuse.myWidthBox025,
        HelpInfoButton(
          title: "_tSorriso".tr,
          text:
              "\n${"sor.sobre".tr} \n\n0 - 7\n${"sor.sorri1".tr}\n\n7 - 10\n${"sor.sorri2".tr}\n\n10 - 13\n${"sor.sorri3".tr}",
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return AutoSizeText(
      textDestricao,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.brown,
        fontSize: MyG.to.margens['margem075']!,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return InfoCardTemplate(
      title: "sobre_sorriso".tr,
      children: [
        ..._buildInfoSections(),
        _buildExpansionTile(context),
        Reuse.myHeigthBox050,
      ],
    );
  }

  List<Widget> _buildInfoSections() {
    return [
      MyTitleExpanded(titulo: "sor_sor".tr, texto: "sor_c1".tr),
      MyTitleExpanded(
        titulo: "sor_t2".tr,
        texto:
            "${"sor_c2_1".tr}\n${"sor_c2_2".tr}\n${"sor_c2_3".tr}\n${"sor_c2_4".tr}\n${"sor_c2_5".tr}\n${"sor_c2_6".tr}\n${"sor_c2_7".tr}"
                .tr,
      ),
      MyTitleExpanded(titulo: "sor_t4".tr, texto: "sor_c4".tr),
      MyTitleExpanded(
        titulo: "sor_t5".tr,
        texto:
            "${"sor_c5_1".tr}\n\n${"sor_c5_2".tr}\n\n${"sor_c5_3".tr}\n\n${"sor_c5_4".tr}"
                .tr,
      ),
    ];
  }

  Widget _buildExpansionTile(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MyG.to.margens['margem05']!),
      child: Container(
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
        clipBehavior:
            Clip.antiAlias, // Garante que a sombra siga o borderRadius
        child: Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              dividerTheme: const DividerThemeData(
                color: Colors.transparent,
                thickness: 0,
                space: 0,
              ),
            ),
            child: ExpansionTile(
              title: AutoSizeText(
                "sor_t3".tr,
                style: TextStyle(
                  fontSize: MyG.to.margens['margem075']!,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
              ),
              children: [
                Padding(
                  padding: EdgeInsets.all(MyG.to.margens['margem05']!),
                  child: Column(
                    children: [
                      Text(
                        "sor_c3".tr,
                        textAlign: TextAlign.justify,
                        style:
                            TextStyle(fontSize: MyG.to.margens['margem075']!),
                      ),
                      Image.asset(RotaImagens.paulEkman),
                      Text(
                        "sor_PE".tr,
                        textAlign: TextAlign.justify,
                        style: TextStyle(
                          color: Theme.of(context).primaryColorLight,
                          fontSize: MyG.to.margens['margem065']!,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

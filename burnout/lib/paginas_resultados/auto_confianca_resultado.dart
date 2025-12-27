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
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';
import '../funcoes/responsive.dart';

class ResultadoAutoConfianca extends StatefulWidget {
  const ResultadoAutoConfianca({super.key});

  @override
  State<ResultadoAutoConfianca> createState() => _ResultadoAutoConfiancaState();
}

class _ResultadoAutoConfiancaState extends State<ResultadoAutoConfianca> {
  final double _resultado = Get.arguments[0];
  late int resultPercent;
  late String textDescricao;
  late String textTitulo;
  late AssetImage imgTeste;
  late Color cordoCard;

  @override
  void initState() {
    super.initState();
    _updateResult();
  }

  void _updateResult() {
    final List<Map<String, dynamic>> escalaConfig = [
      {
        'limite': 16,
        'imagem': RotaImagens.autoconfianca1,
        'titulo': "aut_escala_3t",
        'descricao': "aut_escala_3",
        'cor': Colors.amber.shade500,
      },
      {
        'limite': 31,
        'imagem': RotaImagens.autoconfianca2,
        'titulo': "aut_escala_2t",
        'descricao': "aut_escala_2",
        'cor': Colors.amber.shade200,
      },
      {
        'limite': 46,
        'imagem': RotaImagens.autoconfianca3,
        'titulo': "aut_escala_1t",
        'descricao': "aut_escala_1",
        'cor': Colors.amber.shade50,
      },
    ];

    for (var config in escalaConfig) {
      if (_resultado < config['limite']) {
        _setResultConfig(
          config['imagem'],
          config['titulo'],
          config['descricao'],
          config['cor'],
        );
        break;
      }
    }

    resultPercent = (_resultado * 100 ~/ 45).toInt();
  }

  void _setResultConfig(
      String imgPath, String titleKey, String descKey, Color color) {
    imgTeste = AssetImage(imgPath);
    textTitulo = titleKey.tr;
    textDescricao = descKey.tr;
    cordoCard = color;
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tAutoConfianca".tr,
      appBarImage: RotaImagens.logoAutoConfianca,
      buildResultCard: (context) => buildResultCard(context),
      buildInfoCard: (context) => buildInfoCard(context),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget buildResultCard(BuildContext context) {
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
              Reuse.myHeigthBox1,
              _buildResultImageAndPercent(),
              Reuse.myHeigthBox050,
              _buildTitleRow(context),
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

  Widget _buildResultImageAndPercent() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image(image: imgTeste, height: MyG.to.margens['margem8']!),
        Reuse.myWidthBox050,
        Text(
          "$resultPercent%",
          style: TextStyle(
            fontSize:
                ResponsiveConfig.of(Get.context!).clampFont(MyG.to.margem),
            fontStyle: FontStyle.italic,
            color: Colors.brown,
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    return AutoSizeText(
      textDescricao,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.brown,
        fontSize: MyG.to.margens['margem075']!,
      ),
    );
  }

  Widget _buildTitleRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: AutoSizeText(
            textTitulo,
            style: Reuse.myTitulo.copyWith(color: Colors.brown),
            maxLines: 2,
            textAlign: TextAlign.center,
          ),
        ),
        Reuse.myWidthBox025,
        _buildHelpIcon(),
      ],
    );
  }

  Widget _buildHelpIcon() {
    return HelpInfoButton(
      title: "_tAutoConfianca".tr,
      text: "\n${"aut.sobre".tr}\n\n0 - 15\n${"aut_escala_3t".tr}"
          "\n\n16 - 30\n${"aut_escala_2t".tr}\n\n>31\n${"aut_escala_1t".tr}",
    );
  }

  Widget buildInfoCard(BuildContext context) {
    return InfoCardTemplate(
      title: "sobre_autoconfianca".tr,
      children: [
        MyTitleExpanded(titulo: "aut_def".tr, texto: "aut_def_c".tr),
        MyTitleExpanded(
            titulo: "aut_dest".tr,
            texto:
                "${"aut_dest_c1".tr}\n${"aut_dest_c2".tr}\n${"aut_dest_c3".tr}\n${"aut_dest_c4".tr}\n${"aut_dest_c5".tr}\n${"aut_dest_c6".tr}\n${"aut_dest_c7".tr}\n${"aut_dest_c8".tr}\n${"aut_dest_c9".tr}\n${"aut_dest_c10".tr}\n${"aut_dest_c11".tr}\n${"aut_dest_c12".tr}\n${"aut_dest_c13".tr}\n${"aut_dest_c14".tr}\n${"aut_dest_c15".tr}"),
        MyTitleExpanded(
            titulo: "aut_pro".tr,
            texto:
                "${"aut_pro_c1".tr}\n${"aut_pro_c2".tr}\n${"aut_pro_c3".tr}\n${"aut_pro_c4".tr}\n${"aut_pro_c5".tr}\n${"aut_pro_c6".tr}\n${"aut_pro_c7".tr}\n${"aut_pro_c8".tr}\n${"aut_pro_c9".tr}\n${"aut_pro_c10".tr}\n${"aut_pro_c11".tr}\n${"aut_pro_c12".tr}\n${"aut_pro_c13".tr}\n${"aut_pro_c14".tr}\n${"aut_pro_c15".tr}\n${"aut_pro_c16".tr}"),
        MyTitleExpanded(
            titulo: "aut_aum".tr,
            texto:
                "${"aut_aum_c".tr}\n${"aut_aum_c1".tr}\n${"aut_aum_c2".tr}\n${"aut_aum_c3".tr}\n${"aut_aum_c4".tr}\n${"aut_aum_c5".tr}\n${"aut_aum_c6".tr}\n${"aut_aum_c7".tr}\n${"aut_aum_c8".tr}\n${"aut_aum_c9".tr}\n${"aut_aum_c10".tr}\n${"aut_aum_c11".tr}\n${"aut_aum_c12".tr}\n${"aut_aum_c13".tr}\n${"aut_aum_c14".tr}\n${"aut_aum_c15".tr}\n${"aut_aum_c16".tr}\n${"aut_aum_c17".tr}"),
        Reuse.myHeigthBox050,
      ],
    );
  }
}

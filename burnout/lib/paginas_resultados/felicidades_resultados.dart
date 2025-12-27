import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/botao_imagem.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/internet_site_mail.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/my_dialog.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/responsive.dart';

class ResultadoFelicidade extends StatefulWidget {
  const ResultadoFelicidade({super.key});

  @override
  State<ResultadoFelicidade> createState() => _ResultadoFelicidadeState();
}

class _ResultadoFelicidadeState extends State<ResultadoFelicidade> {
  final bool ads = MyG.to.adsPago;
  final int _resultado = Get.arguments;
  late String _textResultado;
  late AssetImage _imgTeste;
  late Color _cordoCard;
  late String _resultPercent;

  @override
  void initState() {
    super.initState();
    _resultPercent = ((_resultado * 100) / 128).toStringAsFixed(0);
    _setResults();
  }

  void _setResults() {
    final resultsMap = {
      20: (RotaImagens.feliz1, "mtinfelizR", Colors.red.shade100),
      40: (RotaImagens.feliz2, "infelizR", Colors.orange.shade100),
      60: (RotaImagens.feliz3, "satisfatórioR", Colors.yellow.shade100),
      80: (RotaImagens.feliz3, "felizR", Colors.green.shade100),
      128: (RotaImagens.feliz5, "mtfelizR", Colors.greenAccent.shade100),
    };

    final result =
        resultsMap.entries.firstWhere((entry) => _resultado < entry.key).value;

    _imgTeste = AssetImage(result.$1);
    _textResultado = result.$2.tr;
    _cordoCard = result.$3;
  }

  @override
  Widget build(BuildContext context) {
    final Color cardColor = Colors.amber.shade100;
    const Color textColor = Colors.brown;
    final r = ResponsiveConfig.of(context);
    final TextStyle titleStyle = TextStyle(
      fontSize: r.clampFont(MyG.to.margem),
      fontWeight: FontWeight.bold,
      color: textColor,
    );

    return ResultPageTemplate(
      appBarTitle: "_tFelicidade".tr,
      appBarImage: RotaImagens.logoFelicidade,
      buildResultCard: (context) =>
          _buildResultCard(cardColor, textColor, titleStyle),
      buildInfoCard: (context) => const SizedBox.shrink(),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget _buildResultCard(
      Color cardColor, Color textColor, TextStyle titleStyle) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge), // Bordas arredondadas
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
        ),
        color: cardColor,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem05']!,
            MyG.to.margens['margem1']!,
            MyG.to.margens['margem05']!,
          ),
          child: Column(
            children: [
              _buildResultHeader(textColor),
              Reuse.myHeigthBox1,
              _buildScoreInfo(textColor),
              Reuse.myHeigthBox1,
              _buildDescriptionCard(titleStyle),
              Reuse.myHeigthBox1,
              _buildReportButton(),
              Reuse.myHeigthBox1,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultHeader(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image(image: _imgTeste, height: MyG.to.margens['margem5']!),
        Reuse.myWidthBox050,
        Text(
          "$_resultPercent%",
          style: TextStyle(
            fontSize: ResponsiveConfig.of(context).clampFont(MyG.to.margem),
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreInfo(Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AutoSizeText(
          "${"fSintt".tr}: $_resultado / 128  ",
          style: TextStyle(
            color: textColor,
            fontSize: MyG.to.margens['margem085']!,
          ),
          maxLines: 1,
          textAlign: TextAlign.center,
        ),
        IconButton(
          icon: Reuse.myHelpIcon,
          onPressed: () {
            Get.dialog(
              MyAlertDialog(
                titulo: "fEscala1".tr,
                texto:
                    "${"fEscala2".tr}\n\n${"fEscalaT".tr}\n${"fEscala3".tr}\n${"fEscala4".tr}\n${"fEscala5".tr}\n${"fEscala6".tr}\n${"fEscala7".tr}\n",
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDescriptionCard(TextStyle titleStyle) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem1']!),
      child: Container(
        color: _cordoCard,
        child: Padding(
          padding: EdgeInsets.all(MyG.to.margens['margem1_5']!),
          child: AutoSizeText(
            _textResultado,
            textAlign: TextAlign.center,
            style: titleStyle,
            maxLines: 5,
          ),
        ),
      ),
    );
  }

  Widget _buildReportButton() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem05']!),
      child: MyBotaoImagem(
        onPressed: () {
          SiteMail().siteEmail(Variaveis.worldHappinessReport);
        },
        titulo: "World Happiness Report",
        imagem: RotaImagens.whr,
      ),
    );
  }
}

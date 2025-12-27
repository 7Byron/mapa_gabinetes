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
import '../funcoes/spacing.dart';

class ResultadoAnsiedade extends StatefulWidget {
  const ResultadoAnsiedade({super.key});

  @override
  State<ResultadoAnsiedade> createState() => _ResultadoAnsiedadeState();
}

class _ResultadoAnsiedadeState extends State<ResultadoAnsiedade> {
  final int resultado = Get.arguments;
  String textDescricao = "";
  String textTitulo = "";
  AssetImage imgTeste = const AssetImage(RotaImagens.logoAnsiedade);
  Color cordoCard = Colors.amber.shade300;
  int percT = 0;

  @override
  void initState() {
    super.initState();

    setAnsiedadeValues();
  }

  void setAnsiedadeValues() {
    final List<Map<String, dynamic>> anxietyLevels = [
      {
        'limit': 11,
        'image': RotaImagens.ans1,
        'title': 'Ans-10r',
        'description': 'Ans-10',
        'color': Colors.amber.shade50,
      },
      {
        'limit': 24,
        'image': RotaImagens.ans2,
        'title': 'Ans11-18r',
        'description': 'Ans11-18',
        'color': Colors.amber.shade200,
      },
      {
        'limit': 40,
        'image': RotaImagens.logoAnsiedade,
        'title': 'Ans19-25r',
        'description': 'Ans19-25',
        'color': Colors.amber.shade300,
      },
      {
        'limit': 100,
        'image': RotaImagens.ans4,
        'title': 'Ans+26r',
        'description': 'Ans+26',
        'color': Colors.amber.shade500,
      },
    ];

    percT = (resultado * 100 ~/ 63).toInt();

    final level = anxietyLevels.firstWhere(
      (l) => percT <= l['limit'],
      orElse: () => anxietyLevels.last, // Fallback para último nível
    );

    imgTeste = AssetImage(level['image']);
    textTitulo = level['title'];
    textDescricao = level['description'];
    cordoCard = level['color'];
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tAnsiedade".tr,
      appBarImage: RotaImagens.logoAnsiedade,
      buildResultCard: (context) => buildResultCard(),
      buildInfoCard: (context) => buildInfoCard(),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget buildResultCard() {
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
          padding: EdgeInsets.all(MyG.to.margens['margem075']!),
          child: Column(
            children: [
              ResultHeader(
                image: imgTeste,
                percentText: "$percT%",
              ),
              Reuse.myHeigthBox050,
              buildSymptomsRow(),
              Reuse.myHeigthBox050,
              buildTitleRow(),
              buildDescription(),
              buildLink(),
              disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildDescription() {
    return Padding(
      padding: EdgeInsets.only(top: MyG.to.margens['margem05']!),
      child: MyCustomText(
        text: textDescricao.tr,
        color: Colors.brown,
        fontSize: MyG.to.margens['margem075']!,
        fontWeight: FontWeight.normal,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget buildLink() {
    return GestureDetector(
      onTap: () => SiteMail().siteEmail(Variaveis.anxietyWiki),
      child: MyCustomText(
        text: "About Beck Anxiety Inventory",
        color: Colors.blue,
        fontSize: MyG.to.margens['margem065']!,
        fontWeight: FontWeight.normal,
        decoration: TextDecoration.underline,
      ),
    );
  }

  Widget buildSymptomsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        MyCustomText(
            text: "${"AnsSint".tr}: $resultado / 63",
            color: Colors.brown,
            fontSize: MyG.to.margens['margem085']!,
            fontWeight: FontWeight.normal),
        Spacing.hs,
        HelpInfoButton(
          title: "AnsEscala1".tr,
          text:
              "${"SobreTesteAns".tr}\n\n${"AnsEscala2".tr}\n\n${"AnsEscala3".tr}\n${"AnsEscala4".tr}\n${"AnsEscala5".tr}\n${"AnsEscala6".tr}\n${"AnsEscala7".tr}",
        ),
      ],
    );
  }

  Widget buildTitleRow() {
    return Center(
      child: MyCustomText(
          text: textTitulo.tr,
          color: Colors.brown,
          fontSize: MyG.to.margens['margem085']!,
          fontWeight: FontWeight.bold),
    );
  }

  Widget buildInfoCard() {
    return InfoCardTemplate(
      title: "VerAnsiedadeAns".tr,
      topPadding: MyG.to.margem,
      children: [
        MyTitleExpanded(
          titulo: "SinttAns".tr,
          texto: "SintAns".tr,
        ),
        MyTitleExpanded(
          titulo: "Trat".tr,
          texto: "TraAns".tr,
        ),
        Reuse.myHeigthBox1,
      ],
    );
  }
}

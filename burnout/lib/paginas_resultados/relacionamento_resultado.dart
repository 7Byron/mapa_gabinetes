import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/disclamer.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/result_header.dart';
import '../widgets/help_info_button.dart';
import '../funcoes/theme_tokens.dart';

class ResultadoRelacionamento extends StatefulWidget {
  const ResultadoRelacionamento({super.key});

  @override
  State<ResultadoRelacionamento> createState() =>
      _ResultadoRelacionamentoState();
}

class _ResultadoRelacionamentoState extends State<ResultadoRelacionamento> {
  final double resultado = (Get.arguments as double?) ?? 0.0;
  late int resultPercent = 0;

  late String textDescricao;
  late String textTitulo;
  late AssetImage imgTeste;
  late Color cordoCard;

  @override
  void initState() {
    super.initState();

    setResults();
  }

  void setResults() {
    final List<Map<String, dynamic>> escalas = [
      {
        "max": 33,
        "image": RotaImagens.rel1,
        "titulo": "rel.escala.1t".tr,
        "descricao": "rel.escala.1".tr,
        "cor": Colors.amber.shade400
      },
      {
        "max": 47,
        "image": RotaImagens.rel2,
        "titulo": "rel.escala.2t".tr,
        "descricao": "rel.escala.2".tr,
        "cor": Colors.amber.shade300
      },
      {
        "max": 66,
        "image": RotaImagens.rel3,
        "titulo": "rel.escala.3t".tr,
        "descricao": "rel.escala.3".tr,
        "cor": Colors.amber.shade200
      },
      {
        "max": 85,
        "image": RotaImagens.rel4,
        "titulo": "rel.escala.4t".tr,
        "descricao": "rel.escala.4".tr,
        "cor": Colors.amber.shade100
      },
      {
        "max": double.infinity,
        "image": RotaImagens.rel5,
        "titulo": "rel.escala.5t".tr,
        "descricao": "rel.escala.5".tr,
        "cor": Colors.amber.shade50
      },
    ];

    for (var escala in escalas) {
      if (resultado < escala["max"]) {
        imgTeste = AssetImage(escala["image"]);
        textTitulo = escala["titulo"];
        textDescricao = escala["descricao"];
        cordoCard = escala["cor"];
        break;
      }
    }

    resultPercent = resultado.toInt();
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tRelacionamentos".tr,
      appBarImage: RotaImagens.logoRelacionamentos,
      buildResultCard: (context) => buildResultCard(),
      buildInfoCard: (context) => const SizedBox.shrink(),
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
          padding: EdgeInsets.all(MyG.to.margens['margem05']!),
          child: Column(
            children: [
              ResultHeader(image: imgTeste, percentText: "$resultPercent%"),
              Reuse.myHeigthBox050,
              AutoSizeText(
                textTitulo,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: MyG.to.margens['margem085']!,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              Reuse.myHeigthBox050,
              _buildHelpIcon(),
              Reuse.myHeigthBox1,
              AutoSizeText(
                textDescricao,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: MyG.to.margens['margem075']!,
                ),
              ),
              Reuse.myHeigthBox050,
              disclaimer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHelpIcon() {
    return HelpInfoButton(
      title: "_tRelacionamentos".tr,
      text: """
            < 33% ${"rel.escala.1t".tr}
             ${"rel.escala.1".tr}
              33% - 47% ${"rel.escala.2t".tr}
            ${"rel.escala.2".tr}

            48% - 66% ${"rel.escala.3t".tr}
            ${"rel.escala.3".tr}

            67% - 85% ${"rel.escala.4t".tr}
          ${"rel.escala.4".tr}

          > 85% ${"rel.escala.5t".tr}
          ${"rel.escala.5".tr}
          """,
    );
  }
}

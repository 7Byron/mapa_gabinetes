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
import '../funcoes/responsive.dart';

class ResultadoTesteStress extends StatefulWidget {
  const ResultadoTesteStress({super.key});

  @override
  State<ResultadoTesteStress> createState() => _ResultadoTesteStressState();
}

class _ResultadoTesteStressState extends State<ResultadoTesteStress> {
  final bool ads = MyG.to.adsPago;
  late final int _sumValores = Get.arguments[0] ?? 0;
  late final List<int> _grupos = Get.arguments[1] ?? [0, 0, 0, 0, 0, 0];
  late final double _perc;

  @override
  void initState() {
    super.initState();
    _perc = (_sumValores > 0) ? (_sumValores * 100) / 303 : 0.0;
  }

  String getZoneTextRed() {
    if (_sumValores < 48) return "zon1_des_red".tr;
    if (_sumValores < 73) return "zon2_des_red".tr;
    if (_sumValores < 120) return "zon3_des_red".tr;
    if (_sumValores < 145) return "zon4_des_red".tr;
    return "zon5_des_red".tr;
  }

  String getZoneImage() {
    if (_sumValores < 48) return RotaImagens.stress1;
    if (_sumValores < 73) return RotaImagens.stress2;
    if (_sumValores < 120) return RotaImagens.stress3;
    if (_sumValores < 145) return RotaImagens.logoStress;
    return RotaImagens.stress5;
  }

  Color getCardColor() {
    if (_sumValores < 48) return Colors.amber.shade50;
    if (_sumValores < 73) return Colors.amber.shade200;
    if (_sumValores < 120) return Colors.amber.shade300;
    if (_sumValores < 145) return Colors.amber.shade400;
    return Colors.amber.shade500;
  }

  String getZoneTextDescricao() {
    if (_sumValores < 48) return "zon1_des".tr;
    if (_sumValores < 73) return "zon2_des".tr;
    if (_sumValores < 120) return "zon3_des".tr;
    if (_sumValores < 145) return "zon4_des".tr;
    return "zon5_des".tr;
  }

  Map<String, dynamic> getZoneInfo() {
    final List<int> limits = [48, 73, 120, 145, 9999];
    final List<String> textsRed = [
      "zon1_des_red".tr,
      "zon2_des_red".tr,
      "zon3_des_red".tr,
      "zon4_des_red".tr,
      "zon5_des_red".tr,
    ];
    final List<String> images = [
      RotaImagens.stress1,
      RotaImagens.stress2,
      RotaImagens.stress3,
      RotaImagens.logoStress,
      RotaImagens.stress5,
    ];
    final List<Color> colors = [
      Colors.amber.shade50,
      Colors.amber.shade200,
      Colors.amber.shade300,
      Colors.amber.shade400,
      Colors.amber.shade500,
    ];
    final List<String> descriptions = [
      "zon1_des".tr,
      "zon2_des".tr,
      "zon3_des".tr,
      "zon4_des".tr,
      "zon5_des".tr,
    ];

    int index = limits
        .indexWhere((limit) => _sumValores.isFinite && _sumValores < limit);
    if (index == -1) {
      index = limits.length - 1; // Garante que não ocorra erro de index
    }

    return {
      "textRed": textsRed[index],
      "image": images[index],
      "color": colors[index],
      "description": descriptions[index],
    };
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tStress".tr,
      appBarImage: RotaImagens.logoStress,
      buildResultCard: (context) => _buildStressResultCard(),
      buildInfoCard: (context) => _buildStressInfoCard(),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget _buildStressResultCard() {
    final zoneInfo = getZoneInfo();

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
        color: zoneInfo['color'],
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              MyG.to.margens['margem075']!,
              MyG.to.margens['margem1']!,
              MyG.to.margens['margem075']!,
              MyG.to.margens['margem1']!),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: AutoSizeText(
                      zoneInfo['textRed'],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.brown,
                        fontSize: ResponsiveConfig.of(Get.context!)
                            .clampFont(MyG.to.margem),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Reuse.myWidthBox025,
                  Column(
                    children: [
                      Image.asset(
                        zoneInfo['image'],
                        height: MyG.to.margens['margem3']!,
                      ),
                      Row(
                        children: [
                          Text(
                            "${_perc.toStringAsFixed(0)}%",
                            style: TextStyle(
                              color: Colors.brown,
                              fontSize: MyG.to.margens['margem085']!,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          HelpInfoButton(
                            title: "_tStress".tr,
                            text:
                                "${"SobreTesteStress".tr}\n\n${"resultado".tr}\n"
                                "< 15% : ${"zon1".tr}\n"
                                "15-24% : ${"zon2".tr}\n"
                                "24-40% : ${"zon3".tr}\n"
                                "40-48% : ${"zon4".tr}\n"
                                "> 48%  : ${"zon5".tr}\n",
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              disclaimer(),
              AutoSizeText(
                "tit_niv_categ".tr,
                maxLines: 1,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: MyG.to.margens['margem085']!,
                ),
              ),
              const Divider(),
              for (int i = 0; i < _grupos.length; i++)
                _buildNivelCategoria(_getTituloCategoria(i), _grupos[i]),
              Reuse.myHeigthBox1,
              Text(
                zoneInfo['description'],
                textAlign: TextAlign.justify,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: MyG.to.margens['margem075']!,
                  fontWeight: FontWeight.normal,
                ),
              ),
              Reuse.myHeigthBox050,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStressInfoCard() {
    return InfoCardTemplate(
      title: "_SobreStresTitulo".tr,
      children: [
        MyTitleExpanded(
          titulo: "def_stress_titulo".tr,
          texto: "def_stress_texto".tr,
        ),
        MyTitleExpanded(
          titulo: "sint_stress_titulo".tr,
          texto: "sint_stress_alto".tr,
        ),
        Reuse.myHeigthBox1,
      ],
    );
  }

  Map<String, dynamic> getNivelInfo(int valor) {
    final List<int> limites = [8, 12, 18, 22, 9999];
    final List<String> zonas = [
      "zon1".tr,
      "zon2".tr,
      "zon3".tr,
      "zon4".tr,
      "zon5".tr
    ];
    final List<String> imagens = [
      RotaImagens.stress1,
      RotaImagens.stress2,
      RotaImagens.stress3,
      RotaImagens.logoStress,
      RotaImagens.stress5,
    ];
    final List<Color> cores = [
      Colors.blue[200]!,
      Colors.green[200]!,
      Colors.yellow[200]!,
      Colors.orange[200]!,
      Colors.red[400]!,
    ];

    final int index = limites.indexWhere((limit) => valor < limit);

    return {
      "zona": zonas[index],
      "imagem": imagens[index],
      "color": cores[index],
      "percentual": (valor * 100 / 48),
    };
  }

  Widget _buildNivelCategoria(String titulo, int valor) {
    final nivelInfo = getNivelInfo(valor);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      color: nivelInfo['color'],
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margens['margem035']!),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: MyG.to.margens['margem035']!),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        AutoSizeText(
                          titulo,
                          maxLines: 1,
                          style: Reuse.myFontSize075,
                        ),
                        Text(
                          nivelInfo['zona'],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MyG.to.margens['margem065']!,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Reuse.myWidthBox050,
                  Text(
                    "${nivelInfo['percentual'].toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: MyG.to.margens['margem085']!,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Reuse.myWidthBox050,
                  Image.asset(
                    nivelInfo['imagem'],
                    width: MyG.to.margens['margem2']!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTituloCategoria(int index) {
    switch (index) {
      case 0:
        return "gr_estilo_vida".tr;
      case 1:
        return "gr_ambiente".tr;
      case 2:
        return "gr_sintomas".tr;
      case 3:
        return "gr_emprego_ocupacao".tr;
      case 4:
        return "gr_relacionamentos".tr;
      case 5:
        return "gr_personalidade".tr;
      default:
        return "";
    }
  }
}

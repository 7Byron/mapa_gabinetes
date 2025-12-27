import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/result_template.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/rotas_paginas.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/botao_icon.dart';
import '../widgets/cartao_helpme.dart';
import '../widgets/common_text_style.dart';
import '../widgets/disclamer.dart';
import '../widgets/expanded_title.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets/help_info_button.dart';
import '../widgets/info_card_template.dart';
import '../widgets_pagina_testes/imagem_teste.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/image_value_thresholds.dart';
import '../funcoes/spacing.dart';
import '../funcoes/responsive.dart';

class TesteDependenciaResultado extends StatefulWidget {
  const TesteDependenciaResultado({super.key});

  @override
  State<TesteDependenciaResultado> createState() =>
      _TesteDependenciaResultadoState();
}

class _TesteDependenciaResultadoState extends State<TesteDependenciaResultado> {
  final int _teste = Get.arguments[0];
  final double _resultado = Get.arguments[1];
  late String _resultPercent = "";

  Color _getCardColor() {
    if (_resultado < _teste * .10) return Colors.amber.shade50;
    if (_resultado < _teste * .25) return Colors.amber.shade200;
    if (_resultado < _teste * .40) return Colors.amber.shade300;
    return Colors.amber.shade500;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _processarResultado();
  }

  void _processarResultado() async {
    final percent = ((_resultado * 100) / _teste).toStringAsFixed(0);
    setState(() {
      _resultPercent = percent.padLeft(3, '0');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ResultPageTemplate(
      appBarTitle: "_tDependencia".tr,
      appBarImage: RotaImagens.logoDependencia,
      buildResultCard: (context) => _buildResultCard(context),
      buildInfoCard: (context) => _buildInfoCard(context),
      middleWidgets: [CartaoHelpMe()],
    );
  }

  Widget _buildResultCard(BuildContext context) {
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
        color: _getCardColor(),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Spacing.l, vertical: Spacing.xs),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ImageForValues(
                    percentual: double.parse(_resultPercent),
                    valueImages: ImageThresholds.dependencia,
                  ),
                  Reuse.myWidthBox050,
                  Text(
                    "${int.parse(_resultPercent)}%",
                    style: TextStyle(
                      fontSize: ResponsiveConfig.of(context).clampFont(MyG.to.margem),
                      fontStyle: FontStyle.italic,
                      color: Colors.brown,
                    ),
                  ),
                ],
              ),
              Reuse.myHeigthBox050,
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: MyCustomText(
                      text: _resultado < _teste * .10
                          ? "R1T".tr
                          : _resultado < _teste * .25
                              ? "R2T".tr
                              : _resultado < _teste * .40
                                  ? "R3T".tr
                                  : "R4T".tr,
                      color: Colors.brown,
                      fontSize: MyG.to.margens['margem085']!,
                      fontWeight: FontWeight.bold,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Reuse.myWidthBox025,
                  HelpInfoButton(
                    title: "escala".tr,
                    text:
                        "\n${"_SobreTesteDependencia".tr} \n\n<10%    ${"R1T".tr}\n10-25% ${"R2T".tr}\n25-40% ${"R3T".tr} \n>40%    ${"R4T".tr}",
                  ),
                ],
              ),
              Reuse.myHeigthBox050,
              AutoSizeText(
                _resultado < _teste * .10
                    ? "R1".tr
                    : _resultado < _teste * .25
                        ? "R2".tr
                        : _resultado < _teste * .40
                            ? "R3".tr
                            : "R4".tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.brown,
                  fontSize: MyG.to.margens['margem075']!,
                ),
              ),
              Reuse.myHeigthBox025,
              disclaimer(),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: MyG.to.margens['margem1']!),
                child: MyBotaoIcon(
                  onPressed: () {
                    Get.toNamed(RotasPaginas.testeDependencia, arguments: 90);
                  },
                  titulo: "testecompleto".tr,
                  linhas: 2,
                  myIcon: Icons.directions_walk_outlined,
                ),
              ),
              Reuse.myHeigthBox050,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return InfoCardTemplate(
      title: "_SobreDependenciaTitulo".tr,
      children: [
        MyTitleExpanded(
          titulo: "DEF_T".tr,
          texto: "DEF".tr,
        ),
        MyTitleExpanded(
          titulo: "CAUSA_T".tr,
          texto: "CAUSA".tr,
        ),
        MyTitleExpanded(
          titulo: "SINTOMAS_T".tr,
          texto: "SINTOMAS".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT1_T".tr,
          texto: "TRAT1".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT2_T".tr,
          texto: "TRAT2".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT3_T".tr,
          texto: "TRAT3".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT4_T".tr,
          texto: "TRAT4".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT5_T".tr,
          texto: "TRAT5".tr,
        ),
        MyTitleExpanded(
          titulo: "TRAT6_T".tr,
          texto: "TRAT6".tr,
        ),
        Reuse.myHeigthBox050,
      ],
    );
  }

  Future<dynamic> dialogOK(
      BuildContext context, String titulo, String mensagem, double margem) {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: MyG.to.margens['margem085']!,
                fontWeight: FontWeight.bold),
          ),
          content: Text(
            mensagem,
            style: TextStyle(fontSize: margem * .65),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
              ),
              child: Text(
                "Ok".tr,
                style: TextStyle(
                    fontSize: MyG.to.margens['margem085']!,
                    color: Colors.black),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

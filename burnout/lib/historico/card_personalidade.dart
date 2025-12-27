import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../funcoes/theme_tokens.dart';

class CardPersonalidade extends StatelessWidget {
  final TesteModel teste;

  const CardPersonalidade({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final String historico = teste.historico;

    // Extrair os valores do histórico no formato `a15b15c27d15e28f`
    final RegExp regex = RegExp(r'([a-z])(\d+)');
    final Iterable<Match> matches = regex.allMatches(historico);

    int ext = 0, ama = 0, con = 0, neu = 0, abe = 0;

    for (var match in matches) {
      final String key = match.group(1)!;
      final int value = int.parse(match.group(2)!);

      switch (key) {
        case 'a':
          ext = value;
          break;
        case 'b':
          ama = value;
          break;
        case 'c':
          con = value;
          break;
        case 'd':
          neu = value;
          break;
        case 'e':
          abe = value;
          break;
      }
    }

    final double barra100 = Get.width - MyG.to.margens['margem4']!;
    final double extValue = ext < 0 ? 0 : ((ext * barra100) / 100);
    final double amaValue = ama < 0 ? 0 : ((ama * barra100) / 100);
    final double conValue = con < 0 ? 0 : ((con * barra100) / 100);
    final double neuValue = neu < 0 ? 0 : ((neu * barra100) / 100);
    final double abeValue = abe < 0 ? 0 : ((abe * barra100) / 100);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margens['margem05']!),
        child: Column(
          children: [
            Text(
              data,
              style: TextStyle(
                fontSize: MyG.to.margens['margem085'],
                color: Colors.brown,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _barrasRespostas(
              context,
              MyG.to.margem,
              Colors.cyan,
              Colors.cyan.shade100,
              Colors.cyan.shade900,
              extValue,
              "5_e".tr,
              ext < 0 ? 0 : ext.toDouble(),
            ),
            _barrasRespostas(
              context,
              MyG.to.margem,
              Colors.green,
              Colors.green.shade100,
              Colors.green.shade900,
              amaValue,
              "5_a".tr,
              ama < 0 ? 0 : ama.toDouble(),
            ),
            _barrasRespostas(
              context,
              MyG.to.margem,
              Colors.yellow,
              Colors.yellow.shade100,
              Colors.yellow.shade900,
              conValue,
              "5_c".tr,
              con < 0 ? 0 : con.toDouble(),
            ),
            _barrasRespostas(
              context,
              MyG.to.margem,
              Colors.orange,
              Colors.orange.shade100,
              Colors.orange.shade900,
              neuValue,
              "5_n".tr,
              neu < 0 ? 0 : neu.toDouble(),
            ),
            _barrasRespostas(
              context,
              MyG.to.margem,
              Colors.brown,
              Colors.brown.shade100,
              Colors.brown.shade900,
              abeValue,
              "5_o".tr,
              abe < 0 ? 0 : abe.toDouble(),
            ),
            Reuse.myHeigthBox050,
          ],
        ),
      ),
    );
  }

  Widget _barrasRespostas(
    BuildContext context,
    double margem,
    Color corBarra,
    Color corFundo,
    Color corBorda,
    double tamanhoBarra,
    String titulo,
    double percentagem,
  ) {
    return Column(
      children: [
        SizedBox(
          height: MyG.to.margens['margem035'],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  height: MyG.to.margens['margem1_5'],
                  //width: Get.width - margem * 4,
                  width: Get.width > 600
                      ? MyG.to.margens['margem22']! - margem * 4
                      : Get.width - margem * 4,
                  decoration: BoxDecoration(
                      color: corFundo,
                      border: Border.all(
                        color: corFundo,
                      ),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12))),
                ),
                Container(
                  height: MyG.to.margens['margem1_5'],
                  width: tamanhoBarra,
                  decoration: BoxDecoration(
                      color: corBarra,
                      border: Border.all(
                        color: corBorda,
                      ),
                      borderRadius:
                          const BorderRadius.all(Radius.circular(12))),
                ),
                Positioned(
                  top: MyG.to.margens['margem035'],
                  left: margem * .45,
                  child: Text(
                    "$titulo ${percentagem.toStringAsFixed(0)}%",
                    style: TextStyle(fontSize: margem * .6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';

class StatusBar extends StatelessWidget {
  final String tipo;
  final int tamanhoBarra;
  final int max;
  final int grupo;

  const StatusBar({
    super.key,
    required this.tipo,
    required this.tamanhoBarra,
    required this.max,
    required this.grupo,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                Container(
                  height: MyG.to.margens['margem085']!,
                  width: MyG.to.margens['margem1']! * 12,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: Border.all(
                      color: (tipo == "G1tit".tr && grupo == 1) ||
                          (tipo == "G2tit".tr && grupo == 2) ||
                          (tipo == "G3tit".tr && grupo == 3) ||
                          (tipo == "G4tit".tr && grupo == 4) ||
                          (tipo == "G5tit".tr && grupo == 5) ||
                          (tipo == "G6tit".tr && grupo == 6) ||
                          tipo == "Inttit".tr ||
                          tipo == "Exttit".tr ||
                          tipo == "Hostil".tr
                          ? Colors.black38
                          : Colors.green.shade100,
                    ),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                Container(
                  height: MyG.to.margens['margem085']!,
                  width: (tamanhoBarra * MyG.to.margens['margem1']! * 12) / max,
                  decoration: BoxDecoration(
                    color: ((tamanhoBarra * 100) / max) < 10
                        ? Colors.blue.shade200
                        : ((tamanhoBarra * 100) / max) < 30
                        ? Colors.yellow
                        : ((tamanhoBarra * 100) / max) < 73
                        ? Colors.orange
                        : Colors.red,
                    border: Border.all(color: Colors.black12),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(left: MyG.to.margens['margem035']!),
                  child: AutoSizeText(
                    "$tipo ${(tamanhoBarra * 100) ~/ max}%",
                    style: TextStyle(
                      color: Colors.black26,
                      fontSize: MyG.to.margens['margem065']!,
                    ),
                    maxLines: 1,
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

import 'package:flutter/material.dart';
import '../historico/teste_model.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/rota_imagens.dart';
import '../widgets_pagina_testes/status_row_raiva.dart';
import '../funcoes/theme_tokens.dart';

class CardRaiva extends StatelessWidget {
  final TesteModel teste;

  const CardRaiva({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final String historico = teste.historico;

    int? valAc = _extractValue(historico, r':(\d+)');
    int? valG1 = _extractValue(historico, r'G1(\d+)');
    int? valG2 = _extractValue(historico, r'G2(\d+)');
    int? valG3 = _extractValue(historico, r'G3(\d+)');
    int? valG4 = _extractValue(historico, r'G4(\d+)');
    int? valG5 = _extractValue(historico, r'G5(\d+)');
    int? valG6 = _extractValue(historico, r'G6(\d+)');
    int? valInt = _extractValue(historico, r'Int(\d+)');
    int? valExt = _extractValue(historico, r'Ext(\d+)');
    int? valHos = _extractValue(historico, r'Hos(\d+)');

    if ([valAc, valG1, valG2, valG3, valG4, valG5, valG6, valInt, valExt, valHos].contains(null)) {
      return const Text('Invalid data');
    }

    valAc = valAc!.clamp(0, 188);
    valG1 = valG1!.clamp(0, 16);
    valG2 = valG2!.clamp(0, 32);
    valG3 = valG3!.clamp(0, 28);
    valG4 = valG4!.clamp(0, 12);
    valG5 = valG5!.clamp(0, 84);
    valG6 = valG6!.clamp(0, 12);
    valInt = valInt!.clamp(0, 92);
    valExt = valExt!.clamp(0, 44);
    valHos = valHos!.clamp(0, 36);

    final Map<String, int> valores = {
      "valG1": valG1,
      "valG2": valG2,
      "valG3": valG3,
      "valG4": valG4,
      "valG5": valG5,
      "valG6": valG6,
      "raivaInterna": valInt,
      "raivaExterna": valExt,
      "prespectivaHostil": valHos,
    };

    final int perctvalAc = valAc * 100 ~/ 188;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margem),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(MyG.to.margens['margem05']!),
              child: Column(
                children: [
                  Text(
                    data,
                    style: TextStyle(
                        fontSize: MyG.to.margens['margem075']!,
                        color: Colors.brown,
                        fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                ],
              ),
            ),
            Stack(
              children: [
                Row(
                  children: [
                    StatusRow(valores: valores, grupo: 0),
                    SizedBox(width: MyG.to.margens['margem2']!),
                  ],
                ),
                Positioned(
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        perctvalAc < 10
                            ? RotaImagens.raiva1
                            : perctvalAc < 30
                            ? RotaImagens.raiva2
                            : perctvalAc < 73
                            ? RotaImagens.logoRaiva
                            : RotaImagens.raiva4,
                        height: MyG.to.margens['margem5']!,
                      ),
                      Text(
                        "$perctvalAc %",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: MyG.to.margens['margem065']!),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  int? _extractValue(String source, String pattern) {
    final RegExp regex = RegExp(pattern);
    final Match? match = regex.firstMatch(source);
    if (match != null && match.groupCount >= 1) {
      return int.parse(match.group(1)!);
    } else {
      return null;
    }
  }
}

// widgets/card_stress.dart

import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/rota_imagens.dart';
import '../funcoes/theme_tokens.dart';
import '../funcoes/spacing.dart';

class CardStress extends StatelessWidget {
  final TesteModel teste;

  const CardStress({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;



    // Extrair números da string usando expressão regular
    final RegExp exp = RegExp(r'\d+');
    final Iterable<Match> matches = exp.allMatches(teste.historico);
    final List<int> numbers = matches.map((m) => int.parse(m.group(0)!)).toList();

    // Verificar se temos números suficientes
    if (numbers.length < 7) {
      return const Text('Invalid data');
    }

    final int valorTotal = numbers[0];
    final List<int> grupos = numbers.sublist(1, 7); // Índices de 1 a 6

    final double perc = (valorTotal * 100) / 303;

    Color? colorCard;

    if (perc <= 15) {
      colorCard = Colors.orange[50];
    } else if (perc <= 29) {
      colorCard = Colors.orange[100];
    } else if (perc <= 40) {
      colorCard = Colors.orange[200];
    } else {
      colorCard = Colors.orange[300];
    }

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      color: colorCard,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: Spacing.s, vertical: Spacing.xxl),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MyG.to.margem),
              child: AutoSizeText(
                data,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: MyG.to.margens['margem075']!,
                ),
                maxLines: 1,
              ),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  flex: 4,
                  child: AutoSizeText(
                    valorTotal < 48
                        ? "zon1".tr
                        : valorTotal < 73
                        ? "zon2".tr
                        : valorTotal < 120
                        ? "zon3".tr
                        : valorTotal < 145
                        ? "zon4".tr
                        : "zon5".tr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MyG.to.margens['margem075']!,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: AutoSizeText(
                    "${perc.toStringAsFixed(0)}%",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: MyG.to.margens['margem085']!,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                  ),
                ),
                Image.asset(
                  valorTotal < 48
                      ? RotaImagens.stress1
                      : valorTotal < 73
                      ? RotaImagens.stress2
                      : valorTotal < 120
                      ? RotaImagens.stress3
                      : valorTotal < 145
                      ? RotaImagens.logoStress
                      : RotaImagens.stress5,
                  height: MyG.to.margens['margem4']!,
                ),
                SizedBox(width: MyG.to.margem),
              ],
            ),
            const Divider(),
            Column(
              children: [
                nivelCategoriaStress(
                    "gr_estilo_vida".tr, grupos[0], MyG.to.margem),
                nivelCategoriaStress(
                    "gr_ambiente".tr, grupos[1], MyG.to.margem),
                nivelCategoriaStress(
                    "gr_sintomas".tr, grupos[2], MyG.to.margem),
                nivelCategoriaStress(
                    "gr_emprego_ocupacao".tr, grupos[3], MyG.to.margem),
                nivelCategoriaStress(
                    "gr_relacionamentos".tr, grupos[4], MyG.to.margem),
                nivelCategoriaStress(
                    "gr_personalidade".tr, grupos[5], MyG.to.margem),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Card nivelCategoriaStress(String titulo, int valor, double margem) {
    final Color cardColor = valor < 8
        ? Colors.blue.shade200
        : valor < 12
        ? Colors.green.shade200
        : valor < 18
        ? Colors.yellow.shade200
        : valor < 22
        ? Colors.orange.shade200
        : Colors.red.shade400;

    final String zoneText = valor < 8
        ? "zon1".tr
        : valor < 12
        ? "zon2".tr
        : valor < 18
        ? "zon3".tr
        : valor < 22
        ? "zon4".tr
        : "zon5".tr;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeTokens.radiusLarge),
      ),
      color: cardColor,
      child: Padding(
        padding: EdgeInsets.all(MyG.to.margens['margem035']!),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem035']!),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      children: [
                        AutoSizeText(
                          titulo,
                          style: TextStyle(fontSize: MyG.to.margens['margem075']!),
                          maxLines: 1,
                        ),
                        Text(
                          zoneText,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: MyG.to.margens['margem075']!),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "${(valor * 100 / 48).toStringAsFixed(0)}%",
                      style: TextStyle(fontSize: MyG.to.margens['margem075']!),
                    ),
                  ),
                  Image.asset(
                    valor < 8
                        ? RotaImagens.stress1
                        : valor < 12
                        ? RotaImagens.stress2
                        : valor < 18
                        ? RotaImagens.stress3
                        : valor < 22
                        ? RotaImagens.logoStress
                        : RotaImagens.stress5,
                    height: MyG.to.margens['margem2']!,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

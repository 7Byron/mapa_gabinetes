// widgets/card_sorriso.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

class CardSorriso extends StatelessWidget {
  final TesteModel teste;

  const CardSorriso({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final double valor = double.parse(teste.historico);
    final int perc = (valor * 100 ~/ 15).toInt();

    Color cardColor;
    if (valor <= 7) {
      cardColor = Colors.orange[500]!;
    } else if (valor <= 10) {
      cardColor = Colors.orange[200]!;
    } else {
      cardColor = Colors.orange[50]!;
    }

    String imageIcon;
    if (valor <= 7) {
      imageIcon = RotaImagens.sorriso1;
    } else if (valor <= 10) {
      imageIcon = RotaImagens.sorriso2;
    } else {
      imageIcon = RotaImagens.logoSorriso;
    }

    String textTitle;
    if (valor <= 7) {
      textTitle = "sor.sorri1".tr;
    } else if (valor <= 10) {
      textTitle = "sor.sorri2".tr;
    } else {
      textTitle = "sor.sorri3".tr;
    }

    return CardHistoricoComum(
      data: data,
      perc: perc,
      cardColor: cardColor,
      imageAsset: imageIcon,
      statusText: textTitle,
    );
  }
}

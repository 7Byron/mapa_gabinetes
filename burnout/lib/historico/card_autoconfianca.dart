// widgets/card_autoconfianca.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

class CardAutoConfianca extends StatelessWidget {
  final TesteModel teste;

  const CardAutoConfianca({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final double valor = double.parse(teste.historico);
    final int perc = (valor * 100 ~/ 45).toInt();

    Color cardColor;
    if (valor < 16) {
      cardColor = Colors.orange[500]!;
    } else if (valor < 31) {
      cardColor = Colors.orange[200]!;
    } else {
      cardColor = Colors.orange[50]!;
    }

    String imageIcon;
    if (valor < 16) {
      imageIcon = RotaImagens.autoconfianca1;
    } else if (valor < 31) {
      imageIcon = RotaImagens.autoconfianca2;
    } else {
      imageIcon = RotaImagens.autoconfianca3;
    }

    String textTitle;
    if (valor < 16) {
      textTitle = "aut_escala_3t".tr;
    } else if (valor < 31) {
      textTitle = "aut_escala_2t".tr;
    } else {
      textTitle = "aut_escala_1t".tr;
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

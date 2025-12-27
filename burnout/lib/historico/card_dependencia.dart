// widgets/card_dependencia.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

class CardDependencia extends StatelessWidget {
  final TesteModel teste;

  const CardDependencia({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final int resultado = int.parse(teste.historico);

    Color cardColor;
    if (resultado < 10) {
      cardColor = Colors.amber.shade50;
    } else if (resultado < 25) {
      cardColor = Colors.amber.shade200;
    } else if (resultado < 40) {
      cardColor = Colors.amber.shade300;
    } else {
      cardColor = Colors.amber.shade500;
    }

    String imageIcon;
    if (resultado < 10) {
      imageIcon = RotaImagens.depEmo1;
    } else if (resultado < 25) {
      imageIcon = RotaImagens.depEmo2;
    } else if (resultado < 40) {
      imageIcon = RotaImagens.depEmo3;
    } else {
      imageIcon = RotaImagens.depEmo4;
    }

    String textTitle;
    if (resultado < 10) {
      textTitle = 'R1T'.tr;
    } else if (resultado < 25) {
      textTitle = 'R2T'.tr;
    } else if (resultado < 40) {
      textTitle = 'R3T'.tr;
    } else {
      textTitle = 'R4T'.tr;
    }

    return CardHistoricoComum(
      data: data,
      perc: resultado,
      cardColor: cardColor,
      imageAsset: imageIcon,
      statusText: textTitle,
    );
  }
}

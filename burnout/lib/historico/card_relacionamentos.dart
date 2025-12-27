// widgets/card_relacionamentos.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import 'card_historico.dart';
import '../funcoes/rota_imagens.dart';

class CardRelacionamentos extends StatelessWidget {
  final TesteModel teste;

  const CardRelacionamentos({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final double valorDouble = double.parse(teste.historico);
    final int valorInt = valorDouble.toInt();

    Color corCard;
    String imageAsset;
    String textTitle;

    if (valorInt <= 32) {
      corCard = Colors.orange[500]!;
      imageAsset = RotaImagens.rel1;
      textTitle = 'rel.escala.1t'.tr;
    } else if (valorInt <= 47) {
      corCard = Colors.orange[300]!;
      imageAsset = RotaImagens.rel2;
      textTitle = 'rel.escala.2t'.tr;
    } else if (valorInt <= 66) {
      corCard = Colors.orange[200]!;
      imageAsset = RotaImagens.rel3;
      textTitle = 'rel.escala.3t'.tr;
    } else if (valorInt <= 86) {
      corCard = Colors.orange[100]!;
      imageAsset = RotaImagens.rel4;
      textTitle = 'rel.escala.4t'.tr;
    } else {
      corCard = Colors.orange[50]!;
      imageAsset = RotaImagens.rel5;
      textTitle = 'rel.escala.5t'.tr;
    }

    return CardHistoricoComum(
      data: data,
      perc: valorInt,
      cardColor: corCard,
      imageAsset: imageAsset,
      statusText: textTitle,
    );
  }
}

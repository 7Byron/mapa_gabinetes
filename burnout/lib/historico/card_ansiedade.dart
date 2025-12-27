// widgets/card_ansiedade.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

class CardAnsiedade extends StatelessWidget {
  final TesteModel teste;

  const CardAnsiedade({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final int valor = int.parse(teste.historico);

    Color corCard;
    String imageIcon;
    String textTitle;

    final int perc = (valor * 100) ~/ 63;

    if (perc <= 11) {
      corCard = Colors.orange.shade50;
      imageIcon = RotaImagens.ans1;
      textTitle = 'Ans-10r'.tr;
    } else if (perc <= 24) {
      corCard = Colors.orange.shade100;
      imageIcon = RotaImagens.ans2;
      textTitle = 'Ans11-18r'.tr;
    } else if (perc <= 40) {
      corCard = Colors.orange.shade200;
      imageIcon = RotaImagens.logoAnsiedade;
      textTitle = 'Ans19-25r'.tr;
    } else {
      corCard = Colors.orange.shade300;
      imageIcon = RotaImagens.ans4;
      textTitle = 'Ans+26r'.tr;
    }

    return CardHistoricoComum(
      data: data,
      cardColor: corCard,
      imageAsset: imageIcon,
      perc: perc,
      statusText: textTitle,
    );
  }
}

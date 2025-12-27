
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

enum TipoDepressao { dep, dep2 }

class CardDepressaoUnificado extends StatelessWidget {
  final TesteModel teste;
  final TipoDepressao tipoDepressao;

  const CardDepressaoUnificado({
    super.key,
    required this.teste,
    required this.tipoDepressao,
  });

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final int valor = int.parse(teste.historico);

    Color corCard;
    String imageIcon;
    String textTitle;
    int perc=0;
    tipoDepressao==TipoDepressao.dep?perc = valor * 100 ~/ 63:perc = 100 - (valor * 100 ~/ 90);

    if (tipoDepressao == TipoDepressao.dep) {
      if (perc <= 10) {
        corCard = Colors.orange[50]!;
        imageIcon = RotaImagens.dep1;
        textTitle = '-10r'.tr;
      } else if (perc <= 32) {
        corCard = Colors.orange[100]!;
        imageIcon = RotaImagens.dep2;
        textTitle = '11-18r'.tr;
      } else if (perc <= 46) {
        corCard = Colors.orange[200]!;
        imageIcon = RotaImagens.logoDepressao;
        textTitle = '19-25r'.tr;
      } else {
        corCard = Colors.orange[300]!;
        imageIcon = RotaImagens.dep4;
        textTitle = '+26r'.tr;
      }
    } else {

      if (perc <= 11) {
        corCard = Colors.amber.shade50;
        imageIcon = RotaImagens.dep1;
        textTitle = '_depR1'.tr;
      } else if (perc <= 20) {
        corCard = Colors.amber.shade200;
        imageIcon = RotaImagens.dep1;
        textTitle = '_depR2'.tr;
      } else if (perc <= 24) {
        corCard = Colors.amber.shade300;
        imageIcon = RotaImagens.dep2;
        textTitle = '_depR3'.tr;
      } else if (perc <= 40) {
        corCard = Colors.amber.shade400;
        imageIcon = RotaImagens.dep2;
        textTitle = '_depR4'.tr;
      } else if (perc <= 60) {
        corCard = Colors.amber.shade500;
        imageIcon = RotaImagens.logoDepressao;
        textTitle = '_depR5'.tr;
      } else {
        corCard = Colors.amber.shade600;
        imageIcon = RotaImagens.dep4;
        textTitle = '_depR6'.tr;
      }
    }

    return CardHistoricoComum(
      data: data,
      perc: perc,
      cardColor: corCard,
      imageAsset: imageIcon,
      statusText: textTitle,
    );
  }
}

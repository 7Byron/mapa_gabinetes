// widgets/card_felicidade.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../historico/teste_model.dart';
import '../funcoes/rota_imagens.dart';
import 'card_historico.dart';

class CardFelicidade extends StatelessWidget {
  final TesteModel teste;

  const CardFelicidade({super.key, required this.teste});

  @override
  Widget build(BuildContext context) {
    final String data = teste.data;
    final int resultado = int.parse(teste.historico);
    final int perc = resultado != 0 ? (resultado * 100) ~/ 128 : 0;

    Color cardColor;
    if (resultado < 20) {
      cardColor = Colors.red.shade400;
    } else if (resultado < 40) {
      cardColor = Colors.orange.shade300;
    } else if (resultado < 60) {
      cardColor = Colors.yellow.shade300;
    } else if (resultado < 80) {
      cardColor = Colors.greenAccent.shade100;
    } else {
      cardColor = Colors.greenAccent.shade400;
    }

    String imageAsset;
    if (resultado < 20) {
      imageAsset = RotaImagens.feliz1;
    } else if (resultado < 40) {
      imageAsset = RotaImagens.feliz2;
    } else if (resultado < 60) {
      imageAsset = RotaImagens.feliz4;
    } else if (resultado <= 80) {
      imageAsset = RotaImagens.feliz3;
    } else {
      imageAsset = RotaImagens.feliz5;
    }

    String statusText;
    if (resultado <= 20) {
      statusText = 'mtinfeliz'.tr;
    } else if (resultado <= 40) {
      statusText = 'infeliz'.tr;
    } else if (resultado <= 60) {
      statusText = 'satisfatório'.tr;
    } else if (resultado <= 80) {
      statusText = 'feliz'.tr;
    } else {
      statusText = 'mtfeliz'.tr;
    }

    return CardHistoricoComum(
      data: data,
      cardColor: cardColor,
      imageAsset: imageAsset,
      perc: perc,
      statusText: statusText,
    );
  }
}
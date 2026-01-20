import 'package:flutter/material.dart';

class MedicosDisponiveisLayoutUtils {
  static double calcularAlturaMinima({
    required BuildContext context,
    required int totalMedicos,
  }) {
    if (totalMedicos == 0) {
      return 14 + 40 + 8 + 12;
    }

    final larguraTela = MediaQuery.of(context).size.width;
    final larguraCartao = 180.0;
    final spacing = 6.0;
    final paddingHorizontal = 40.0;
    final paddingInterno = 24.0;
    final larguraDisponivel = larguraTela - paddingHorizontal - paddingInterno;
    final cartoesPorLinha =
        (larguraDisponivel / (larguraCartao + spacing)).floor();
    final numLinhas =
        (totalMedicos / (cartoesPorLinha > 0 ? cartoesPorLinha : 1)).ceil();

    final alturaTitulo = 14 + 40 + 8;
    final alturaCartao = 100.0;
    final alturaCartoes = (alturaCartao * numLinhas) + (6 * (numLinhas - 1));
    final paddingBottom = 12.0;

    if (numLinhas >= 2) {
      return alturaTitulo + (alturaCartao * 2) + 6 + paddingBottom;
    }

    return alturaTitulo + alturaCartoes + paddingBottom;
  }
}

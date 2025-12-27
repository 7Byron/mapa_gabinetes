import 'package:flutter/material.dart';
import '../widgets_pagina_testes/grafico_percentagem_vertical.dart';
import '../widgets_pagina_testes/percent_color.dart';
import '../widgets_pagina_testes/valor_percentagem.dart';
import '../widgets_pagina_testes/imagem_teste.dart';

class QuestionMetricsVerticalRow extends StatelessWidget {
  final double perct;
  final List<PercentColor> percentColors;
  final List<ValueImage> valueImages;
  final int graphUnits;
  final double? imageHeight;

  const QuestionMetricsVerticalRow({
    super.key,
    required this.perct,
    required this.percentColors,
    required this.valueImages,
    required this.graphUnits,
    this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ImageForValues(
          alturaImagem: imageHeight,
          percentual: perct,
          valueImages: valueImages,
        ),
        ValorPercentagem(perct: perct),
        GraficoPercentagemVertical(
          perct: perct,
          tamanhografico: graphUnits,
          percentColors: percentColors,
        ),
      ],
    );
  }
}


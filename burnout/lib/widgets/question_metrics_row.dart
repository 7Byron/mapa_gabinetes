import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';
import '../widgets_pagina_testes/grafico_percentagem_horizontal.dart';
import '../widgets_pagina_testes/percent_color.dart';
import '../widgets_pagina_testes/valor_percentagem.dart';
import '../widgets_pagina_testes/imagem_teste.dart';

class QuestionMetricsRow extends StatelessWidget {
  final double perct;
  final List<PercentColor> percentColors;
  final List<ValueImage> valueImages;
  final int desiredUnits;
  final double barHeight;
  final double? imageWidth;
  final double? imageHeight;
  final bool imageOnRight;

  const QuestionMetricsRow({
    super.key,
    required this.perct,
    required this.percentColors,
    required this.valueImages,
    required this.desiredUnits,
    required this.barHeight,
    this.imageWidth,
    this.imageHeight,
    this.imageOnRight = false,
  });

  @override
  Widget build(BuildContext context) {
    final image = SizedBox(
      width: imageWidth,
      child: ImageForValues(
        percentual: perct,
        alturaImagem: imageHeight,
        valueImages: valueImages,
      ),
    );

    final barAndPercent = LayoutBuilder(
      builder: (context, constraints) {
        final double availableWidth = constraints.maxWidth;
        final double desiredWidth = MyG.to.margem * desiredUnits;
        final double width =
            desiredWidth > availableWidth ? availableWidth : desiredWidth;
        return Center(
          child: SizedBox(
            width: width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GraficoPercentagemHorizontal(
                  perct: perct,
                  tamanhografico: (width / MyG.to.margem).floor(),
                  heightOverride: barHeight,
                  percentColors: percentColors,
                ),
                Reuse.myHeigthBox025,
                ValorPercentagem(perct: perct),
              ],
            ),
          ),
        );
      },
    );

    return Row(
      children: imageOnRight
          ? [
              Expanded(child: barAndPercent),
              Reuse.myWidthBox050,
              image,
            ]
          : [
              image,
              Reuse.myWidthBox050,
              Expanded(child: barAndPercent),
            ],
    );
  }
}


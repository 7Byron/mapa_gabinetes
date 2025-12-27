import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import 'percent_color.dart';
import '../funcoes/spacing.dart';

class GraficoPercentagemVertical extends StatelessWidget {
  final double perct;
  final int tamanhografico;
  final List<PercentColor> percentColors;

  const GraficoPercentagemVertical({
    super.key,
    required this.perct,
    required this.percentColors,
    required this.tamanhografico,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MyG.to.margem * tamanhografico,
      width: MyG.to.margem,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MyG.to.margem * tamanhografico,
              width: MyG.to.margem,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: const BorderRadius.all(
                  Radius.circular(6),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(Spacing.xs),
              child: FractionallySizedBox(
                heightFactor: perct / 100,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: _getProgressBarColor(perct),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(6),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black87.withAlpha((0.18 * 255).toInt()),
                        spreadRadius: 1,
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressBarColor(double percentual) {
    for (final percentColor in percentColors) {
      if (percentual <= percentColor.limit) {
        return percentColor.color;
      }
    }
    return percentColors.last.color;
  }
}

// PercentColor movido para percent_color.dart (reutilizável)

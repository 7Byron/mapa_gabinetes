import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import 'percent_color.dart';

class GraficoPercentagemHorizontal extends StatelessWidget {
  final double perct;
  final int tamanhografico;
  final List<PercentColor> percentColors;
  final double? heightOverride;

  const GraficoPercentagemHorizontal({
    super.key,
    required this.perct,
    required this.percentColors,
    required this.tamanhografico,
    this.heightOverride,
  });

  @override
  Widget build(BuildContext context) {
    final bool isWide = MediaQuery.of(context).size.width >= 1024;
    final double heightScale = isWide ? 0.9 : 1.0;
    // Garante uma altura mínima visível para evitar aspecto de "linha"
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    final double base =
        isShortScreen ? MyG.to.margens['margem025']! : MyG.to.margem;
    final double barHeight =
        (heightOverride ?? (base * heightScale)).clamp(10.0, 36.0).toDouble();
    final bool lightShadow = barHeight > 14 && !isShortScreen;
    // Padding interno fixo (px) para garantir que a barra colorida fica dentro da "grelha"
    const double innerPadding = 2.0;
    return Stack(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: barHeight,
            width: MyG.to.margem * tamanhografico,
              decoration: BoxDecoration(
              border: Border.all(color: Colors.black12),
              borderRadius: const BorderRadius.all(
                Radius.circular(6),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.all(innerPadding),
            child: Container(
              width: ((perct / 100) *
                      ((MyG.to.margem * tamanhografico) - (innerPadding * 2)))
                  .clamp(0.0, double.infinity),
              height: (barHeight - innerPadding * 2).clamp(0.0, double.infinity),
              decoration: BoxDecoration(
                color: _getProgressBarColor(perct),
                borderRadius: const BorderRadius.all(
                  Radius.circular(6),
                ),
                boxShadow: lightShadow
                    ? [
                        BoxShadow(
                          color: Colors.black87.withAlpha((0.18 * 255).toInt()),
                          spreadRadius: 2,
                          blurRadius: 3,
                        ),
                      ]
                    : const [],
              ),
            ),
          ),
        ),
      ],
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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../funcoes/variaveis_globais.dart';

class Botoes5Resposta extends StatefulWidget {
  final Function(int) onSelectedResponse;

  const Botoes5Resposta({
    super.key,
    required this.onSelectedResponse,
  });

  @override
  Botoes5RespostaState createState() => Botoes5RespostaState();
}

class Botoes5RespostaState extends State<Botoes5Resposta> {
  int _selectedIndex = -1;

  @override
  Widget build(BuildContext context) {
    // Tamanhos base
    final bool isShortScreen = MediaQuery.of(context).size.height < 800;
    final double baseGapBase = MyG.to.margens['margem01']!;
    // Largura da borda do círculo (usada para compensar altura total)
    const double circleBorderWidth = 2.0;
    const double offMaiorBase = -16;
    const double offMenorBase = -6;
    const double offZeroBase = 0;
    final double circleRadiusBase = MyG.to.margens['margem1_25']!;
    final double circleDiameterBase = circleRadiusBase * 2;
    final double labelHeightBase = MyG.to.margens['margem1_25']!;

    // Escala leve para ecrãs curtos
    final double shortScreenScale = isShortScreen ? 0.88 : 1.0;

    return LayoutBuilder(builder: (context, c) {
      // Altura alvo (tamanhos base)
      final double targetHeight =
          circleDiameterBase + baseGapBase + labelHeightBase;
      // Escala para caber no espaço disponível
      final double constraintScale =
          (c.maxHeight / targetHeight).clamp(0.7, 1.0);
      final double scale = (shortScreenScale * constraintScale).clamp(0.7, 1.0);

      final double circleRadius = circleRadiusBase * scale;
      final double circleDiameter = circleRadius * 2;
      // Margem de segurança para evitar overflows mínimos
      const double safetyPx = 2.0;
      double baseGap = (baseGapBase * scale * 0.9) - (safetyPx / 2);
      double labelHeight = (labelHeightBase * scale) - safetyPx;
      // Estimativa da altura ocupada (considera a borda do círculo)
      final double estimatedHeight =
          (circleDiameter + (circleBorderWidth * 2)) + baseGap + labelHeight;
      // Se faltar espaço, reduzimos a altura da legenda para caber
      if (estimatedHeight > c.maxHeight) {
        final double excess = estimatedHeight - c.maxHeight;
        // Reduzimos primeiro a legenda; se necessário, um pouco do gap
        final double reduceFromLabel = excess.clamp(0.0, labelHeight);
        labelHeight -= reduceFromLabel;
        final double remaining = excess - reduceFromLabel;
        if (remaining > 0) {
          baseGap = (baseGap - remaining).clamp(0.0, baseGap);
        }
      }
      // Altura final do palco não pode ultrapassar a disponível
      final double palcoHeight =
          (circleDiameter + (circleBorderWidth * 2)) + baseGap + labelHeight;
      final double offMaior = offMaiorBase * scale;
      final double offMenor = offMenorBase * scale;
      final double offZero = offZeroBase * scale;

      return Column(
        children: [
          SizedBox(
            height: palcoHeight,
            width: double.infinity,
            child: Padding(
              padding: EdgeInsets.zero,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offZero),
                            child: _buildScaleEntry(
                              Colors.indigo,
                              _getValueForIndex(0),
                              radiusOverride: circleRadius,
                            ),
                          ),
                          SizedBox(height: baseGap),
                          Transform.translate(
                            offset: Offset(0, offZero),
                            child: SizedBox(
                              height: labelHeight,
                              child: _buildAlignedLabel('nunca'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offMenor),
                            child: _buildScaleEntry(
                              Colors.cyan,
                              _getValueForIndex(1),
                              radiusOverride: circleRadius,
                            ),
                          ),
                          SizedBox(height: baseGap),
                          Transform.translate(
                            offset: Offset(0, offMenor),
                            child: SizedBox(
                              height: labelHeight,
                              child: _buildAlignedLabel('raramente'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offMaior),
                            child: _buildScaleEntry(
                              Colors.green,
                              _getValueForIndex(2),
                              radiusOverride: circleRadius,
                            ),
                          ),
                          SizedBox(height: baseGap),
                          Transform.translate(
                            offset: Offset(0, offMaior),
                            child: SizedBox(
                              height: labelHeight,
                              child: _buildAlignedLabel('algumas'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offMenor),
                            child: _buildScaleEntry(
                              Colors.yellow,
                              _getValueForIndex(3),
                              radiusOverride: circleRadius,
                            ),
                          ),
                          SizedBox(height: baseGap),
                          Transform.translate(
                            offset: Offset(0, offMenor),
                            child: SizedBox(
                              height: labelHeight,
                              child: _buildAlignedLabel('frequente'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Transform.translate(
                            offset: Offset(0, offZero),
                            child: _buildScaleEntry(
                              Colors.red,
                              _getValueForIndex(4),
                              radiusOverride: circleRadius,
                            ),
                          ),
                          SizedBox(height: baseGap),
                          Transform.translate(
                            offset: Offset(0, offZero),
                            child: SizedBox(
                              height: labelHeight,
                              child: _buildAlignedLabel('sempre'.tr),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  int _getValueForIndex(int index) {
    return index;
  }

  Widget _buildScaleEntry(Color color, int value, {double? radiusOverride}) {
    final bool isSelected = _selectedIndex == value;
    final bool isShortScreen = MediaQuery.of(context).size.height < 800;
    final double shortScale = isShortScreen ? 0.88 : 1.0;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = value;
        });

        widget.onSelectedResponse(value);

        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          setState(() => _selectedIndex = -1);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.brown,
            width: 2.0,
          ),
          boxShadow: !isSelected
              ? [
                  const BoxShadow(
                    color: Colors.black45,
                    offset: Offset(0, 6),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: CircleAvatar(
          backgroundColor: Colors.transparent,
          radius:
              radiusOverride ?? (MyG.to.margens['margem1_25']! * shortScale),
        ),
      ),
    );
  }

  Widget _buildAlignedLabel(String label) {
    final bool isShortScreen = MediaQuery.of(context).size.height < 800;
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity,
          child: AutoSizeText(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MyG.to.margens['margem065']!, // aumenta legendas
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.brown
                  : Colors.white,
            ),
            // AutoSizeText requer que maxFontSize seja múltiplo de stepGranularity.
            // Arredondamos para garantir compatibilidade e evitar asserções.
            maxFontSize: MyG.to.margens['margem065']!.floorToDouble(),
            minFontSize: isShortScreen ? 7 : 9,
            // Permite variações finas e compatíveis com valores não inteiros.
            stepGranularity: 0.1,
            maxLines: 2,
            // Garante que palavras não sejam cortadas
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'dart:math' as math;

import '../funcoes/variaveis_globais.dart';

class ImageForValues extends StatelessWidget {
  final double percentual;
  final List<ValueImage> valueImages;
  final double? alturaImagem;

  const ImageForValues({
    super.key,
    required this.percentual,
    required this.valueImages,
    this.alturaImagem,
  });

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final bool reduceMotion = size.height < 700 || size.width < 360;
    final Widget image = _getImageForPercentual(percentual);

    if (reduceMotion) {
      // Evita animações pesadas em ecrãs mais pequenos/menos potentes
      return image;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: WidgetAnimator(
        key: ValueKey<double>(percentual),
        atRestEffect: WidgetRestingEffects.wave(
          effectStrength: 0.2,
          duration: const Duration(seconds: 20),
        ),
        child: image,
      ),
    );
  }

  Widget _getImageForPercentual(double percentual) {
    final double imageHeight = alturaImagem ?? MyG.to.margens['margem4']!;

    for (final valueImage in valueImages) {
      if (percentual <= valueImage.limit) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final int targetWidth = math.max(
              1,
              (imageHeight * MediaQuery.of(context).devicePixelRatio).round(),
            );
            return Image.asset(
              valueImage.imagePath,
              height: imageHeight,
              cacheWidth: targetWidth,
            );
          },
        );
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int targetWidth = math.max(
          1,
          (imageHeight * MediaQuery.of(context).devicePixelRatio).round(),
        );
        return Image.asset(
          valueImages.last.imagePath,
          height: imageHeight,
          cacheWidth: targetWidth,
        );
      },
    );
  }
}

class ValueImage {
  final int limit;
  final String imagePath;

  ValueImage({
    required this.limit,
    required this.imagePath,
  });
}

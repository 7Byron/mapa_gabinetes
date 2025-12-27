import 'package:flutter/widgets.dart';

class ResponsiveConfig {
  final Size size;
  final double factor;

  ResponsiveConfig._(this.size, this.factor);

  factory ResponsiveConfig.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Base de referência: 390x780 (telefones comuns)
    final double reference = 390.0;
    final double minSide = size.shortestSide; // reação progressiva
    // fator contínuo e limitado
    final double f = (minSide / reference).clamp(0.6, 1.8);
    return ResponsiveConfig._(size, f);
  }

  double px(double base) => base * factor;
  double font(double base) => base * factor;
  double icon(double base) => base * factor;
  double height(double base) => base * factor;

  double get spacingSmall => px(8);
  double get spacingMedium => px(16);
  double get spacingLarge => px(24);

  double get buttonHeight => height(56);
  double get logoHeight => size.height * 0.12;

  double get contentMaxWidth =>
      (size.width * 0.92) < 640.0 ? (size.width * 0.92) : 640.0;

  double clampFont(double value) {
    final bool isTablet = size.shortestSide >= 600;
    final double max = isTablet ? 22.0 : 18.0;
    return value.clamp(8.0, max);
  }

  double get textScale => factor;
  double get buttonHeightScale => factor;
}

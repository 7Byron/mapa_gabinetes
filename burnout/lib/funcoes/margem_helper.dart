import 'variaveis_globais.dart';

class Margem {
  static double get base => MyG.to.margem;

  static double get xs => MyG.to.margem025;
  static double get sm => MyG.to.margem05;
  static double get md => MyG.to.margem1;
  static double get lg => MyG.to.margem2;
  static double get xl => MyG.to.margem3;
  static double get xxl => MyG.to.margem5;

  static double get micro => MyG.to.margem01;
  static double get tiny => MyG.to.margem025;
  static double get small => MyG.to.margem05;
  static double get medium => MyG.to.margem1;
  static double get large => MyG.to.margem2;
  static double get huge => MyG.to.margem5;
  static double get massive => MyG.to.margem10;

  static double get containerWidth => MyG.to.margem22;
  static double get maxContent => MyG.to.margem18;
  static double get cardPadding => MyG.to.margem1;
  static double get iconSize => MyG.to.margem1_25;
  static double get buttonHeight => MyG.to.margem2_5;
}

extension MargemQuick on double {
  double get margem => this * MyG.to.margem;
}

class MargemConstantes {
  static const double defaultIconSize = 24.0;
  static const double defaultButtonHeight = 48.0;
  static const double defaultCardRadius = 12.0;

  static late final double responsiveIconSize;
  static late final double responsiveButtonHeight;
  static late final double responsiveCardRadius;

  static void calcular() {
    responsiveIconSize = MyG.to.margem1_25;
    responsiveButtonHeight = MyG.to.margem2_5;
    responsiveCardRadius = MyG.to.margem065;
  }
}

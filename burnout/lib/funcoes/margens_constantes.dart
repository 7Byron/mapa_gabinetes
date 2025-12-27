import 'package:flutter/material.dart';

/// Sistema de margens otimizado para melhor performance
/// Evita recálculos desnecessários usando valores constantes
class MargensConstantes {
  // Valores base
  static const double base = 10.0;

  // Margens fixas mais utilizadas
  static const EdgeInsets padding05 = EdgeInsets.all(5.0);
  static const EdgeInsets padding10 = EdgeInsets.all(10.0);
  static const EdgeInsets padding15 = EdgeInsets.all(15.0);
  static const EdgeInsets padding20 = EdgeInsets.all(20.0);

  static const EdgeInsets paddingHorizontal05 =
      EdgeInsets.symmetric(horizontal: 5.0);
  static const EdgeInsets paddingHorizontal10 =
      EdgeInsets.symmetric(horizontal: 10.0);
  static const EdgeInsets paddingHorizontal15 =
      EdgeInsets.symmetric(horizontal: 15.0);

  static const EdgeInsets paddingVertical05 =
      EdgeInsets.symmetric(vertical: 5.0);
  static const EdgeInsets paddingVertical10 =
      EdgeInsets.symmetric(vertical: 10.0);
  static const EdgeInsets paddingVertical15 =
      EdgeInsets.symmetric(vertical: 15.0);

  // SizedBoxes constantes para espaçamento
  static const SizedBox heightBox5 = SizedBox(height: 5.0);
  static const SizedBox heightBox10 = SizedBox(height: 10.0);
  static const SizedBox heightBox15 = SizedBox(height: 15.0);
  static const SizedBox heightBox20 = SizedBox(height: 20.0);
  static const SizedBox heightBox25 = SizedBox(height: 25.0);
  static const SizedBox heightBox30 = SizedBox(height: 30.0);

  static const SizedBox widthBox5 = SizedBox(width: 5.0);
  static const SizedBox widthBox10 = SizedBox(width: 10.0);
  static const SizedBox widthBox15 = SizedBox(width: 15.0);
  static const SizedBox widthBox20 = SizedBox(width: 20.0);

  // Bordas constantes
  static const BorderRadius borderRadius10 =
      BorderRadius.all(Radius.circular(10.0));
  static const BorderRadius borderRadius15 =
      BorderRadius.all(Radius.circular(15.0));
  static const BorderRadius borderRadius20 =
      BorderRadius.all(Radius.circular(20.0));
  static const BorderRadius borderRadius30 =
      BorderRadius.all(Radius.circular(30.0));

  // Sombras constantes
  static const List<BoxShadow> sombraPequena = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4.0,
      offset: Offset(0.0, 2.0),
    ),
  ];

  static const List<BoxShadow> sombraMedia = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8.0,
      offset: Offset(0.0, 4.0),
    ),
  ];

  static const List<BoxShadow> sombraGrande = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 20.0,
      offset: Offset(0.0, 5.0),
    ),
  ];

  // Divisor constante
  static const Widget divisor = Column(
    children: [
      heightBox5,
      Divider(
        height: 8,
        thickness: 1,
        indent: 20,
        endIndent: 20,
        color: Colors.grey,
      ),
      heightBox5,
    ],
  );

  // Gradientes comuns
  static const LinearGradient gradienteAmbar = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.orangeAccent, Colors.amber],
  );
}

/// Extension para facilitar o uso das margens responsivas
extension ResponsiveMargem on double {
  /// Converte um valor base para margin responsiva
  double get responsiva => this * MargensConstantes.base * 0.1;

  /// Cria um SizedBox com altura responsiva
  SizedBox get alturaBox => SizedBox(height: responsiva);

  /// Cria um SizedBox com largura responsiva
  SizedBox get larguraBox => SizedBox(width: responsiva);

  /// Cria um EdgeInsets simétrico responsivo
  EdgeInsets get paddingTodos => EdgeInsets.all(responsiva);

  /// Cria um EdgeInsets horizontal responsivo
  EdgeInsets get paddingHorizontal =>
      EdgeInsets.symmetric(horizontal: responsiva);

  /// Cria um EdgeInsets vertical responsivo
  EdgeInsets get paddingVertical => EdgeInsets.symmetric(vertical: responsiva);
}

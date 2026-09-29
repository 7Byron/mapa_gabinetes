import 'package:flutter/material.dart';

/// Posiciona um único cartão pela hora de início, numa escala comum de 08–20h.
/// Vários cartões ficam em sequência; conteúdos altos continuam acessíveis.
class CartoesGabineteLayout extends StatelessWidget {
  final String? horarioInicio;
  final List<Widget> children;

  const CartoesGabineteLayout({
    super.key,
    this.horarioInicio,
    required this.children,
  });

  double get _posicaoVertical {
    if (children.length != 1) return -1;
    final partes = horarioInicio?.split(':');
    if (partes == null || partes.length != 2) return -1;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null ||
        minuto == null ||
        hora < 0 ||
        hora > 23 ||
        minuto < 0 ||
        minuto > 59) {
      return -1;
    }
    final fracao = ((hora * 60 + minuto - 8 * 60) / (12 * 60)).clamp(0.0, 1.0);
    return fracao * 2 - 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Align(
            alignment: Alignment(0, _posicaoVertical),
            heightFactor: 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

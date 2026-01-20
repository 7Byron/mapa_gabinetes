import 'package:flutter/material.dart';
import '../widgets/layout_responsivo_toggle.dart';
import '../widgets/zoomable_container.dart';

class LayoutResponsivoAlocacao extends StatelessWidget {
  final bool mostrarColunaEsquerda;
  final VoidCallback onMostrarFiltros;
  final VoidCallback onMostrarMapa;
  final Widget colunaEsquerda;
  final Widget colunaDireita;
  final double zoomLevel;

  const LayoutResponsivoAlocacao({
    super.key,
    required this.mostrarColunaEsquerda,
    required this.onMostrarFiltros,
    required this.onMostrarMapa,
    required this.colunaEsquerda,
    required this.colunaDireita,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutResponsivoToggle(
          mostrarColunaEsquerda: mostrarColunaEsquerda,
          onMostrarFiltros: onMostrarFiltros,
          onMostrarMapa: onMostrarMapa,
        ),
        Expanded(
          child: mostrarColunaEsquerda
              ? colunaEsquerda
              : ZoomableContainer(
                  zoomLevel: zoomLevel,
                  child: colunaDireita,
                ),
        ),
      ],
    );
  }
}

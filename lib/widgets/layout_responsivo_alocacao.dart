import 'package:flutter/material.dart';
import '../widgets/layout_responsivo_toggle.dart';
import '../widgets/zoomable_container.dart';
import '../utils/app_colors.dart';
import 'painel_lateral_tema.dart';

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
              ? Theme(
                  data: temaPainelLateral(context),
                  child: Material(
                      color: AppColors.navegacao,
                      child: SingleChildScrollView(child: colunaEsquerda)))
              : ZoomableContainer(
                  zoomLevel: zoomLevel,
                  child: colunaDireita,
                ),
        ),
      ],
    );
  }
}

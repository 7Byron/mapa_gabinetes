import 'package:flutter/material.dart';
import '../widgets/zoomable_container.dart';
import '../utils/app_colors.dart';
import 'painel_lateral_tema.dart';

class LayoutDesktopAlocacao extends StatelessWidget {
  final Widget colunaEsquerda;
  final Widget colunaDireita;
  final double zoomLevel;

  const LayoutDesktopAlocacao({
    super.key,
    required this.colunaEsquerda,
    required this.colunaDireita,
    required this.zoomLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 264,
          child: Theme(
              data: temaPainelLateral(context),
              child: Material(
                  color: AppColors.navegacao,
                  child: SingleChildScrollView(child: colunaEsquerda))),
        ),
        Expanded(
          child: ZoomableContainer(
            zoomLevel: zoomLevel,
            child: colunaDireita,
          ),
        ),
      ],
    );
  }
}

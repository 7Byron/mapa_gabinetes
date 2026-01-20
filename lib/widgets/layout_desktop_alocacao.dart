import 'package:flutter/material.dart';
import '../widgets/zoomable_container.dart';

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
        Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: SingleChildScrollView(
            child: colunaEsquerda,
          ),
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

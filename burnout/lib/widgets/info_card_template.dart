import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import '../widgets/itens_reutilizaveis.dart';

class InfoCardTemplate extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final double? topPadding;

  const InfoCardTemplate({
    super.key,
    required this.title,
    required this.children,
    this.topPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.0), // Bordas arredondadas
        boxShadow: Reuse.mySombraContainer.boxShadow,
      ),
      clipBehavior: Clip.antiAlias, // Garante que a sombra siga o borderRadius
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0), // Mesmo borderRadius
        ),
        color: Theme.of(context).brightness == Brightness.light
            ? Colors.amber.shade100
            : Colors.black38,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: MyG.to.margens['margem1']!),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: topPadding ?? MyG.to.margens['margem1']!,
                ),
                child: Column(
                  children: [
                    Text(title, style: Reuse.myTitulo),
                    Reuse.myDivider,
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

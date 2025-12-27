import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/margens_constantes.dart';

class TestCardContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? outerPadding;
  final EdgeInsetsGeometry? innerPadding;

  const TestCardContainer({
    super.key,
    required this.child,
    this.outerPadding,
    this.innerPadding,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? Colors.grey.shade800 : Colors.white;

    return Padding(
      padding: outerPadding ?? EdgeInsets.all(MyG.to.margens['margem05']!),
      child: Card(
        elevation: 0, // Remove a elevação padrão do Card
        color: cardColor, // Adapta a cor ao tema
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0), // Bordas arredondadas
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardColor, // Adapta a cor ao tema
            borderRadius: BorderRadius.circular(
                16.0), // Mesmo borderRadius para a sombra seguir
            boxShadow: MargensConstantes.sombraMedia,
          ),
          clipBehavior:
              Clip.antiAlias, // Garante que a sombra siga o borderRadius
          child: Padding(
            padding:
                innerPadding ?? EdgeInsets.all(MyG.to.margens['margem05']!),
            child: child,
          ),
        ),
      ),
    );
  }
}

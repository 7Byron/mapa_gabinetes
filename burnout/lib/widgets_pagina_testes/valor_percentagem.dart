import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class ValorPercentagem extends StatelessWidget {
  final double perct;

  const ValorPercentagem({
    super.key,
    required this.perct,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    return SizedBox(
      width: MyG.to.margens['margem3']!,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: animation,
            child: child,
          );
        },
        child: AutoSizeText(
          "${perct.toStringAsFixed(1)} %",
          key: ValueKey<double>(perct.toDouble()),
          maxLines: 1,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: r.clampFont(r.font(14)),
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.brown
                : Colors.white,
          ),
        ),
      ),
    );
  }
}

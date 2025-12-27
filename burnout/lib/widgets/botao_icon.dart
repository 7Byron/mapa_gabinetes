import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class MyBotaoIcon extends StatelessWidget {
  final String titulo;
  final int linhas;
  final IconData myIcon;
  final void Function() onPressed;
  final double? verticalPadding;
  final double? height;

  const MyBotaoIcon({
    super.key,
    required this.onPressed,
    required this.titulo,
    required this.linhas,
    required this.myIcon,
    this.verticalPadding,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    return Padding(
      padding:
          EdgeInsets.symmetric(vertical: verticalPadding ?? r.spacingMedium),
      child: Container(
        height: (height ?? r.buttonHeight).clamp(40.0, 64.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x80000000),
              blurRadius: 20.0,
              offset: Offset(0.0, 5.0),
            ),
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          elevation: 6.0,
          color: Colors.transparent,
          shadowColor: Colors.grey[50],
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                        MyG.to.margens['margem1']!,
                        MyG.to.margens['margem01']!,
                        MyG.to.margens['margem025']!,
                        MyG.to.margens['margem01']!),
                    child: Icon(myIcon, color: Colors.brown, size: r.icon(28)),
                  ),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: r.spacingSmall),
                        child: AutoSizeText(titulo,
                            style: TextStyle(
                              fontSize: r.clampFont(r.font(18)),
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.brown
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: linhas),
                      ),
                    ),
                  ),
                  SizedBox(width: MyG.to.margens['margem05']!),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../funcoes/variaveis_globais.dart';
import '../funcoes/responsive.dart';

class MyBotaoImagem extends StatelessWidget {
  final String titulo;
  final String imagem;
  final void Function() onPressed;

  const MyBotaoImagem({
    super.key,
    required this.onPressed,
    required this.titulo,
    required this.imagem,
  });

  @override
  Widget build(BuildContext context) {
    final r = ResponsiveConfig.of(context);
    final double screenH = MediaQuery.of(context).size.height;
    final bool isShortScreen = screenH < 800;
    final double buttonHeight =
        (r.buttonHeight.clamp(40.0, 64.0)) * (isShortScreen ? 0.85 : 1.0);
    final double imageHeight =
        (MyG.to.margens['margem2']!) * (isShortScreen ? 0.85 : 1.0);
    final double fontSize = r.clampFont(r.font(18));
    return Padding(
      padding: EdgeInsets.symmetric(vertical: MyG.to.margens['margem05']!),
      child: Container(
        height: buttonHeight,
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
              Theme.of(context).colorScheme.primary,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      MyG.to.margens['margem05']!,
                      MyG.to.margens['margem01']!,
                      MyG.to.margens['margem025']!,
                      MyG.to.margens['margem01']!,
                    ),
                    child: Image.asset(
                      imagem,
                      height: imageHeight,
                      cacheWidth: math.max(
                        1,
                        (imageHeight *
                                MediaQuery.of(context).devicePixelRatio)
                              .round(),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MyG.to.margens['margem025']!),
                      child: AutoSizeText(
                        titulo,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimary, // Usa a cor de texto primária do tema
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
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
